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
#include "llvm/CodeGen/LiveIntervals.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Transforms/InstCombine/InstCombine.h"
#include "llvm/Transforms/Scalar.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "RL78TargetMachine"

using namespace llvm;

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRL78Target() {
  // Register the target.
  RegisterTargetMachine<RL78TargetMachine> X(getTheRL78Target());
  auto *PR = PassRegistry::getPassRegistry();
  initializeRL78DAGToDAGISelPass(*PR);
}

static std::string computeDataLayout(const Triple &T, StringRef FS) {

  size_t FarFlagPos = FS.rfind("+far-code");
  size_t NearFlagPos = FS.rfind("+near-code");

  const auto farCodeModel =
      FarFlagPos != StringRef::npos &&
      (NearFlagPos == StringRef::npos || NearFlagPos < FarFlagPos);
  const auto farDataModel = FS.rfind("+far-data") != StringRef::npos;

  std::string DL;
  llvm::raw_string_ostream SS(DL);

  // NOTE: keep in sync with def from clang/lib/Basic/Targets/RL78.cpp
  SS << "e"               // little endian
        "-m:o";           // Mach-O mangling: Private symbols get L prefix.
                          // Other symbols get a _ prefix.
  if (farDataModel) {
    SS << "-p0:32:16:16"  // default: 32 bit width, 16 bit aligned
          "-A1";          // near allocas
  } else {
    SS << "-p0:16:16:16"; // default: 16 bit width, 16 bit aligned
  }

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
                                     CodeGenOpt::Level OL, bool JIT)
    : LLVMTargetMachine(T, computeDataLayout(TT, FS), TT, CPU, FS, Options,
                        getEffectiveRelocModel(RM),
                        getEffectiveCodeModel(CM, CodeModel::Tiny), OL),
      TLOF(std::make_unique<RL78ELFTargetObjectFile>()) {

  // Bcause the optimizer is getting smarter in figuring out undefined behavior/poison
  // cases, we have trap unreachable = true as default (can be overriden by the user).
  // We don't want to trap after the __attribute__((noreturn)) though.
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
    // This needs to be done before we create a new subtarget since any
    // creation will depend on the TM and the code generation flags on the
    // function that reside in TargetOptions.
    resetTargetOptions(F);
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
  return TargetTransformInfo(RL78TTIImpl(this, F));
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
  void addPreEmitPass() override;
  void addFastRegAlloc() override;
  void addPreRegAlloc() override;
  void addPostRegAlloc() override;
};
} // end anonymous namespace

TargetPassConfig *RL78TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new RL78PassConfig(*this, PM);
}

bool RL78PassConfig::addPreISel() {
  return false;
}

void RL78PassConfig::addIRPasses() {
  addPass(createNaryReassociatePass());
  addPass(createSinkingPass());
  if (getOptLevel() != CodeGenOpt::None)
    addPass(createRL78NarrowDemandedOpsPass());
  TargetPassConfig::addIRPasses();
}

bool RL78PassConfig::addInstSelector() {
  addPass(createRL78ISelDag(getRL78TargetMachine(), getOptLevel()));
  return false;
}

void RL78PassConfig::addPreEmitPass() {
  addPass(createRL78InsertExchangeInstructionsPass());
  // UseCopyInstr, so it matches the real moves rather than only COPY pseudos.
  addPass(createMachineCopyPropagationPass(true));
  addPass(createRL78CMPWithZeroElimPass());
  addPass(createRL78InstructionSpecializationPass());
  addPass(createRL78ExpandPseudoInstsPass());
  addPass(createRL78SelectBTCLRPass());
  if (!InsertNOPWithLabel.empty()) {
    addPass(createRL78InsertNOPWithLabelPass());
  }
  addPass(createRL78InsertInstsForDelayCyclesPass());
}

// Use the optimized reg also on -O0
void RL78PassConfig::addFastRegAlloc() {
  TargetPassConfig::addOptimizedRegAlloc();
}

void RL78PassConfig::addPreRegAlloc() {
  addPass(createRL78AdjustMemRefsPass());
  if (getOptLevel() != CodeGenOpt::None) {
    addPass(createRL78ConstPropAndOpSwap());
    addPass(&ProcessImplicitDefsID);

    // LiveVariables currently requires pure SSA form.
    
    addPass(&LiveVariablesID);
    addPass(&ProcessImplicitDefsID);
    addPass(&UnreachableMachineBlockElimID);
    addPass(&DeadMachineInstructionElimID);
  }
  addPass(createRL78ESOptPass());
}

void RL78PassConfig::addPostRegAlloc() {
  addPass(createRL78CMPWithZeroElimPass());
}
