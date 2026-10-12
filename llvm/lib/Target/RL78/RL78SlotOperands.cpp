//===-- RL78SlotOperands.cpp - Operands in stack slots --------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A value reloaded from the stack into B, C, D, E, H, L, BC, DE or HL goes
// through the accumulator, [SP+byte] being a form of MOV A and MOVW AX only:
//
//   movw ax, [sp+4]      ; with an XCHW on either side where AX is taken
//   movw bc, ax
//   ...
//   addw ax, bc
//
// ADD, ADDC, SUB, SUBC, AND, OR, XOR, CMP, ADDW, SUBW and CMPW read their
// second operand from [HL+byte] as well, and HL can stand for SP:
//
//   movw hl, sp          ; once for a run of them, while HL and SP stand
//   ...
//   addw ax, [hl+4]
//
// This pass does that for a reload whose every use is such an operand, or a
// copy to the accumulator (which becomes the load itself), where it takes
// fewer clocks, or fewer bytes in a function optimized for size. HL has to be
// free at each use, or be the reloaded register.
//
// The allocator's own folding (TargetInstrInfo::foldMemoryOperand) does not
// serve here: it would leave an instruction that needs HL where the allocator
// has not kept HL free.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstrInfo.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/LiveRegUnits.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-slot-operands"

STATISTIC(NumReloads, "Reloads replaced by slot operands");
STATISTIC(NumHL, "MOVW HL, SP inserted");

static cl::opt<bool> FoldReloads(
    "rl78-fold-reloads", cl::Hidden, cl::init(true),
    cl::desc("Use a reloaded value from its stack slot where every use is the "
             "second operand of an 8- or 16-bit operation"));

namespace {
class RL78SlotOperands : public MachineFunctionPass {
public:
  RL78SlotOperands() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 slot operands"; }

  bool runOnMachineFunction(MachineFunction &MF) override;

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoVRegs();
  }

private:
  // A use of a reloaded register and the offset from SP it reads instead.
  struct SlotUse {
    MachineInstr *MI;
    int64_t Offset;
  };
  // What is live after an instruction.
  struct LiveAfter {
    bool HL;
    bool AX;
    BitVector Units;
  };

  bool findSlotUses(MachineInstr &Load, bool HLIsSP,
                    SmallVectorImpl<SlotUse> &Uses);
  bool processBlock(MachineBasicBlock &MBB);

  const TargetRegisterInfo *TRI = nullptr;
  const TargetInstrInfo *TII = nullptr;
  bool OptSize = false;
  DenseMap<const MachineInstr *, LiveAfter> Live;
  // The instructions from a reload of HL that is gone to its last use: HL is
  // free there, whatever Live says.
  SmallPtrSet<const MachineInstr *, 16> HLRange;

  static char ID;
};

char RL78SlotOperands::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78SlotOperandsPass() {
  return new RL78SlotOperands();
}

// Mn A, r / Mn AX, rp and their [HL+byte] and [HL] forms.
namespace {
struct MemForm {
  unsigned Reg;
  unsigned HLi;
  unsigned HL; // 0 for the 16-bit operations
};
} // end anonymous namespace

static const MemForm *getMemForm(unsigned Opc) {
  static const MemForm Forms[] = {
#define RL78_ALU8(N) {RL78::N##_A_r, RL78::N##_A_mHLi, RL78::N##_A_mHL}
      RL78_ALU8(ADD), RL78_ALU8(ADDC), RL78_ALU8(SUB), RL78_ALU8(SUBC),
      RL78_ALU8(AND), RL78_ALU8(OR),   RL78_ALU8(XOR), RL78_ALU8(CMP),
#undef RL78_ALU8
      {RL78::ADDW_AX_rp, RL78::ADDW_AX_mHLi, 0},
      {RL78::SUBW_AX_rp, RL78::SUBW_AX_mHLi, 0},
      {RL78::CMPW_AX_rp, RL78::CMPW_AX_mHLi, 0},
      {RL78::LowCMPW_rp_rp, RL78::LowCMPW_rp_memri, 0},
  };
  for (const MemForm &F : Forms)
    if (F.Reg == Opc)
      return &F;
  return nullptr;
}

// The bytes [SP+Offset, SP+Offset+Size) a direct stack access of MI touches.
static bool getStackAccess(const MachineInstr &MI, int64_t &Offset,
                           unsigned &Size) {
  unsigned Idx;
  switch (MI.getOpcode()) {
  case RL78::LOAD8_r_stack_slot:
  case RL78::MOV_A_mSPi:
    Idx = 1, Size = 1;
    break;
  case RL78::LOAD16_rp_stack_slot:
  case RL78::MOVW_AX_mSPi:
    Idx = 1, Size = 2;
    break;
  case RL78::STORE8_stack_slot_r:
  case RL78::MOV_mSPi_A:
  case RL78::MOV_mSPi_i8:
    Idx = 0, Size = 1;
    break;
  case RL78::STORE16_stack_slot_rp:
  case RL78::MOVW_mSPi_AX:
    Idx = 0, Size = 2;
    break;
  default:
    return false;
  }
  if (!MI.getOperand(Idx).isReg() ||
      MI.getOperand(Idx).getReg() != RL78::SPreg ||
      !MI.getOperand(Idx + 1).isImm())
    return false;
  Offset = MI.getOperand(Idx + 1).getImm();
  return true;
}

// An instruction that addresses through a register the one before it wrote
// waits a clock (manual 7.2.3), so MOVW HL, SP goes above the instruction
// before the operand when that one has nothing to do with HL or SP.
static bool canSetHLAbove(const MachineInstr &Prev,
                          const TargetRegisterInfo *TRI) {
  return !Prev.isCall() && !Prev.isInlineAsm() && !Prev.isMetaInstruction() &&
         !Prev.readsRegister(RL78::RP6, TRI) &&
         !Prev.modifiesRegister(RL78::RP6, TRI) &&
         !Prev.modifiesRegister(RL78::SPreg, TRI);
}

// The instruction before I that is not a debug instruction, or null.
static MachineInstr *prevInstr(MachineBasicBlock::iterator I) {
  MachineBasicBlock &MBB = *I->getParent();
  while (I != MBB.begin())
    if (!(--I)->isDebugInstr())
      return &*I;
  return nullptr;
}

static bool changesHLOrSP(const MachineInstr &MI,
                          const TargetRegisterInfo *TRI) {
  return MI.isCall() || MI.isInlineAsm() ||
         MI.modifiesRegister(RL78::RP6, TRI) ||
         MI.modifiesRegister(RL78::SPreg, TRI);
}

// The uses of the register Load writes, if they can all read the slot and
// that is cheaper. HLIsSP: HL holds SP where Load is.
bool RL78SlotOperands::findSlotUses(MachineInstr &Load, bool HLIsSP,
                                    SmallVectorImpl<SlotUse> &Uses) {
  int64_t Offset;
  unsigned Size;
  if ((Load.getOpcode() != RL78::LOAD8_r_stack_slot &&
       Load.getOpcode() != RL78::LOAD16_rp_stack_slot) ||
      !getStackAccess(Load, Offset, Size) || !isUInt<8>(Offset + Size - 1))
    return false;
  Register D = Load.getOperand(0).getReg();
  if (TRI->regsOverlap(D, RL78::RP0))
    return false;
  // HL as a whole stands for SP, so a byte of it cannot be reloaded data.
  bool IsHL = TRI->regsOverlap(D, RL78::RP6);
  if (IsHL && D != RL78::RP6)
    return false;
  MachineBasicBlock &MBB = *Load.getParent();

  auto IsLiveAfter = [&](const MachineInstr &MI) {
    const BitVector &Units = Live.find(&MI)->second.Units;
    for (MCRegUnit U : TRI->regunits(D))
      if (Units.test(static_cast<unsigned>(U)))
        return true;
    return false;
  };

  // The operands through HL, and whether the first of them finds SP there.
  unsigned NumHLUses = 0, NumCopies = 0, HLBytes = 0;
  bool Shared = HLIsSP, Hazard = false;
  // The instruction before MI once the reload is gone.
  const MachineInstr *Prev = prevInstr(Load.getIterator());
  const MachineInstr *BeforeLoad = Prev;
  bool Done = false;
  for (MachineBasicBlock::iterator I = std::next(Load.getIterator()),
                                   E = MBB.end();
       I != E && !Done; ++I) {
    MachineInstr &MI = *I;
    if (MI.isDebugInstr())
      continue;
    if (MI.readsRegister(D, TRI)) {
      for (const MachineOperand &MO : MI.operands())
        if (MO.isReg() && MO.isDef() && MO.getReg().isValid() &&
            TRI->regsOverlap(MO.getReg(), D))
          return false;
      if ((MI.getOpcode() == RL78::MOVW_AX_rp ||
           MI.getOpcode() == RL78::MOV_A_r) &&
          MI.getOperand(1).getReg() == D) {
        // The copy becomes the load.
        Uses.push_back({&MI, Offset});
        ++NumCopies;
      } else {
        const MemForm *F = getMemForm(MI.getOpcode());
        if (!F)
          return false;
        unsigned SrcIdx = MI.getNumExplicitOperands() - 1;
        Register R = MI.getOperand(SrcIdx).getReg();
        for (unsigned J = 0, N = MI.getNumOperands(); J != N; ++J)
          if (J != SrcIdx && MI.getOperand(J).isReg() &&
              MI.getOperand(J).getReg().isValid() &&
              TRI->regsOverlap(MI.getOperand(J).getReg(), D))
            return false;
        int64_t Disp = Offset;
        if (R != D) {
          // A byte of a reloaded pair.
          if (!F->HL || !TRI->isSubRegister(D, R))
            return false;
          if (Register(TRI->getSubReg(D, RL78::sub_hi)) == R)
            ++Disp;
        } else if (!F->HL != (Size == 2)) {
          return false;
        }
        if (!IsHL && Live.find(&MI)->second.HL && !HLRange.count(&MI))
          return false;
        if (!NumHLUses && !Shared)
          Hazard = !Prev || !canSetHLAbove(*Prev, TRI);
        ++NumHLUses;
        HLBytes += F->HL ? (Disp ? 2 : 1) : 3;
        Uses.push_back({&MI, Disp});
      }
    } else if (MI.modifiesRegister(D, TRI)) {
      // Rewritten before it is read again; a part of it leaves the rest.
      if (!MI.definesRegister(D, TRI))
        return false;
      break;
    }
    if (!IsLiveAfter(MI))
      Done = true;
    else if (MI.isCall() || MI.isInlineAsm() ||
             MI.modifiesRegister(RL78::SPreg, TRI))
      // The slot and the way to it must stand until the last use.
      return false;
    else if (MI.mayStore()) {
      int64_t O;
      unsigned S;
      if (!getStackAccess(MI, O, S) || (O < Offset + Size && Offset < O + S))
        return false;
    }
    if (!NumHLUses && !IsHL && changesHLOrSP(MI, TRI))
      Shared = false;
    Prev = &MI;
  }
  if (Uses.empty() || (!Done && IsLiveAfter(MBB.back())))
    return false; // live out of the block

  // The reload is MOV(W) A(X), [SP+byte] and a move, or exchanges on either
  // side of it where the accumulator is taken.
  unsigned LoadCost = Live.find(&Load)->second.AX ? 3 : 2;
  // Right after MOVW AX, rp the exchange pass has shorter ways
  // (loadIntoAXFirst): into AX and an XCHW when it reloads rp itself, and
  // into AX with the operands of the ADDW swapped when that is its one use.
  if (BeforeLoad && BeforeLoad->getOpcode() == RL78::MOVW_AX_rp &&
      Size == 2) {
    if (BeforeLoad->getOperand(1).getReg() == D)
      LoadCost = 1;
    else if (Uses.size() == 1 && Uses[0].MI->getOpcode() == RL78::ADDW_AX_rp &&
             prevInstr(Uses[0].MI->getIterator()) == &Load)
      LoadCost = 0;
  }
  // The same with the reload before the MOVW AX, rp.
  if (Size == 2 && Uses.size() == 1 &&
      Uses[0].MI->getOpcode() == RL78::ADDW_AX_rp)
    if (MachineInstr *Copy = prevInstr(Uses[0].MI->getIterator());
        Copy && Copy->getOpcode() == RL78::MOVW_AX_rp &&
        prevInstr(Copy->getIterator()) == &Load)
      LoadCost = 0;
  unsigned SetHL = NumHLUses && !Shared ? 1 : 0;
  if (!OptSize)
    return SetHL + (Hazard ? 1 : 0) < LoadCost;
  // In bytes: the reload takes three where the exchange pass finds AX free
  // for it, which it mostly does; a copy that becomes a load one more, MOVW
  // HL, SP three, and the register forms of the operations one (16 bits) or
  // two.
  // Two loads for two copies would still be a byte less, but they are
  // [SP+byte] instructions the outliner then cannot share as freely as
  // register moves (Embench nettle-sha256 at -Os: +339 bytes).
  if (NumCopies > 1)
    return false;
  unsigned Before = std::min(LoadCost, 2u) + 1 + NumCopies;
  for (const SlotUse &U : Uses)
    if (const MemForm *F = getMemForm(U.MI->getOpcode()))
      Before += F->HL ? 2 : 1;
  return 3 * SetHL + 2 * NumCopies + HLBytes < Before;
}

bool RL78SlotOperands::processBlock(MachineBasicBlock &MBB) {
  bool AnyLoad = false;
  for (const MachineInstr &MI : MBB)
    AnyLoad |= MI.getOpcode() == RL78::LOAD8_r_stack_slot ||
               MI.getOpcode() == RL78::LOAD16_rp_stack_slot;
  if (!AnyLoad)
    return false;

  Live.clear();
  HLRange.clear();
  LiveRegUnits Units(*TRI);
  Units.addLiveOuts(MBB);
  for (MachineInstr &MI : reverse(MBB)) {
    Live[&MI] = {!Units.available(RL78::RP6), !Units.available(RL78::RP0),
                 Units.getBitVector()};
    if (!MI.isDebugInstr())
      Units.stepBackward(MI);
  }

  bool Changed = false;
  // HL holds SP from an earlier operand of this block.
  bool HLIsSP = false;
  DenseMap<MachineInstr *, int64_t> SlotUses;
  for (MachineInstr &MI : make_early_inc_range(MBB)) {
    auto It = SlotUses.find(&MI);
    if (It == SlotUses.end()) {
      SmallVector<SlotUse, 4> Uses;
      if (findSlotUses(MI, HLIsSP, Uses)) {
        for (const SlotUse &U : Uses)
          SlotUses[U.MI] = U.Offset;
        if (MI.getOperand(0).getReg() == RL78::RP6)
          for (MachineBasicBlock::iterator I = std::next(MI.getIterator());;
               ++I) {
            HLRange.insert(&*I);
            if (&*I == Uses.back().MI)
              break;
          }
        MI.eraseFromParent();
        ++NumReloads;
        Changed = true;
      } else if (changesHLOrSP(MI, TRI)) {
        HLIsSP = false;
      }
      continue;
    }

    int64_t Offset = It->second;
    if (MI.getOpcode() == RL78::MOVW_AX_rp || MI.getOpcode() == RL78::MOV_A_r) {
      bool IsWord = MI.getOpcode() == RL78::MOVW_AX_rp;
      MI.setDesc(TII->get(IsWord ? RL78::MOVW_AX_mSPi : RL78::MOV_A_mSPi));
      MI.getOperand(1).ChangeToRegister(RL78::SPreg, false);
      MI.addOperand(MachineOperand::CreateImm(Offset));
      // As RL78RegisterInfo::eliminateFrameIndex marks them: in an outlined
      // function the slot is a return address further up.
      MI.getOperand(2).setTargetFlags(isUInt<8>(Offset + 4)
                                          ? SPII::MO_OUTLINE_SP
                                          : SPII::MO_NO_OUTLINE_SP);
      continue;
    }
    // Mn A, r / Mn AX, rp become Mn A, [HL+byte] / Mn AX, [HL+byte].
    const MemForm *Form = getMemForm(MI.getOpcode());
    if (!HLIsSP) {
      MachineBasicBlock::iterator At = MI.getIterator();
      if (MachineInstr *Prev = prevInstr(At); Prev && canSetHLAbove(*Prev, TRI))
        At = Prev->getIterator();
      BuildMI(MBB, At, MI.getDebugLoc(), TII->get(RL78::MOVW_rp_SP), RL78::RP6)
          .addReg(RL78::SPreg);
      HLIsSP = true;
      ++NumHL;
    }
    unsigned SrcIdx = MI.getNumExplicitOperands() - 1;
    MI.getOperand(SrcIdx).ChangeToRegister(RL78::RP6, false);
    if (Offset == 0 && Form->HL) {
      MI.setDesc(TII->get(Form->HL));
    } else {
      MI.setDesc(TII->get(Form->HLi));
      MI.addOperand(MachineOperand::CreateImm(Offset));
    }
  }
  return Changed;
}

bool RL78SlotOperands::runOnMachineFunction(MachineFunction &MF) {
  if (!FoldReloads || skipFunction(MF.getFunction()))
    return false;
  TRI = MF.getSubtarget().getRegisterInfo();
  TII = MF.getSubtarget().getInstrInfo();
  OptSize = MF.getFunction().hasOptSize();
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF)
    Changed |= processBlock(MBB);
  return Changed;
}
