//===-- RL78TargetMachine.cpp - Define TargetMachine for RL78 -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

#include "RL78TargetMachine.h"
#include "RL78TargetObjectFile.h"
#include "RL78MachineFunctionInfo.h"
#include "RL78TargetTransformInfo.h"
#include "RL78InsertNOPWithLabel.h"
#include "RL78GenSet1Clr1Intrin.h"
#include "TargetInfo/RL78TargetInfo.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/CodeGen/MachineScheduler.h"
#include "llvm/CodeGen/ScheduleDAGMutation.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Transforms/InstCombine/InstCombine.h"
#include "llvm/Transforms/Scalar.h"
#include "llvm/Transforms/Scalar/LoopFlatten.h"
#include "llvm/Transforms/Scalar/LoopPassManager.h"
#include "llvm/Transforms/Scalar/LoopUnrollAndJamPass.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "RL78TargetMachine"

using namespace llvm;

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRL78Target() {
  // Register the target.
  RegisterTargetMachine<RL78TargetMachine> X(getTheRL78Target());
  auto *PR = PassRegistry::getPassRegistry();
  initializeRL78DAGToDAGISelLegacyPass(*PR);
  initializeRL78ExpandInlineAsmPass(*PR);
  initializeRL78NarrowDemandedOpsPass(*PR);
  initializeRL78NarrowLoopCountersPass(*PR);
  initializeRL78ByteLoopCountersPass(*PR);
  initializeRL78OuterLoopPointersPass(*PR);
  initializeRL78UnspeculateLoopLatchPass(*PR);
  initializeRL78BiasSignedComparesPass(*PR);
  initializeRL78SlotOperandsPass(*PR);
  initializeRL78LateReorderPass(*PR);
  initializeRL78LoadLateStoreEarlyPass(*PR);
}

static std::string computeDataLayout(const Triple &T, StringRef FS) {

  size_t FarFlagPos = FS.rfind("+far-code");
  size_t NearFlagPos = FS.rfind("+near-code");

  const auto farCodeModel =
      FarFlagPos != StringRef::npos &&
      (NearFlagPos == StringRef::npos || NearFlagPos < FarFlagPos);

  std::string DL;
  llvm::raw_string_ostream SS(DL);

  // NOTE: keep in sync with clang/lib/Basic/Targets/RL78.cpp and, for the
  // default (no far features), Triple::computeDataLayout in
  // llvm/lib/TargetParser/TargetDataLayout.cpp.
  SS << "e"               // little endian
        "-m:o";           // Mach-O mangling: Private symbols get L prefix.
                          // Other symbols get a _ prefix.
  SS << "-p0:16:16:16"; // default: 16 bit width, 16 bit aligned

  SS << "-p1:16:16:16" // Near pointers: 16 bit width, 16 bit aligned.
        "-p2:32:16:16:16" // Far data pointers: 32 bit width, 16 bit aligned.
        "-p3:32:16:16:16" // Far code pointers: 32 bit width, 16 bit aligned.
        "-i32:16-i64:16-f32:16-f64:16-a:8" // integers of bit size 32 and 64, float and double types are 16 bit aligned. aggregate type objects are 8 bit aligned
        "-n8:8"                            // 8 bit native integer width
        "-n16:16"                          // 16 bit native integer width
        "-S16";                            // 16 bit natural stack alignment

  if (farCodeModel)
    SS << "-P3"; // Use far pointers for functions.

  SS.flush();

  return DL;
}

static Reloc::Model getEffectiveRelocModel(std::optional<Reloc::Model> RM) {
  if (!RM.has_value())
    return Reloc::Static;
  return *RM;
}

/// Create an RL78 architecture model
RL78TargetMachine::RL78TargetMachine(const Target &T, const Triple &TT,
                                     StringRef CPU, StringRef FS,
                                     const TargetOptions &Options,
                                     std::optional<Reloc::Model> RM,
                                     std::optional<CodeModel::Model> CM,
                                     CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, computeDataLayout(TT, FS), TT, CPU, FS,
                               Options, getEffectiveRelocModel(RM),
                               getEffectiveCodeModel(CM, CodeModel::Tiny), OL),
      TLOF(std::make_unique<RL78ELFTargetObjectFile>()) {

  // Code that the optimizer proves unreachable (often undefined behaviour)
  // traps instead of running into whatever follows; not after a call to a
  // noreturn function, though.
  this->Options.TrapUnreachable = true;
  this->Options.NoTrapAfterNoreturn = true;
  this->Options.ExceptionModel = ExceptionHandling::None;
  initAsmInfo();

  // RL78 supports the MachineOutliner.
  setMachineOutliner(true);

  // RL78 supports default outlining behaviour.
  setSupportsDefaultOutlining(true);

}

RL78TargetMachine::~RL78TargetMachine() {}

const RL78Subtarget *
RL78TargetMachine::getSubtargetImpl(const Function &F) const {
  Attribute CPUAttr = F.getFnAttribute("target-cpu");
  Attribute FSAttr = F.getFnAttribute("target-features");

  std::string CPU = !CPUAttr.hasAttribute(Attribute::None)
                        ? CPUAttr.getValueAsString().str()
                        : TargetCPU;
  std::string FS = !FSAttr.hasAttribute(Attribute::None)
                       ? FSAttr.getValueAsString().str()
                       : TargetFS;

  auto &I = SubtargetMap[CPU + FS];
  if (!I) {
    Attribute TuneAttr = F.getFnAttribute("tune-cpu");
    std::string TuneCPU =
      TuneAttr.isValid() ? TuneAttr.getValueAsString().str() : CPU;
    auto ABIName = Options.MCOptions.getABIName();
    I = std::make_unique<RL78Subtarget>(TargetTriple, CPU, TuneCPU, FS, ABIName, *this);
  }
  return I.get();
}

TargetTransformInfo
RL78TargetMachine::getTargetTransformInfo(const Function &F) const {
  return TargetTransformInfo(std::make_unique<RL78TTIImpl>(this, F));
}

MachineFunctionInfo *RL78TargetMachine::createMachineFunctionInfo(
    BumpPtrAllocator &Allocator, const Function &F,
    const TargetSubtargetInfo *STI) const {
  return RL78MachineFunctionInfo::create<RL78MachineFunctionInfo>(Allocator,
                                                                    F, STI);
}

void RL78TargetMachine::registerPassBuilderCallbacks(PassBuilder &PB) {
  PB.registerPipelineStartEPCallback(
      [=](ModulePassManager &MPM, OptimizationLevel) {
        FunctionPassManager FPM;
        FPM.addPass(RL78GenSet1Clr1IntrinPass());
        MPM.addPass(createModuleToFunctionPassAdaptor(std::move(FPM)));
      });

  // At -O3, unroll an outer loop and jam the copies of its inner loop (as
  // -enable-unroll-and-jam would), before the loops are unrolled: CoreMark's
  // matrix kernels, 3% of its clocks. getUnrollingPreferences says where.
  // At -O3, flatten i*N+j loop nests into one loop, as CC-RL does: CoreMark's
  // matrix kernels, 4% of its clocks. Their trip counts are i32, which takes
  // a library call to multiply for the overflow check; worth it all the same.
  PB.registerLateLoopOptimizationsEPCallback(
      [](LoopPassManager &LPM, OptimizationLevel Level) {
        if (Level == OptimizationLevel::O3)
          LPM.addPass(LoopFlattenPass(/*VersionIllegalTripCount=*/true));
      });

  PB.registerVectorizerStartEPCallback(
      [](FunctionPassManager &FPM, OptimizationLevel Level) {
        if (Level == OptimizationLevel::O3)
          FPM.addPass(createFunctionToLoopPassAdaptor(
              LoopUnrollAndJamPass(static_cast<int>(Level))));
      });

  PB.registerPipelineParsingCallback(
      [](StringRef PassName, FunctionPassManager &PM,
         ArrayRef<PassBuilder::PipelineElement>) {
        if (PassName == "rl78-gen-set1-clr1-intrin") {
          PM.addPass(RL78GenSet1Clr1IntrinPass());
          return true;
        }
        return false;
      });
}

namespace {
/// RL78 Code Generator Pass Configuration Options.
class RL78PassConfig : public TargetPassConfig {
public:
  RL78PassConfig(RL78TargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  RL78TargetMachine &getRL78TargetMachine() const {
    return getTM<RL78TargetMachine>();
  }

  bool addPreISel() override;
  void addIRPasses() override;
  bool addInstSelector() override;
  void addMachineSSAOptimization() override;
  bool addRegAssignAndRewriteOptimized() override;
  void addPreEmitPass() override;
  void addPreEmitPass2() override;
  void addFastRegAlloc() override;
  void addPreRegAlloc() override;
  void addPostRegAlloc() override;
};
} // end anonymous namespace

static cl::opt<bool> RL78AccMisched(
    "rl78-acc-misched", cl::Hidden, cl::init(false),
    cl::desc("Schedule before register allocation"));

bool RL78Subtarget::enableMachineScheduler() const { return RL78AccMisched; }

namespace {
// An accumulator operand in a virtual register (RL78AXRP, RL78AReg) has to be
// in AX (A) where it is used, which the scheduler does not know: moving it
// into the live range of a value still in physical AX, say a return value
// not yet copied out, leaves the allocator no way out. Keep the instructions
// that read or write AX, A or X physically in order with every instruction
// that uses an accumulator class; the rest move freely.
class RL78AccumulatorOrder : public ScheduleDAGMutation {
public:
  void apply(ScheduleDAGInstrs *DAG) override {
    const TargetRegisterInfo *TRI = DAG->TRI;
    const MachineRegisterInfo &MRI = DAG->MRI;
    SUnit *LastPhys = nullptr;
    SmallVector<SUnit *, 8> SinceLastPhys;
    for (SUnit &SU : DAG->SUnits) {
      bool Phys = false, Virt = false;
      for (const MachineOperand &MO : SU.getInstr()->operands()) {
        if (MO.isRegMask() && MO.clobbersPhysReg(RL78::RP0))
          Phys = true;
        if (!MO.isReg() || !MO.getReg())
          continue;
        Register R = MO.getReg();
        if (R.isPhysical()) {
          Phys |= TRI->regsOverlap(R, RL78::RP0);
        } else {
          const TargetRegisterClass *RC = MRI.getRegClass(R);
          Virt |= RC == &RL78::RL78AXRPRegClass ||
                  RC == &RL78::RL78ARegRegClass;
        }
      }
      if (Phys) {
        for (SUnit *Prev : SinceLastPhys)
          DAG->addEdge(&SU, SDep(Prev, SDep::Artificial));
        if (LastPhys)
          DAG->addEdge(&SU, SDep(LastPhys, SDep::Artificial));
        SinceLastPhys.clear();
        LastPhys = &SU;
      } else if (Virt) {
        if (LastPhys)
          DAG->addEdge(&SU, SDep(LastPhys, SDep::Artificial));
        SinceLastPhys.push_back(&SU);
      }
    }
  }
};
} // end anonymous namespace

ScheduleDAGInstrs *
RL78TargetMachine::createMachineScheduler(MachineSchedContext *C) const {
  ScheduleDAGMILive *DAG = createSchedLive(C);
  DAG->addMutation(std::make_unique<RL78AccumulatorOrder>());
  return DAG;
}

TargetPassConfig *RL78TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new RL78PassConfig(*this, PM);
}

bool RL78PassConfig::addPreISel() {
  // After loop strength reduction, which makes the counters this looks for
  // and would take the byte counters for something to reduce.
  if (getOptLevel() != CodeGenOptLevel::None)
    addPass(createRL78ByteLoopCountersPass());
  return false;
}

void RL78PassConfig::addIRPasses() {
  // asm("nop"/"halt"/"stop"/"brk"/"ei"/"di") -> RL78 intrinsics (LLVM 17 did
  // this in CodeGenPrepare via TargetLowering::ExpandInlineAsm).
  addPass(createRL78ExpandInlineAsmPass());
  addPass(createAtomicExpandLegacyPass());
  addPass(createNaryReassociatePass());
  addPass(createSinkingPass());
  if (getOptLevel() != CodeGenOptLevel::None) {
    addPass(createRL78NarrowLoopCountersPass());
    addPass(createRL78NarrowDemandedOpsPass());
    // Before LSR, which would start such a loop one step back.
    addPass(createRL78UnspeculateLoopLatchPass());
  }
  TargetPassConfig::addIRPasses();
  if (getOptLevel() != CodeGenOptLevel::None) {
    // After LSR, which does this for the innermost loops only.
    addPass(createRL78OuterLoopPointersPass());
    // After LSR, which replaces the exit tests it can.
    addPass(createRL78BiasSignedComparesPass());
    // After LSR, which folds a zext(trunc) of a value with a known range.
    addPass(createRL78NarrowDemandedOpsPass(/*Bytes=*/true));
  }
}

bool RL78PassConfig::addInstSelector() {
  addPass(createRL78ISelDag(getRL78TargetMachine(), getOptLevel()));
  addPass(createRL78AssignESPass());
  return false;
}

void RL78PassConfig::addPreEmitPass() {
  addPass(createRL78SlotOperandsPass());
  addPass(createRL78InsertExchangeInstructionsPass());
  // UseCopyInstr, so it matches the real moves rather than only COPY pseudos.
  addPass(createMachineCopyPropagationPass(true));
  addPass(createRL78CMPWithZeroElimPass(/*Late=*/true));
  if (getOptLevel() != CodeGenOptLevel::None)
    addPass(createRL78LateReorderPass());
  if (!InsertNOPWithLabel.empty()) {
    addPass(createRL78InsertNOPWithLabelPass());
  }
  addPass(createRL78InsertInstsForDelayCyclesPass());
}

// The branch pseudos get their short or long form here, after the
// MachineOutliner: outlining shortens the distances, and a branch over what
// became a single call can be a skip.
void RL78PassConfig::addPreEmitPass2() {
  addPass(createRL78ExpandPseudoInstsPass());
  addPass(createRL78SelectBTCLRPass());
}

// Use the optimized reg also on -O0
void RL78PassConfig::addFastRegAlloc() {
  TargetPassConfig::addOptimizedRegAlloc();
}

void RL78PassConfig::addMachineSSAOptimization() {
  // What is hoisted out of a loop stays in a register across the loop, and
  // there are four 16-bit registers: the loop body pays with spills for more
  // than the hoisting saves, in size and (CoreMark, Embench at -O3) in time.
  disablePass(&EarlyMachineLICMID);
  TargetPassConfig::addMachineSSAOptimization();
}

bool RL78PassConfig::addRegAssignAndRewriteOptimized() {
  return TargetPassConfig::addRegAssignAndRewriteOptimized();
}

void RL78PassConfig::addPreRegAlloc() {
  if (getOptLevel() != CodeGenOptLevel::None)
    addPass(createRL78MACRLoopPromotePass());
  if (getOptLevel() != CodeGenOptLevel::None) {
    addPass(createRL78ConstPropAndOpSwap());
    addPass(createRL78SinkToAccumulatorPass());
    addPass(createRL78LoadLateStoreEarlyPass());
    addPass(&ProcessImplicitDefsID);

    // LiveVariables currently requires pure SSA form.
    
    addPass(&LiveVariablesID);
    addPass(&ProcessImplicitDefsID);
    addPass(&UnreachableMachineBlockElimID);
    addPass(&DeadMachineInstructionElimID);
  }
  addPass(createRL78ESOptPass());
  // Last before the allocator's own passes: the SSA optimisations (copy
  // propagation in MachineCSE and the peephole optimiser) narrow a value's
  // class to that of an operand whenever they can.
  addPass(createRL78SplitConstrainedValuesPass());
}

void RL78PassConfig::addPostRegAlloc() {
  if (getOptLevel() != CodeGenOptLevel::None)
    addPass(createRL78AccumulatorCopiesPass());
  addPass(createRL78CMPWithZeroElimPass());
}
