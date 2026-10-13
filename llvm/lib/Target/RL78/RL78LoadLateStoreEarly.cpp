//===-- RL78LoadLateStoreEarly.cpp - Loads to the use, stores to the value -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The instructions of a carry chain (ADDW, then ADDC on the bytes of each
// word above) are selected as one group, and the stores of a value of several
// words come after the loads of all of them. So every word the operation does
// not read from memory itself is loaded before the group, and every result
// waits in a register until after it:
//
//   %lo:rl78rpregs = MOVW_rp_abs16 @g
//   %hi:rl78rpregs = MOVW_rp_abs16 @g + 2
//   %lo1:rl78axrp = ADDW_AX_abs16 %lo, @h
//   %hi1:rl78axrp = ADDE_AX_abs16 %hi, @h + 2
//   MOVW_abs16_AX @g, %lo1
//   MOVW_abs16_AX @g + 2, %hi1
//
// With four register pairs, of which only AX loads, stores and computes, a
// value that waits costs copies or a stack slot. Neither a load nor a store
// changes the flags, so a store is moved up to the instruction that leaves
// the value it writes in A or AX, and a load down to its only reader, when
// nothing in between may write that memory (or read it, for the store):
//
//   %lo:rl78rpregs = MOVW_rp_abs16 @g
//   %lo1:rl78axrp = ADDW_AX_abs16 %lo, @h
//   MOVW_abs16_AX @g, %lo1
//   %hi:rl78rpregs = MOVW_rp_abs16 @g + 2
//   %hi1:rl78axrp = ADDE_AX_abs16 %hi, @h + 2
//   MOVW_abs16_AX @g + 2, %hi1
//
// On SSA machine code before register allocation, within a block.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/CommandLine.h"

#define DEBUG_TYPE "rl78-load-late-store-early"
using namespace llvm;

STATISTIC(NumStores, "Number of stores moved up to the value they write");
STATISTIC(NumLoads, "Number of loads moved down to their reader");

static cl::opt<unsigned> Window(
    "rl78-load-store-window", cl::Hidden, cl::init(24),
    cl::desc("Most instructions a load or a store is moved across"));

namespace {
class RL78LoadLateStoreEarly : public MachineFunctionPass {
public:
  static char ID;
  RL78LoadLateStoreEarly() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 loads to their reader, stores to their value";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<AAResultsWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  MachineRegisterInfo *MRI = nullptr;
  const TargetRegisterInfo *TRI = nullptr;
  AAResults *AA = nullptr;

  bool mayCross(const MachineInstr &Moved, const MachineInstr &Other) const;
  bool hoistStore(MachineInstr &Store);
  bool sinkLoad(MachineInstr &Load);
};
} // end anonymous namespace

char RL78LoadLateStoreEarly::ID = 0;

INITIALIZE_PASS_BEGIN(RL78LoadLateStoreEarly, DEBUG_TYPE,
                      "RL78 loads to their reader, stores to their value",
                      false, false)
INITIALIZE_PASS_DEPENDENCY(AAResultsWrapperPass)
INITIALIZE_PASS_END(RL78LoadLateStoreEarly, DEBUG_TYPE,
                    "RL78 loads to their reader, stores to their value", false,
                    false)

FunctionPass *llvm::createRL78LoadLateStoreEarlyPass() {
  return new RL78LoadLateStoreEarly();
}

static bool isVolatile(const MachineInstr &MI) {
  return any_of(MI.memoperands(),
                [](const MachineMemOperand *MMO) { return MMO->isVolatile(); });
}

// An instruction that conditionally skips the next one: nothing may come
// between the two.
static bool isSkip(const MachineInstr &MI) {
  switch (MI.getOpcode()) {
  case RL78::SKcc:
  case RL78::SKHcc:
  case RL78::SKcc_cg:
  case RL78::SKHcc_cg:
  case RL78::Bcc_over:
    return true;
  }
  return false;
}

// X, A, C, B, E, D, L, H and their pairs: the registers values are in.
static bool isGeneralRegister(Register R) {
  return RL78::RL78RegRegClass.contains(R) ||
         RL78::RL78RPRegsRegClass.contains(R);
}

// A store and nothing else: it writes memory from virtual registers.
static bool isPlainStore(const MachineInstr &MI) {
  if (!MI.mayStore() || MI.mayLoad() || MI.isCall() || MI.isBundled() ||
      MI.hasUnmodeledSideEffects() || MI.memoperands_empty() || isVolatile(MI))
    return false;
  return none_of(MI.operands(), [](const MachineOperand &MO) {
    return MO.isReg() && MO.isDef();
  });
}

// A load and nothing else: its one result is a virtual register and no
// operand is tied to it.
static bool isPlainLoad(const MachineInstr &MI) {
  if (!MI.mayLoad() || MI.mayStore() || MI.isCall() || MI.isBundled() ||
      MI.hasUnmodeledSideEffects() || MI.memoperands_empty() || isVolatile(MI))
    return false;
  unsigned Defs = 0;
  for (const MachineOperand &MO : MI.operands()) {
    if (!MO.isReg())
      continue;
    if (MO.isDef() && (MO.isImplicit() || !MO.getReg().isVirtual() || ++Defs > 1))
      return false;
    if (MO.isUse() && MO.isTied())
      return false;
  }
  return Defs == 1;
}

// May Moved, a load or a store, change places with Other?
bool RL78LoadLateStoreEarly::mayCross(const MachineInstr &Moved,
                                      const MachineInstr &Other) const {
  if (Other.isCall() || Other.isInlineAsm() || Other.isPosition() ||
      Other.isBundled() || Other.hasUnmodeledSideEffects() ||
      Other.getOpcode() == RL78::ADJCALLSTACKDOWN ||
      Other.getOpcode() == RL78::ADJCALLSTACKUP)
    return false;
  // A load passes other loads; a store passes neither loads nor stores of
  // what it writes.
  if ((Other.mayStore() || (Other.mayLoad() && Moved.mayStore())) &&
      Moved.mayAlias(AA, Other, /*UseTBAA=*/true))
    return false;
  for (const MachineOperand &MO : Other.operands()) {
    if (!MO.isReg() || !MO.getReg().isPhysical())
      continue;
    // A register an instruction names holds a value up to here or from here
    // on (an argument, a result): a value that must be in that register can
    // only join it on the side it was on.
    if (isGeneralRegister(MO.getReg()) && (MO.isUse() || !MO.isImplicit()))
      return false;
    // ES, for one, which a far access reads.
    if (MO.isDef() && Moved.readsRegister(MO.getReg(), TRI))
      return false;
  }
  return true;
}

// Move a store up to right behind the instruction that computes, in A or
// AX, the value it writes.
bool RL78LoadLateStoreEarly::hoistStore(MachineInstr &Store) {
  MachineBasicBlock &MBB = *Store.getParent();
  // The copy that brings the value to the register the store takes it from
  // goes with it.
  MachineInstr *Copy = nullptr;
  SmallVector<Register, 4> Reads;
  // The register the store writes to memory: its operand in A or AX.
  Register Value;
  const TargetInstrInfo *TII = MBB.getParent()->getSubtarget().getInstrInfo();
  for (const MachineOperand &MO : Store.operands()) {
    if (!MO.isReg() || !MO.getReg())
      continue;
    if (!MO.getReg().isVirtual()) {
      if (isGeneralRegister(MO.getReg()))
        return false;
      continue;
    }
    MachineInstr *Def = MRI->getUniqueVRegDef(MO.getReg());
    if (!Def)
      return false;
    Register Read = MO.getReg();
    if (!Copy && Def->isCopy() && Def->getParent() == &MBB &&
        Def->getOperand(1).getReg().isVirtual() &&
        !Def->getOperand(1).getSubReg() && MRI->hasOneNonDBGUse(Read) &&
        next_nodbg(MachineBasicBlock::iterator(Def), MBB.end()) ==
            Store.getIterator()) {
      Copy = Def;
      Read = Def->getOperand(1).getReg();
    }
    Reads.push_back(Read);
    const TargetRegisterClass *RC =
        Store.getRegClassConstraint(MO.getOperandNo(), TII, TRI);
    if (RC == &RL78::RL78AXRPRegClass || RC == &RL78::RL78ARegRegClass)
      Value = Read;
  }

  // Up to the instruction that defines the value. False if the store may
  // not pass an instruction on the way, or meets the definition of another
  // register it reads first; otherwise To is where it got to, and AtValue
  // whether that is behind the value.
  unsigned Crossed = 0;
  bool AtValue = false;
  auto ScanUp = [&](MachineBasicBlock &Block, MachineBasicBlock::iterator &To) {
    while (To != Block.begin()) {
      MachineBasicBlock::iterator Prev = std::prev(To);
      if (Prev->isDebugInstr()) {
        To = Prev;
        continue;
      }
      if (Prev->isPHI())
        break;
      if (any_of(Reads, [&](Register R) {
            return Prev->definesRegister(R, /*TRI=*/nullptr);
          })) {
        // The value is in A or AX there, where the store takes it from: a
        // register of the address, or a value in another register, would
        // only be copied earlier.
        AtValue = Value.isValid() && Prev->definesRegister(Value, nullptr) &&
                  MRI->getRegClass(Value)->getNumRegs() == 1;
        return AtValue;
      }
      if (Crossed++ == Window || !mayCross(Store, *Prev))
        return false;
      To = Prev;
    }
    return true;
  };

  MachineBasicBlock::iterator First = Copy ? Copy->getIterator()
                                           : Store.getIterator();
  MachineBasicBlock::iterator To = First;
  MachineBasicBlock *Into = &MBB;
  if (!ScanUp(MBB, To))
    return false;
  if (!AtValue) {
    // At the top of the block. The carry into the next word is often added
    // under a branch (BNC; INCW), with the value above it:
    //
    //   Above:  value; branch to MBB    Middle:  ...    MBB:  store
    if (MBB.pred_size() != 2)
      return false;
    MachineBasicBlock *Above = *MBB.pred_begin(), *Middle = *MBB.pred_rbegin();
    if (Above->pred_size() == 1 && *Above->pred_begin() == Middle)
      std::swap(Above, Middle);
    if (Middle->pred_size() != 1 || *Middle->pred_begin() != Above ||
        Middle->succ_size() != 1 || Above->succ_size() != 2 ||
        Middle->isEHPad() || MBB.isEHPad())
      return false;
    // What the store reads is there on both ways.
    for (Register R : Reads) {
      const MachineBasicBlock *DefBlock = MRI->getUniqueVRegDef(R)->getParent();
      if (DefBlock == &MBB || DefBlock == Middle)
        return false;
    }
    MachineBasicBlock::iterator End = Middle->end();
    if (!ScanUp(*Middle, End) || End != Middle->begin())
      return false;
    To = Above->end();
    Into = Above;
    if (!ScanUp(*Above, To) || !AtValue)
      return false;
  }
  // Debug instructions directly behind the definition stay there.
  while (To != Into->end() && To != First && To->isDebugInstr())
    ++To;
  if (To == First || (To != Into->begin() && isSkip(*std::prev(To))))
    return false;
  if (Copy)
    Into->splice(To, &MBB, Copy->getIterator());
  Into->splice(To, &MBB, Store.getIterator());
  for (Register R : Reads)
    MRI->clearKillFlags(R);
  ++NumStores;
  return true;
}

// Move a load down to right before its only reader.
bool RL78LoadLateStoreEarly::sinkLoad(MachineInstr &Load) {
  MachineBasicBlock &MBB = *Load.getParent();
  Register Value;
  for (const MachineOperand &MO : Load.operands())
    if (MO.isReg() && MO.isDef())
      Value = MO.getReg();
  if (!MRI->hasOneNonDBGUse(Value))
    return false;
  MachineInstr &Reader = *MRI->use_instr_nodbg_begin(Value);
  if (Reader.getParent() != &MBB || Reader.isPHI() || Reader.isBundled())
    return false;

  MachineBasicBlock::iterator To = std::next(Load.getIterator());
  unsigned Crossed = 0;
  for (; To != Reader.getIterator(); ++To) {
    if (To == MBB.end())
      return false; // The reader is above the load: a loop of one block.
    if (To->isDebugInstr())
      continue;
    if (Crossed++ == Window || !mayCross(Load, *To))
      return false;
  }
  if (!Crossed || isSkip(*prev_nodbg(To, MBB.begin())))
    return false;

  // A register of the address must not live longer for it.
  for (const MachineOperand &MO : Load.uses()) {
    if (!MO.isReg() || !MO.getReg())
      continue;
    if (!MO.getReg().isVirtual()) {
      if (isGeneralRegister(MO.getReg()))
        return false;
      continue;
    }
    bool ReadLater = any_of(
        MRI->use_nodbg_instructions(MO.getReg()), [&](MachineInstr &Use) {
          if (&Use == &Load)
            return false;
          if (Use.getParent() != &MBB)
            return true;
          for (MachineBasicBlock::iterator I = To; I != MBB.end(); ++I)
            if (&*I == &Use)
              return true;
          return false;
        });
    if (!ReadLater)
      return false;
  }

  // What describes the value to the debugger follows it.
  SmallVector<MachineInstr *, 2> DebugUsers;
  for (MachineBasicBlock::iterator I = std::next(Load.getIterator()); I != To;
       ++I)
    if (I->isDebugInstr() && I->readsRegister(Value, /*TRI=*/nullptr))
      DebugUsers.push_back(&*I);
  MBB.splice(To, &MBB, Load.getIterator());
  for (MachineInstr *Debug : DebugUsers)
    MBB.splice(To, &MBB, Debug->getIterator());
  for (const MachineOperand &MO : Load.uses())
    if (MO.isReg() && MO.getReg().isVirtual())
      MRI->clearKillFlags(MO.getReg());
  ++NumLoads;
  return true;
}

bool RL78LoadLateStoreEarly::runOnMachineFunction(MachineFunction &MF) {
  MRI = &MF.getRegInfo();
  if (!MRI->isSSA())
    return false;
  TRI = MF.getSubtarget().getRegisterInfo();
  AA = &getAnalysis<AAResultsWrapperPass>().getAAResults();
  bool Changed = false;
  SmallVector<MachineInstr *, 16> Stores, Loads;
  for (MachineBasicBlock &MBB : MF) {
    Stores.clear();
    Loads.clear();
    for (MachineInstr &MI : MBB) {
      if (isPlainStore(MI))
        Stores.push_back(&MI);
      else if (isPlainLoad(MI))
        Loads.push_back(&MI);
    }
    // Stores from the top, so that one that follows another to the same
    // value stays behind it; loads from the bottom for the same reason.
    for (MachineInstr *Store : Stores)
      Changed |= hoistStore(*Store);
    for (MachineInstr *Load : reverse(Loads))
      Changed |= sinkLoad(*Load);
  }
  return Changed;
}
