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
// copy to the accumulator (which becomes the load itself, of one byte too), where it takes
// fewer clocks, or fewer bytes in a function optimized for size. HL has to be
// free at each use, or be the reloaded register.
//
// The allocator's own folding (TargetInstrInfo::foldMemoryOperand) does not
// serve here: it would leave an instruction that needs HL where the allocator
// has not kept HL free.
//
// HL then keeps SP across blocks: a MOVW HL, SP that every path reaches with
// SP in HL already goes, and a loop that does nothing else to HL sets it once
// in its preheader. A pointer that is loaded into HL between two such
// operands, to be the base of loads and stores only, moves to DE or to
// word[BC] where that register is free.
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
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "rl78-slot-operands"

STATISTIC(NumReloads, "Reloads replaced by slot operands");
STATISTIC(NumHL, "MOVW HL, SP inserted");
STATISTIC(NumHLShared, "MOVW HL, SP removed, SP being in HL already");
STATISTIC(NumHLHoisted, "MOVW HL, SP inserted before a loop");
STATISTIC(NumPointersMoved, "Pointers moved from HL to DE or BC");

static cl::opt<bool> FoldReloads(
    "rl78-fold-reloads", cl::Hidden, cl::init(true),
    cl::desc("Use a reloaded value from its stack slot where every use is the "
             "second operand of an 8- or 16-bit operation"));

namespace {
class RL78SlotOperands : public MachineFunctionPass {
public:
  static char ID;

  RL78SlotOperands() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 slot operands"; }

  bool runOnMachineFunction(MachineFunction &MF) override;

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoVRegs();
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<MachineLoopInfoWrapperPass>();
    AU.addPreserved<MachineLoopInfoWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

private:
  // A use of a reloaded register and the offset from SP it reads instead.
  // Op is MI, or the instruction that reads the register in the bundle MI.
  struct SlotUse {
    MachineInstr *MI;
    int64_t Offset;
    MachineInstr *Op;
  };
  // What a use reads once its reload is gone: the offset, and the memory
  // operand of the reload.
  struct SlotRead {
    int64_t Offset;
    MachineMemOperand *MMO;
    MachineInstr *Op;
  };
  // What is live after an instruction.
  struct LiveAfter {
    bool HL;
    bool AX;
    BitVector Units;
  };

  // A pointer in HL from the instruction that puts it there to its last use,
  // every use the base of a load or a store, and the register that is free
  // to hold it instead.
  struct PointerRange {
    MachineInstr *Def;
    SmallVector<MachineInstr *, 4> Uses;
    MCRegister Reg;
  };
  // What a block does to SP in HL: sets it (MOVW HL, SP), loses it, or loses
  // it to a pointer that can move.
  struct Event {
    enum { Set, Kill, Pointer } Kind;
    MachineInstr *MI;
    unsigned Range;
  };
  using EventList = SmallVector<Event, 4>;

  void computeLive(MachineBasicBlock &MBB);
  bool findSlotUses(MachineInstr &Load, bool HLIsSP,
                    SmallVectorImpl<SlotUse> &Uses);
  bool processBlock(MachineBasicBlock &MBB);
  bool findPointerRange(MachineInstr &Def, PointerRange &R);
  void movePointer(PointerRange &R);
  bool hoistToPreheader(const MachineLoop &L,
                        DenseMap<MachineBasicBlock *, EventList> &Events);
  bool shareAcrossBlocks(MachineFunction &MF, const MachineLoopInfo &MLI);

  const TargetRegisterInfo *TRI = nullptr;
  const TargetInstrInfo *TII = nullptr;
  bool OptSize = false;
  DenseMap<const MachineInstr *, LiveAfter> Live;
  // The instructions from a reload of HL that is gone to its last use: HL is
  // free there, whatever Live says.
  SmallPtrSet<const MachineInstr *, 16> HLRange;
};

char RL78SlotOperands::ID = 0;
} // end anonymous namespace

INITIALIZE_PASS_BEGIN(RL78SlotOperands, DEBUG_TYPE, "RL78 slot operands",
                      false, false)
INITIALIZE_PASS_DEPENDENCY(MachineLoopInfoWrapperPass)
INITIALIZE_PASS_END(RL78SlotOperands, DEBUG_TYPE, "RL78 slot operands", false,
                    false)

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

// The one instruction of a bundle that reads D, if nothing in the bundle
// writes D: the ADDW or SUBW of an operation with carry, behind its skip.
static MachineInstr *bundledUser(MachineInstr &Bundle, Register D,
                                 const TargetRegisterInfo *TRI) {
  MachineInstr *User = nullptr;
  for (MachineBasicBlock::instr_iterator
           I = std::next(Bundle.getIterator()),
           E = Bundle.getParent()->instr_end();
       I != E && I->isBundledWithPred(); ++I) {
    if (I->modifiesRegister(D, TRI))
      return nullptr;
    if (!I->readsRegister(D, TRI))
      continue;
    if (User)
      return nullptr;
    User = &*I;
  }
  return User;
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
        Uses.push_back({&MI, Offset, &MI});
        ++NumCopies;
      } else if (MI.getOpcode() == RL78::MOV_A_r && Size == 2 &&
                 TRI->isSubRegister(D, MI.getOperand(1).getReg())) {
        // So does the copy of one byte of a pair: the sign of the second
        // operand of a signed comparison is read this way.
        bool Hi = Register(TRI->getSubReg(D, RL78::sub_hi)) ==
                  MI.getOperand(1).getReg();
        if (!isUInt<8>(Offset + Hi))
          return false;
        Uses.push_back({&MI, Offset + Hi, &MI});
        ++NumCopies;
      } else {
        MachineInstr *Op = MI.isBundle() ? bundledUser(MI, D, TRI) : &MI;
        const MemForm *F = Op ? getMemForm(Op->getOpcode()) : nullptr;
        if (!F)
          return false;
        unsigned SrcIdx = Op->getNumExplicitOperands() - 1;
        Register R = Op->getOperand(SrcIdx).getReg();
        for (unsigned J = 0, N = Op->getNumOperands(); J != N; ++J)
          if (J != SrcIdx && Op->getOperand(J).isReg() &&
              Op->getOperand(J).getReg().isValid() &&
              TRI->regsOverlap(Op->getOperand(J).getReg(), D))
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
        Uses.push_back({&MI, Disp, Op});
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

void RL78SlotOperands::computeLive(MachineBasicBlock &MBB) {
  Live.clear();
  LiveRegUnits Units(*TRI);
  Units.addLiveOuts(MBB);
  for (MachineInstr &MI : reverse(MBB)) {
    Live[&MI] = {!Units.available(RL78::RP6), !Units.available(RL78::RP0),
                 Units.getBitVector()};
    if (!MI.isDebugInstr())
      Units.stepBackward(MI);
  }
}

bool RL78SlotOperands::processBlock(MachineBasicBlock &MBB) {
  bool AnyLoad = false;
  for (const MachineInstr &MI : MBB)
    AnyLoad |= MI.getOpcode() == RL78::LOAD8_r_stack_slot ||
               MI.getOpcode() == RL78::LOAD16_rp_stack_slot;
  if (!AnyLoad)
    return false;

  computeLive(MBB);
  HLRange.clear();

  bool Changed = false;
  // HL holds SP from an earlier operand of this block.
  bool HLIsSP = false;
  DenseMap<MachineInstr *, SlotRead> SlotUses;
  for (MachineInstr &MI : make_early_inc_range(MBB)) {
    auto It = SlotUses.find(&MI);
    if (It == SlotUses.end()) {
      SmallVector<SlotUse, 4> Uses;
      if (findSlotUses(MI, HLIsSP, Uses)) {
        MachineMemOperand *MMO =
            MI.hasOneMemOperand() ? *MI.memoperands_begin() : nullptr;
        for (const SlotUse &U : Uses)
          SlotUses[U.MI] = {U.Offset, MMO, U.Op};
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

    int64_t Offset = It->second.Offset;
    // The use is a load now, of the reload's slot (a byte of it at most:
    // nothing looks at the size).
    MachineInstr &Op = *It->second.Op;
    if (It->second.MMO)
      Op.addMemOperand(*MBB.getParent(), It->second.MMO);
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
    const MemForm *Form = getMemForm(Op.getOpcode());
    if (!HLIsSP) {
      MachineBasicBlock::iterator At = MI.getIterator();
      if (MachineInstr *Prev = prevInstr(At); Prev && canSetHLAbove(*Prev, TRI))
        At = Prev->getIterator();
      BuildMI(MBB, At, MI.getDebugLoc(), TII->get(RL78::MOVW_rp_SP), RL78::RP6)
          .addReg(RL78::SPreg);
      HLIsSP = true;
      ++NumHL;
    }
    unsigned SrcIdx = Op.getNumExplicitOperands() - 1;
    Register Old = Op.getOperand(SrcIdx).getReg();
    Op.getOperand(SrcIdx).ChangeToRegister(RL78::RP6, false);
    if (Offset == 0 && Form->HL) {
      Op.setDesc(TII->get(Form->HL));
    } else {
      Op.setDesc(TII->get(Form->HLi));
      Op.addOperand(MachineOperand::CreateImm(Offset));
    }
    // The bundle reads HL where it read the reloaded register.
    if (&Op != &MI)
      for (MachineOperand &MO : MI.operands())
        if (MO.isReg() && MO.isUse() && MO.getReg() == Old) {
          MO.setReg(RL78::RP6);
          MO.setIsKill(false);
        }
  }
  return Changed;
}

// MOV and MOVW through [DE], [HL], [DE+byte] and [HL+byte], and their
// word[BC] forms.
namespace {
struct BaseForm {
  unsigned Opc;
  unsigned BCw;
  unsigned BaseIdx;
  bool HasDisp;
};
} // end anonymous namespace

static const BaseForm *getBaseForm(unsigned Opc) {
  static const BaseForm Forms[] = {
      {RL78::MOV_A_mRP, RL78::MOV_A_mBCw, 1, false},
      {RL78::MOV_A_mRPi, RL78::MOV_A_mBCw, 1, true},
      {RL78::MOV_mRP_A, RL78::MOV_mBCw_A, 0, false},
      {RL78::MOV_mRPi_A, RL78::MOV_mBCw_A, 0, true},
      {RL78::MOV_mRPi_i8, RL78::MOV_mBCw_i8, 0, true},
      {RL78::MOVW_AX_mRP, RL78::MOVW_AX_mBCw, 1, false},
      {RL78::MOVW_AX_mRPi, RL78::MOVW_AX_mBCw, 1, true},
      {RL78::MOVW_mRP_AX, RL78::MOVW_mBCw_AX, 0, false},
      {RL78::MOVW_mRPi_AX, RL78::MOVW_mBCw_AX, 0, true},
  };
  for (const BaseForm &F : Forms)
    if (F.Opc == Opc)
      return &F;
  return nullptr;
}

static bool isSetHLToSP(const MachineInstr &MI) {
  return MI.getOpcode() == RL78::MOVW_rp_SP &&
         MI.getOperand(0).getReg() == RL78::RP6;
}

// Whether Def puts a pointer in HL that DE or BC can hold instead. Needs
// computeLive of the block.
bool RL78SlotOperands::findPointerRange(MachineInstr &Def, PointerRange &R) {
  switch (Def.getOpcode()) {
  case RL78::LOAD16_rp_stack_slot:
  case RL78::MOVW_rp_i16:
  case RL78::MOVW_rp_AX:
    break;
  default:
    return false;
  }
  if (!Def.getOperand(0).isReg() || Def.getOperand(0).getReg() != RL78::RP6 ||
      Def.getOperand(0).isDead() || Def.readsRegister(RL78::RP6, TRI))
    return false;
  MachineBasicBlock &MBB = *Def.getParent();
  R.Def = &Def;
  bool Done = false;
  for (MachineBasicBlock::iterator I = std::next(Def.getIterator()),
                                   E = MBB.end();
       I != E && !Done; ++I) {
    MachineInstr &MI = *I;
    if (MI.isDebugInstr())
      continue;
    // SP has to stand in HL from before the pointer to after it.
    if (MI.isCall() || MI.isInlineAsm() ||
        MI.modifiesRegister(RL78::SPreg, TRI))
      return false;
    if (MI.readsRegister(RL78::RP6, TRI)) {
      const BaseForm *F = getBaseForm(MI.getOpcode());
      if (!F || MI.getOperand(F->BaseIdx).getReg() != RL78::RP6)
        return false;
      for (unsigned J = 0, N = MI.getNumOperands(); J != N; ++J)
        if (J != F->BaseIdx && MI.getOperand(J).isReg() &&
            MI.getOperand(J).getReg().isValid() &&
            TRI->regsOverlap(MI.getOperand(J).getReg(), RL78::RP6))
          return false;
      R.Uses.push_back(&MI);
    } else if (MI.modifiesRegister(RL78::RP6, TRI)) {
      return false;
    }
    Done = !Live.find(&MI)->second.HL;
  }
  if (!Done || R.Uses.empty())
    return false;

  // DE costs nothing; word[BC] is one or two bytes longer for each access.
  for (MCRegister Reg : {RL78::RP4, RL78::RP2}) {
    if (Reg == RL78::RP2 && OptSize)
      continue;
    if (Def.readsRegister(Reg, TRI))
      continue;
    bool Free = true;
    for (MachineBasicBlock::iterator I = Def.getIterator();; ++I) {
      bool Last = &*I == R.Uses.back();
      if (!I->isDebugInstr()) {
        if (&*I != &Def &&
            (I->readsRegister(Reg, TRI) || I->modifiesRegister(Reg, TRI)))
          Free = false;
        if (!Last) {
          const BitVector &Units = Live.find(&*I)->second.Units;
          for (MCRegUnit U : TRI->regunits(Reg))
            Free &= !Units.test(static_cast<unsigned>(U));
        }
      }
      if (Last || !Free)
        break;
    }
    if (Free) {
      R.Reg = Reg;
      return true;
    }
  }
  return false;
}

void RL78SlotOperands::movePointer(PointerRange &R) {
  MachineBasicBlock &MBB = *R.Def->getParent();
  MachineFunction &MF = *MBB.getParent();
  R.Def->getOperand(0).setReg(R.Reg);
  for (MachineBasicBlock::iterator I = std::next(R.Def->getIterator());
       &*I != R.Uses.back(); ++I)
    if (I->isDebugInstr())
      for (MachineOperand &MO : I->debug_operands())
        if (MO.isReg() && MO.getReg() == RL78::RP6)
          MO.setReg(R.Reg);
  for (MachineInstr *MI : R.Uses) {
    const BaseForm *F = getBaseForm(MI->getOpcode());
    if (R.Reg != RL78::RP2) {
      MI->getOperand(F->BaseIdx).setReg(R.Reg);
      continue;
    }
    MachineInstr *New = MF.CreateMachineInstr(TII->get(F->BCw),
                                              MI->getDebugLoc(),
                                              /*NoImplicit=*/true);
    MBB.insert(MI->getIterator(), New);
    MachineInstrBuilder MIB(MF, New);
    for (unsigned I = 0, E = MI->getNumOperands(); I != E; ++I) {
      const MachineOperand &MO = MI->getOperand(I);
      if (I == F->BaseIdx) {
        MIB.addReg(RL78::RP2, getKillRegState(MO.isKill()));
        if (!F->HasDisp)
          MIB.addImm(0);
      } else {
        MIB.add(MO);
      }
    }
    New->setMemRefs(MF, MI->memoperands());
    New->setFlags(MI->getFlags());
    MI->eraseFromParent();
  }
  ++NumPointersMoved;
}

// A loop whose every block leaves SP in HL when it is entered with SP in HL
// has it there at the start of every block once its preheader sets it: the
// first MOVW HL, SP of a block goes then.
bool RL78SlotOperands::hoistToPreheader(
    const MachineLoop &L, DenseMap<MachineBasicBlock *, EventList> &Events) {
  auto Hoist = [&] {
    MachineBasicBlock *Pre = L.getLoopPreheader();
    if (!Pre)
      return false;
    // No value comes into the loop in HL.
    LiveRegUnits Units(*TRI);
    Units.addLiveIns(*L.getHeader());
    if (!Units.available(RL78::RP6))
      return false;
    unsigned NumGone = 0;
    for (MachineBasicBlock *MBB : L.blocks()) {
      const EventList &List = Events[MBB];
      bool IsSP = true;
      for (unsigned I = 0, E = List.size(); I != E; ++I) {
        if (List[I].Kind == Event::Set) {
          NumGone += IsSP;
          IsSP = true;
        } else if (List[I].Kind == Event::Kill || !IsSP || I + 1 == E ||
                   List[I + 1].Kind != Event::Set) {
          IsSP = false;
        }
      }
      if (!IsSP)
        return false;
    }
    // One instruction more outside the loop for each one less inside.
    if (NumGone < (OptSize ? 2u : 1u))
      return false;
    MachineBasicBlock::iterator At = Pre->getFirstTerminator();
    MachineInstr *MI = BuildMI(*Pre, At, DebugLoc(),
                               TII->get(RL78::MOVW_rp_SP), RL78::RP6)
                           .addReg(RL78::SPreg);
    Events[Pre].push_back({Event::Set, MI, 0});
    ++NumHLHoisted;
    return true;
  };
  if (Hoist())
    return true;
  bool Changed = false;
  for (const MachineLoop *Sub : L)
    Changed |= hoistToPreheader(*Sub, Events);
  return Changed;
}

bool RL78SlotOperands::shareAcrossBlocks(MachineFunction &MF,
                                         const MachineLoopInfo &MLI) {
  DenseMap<MachineBasicBlock *, EventList> Events;
  std::vector<PointerRange> Ranges;
  bool AnySet = false;
  for (MachineBasicBlock &MBB : MF) {
    bool Computed = false;
    EventList &List = Events[&MBB];
    for (MachineBasicBlock::iterator I = MBB.begin(), E = MBB.end(); I != E;
         ++I) {
      MachineInstr &MI = *I;
      if (MI.isDebugInstr())
        continue;
      if (isSetHLToSP(MI)) {
        List.push_back({Event::Set, &MI, 0});
        AnySet = true;
        continue;
      }
      if (!changesHLOrSP(MI, TRI))
        continue;
      if (!Computed)
        computeLive(MBB);
      Computed = true;
      PointerRange R;
      if (findPointerRange(MI, R)) {
        List.push_back({Event::Pointer, &MI, unsigned(Ranges.size())});
        I = R.Uses.back()->getIterator();
        Ranges.push_back(std::move(R));
      } else {
        List.push_back({Event::Kill, &MI, 0});
      }
    }
  }
  if (!AnySet)
    return false;

  bool Changed = false;
  for (const MachineLoop *L : MLI)
    Changed |= hoistToPreheader(*L, Events);

  // Whether SP is in HL at the end of a block, given that it is at the start.
  // A pointer that moves has a MOVW HL, SP after it in its block.
  auto Out = [&](MachineBasicBlock *MBB, bool In) {
    const EventList &List = Events[MBB];
    return List.empty() ? In : List.back().Kind == Event::Set;
  };
  DenseMap<MachineBasicBlock *, bool> In;
  for (MachineBasicBlock &MBB : MF)
    In[&MBB] = &MBB != &MF.front() && !MBB.isEHPad() &&
               !MBB.hasAddressTaken() && !MBB.pred_empty();
  for (bool Again = true; Again;) {
    Again = false;
    for (MachineBasicBlock &MBB : MF) {
      if (!In[&MBB])
        continue;
      for (MachineBasicBlock *Pred : MBB.predecessors())
        if (!Out(Pred, In[Pred])) {
          In[&MBB] = false;
          Again = true;
          break;
        }
    }
  }

  for (MachineBasicBlock &MBB : MF) {
    EventList &List = Events[&MBB];
    bool IsSP = In[&MBB];
    if (!IsSP && List.empty())
      continue;
    unsigned Next = 0;
    for (MachineBasicBlock::iterator I = MBB.begin(); I != MBB.end();) {
      MachineInstr &MI = *I++;
      if (Next == List.size() || List[Next].MI != &MI) {
        // HL is read again after this, where it was last read before.
        if (IsSP && !MI.isDebugInstr())
          MI.clearRegisterKills(RL78::RP6, TRI);
        continue;
      }
      Event &Ev = List[Next++];
      switch (Ev.Kind) {
      case Event::Set:
        if (IsSP) {
          MI.eraseFromParent();
          ++NumHLShared;
          Changed = true;
        }
        IsSP = true;
        break;
      case Event::Pointer:
        if (IsSP && Next != List.size() && List[Next].Kind == Event::Set) {
          I = std::next(Ranges[Ev.Range].Uses.back()->getIterator());
          movePointer(Ranges[Ev.Range]);
          Changed = true;
        } else {
          IsSP = false;
        }
        break;
      case Event::Kill:
        IsSP = false;
        break;
      }
    }
  }
  if (!Changed)
    return false;

  // HL is live into more blocks now.
  DenseMap<MachineBasicBlock *, bool> LiveIn, Through;
  for (MachineBasicBlock &MBB : MF) {
    bool Reads = false, Writes = false;
    for (MachineInstr &MI : MBB) {
      if (MI.isDebugInstr())
        continue;
      if (MI.readsRegister(RL78::RP6, TRI)) {
        Reads = true;
        Writes = true;
      } else if (MI.isCall() || MI.definesRegister(RL78::RP6, TRI)) {
        Writes = true;
      }
      if (Writes)
        break;
    }
    LiveIn[&MBB] = Reads;
    Through[&MBB] = !Writes;
  }
  for (bool Again = true; Again;) {
    Again = false;
    for (MachineBasicBlock &MBB : reverse(MF)) {
      if (LiveIn[&MBB] || !Through[&MBB])
        continue;
      for (MachineBasicBlock *Succ : MBB.successors())
        if (LiveIn[Succ]) {
          LiveIn[&MBB] = true;
          Again = true;
          break;
        }
    }
  }
  for (MachineBasicBlock &MBB : MF)
    if (In[&MBB] && LiveIn[&MBB] && !MBB.isLiveIn(RL78::RP6))
      MBB.addLiveIn(RL78::RP6);
  return true;
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
  Changed |=
      shareAcrossBlocks(MF, getAnalysis<MachineLoopInfoWrapperPass>().getLI());
  return Changed;
}
