//===-- RL78ISelDAGToDAG.cpp - A dag to dag inst selector for RL78 ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines an instruction selector for the RL78 target.
//
//===----------------------------------------------------------------------===//

#include "RL78TargetMachine.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/CodeGen/FunctionLoweringInfo.h"

using namespace llvm;

//===----------------------------------------------------------------------===//
// Instruction Selector Implementation
//===----------------------------------------------------------------------===//

//===--------------------------------------------------------------------===//
/// RL78DAGToDAGISel - RL78 specific code to select RL78 machine
/// instructions for SelectionDAG operations.

#define DEBUG_TYPE "rl78-isel"
#define PASS_NAME "RL78 DAG->DAG Pattern Instruction Selection"

namespace {
class RL78DAGToDAGISel : public SelectionDAGISel {
  /// Subtarget - Keep a pointer to the RL78 Subtarget around so that we can
  /// make the right decision when generating code for different targets.
  const RL78Subtarget *Subtarget = nullptr;

  void MatchSET1CLR1(SDNode *&N);
  bool MatchLOAD_SELECTCC(SDNode *&N);
  bool orderCompareLoadLast(SDNode *Br);
  SDNode *SelectFI(SDNode *N);

public:
  RL78DAGToDAGISel() = delete;

  explicit RL78DAGToDAGISel(RL78TargetMachine &TargetMachine,
                            CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TargetMachine, OptLevel) {}

  bool runOnMachineFunction(MachineFunction &MF) override {
    Subtarget = &MF.getSubtarget<RL78Subtarget>();
    return SelectionDAGISel::runOnMachineFunction(MF);
  }

  void PreprocessISelDAG() override;
  void PostprocessISelDAG() override;

  void Select(SDNode *N) override;
  bool SelectInlineAsmMemoryOperand(const SDValue &Op,
                                    InlineAsm::ConstraintCode ConstraintCode,
                                    std::vector<SDValue> &OutOps) override;
  // Complex Pattern Selectors.
  bool SelectADDRr(SDValue Addr, SDValue &Base);
  bool SelectADDRrr(SDValue Addr, SDValue &R1, SDValue &R2);
  bool SelectADDRSPi(SDValue Addr, SDValue &Base, SDValue &Offset);
  bool SelectADDRArgSP(SDValue Addr, SDValue &Base, SDValue &Offset);

  template <int Max, bool AllowWordBC = false>
  bool SelectADDRri(SDValue Addr, SDValue &Base, SDValue &Offset) {
    return SelectADDRri(Addr, Max, AllowWordBC, Base, Offset);
  }
  bool SelectADDRri(SDValue Addr, unsigned Size, bool AllowWordBC, SDValue &Base,
                    SDValue &Offset, bool PermitFrameIndex = false);
  bool SelectADDRr8i16(SDValue Addr, SDValue &Base,
                    SDValue &Offset);

  // [HL] and [HL+byte], byte 1 to 255.
  bool SelectMemHL(SDValue Addr, SDValue &Base);
  bool SelectMemHLi(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectMemHLw(SDValue Addr, SDValue &Base, SDValue &Disp);

  // [DE]/[HL], [DE+byte]/[HL+byte] (byte 1 to 255, or 0 to 255 for the
  // instructions without a [DE]/[HL] form), word[BC], [HL+B]/[HL+C].
  bool isIndexedAddr(SDValue Addr);
  bool SelectMemRP(SDValue Addr, SDValue &Base);
  bool SelectMemRPi(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectMemRPiw0(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectMemRPw(SDValue Addr, SDValue &Base);
  bool SelectMemRPiw(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectMemRPi0(SDValue Addr, SDValue &Base, SDValue &Disp);
  bool SelectMemBCw(SDValue Addr, SDValue &Base, SDValue &Word);
  bool SelectMemHLr(SDValue Addr, SDValue &Base, SDValue &Index);

  // The same behind ES:. A far address is (HI16 segment, near address); the
  // segment becomes a MOV ES, #byte or MOV ES, A whose result is the
  // instruction's ES operand (RL78AssignES puts it in ES itself).
  bool SelectingFar = false;
  SDValue getES(SDValue Segment);
  template <typename Fn> bool selectFar(SDValue Addr, SDValue &ES, Fn Near) {
    if (Addr.getOpcode() != RL78ISD::HI16)
      return false;
    SelectingFar = true;
    bool Matched = Near(Addr.getOperand(1));
    SelectingFar = false;
    if (Matched)
      ES = getES(Addr.getOperand(0));
    return Matched;
  }
#define RL78_FAR1(NAME)                                                        \
  bool SelectES##NAME(SDValue Addr, SDValue &ES, SDValue &A) {                 \
    return selectFar(Addr, ES, [&](SDValue N) { return Select##NAME(N, A); }); \
  }
#define RL78_FAR2(NAME)                                                        \
  bool SelectES##NAME(SDValue Addr, SDValue &ES, SDValue &A, SDValue &B) {     \
    return selectFar(Addr, ES,                                                 \
                     [&](SDValue N) { return Select##NAME(N, A, B); });        \
  }
  RL78_FAR1(MemHL)
  RL78_FAR2(MemHLi)
  RL78_FAR2(MemHLw)
  RL78_FAR1(MemRP)
  RL78_FAR2(MemRPi)
  RL78_FAR2(MemRPi0)
  RL78_FAR2(MemBCw)
  RL78_FAR2(MemHLr)
#undef RL78_FAR1
#undef RL78_FAR2
  bool SelectESMemHLi0(SDValue Addr, SDValue &ES, SDValue &Base,
                       SDValue &Disp) {
    return selectFar(Addr, ES, [&](SDValue N) {
      return SelectADDRri(N, 255, false, Base, Disp);
    });
  }
  bool SelectESHL(SDValue Addr, SDValue &ES, SDValue &Base) {
    return selectFar(Addr, ES,
                     [&](SDValue N) { return SelectADDRr(N, Base); });
  }
  bool SelectESMemBw(SDValue Addr, SDValue &ES, SDValue &Index,
                     SDValue &Word) {
    return selectFar(Addr, ES, [&](SDValue N) {
      return SelectADDRr8i16(N, Index, Word);
    });
  }
  bool SelectESAbs16(SDValue Addr, SDValue &ES, SDValue &Abs);

  bool SelectADDRABS16(SDValue Addr, SDValue &Base);
  bool SelectSaddr(SDNode *Parent, SDValue Addr, SDValue &Base);
  bool SelectSFR(SDValue Addr, SDValue &Base);

  bool SelectESADDRr(SDValue Addr, SDValue &BaseHi, SDValue &BaseLow);
  bool SelectESADDRrr(SDValue Addr,  SDValue &BaseHi, SDValue &R1, SDValue &R2);
  template <int Max, bool AllowWordBC = false>
  bool SelectESADDRri(SDValue Addr, SDValue &BaseHi, SDValue &BaseLow, SDValue &Offset) {
    return SelectESADDRri(Addr, Max, AllowWordBC, BaseHi, BaseLow, Offset);
  }
  bool SelectESADDRri(SDValue Addr, unsigned Size, bool AllowWordBC, SDValue &BaseHi, SDValue &BaseLow,
                    SDValue &Offset);
  bool SelectESADDRr8i16(SDValue Addr, SDValue &BaseHi, SDValue &BaseLow,
                    SDValue &Offset);
  bool SelectESADDRABS16(SDValue Addr, SDValue &BaseHi, SDValue &BaseLow);

  // Include the pieces autogenerated from the target description.
#include "RL78GenDAGISel.inc"
};

class RL78DAGToDAGISelLegacy : public SelectionDAGISelLegacy {
public:
  static char ID;
  explicit RL78DAGToDAGISelLegacy(RL78TargetMachine &TM,
                                  CodeGenOptLevel OptLevel)
      : SelectionDAGISelLegacy(
            ID, std::make_unique<RL78DAGToDAGISel>(TM, OptLevel)) {}

  StringRef getPassName() const override {
    return "RL78 DAG->DAG Pattern Instruction Selection";
  }
};
} // end anonymous namespace

static SDValue TraversePossibleMOV(SDValue Value) {
  if (Value.isMachineOpcode() &&
      (Value.getMachineOpcode() == RL78::MOV_r_i8 ||
       Value.getMachineOpcode() == RL78::MOVW_rp_i16))
    return Value.getOperand(0);
  return Value;
}

static bool AreCmpOpsEqual(SDValue Cmp) {
  // Avoid matching cmp_r_memri  t41, t41, ...
  // see gcc.c_torture\pr33870.c -O1
  if (!Cmp.isMachineOpcode() ||
      (Cmp.getMachineOpcode() != RL78::CMPW_AX_i16 &&
       Cmp.getMachineOpcode() != RL78::CMPW_AX_rp &&
       Cmp.getMachineOpcode() != RL78::CMP_A_i8 &&
       Cmp.getMachineOpcode() != RL78::CMP_A_r))
    return false;

  SDValue LHS = Cmp.getOperand(0);
  SDValue RHS = Cmp.getOperand(1);
  return TraversePossibleMOV(LHS) == TraversePossibleMOV(RHS);
}

// A branch on a compare whose chain is a TokenFactor of loads that are not
// ordered among themselves, one of them the second operand of the compare
// (the 32-bit compare of two volatile globals): the load's chain reaches the
// branch around the glue, so folding it into the compare would make the
// glued group depend on itself, and the generic check refuses. Make that
// load the last of them, after the others, and the branch's chain its chain:
// then CMPW AX, !addr16 reads it, as in the 16-bit compare. Only the first
// compare, CMP: the ones after it (LOWCMP) are skipped when the words above
// differ, and a volatile load must happen.
bool RL78DAGToDAGISel::orderCompareLoadLast(SDNode *Br) {
  SDValue Chain = Br->getOperand(0);
  if (Chain.getOpcode() != ISD::TokenFactor || !Chain.hasOneUse())
    return false;
  SDNode *Cmp = Br->getOperand(Br->getNumOperands() - 1).getNode();
  while (Cmp->getOpcode() == RL78ISD::LOWCMP && Cmp->getNumOperands() == 3)
    Cmp = Cmp->getOperand(2).getNode();
  if (Cmp->getOpcode() != RL78ISD::CMP)
    return false;
  auto *Ld = dyn_cast<LoadSDNode>(Cmp->getOperand(1));
  if (!Ld || !Ld->isUnindexed() || !Ld->hasNUsesOfValue(1, 0))
    return false;
  SDValue LdChain(Ld, 1);
  SmallVector<SDValue, 4> Before;
  bool Found = false;
  for (SDValue Op : Chain->op_values()) {
    if (Op == LdChain) {
      Found = true;
      continue;
    }
    if (Op.getNode()->hasPredecessor(Ld))
      return false;
    Before.push_back(Op);
  }
  if (!Found)
    return false;
  Before.push_back(Ld->getChain());
  SDValue In = CurDAG->getNode(ISD::TokenFactor, SDLoc(Ld), MVT::Other, Before);
  if (CurDAG->UpdateNodeOperands(Ld, In, Ld->getBasePtr(), Ld->getOffset()) !=
      Ld)
    report_fatal_error("load folded into another while reordering");
  SmallVector<SDValue, 4> BrOps(Br->ops());
  BrOps[0] = LdChain;
  CurDAG->UpdateNodeOperands(Br, BrOps);
  return true;
}

void RL78DAGToDAGISel::PreprocessISelDAG() {
  SelectionDAG::allnodes_iterator Position = CurDAG->allnodes_end();

  bool MadeChange = false;
  while (Position != CurDAG->allnodes_begin()) {
    SDNode *N = &*--Position;
    // Skip dead nodes.
    if (N->use_empty())
      continue;

    switch (N->getOpcode()) {
    default:
      break;
    case ISD::LOAD:
      MadeChange |= MatchLOAD_SELECTCC(N);
      break;
    case RL78ISD::BRCC:
      MadeChange |= orderCompareLoadLast(N);
      break;
    }
  }
  if (MadeChange)
    CurDAG->RemoveDeadNodes();
}

void RL78DAGToDAGISel::PostprocessISelDAG() {
  SelectionDAG::allnodes_iterator Position = CurDAG->allnodes_end();

  bool MadeChange = false;
  while (Position != CurDAG->allnodes_begin()) {
    SDNode *N = &*--Position;
    // Skip dead nodes and any non-machine opcodes.
    if (N->use_empty() || !N->isMachineOpcode())
      continue;

    // Eliminate cmp(w) ax, ax
    //           selectcc ...
    // Assume that N->getOperand(3).getMachineOpcode() == CMP_*.
    if (((N->getMachineOpcode() == RL78::SELECTCC16_rp_rp ||
         N->getMachineOpcode() == RL78::SELECTCC16_imm_rp ||
         N->getMachineOpcode() == RL78::SELECTCC16_rp_imm ||
         N->getMachineOpcode() == RL78::SELECTCC16_imm_imm ||
         N->getMachineOpcode() == RL78::SELECTCC8_r_r ||
         N->getMachineOpcode() == RL78::SELECTCC8_imm_r) &&
            AreCmpOpsEqual(N->getOperand(3))) ||
        ((N->getMachineOpcode() == RL78::SELECTCC16_esaddr_rp ||
         N->getMachineOpcode() == RL78::SELECTCC16_esaddr_imm ||
         N->getMachineOpcode() == RL78::SELECTCC8_esaddr_r ||
         N->getMachineOpcode() == RL78::SELECTCC8_esaddr_imm) &&
            AreCmpOpsEqual(N->getOperand(5)))) {

      SDValue SelectionResult;
      SDValue TrueValue = N->getOperand(0);
      SDValue FalseValue = N->getOperand(1);
      switch ((RL78CC::CondCodes)N->getConstantOperandVal(2)) {
      case RL78CC::RL78CC_C:
      case RL78CC::RL78CC_NZ:
      case RL78CC::RL78CC_H:
        SelectionResult = FalseValue;
        break;
      case RL78CC::RL78CC_NC:
      case RL78CC::RL78CC_NH:
      case RL78CC::RL78CC_Z:
        SelectionResult = TrueValue;
        break;
      }

      // The _imm forms select between target constants, which are not values
      // by themselves: materialize the chosen one.
      if (isa<ConstantSDNode>(SelectionResult)) {
        EVT VT = N->getValueType(0);
        SelectionResult = SDValue(
            CurDAG->getMachineNode(VT == MVT::i8 ? RL78::MOV_r_i8
                                                 : RL78::MOVW_rp_i16,
                                   SDLoc(N), VT, SelectionResult),
            0);
      }

      CurDAG->ReplaceAllUsesWith(N, &SelectionResult);
      MadeChange = true;
    } else if (N->getMachineOpcode() == RL78::BRCC &&
               AreCmpOpsEqual(N->getOperand(3))) {
      // see gcc.c_torture\scal-to-vec1.c. -O3
      switch ((RL78CC::CondCodes)N->getConstantOperandVal(1)) {
      case RL78CC::RL78CC_C:
      case RL78CC::RL78CC_NZ:
      case RL78CC::RL78CC_H: {
        auto tgtBB = (BasicBlockSDNode *)N->getOperand(0).getNode();
        if (tgtBB->hasOneUse())
          FuncInfo.get()->MBB->removeSuccessor(tgtBB->getBasicBlock(), true);
        CurDAG->ReplaceAllUsesWith(N, &N->getOperand(2));
      } break;
      case RL78CC::RL78CC_NC:
      case RL78CC::RL78CC_NH:
      case RL78CC::RL78CC_Z: {
        SDLoc dl(N);
        MachineSDNode *BranchNode =
            CurDAG->getMachineNode(RL78::BR, dl, N->getValueType(0),
                                   N->getOperand(0), N->getOperand(2));
        CurDAG->ReplaceAllUsesWith(N, BranchNode);
        // Also nullify the fall-through BR, now unreachable.
        for (SDNode *Use : BranchNode->users()) {
          if (Use->getMachineOpcode() == RL78::BR) {
            auto tgtBB = (BasicBlockSDNode *)Use->getOperand(0).getNode();
            if (tgtBB->hasOneUse())
              FuncInfo.get()->MBB->removeSuccessor(tgtBB->getBasicBlock(), true);
            CurDAG->ReplaceAllUsesWith(Use, &Use->getOperand(1));
            break;
          }
        }
      } break;
      }
      MadeChange = true;
    } else if ((N->getMachineOpcode() ==
                    RL78::LOAD_SELECTCC8_r_esaddr16_esaddr16 ||
                N->getMachineOpcode() ==
                    RL78::LOAD_SELECTCC16_rp_esaddr16_esaddr16 ||
                N->getMachineOpcode() ==
                    RL78::LOAD_SELECTCC8_r_esaddrr_esaddrr ||
                N->getMachineOpcode() ==
                    RL78::LOAD_SELECTCC16_rp_esaddrr_esaddrr) &&
               AreCmpOpsEqual(N->getOperand(6))) {
      SDValue AddrHi, AddrLo;
      switch ((RL78CC::CondCodes)N->getConstantOperandVal(4)) {
      case RL78CC::RL78CC_C:
      case RL78CC::RL78CC_NZ:
      case RL78CC::RL78CC_H:
        AddrHi = N->getOperand(2);
        AddrLo = N->getOperand(3);
        break;
      case RL78CC::RL78CC_NC:
      case RL78CC::RL78CC_NH:
      case RL78CC::RL78CC_Z:
        AddrHi = N->getOperand(0);
        AddrLo = N->getOperand(1);
        break;
      }

      // The load that is left, with ES loaded from the segment operand.
      SDValue Ops[] = {getES(AddrHi), AddrLo};
      unsigned LdOpcode;
      SDLoc dl(N);

      switch (N->getMachineOpcode()) {
      default:
        llvm_unreachable("Unknown opcode.");
      case RL78::LOAD_SELECTCC8_r_esaddr16_esaddr16:
        LdOpcode = RL78::MOV_r_eabs16;
        break;
      case RL78::LOAD_SELECTCC16_rp_esaddr16_esaddr16:
        LdOpcode = RL78::MOVW_rp_eabs16;
        break;
      case RL78::LOAD_SELECTCC8_r_esaddrr_esaddrr:
        LdOpcode = RL78::MOV_A_emRP;
        break;
      case RL78::LOAD_SELECTCC16_rp_esaddrr_esaddrr:
        LdOpcode = RL78::MOVW_AX_emRP;
        break;
      }

      MachineSDNode *LdNode = CurDAG->getMachineNode(LdOpcode, dl, N->getValueType(0), Ops);
      CurDAG->ReplaceAllUsesWith(N, LdNode);
      MadeChange = true;
    }
  }
  if (MadeChange)
    CurDAG->RemoveDeadNodes();
}

bool RL78DAGToDAGISel::SelectADDRSPi(SDValue Addr, SDValue &Base,
                                     SDValue &Offset) {
  // Addr.dump(CurDAG);
  if (FrameIndexSDNode *FIN = dyn_cast<FrameIndexSDNode>(Addr)) {
    Base = CurDAG->getTargetFrameIndex(
        FIN->getIndex(), TLI->getPointerTy(CurDAG->getDataLayout()));
    Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i16);
    return true;
  }
  if (Addr.getOpcode() == ISD::ADD || Addr.getOpcode() == ISD::OR) {
    if (ConstantSDNode *CN = dyn_cast<ConstantSDNode>(Addr.getOperand(1))) {
      if (isUInt<16>(CN->getZExtValue())) {
        if (FrameIndexSDNode *FIN =
                dyn_cast<FrameIndexSDNode>(Addr.getOperand(0))) {
          // Constant offset from frame ref.
          Base = CurDAG->getTargetFrameIndex(
              FIN->getIndex(), TLI->getPointerTy(CurDAG->getDataLayout()));
          Offset = CurDAG->getTargetConstant(CN->getZExtValue(), SDLoc(Addr),
                                             MVT::i16);
          return true;
        }
      }
    }
  }
  return false;
}

bool RL78DAGToDAGISel::SelectADDRArgSP(SDValue Addr, SDValue &Base,
                                       SDValue &Offset) {
  auto *FIN = dyn_cast<FrameIndexSDNode>(Addr);
  // In a function that realigns its stack the arguments are read through
  // the saved SP, with HL: a sequence written for loads into A and AX.
  if (!FIN || Subtarget->getRegisterInfo()->shouldRealignStack(*MF))
    return false;
  // The fixed objects above the frame (negative offsets) are the arguments
  // and the return address; those at SP are the arguments of calls made
  // here, which are written.
  const MachineFrameInfo &MFI = MF->getFrameInfo();
  int FI = FIN->getIndex();
  if (!MFI.isFixedObjectIndex(FI) || !MFI.isImmutableObjectIndex(FI) ||
      MFI.getObjectOffset(FI) >= 0)
    return false;
  Base = CurDAG->getTargetFrameIndex(
      FIN->getIndex(), TLI->getPointerTy(CurDAG->getDataLayout()));
  Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i16);
  return true;
}

// An inline asm memory operand ("m") is [DE] or [HL]: the address goes into
// one of them. A far address (__far data) is not supported.
bool RL78DAGToDAGISel::SelectInlineAsmMemoryOperand(
    const SDValue &Op, InlineAsm::ConstraintCode ConstraintCode,
    std::vector<SDValue> &OutOps) {
  if (ConstraintCode != InlineAsm::ConstraintCode::m ||
      Op.getValueType() != MVT::i16)
    return true;
  SDLoc DL(Op);
  Register VReg = MF->getRegInfo().createVirtualRegister(&RL78::RL78DEHLRegClass);
  SDValue Copy = CurDAG->getCopyToReg(CurDAG->getEntryNode(), DL, VReg, Op);
  OutOps.push_back(CurDAG->getCopyFromReg(Copy, DL, VReg, MVT::i16));
  return false;
}

bool RL78DAGToDAGISel::SelectADDRr(SDValue Addr, SDValue &Base) {
  if (Addr.getOpcode() == RL78ISD::LOW16 ||
      (Addr.getOpcode() == ISD::ADD &&
       Addr->getOperand(0).getOpcode() == RL78ISD::HI16))
    return false;
  if (Addr.getOpcode() == RL78ISD::HI16)
    return false;
  if (Addr.getOpcode() == RL78ISD::LOW8)
    return false;
  if (Addr.getOpcode() == ISD::FrameIndex)
    return false;
  if (Addr.getOpcode() == ISD::Constant)
    return false;
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetBlockAddress)
    return false; // Direct calls.
  Base = Addr;
  return true;
}

bool RL78DAGToDAGISel::SelectADDRri(SDValue Addr, unsigned Max, bool AllowWordBC, SDValue &Base,
                                    SDValue &Offset, bool PermitFrameIndex) {
  // Addr.dump(CurDAG);
  if (Addr.getOpcode() == RL78ISD::LOW16)
    return false;
  if (Addr.getOpcode() == RL78ISD::HI16)
    return false;
  if (Addr.getOpcode() == RL78ISD::LOW8)
    return false;
  if (!(PermitFrameIndex || SelectingFar) && Addr.getOpcode() == ISD::FrameIndex)
    return false;
  if (Addr.getOpcode() == ISD::Constant)
    return false;
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetBlockAddress)
    return false; // Direct calls.

  if (Addr.getOpcode() == ISD::ADD || Addr.getOpcode() == ISD::OR) {
    if (ConstantSDNode *CN = dyn_cast<ConstantSDNode>(Addr.getOperand(1))) {
      if (!(PermitFrameIndex || SelectingFar) &&
          dyn_cast<FrameIndexSDNode>(Addr.getOperand(0)) != nullptr) {
        return false;
      }
      if(Addr.getOperand(0).getOpcode() ==  RL78ISD::LOW16)
          return false;
      if ((CN->getSExtValue() > 0) && (CN->getSExtValue() <= Max)) {
        Base = Addr.getOperand(0);
        Offset = CurDAG->getTargetConstant(CN->getZExtValue(), SDLoc(Addr),
                                           MVT::i16);
        return true;
      }
    } else if (AllowWordBC && Addr.getOperand(1).getOpcode() == RL78ISD::LOW16) {
      Base =  Addr.getOperand(0);
      Offset = Addr.getOperand(1).getOperand(0);
      return true;
    }
  }
  Base = Addr;
  Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i16);
  return true;
}

bool RL78DAGToDAGISel::SelectMemHL(SDValue Addr, SDValue &Base) {
  SDValue Disp;
  return SelectADDRri(Addr, 255, false, Base, Disp) && isNullConstant(Disp);
}

// [HL+byte] and [HL+byte+1].
bool RL78DAGToDAGISel::SelectMemHLw(SDValue Addr, SDValue &Base,
                                    SDValue &Disp) {
  return SelectADDRri(Addr, 254, false, Base, Disp);
}

bool RL78DAGToDAGISel::SelectMemHLi(SDValue Addr, SDValue &Base,
                                    SDValue &Disp) {
  return SelectADDRri(Addr, 255, false, Base, Disp) && !isNullConstant(Disp);
}

// base + zero-extended 8-bit index: word[B] when the base is an address
// (!addr16), [HL+B]/[HL+C] otherwise.
bool RL78DAGToDAGISel::isIndexedAddr(SDValue Addr) {
  SDValue A, B;
  return SelectADDRr8i16(Addr, A, B) || SelectADDRrr(Addr, A, B);
}

bool RL78DAGToDAGISel::SelectMemHLr(SDValue Addr, SDValue &Base,
                                    SDValue &Index) {
  SDValue A, B;
  return !SelectADDRr8i16(Addr, A, B) && SelectADDRrr(Addr, Base, Index);
}

bool RL78DAGToDAGISel::SelectMemRPi0(SDValue Addr, SDValue &Base,
                                     SDValue &Disp) {
  return !isIndexedAddr(Addr) && SelectADDRri(Addr, 255, false, Base, Disp);
}

bool RL78DAGToDAGISel::SelectMemRP(SDValue Addr, SDValue &Base) {
  SDValue Disp, Word;
  return !SelectMemBCw(Addr, Base, Word) && SelectMemRPi0(Addr, Base, Disp) &&
         isNullConstant(Disp);
}

bool RL78DAGToDAGISel::SelectMemRPi(SDValue Addr, SDValue &Base,
                                    SDValue &Disp) {
  return SelectMemRPi0(Addr, Base, Disp) && !isNullConstant(Disp);
}

// [rp] and [rp+byte] of a word. There is no word at [HL+B] or [HL+C], so a
// base plus a zero-extended byte is a base register like any other.
bool RL78DAGToDAGISel::SelectMemRPiw0(SDValue Addr, SDValue &Base,
                                      SDValue &Disp) {
  SDValue A, B;
  return !SelectADDRr8i16(Addr, A, B) && !SelectMemBCw(Addr, A, B) &&
         SelectADDRri(Addr, 255, false, Base, Disp);
}

bool RL78DAGToDAGISel::SelectMemRPw(SDValue Addr, SDValue &Base) {
  SDValue Disp;
  return SelectMemRPiw0(Addr, Base, Disp) && isNullConstant(Disp);
}

bool RL78DAGToDAGISel::SelectMemRPiw(SDValue Addr, SDValue &Base,
                                     SDValue &Disp) {
  return SelectMemRPiw0(Addr, Base, Disp) && !isNullConstant(Disp);
}

// word[BC]: a register plus a constant above 255 or plus an address.
bool RL78DAGToDAGISel::SelectMemBCw(SDValue Addr, SDValue &Base,
                                    SDValue &Word) {
  if (isIndexedAddr(Addr) ||
      !SelectADDRri(Addr, 65535, true, Base, Word))
    return false;
  if (auto *C = dyn_cast<ConstantSDNode>(Word))
    return C->getZExtValue() > 255;
  return true;
}

bool RL78DAGToDAGISel::SelectADDRrr(SDValue Addr, SDValue &R1, SDValue &R2) {
  if (Addr.getOpcode() == RL78ISD::LOW16)
    return false;
  if (Addr.getOpcode() == RL78ISD::HI16)
    return false;
  if (Addr.getOpcode() == RL78ISD::LOW8)
    return false;
  if (Addr.getOpcode() == ISD::FrameIndex)
    return false;
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetBlockAddress)
    return false; // direct calls.

  if (Addr.getOpcode() == ISD::ADD) {
    if (ConstantSDNode *CN = dyn_cast<ConstantSDNode>(Addr.getOperand(1)))
      return false;
    // the index must be zero-extended to i16 (full 16-bit index is not supported,
    // also sign-extension won't work for negative values)
    if ((Addr.getValueType() != MVT::i16) ||
        (Addr.getOperand(1).getOpcode() != ISD::ZERO_EXTEND))
      return false;
    R1 = Addr.getOperand(0);
    R2 = Addr.getOperand(1)->getOperand(0);
    return true;
  }
  //
  return false;
}

static bool selectADDRABS16(SDValue Addr, SDValue &Base, SelectionDAG *CurDAG,
                            bool checkSFR) {
  if (Addr.getOpcode() == RL78ISD::LOW16 &&
      (Addr.getOperand(0).getOpcode() == ISD::TargetGlobalAddress ||
       Addr.getOperand(0).getOpcode() == ISD::Constant)) {
    Base = Addr->getOperand(0);
    return true;
  }

  // addr16 + const
  if (Addr.getOpcode() == ISD::ADD &&
      ((Addr.getOperand(0).getOpcode() == ISD::Constant &&
           Addr.getOperand(1).getOpcode() == RL78ISD::LOW16) ||
       (Addr.getOperand(1).getOpcode() == ISD::Constant &&
           Addr.getOperand(0).getOpcode() == RL78ISD::LOW16))) {

    int64_t additionalOffset = 0;
    SDValue Low16;
    if (Addr.getOperand(0).getOpcode() == ISD::Constant) {
      additionalOffset = Addr.getConstantOperandVal(0);
      Low16 = Addr.getOperand(1);
    } else {
      additionalOffset = Addr.getConstantOperandVal(1);
      Low16 = Addr.getOperand(0);
    }

    if (Low16.getOperand(0).getOpcode() == ISD::TargetGlobalAddress) {
      GlobalAddressSDNode *globalAddress = dyn_cast<GlobalAddressSDNode>(Low16.getOperand(0));
      int64_t originalOffset = globalAddress->getOffset();
      Base = CurDAG->getTargetGlobalAddress(
          globalAddress->getGlobal(), SDLoc(Low16.getOperand(0)), MVT::i16,
          originalOffset + additionalOffset, globalAddress->getTargetFlags());
      return true;
    } else if (Low16.getOperand(0).getOpcode() == ISD::Constant) {
      uint64_t address =
          dyn_cast<ConstantSDNode>(Low16.getOperand(0))->getConstantIntValue()->getZExtValue();
      Base = CurDAG->getTargetConstant(address + additionalOffset, SDLoc(Low16.getOperand(0)),
                                       MVT::i16);
      return true;
    } else {
      return false;
    }
  }

  if (Addr.getOpcode() == ISD::Constant) {
    unsigned address =
        dyn_cast<ConstantSDNode>(Addr)->getConstantIntValue()->getZExtValue();
    if (checkSFR && (address >= 0xFF00))
      return false;
    Base = CurDAG->getTargetConstant(address, SDLoc(Addr), MVT::i16);
    return true;
  }

  return false;
}

bool RL78DAGToDAGISel::SelectESAbs16(SDValue Addr, SDValue &ES,
                                     SDValue &Abs) {
  return selectFar(Addr, ES, [&](SDValue N) {
    return selectADDRABS16(N, Abs, CurDAG, false);
  });
}

SDValue RL78DAGToDAGISel::getES(SDValue Segment) {
  SDLoc DL(Segment);
  switch (Segment.getOpcode()) {
  case ISD::Constant:
  case ISD::TargetConstant:
    Segment = CurDAG->getTargetConstant(
        cast<ConstantSDNode>(Segment)->getZExtValue() & 0xFF, DL, MVT::i8);
    [[fallthrough]];
  case ISD::TargetGlobalAddress:
  case ISD::TargetExternalSymbol:
  case ISD::TargetBlockAddress:
  case ISD::TargetConstantPool:
  case ISD::TargetJumpTable:
    return SDValue(
        CurDAG->getMachineNode(RL78::MOV_ES_i8, DL, MVT::i8, Segment), 0);
  }
  // The segment is the low byte of the upper word.
  SDValue Byte =
      CurDAG->getTargetExtractSubreg(RL78::sub_lo, DL, MVT::i8, Segment);
  return SDValue(CurDAG->getMachineNode(RL78::MOV_ES_A, DL, MVT::i8, Byte), 0);
}

bool RL78DAGToDAGISel::SelectADDRABS16(SDValue Addr, SDValue &Base) {
  return selectADDRABS16(Addr, Base, CurDAG, true);
}

bool RL78DAGToDAGISel::SelectADDRr8i16(SDValue Addr, SDValue &Base,
                                       SDValue &Offset) {
  if (Addr.getOpcode() !=  ISD::ADD ||
      Addr.getValueType() != MVT::i16)
    return false;

  if (selectADDRABS16(Addr.getOperand(0), Offset, CurDAG, false) &&
      Addr.getOperand(1).getOpcode() == ISD::ZERO_EXTEND)
    Base = Addr.getOperand(1).getOperand(0);
  else if (selectADDRABS16(Addr.getOperand(1), Offset, CurDAG, false) &&
           Addr.getOperand(0).getOpcode() == ISD::ZERO_EXTEND)
    Base = Addr.getOperand(0).getOperand(0);
  else
    return false;
  return Base.getValueType() == MVT::i8;
}

static bool SelectBaseHi(SDValue Addr, SDValue &BaseHi, SelectionDAG *CurDAG) {
  if (Addr.getOpcode() != RL78ISD::HI16)
    return false;
  if (Addr.getOperand(0).getOpcode() == ISD::Constant)
    BaseHi = CurDAG->getTargetConstant(Addr.getConstantOperandVal(0),
                                       SDLoc(Addr), MVT::i16);
  else
    BaseHi = Addr.getOperand(0);
  return true;
}

bool RL78DAGToDAGISel::SelectESADDRr(SDValue Addr, SDValue &BaseHi,
                                     SDValue &BaseLow) {
  return SelectBaseHi(Addr, BaseHi, CurDAG) &&
         SelectADDRr(Addr.getOperand(1), BaseLow);
}

bool RL78DAGToDAGISel::SelectESADDRrr(SDValue Addr, SDValue &BaseHi, SDValue &R1, SDValue &R2) {
    return SelectBaseHi(Addr, BaseHi, CurDAG) &&
         SelectADDRrr(Addr.getOperand(1), R1, R2);
}

bool RL78DAGToDAGISel::SelectESADDRri(SDValue Addr, unsigned Size,
                                      bool AllowWordBC, SDValue &BaseHi,
                                      SDValue &BaseLow, SDValue &Offset) {
  return SelectBaseHi(Addr, BaseHi, CurDAG) &&
         SelectADDRri(Addr.getOperand(1), Size, AllowWordBC, BaseLow, Offset, true);
}

bool RL78DAGToDAGISel::SelectESADDRr8i16(SDValue Addr, SDValue &BaseHi, SDValue &BaseLow,
                       SDValue &Offset) {
    return SelectBaseHi(Addr, BaseHi, CurDAG) &&
         SelectADDRr8i16(Addr.getOperand(1), BaseLow, Offset);
}

bool RL78DAGToDAGISel::SelectESADDRABS16(SDValue Addr, SDValue &BaseHi,
                                         SDValue &BaseLow) {
  return SelectBaseHi(Addr, BaseHi, CurDAG) &&
         selectADDRABS16(Addr.getOperand(1), BaseLow, CurDAG, false);
}

bool RL78DAGToDAGISel::SelectSaddr(SDNode *Parent, SDValue Addr,
                                   SDValue &Base) {
  // A variable in the short direct area.
  if (Addr.getOpcode() == RL78ISD::LOW8) {
    Base = Addr->getOperand(0);
    return true;
  }
  // A constant address in the area, FFE20H to FFF1FH (a register written as
  // an integer cast to a pointer). A word (saddrp) has to be at an even
  // address.
  auto *C = dyn_cast<ConstantSDNode>(Addr);
  if (!C)
    return false;
  uint64_t Address = C->getZExtValue() & 0xFFFF;
  if (Address < 0xFE20 || Address > 0xFF1F)
    return false;
  if (auto *Mem = dyn_cast_or_null<MemSDNode>(Parent))
    if (Mem->getMemoryVT().getStoreSize() > 1 && (Address & 1))
      return false;
  // The operand is the full 20-bit address.
  Base = CurDAG->getTargetConstant(0xF0000 | Address, SDLoc(Addr), MVT::i32);
  return true;
}

bool RL78DAGToDAGISel::SelectSFR(SDValue Addr, SDValue &Base) {
  if (Addr.getOpcode() != ISD::Constant)
    return false;
  unsigned address =
      dyn_cast<ConstantSDNode>(Addr)->getConstantIntValue()->getZExtValue();
  if (address < 0xFF00)
    return false;
  Base = CurDAG->getTargetConstant(address, SDLoc(Addr), MVT::i16);
  return true;
}

// HARD REQUIREMENT:
// 11.1.8 Controlling the Output of Bit Manipulation Instructions [V1.04 or
// later] To output bit manipulation instructions without using intrinsic
// functions, satisfy all conditions shown below. (a) A constant value is
// assigned. (b) The value is assigned to a single-bit bit field of the
// charunsigned charsigned char_Bool type in the near area. (c) The bit field
// where the value is assigned is qualified with volatile.
void RL78DAGToDAGISel::MatchSET1CLR1(SDNode *&N) {
  //   LOAD  IMM
  //    \     /
  //     \   /
  //     AND/OR
  //       |
  //     STORE
  const SDValue &logicalOp = N->getOperand(1);
  if ((logicalOp->getOpcode() != ISD::AND) &&
      (logicalOp->getOpcode() != ISD::OR))
    return;
  EVT VT = logicalOp->getValueType(0);
  if ((VT != MVT::i8) && (VT != MVT::i16))
    return;
  // The logical op needs to have only one use.
  if (!logicalOp->hasOneUse())
    return;
  const SDValue &load = logicalOp->getOperand(0);

  if ((load->getOpcode() != ISD::LOAD))
    return;
  // Reducing the width of a volatile load is illegal.
  if (VT == MVT::i16) {
    LoadSDNode *LN = cast<LoadSDNode>(load);
    if (LN->isVolatile())
      return;
  }

  // Check the chain uses for the load instruction:
  // the store is the only user either directly or through
  // a TokenFactor.
  SDNode *chainNode = nullptr;
  SDNode::use_iterator UI = load.getNode()->use_begin(),
                       UE = load.getNode()->use_end();
  while (UI != UE) {
    SDUse &Use = *UI;
    if (Use.getResNo() == 1 && Use.getUser() != N) {
      if (Use.getUser()->getOpcode() == ISD::TokenFactor) {
        if ((!Use.getUser()->hasOneUse()) ||
            (Use.getUser()->use_begin()->getUser() != N))
          return;
        else
          chainNode = Use.getUser();
      } else
        return;
    } else if (Use.getResNo() == 0 && Use.getUser() != logicalOp.getNode())
      return;
    ++UI;
  }
  const SDValue &chain =
      chainNode ? SDValue(chainNode, 0) : load->getOperand(0);

  // The load and store need to use the same address.
  if (load->getOperand(1) != N->getOperand(2))
    return;
  // Check the constant node is power of 2.
  if (!isa<ConstantSDNode>(logicalOp->getOperand(1)))
    return;
  uint64_t imm = logicalOp->getConstantOperandVal(1);
  if (logicalOp->getOpcode() == ISD::AND)
    imm = ~imm & ((VT == MVT::i8) ? 0xFF : 0xFFFF);
  if (!isPowerOf2_64(imm))
    return;
  // Make sure we can select.
  SDValue memOp = N->getOperand(2);
  if (FrameIndexSDNode *FIN = dyn_cast<FrameIndexSDNode>(memOp)) {
    SDNode *MFIN = SelectFI(FIN);
    memOp = SDValue(MFIN, 0);
  }
  if (VT == MVT::i16) {
    if (imm & 0xFF00)
      return;
    VT = MVT::i8;
  }
  SDLoc dl(N);
  SDValue constVal = CurDAG->getConstant(Log2_64(imm), dl, VT);
  RL78ISD::NodeType opcode =
      (logicalOp->getOpcode() == ISD::AND) ? RL78ISD::CLR1 : RL78ISD::SET1;
  SDValue set1 = CurDAG->getNode(
      opcode, dl, MVT::Other, chain, constVal, memOp);
  // Update DAG.
  CurDAG->ReplaceAllUsesWith(N, &set1);
  CurDAG->RemoveDeadNodes();
  N = set1.getNode();
  return;
}

// Replace loads from SELECTCC between far addresses with LOAD_SELECTCC.
// Needed for allowing the optimization from DAGCombiner::SimplifySelectOps()
// on far pointers, as otherwise the load generates incorrect code (a
// near-address load from the HI16 part of the selected far address). Returns
// true on success.
bool RL78DAGToDAGISel::MatchLOAD_SELECTCC(SDNode*& N) {
  LoadSDNode *LD = cast<LoadSDNode>(N);
  SDValue Ptr = LD->getBasePtr();

  if (LD->isSimple() && Ptr.getOpcode() == RL78ISD::SELECTCC) {
    SDValue TrueAddr = Ptr.getOperand(0);
    SDValue FalseAddr = Ptr.getOperand(1);

    if (TrueAddr.getOpcode() == RL78ISD::HI16 || FalseAddr.getOpcode() == RL78ISD::HI16) {
      SDValue Chain = LD->getChain();
      SDValue TargetCC = Ptr.getOperand(2);
      SDValue Cmp = Ptr.getOperand(3);

      // Result type list: (valueVT, chain).
      SDVTList VTs = CurDAG->getVTList(N->getValueType(0), MVT::Other);

      // Build operands with incoming chain first, glue last.
      SDValue Ops[] = { Chain, TrueAddr, FalseAddr, TargetCC, Cmp };
      SDValue LoadSelectCC = CurDAG->getNode(RL78ISD::LOAD_SELECTCC, SDLoc(N), VTs, Ops);
      CurDAG->ReplaceAllUsesWith(N, LoadSelectCC.getNode());
      N = LoadSelectCC.getNode();
      return true;
    }
  }
  return false;
}

SDNode *RL78DAGToDAGISel::SelectFI(SDNode *N) {
  SDLoc DL(N);
  // N->dump();
  int FI = cast<FrameIndexSDNode>(N)->getIndex();
  EVT VT = N->getValueType(0);
  SDValue TFI = CurDAG->getTargetFrameIndex(FI, VT);
  // CurDAG->dump();
  unsigned Opc = RL78::MOVW_rp_stack_slot;
  SDValue Imm = CurDAG->getTargetConstant(0, DL, MVT::i16);
  if (N->hasOneUse()) {
    return CurDAG->SelectNodeTo(N, Opc, VT, TFI, Imm);
  } else {
    SDNode *MN = CurDAG->getMachineNode(Opc, DL, VT, TFI, Imm);
    ReplaceNode(N, MN);
    return MN;
  }
  // CurDAG->dump();
}

void RL78DAGToDAGISel::Select(SDNode *N) {
  SDLoc dl(N);
  if (N->isMachineOpcode()) {
    N->setNodeId(-1);
    return; // Already selected.
  }
  // N->dump(CurDAG);
  switch (N->getOpcode()) {
  default:
    break;
  case ISD::STORE:
    MatchSET1CLR1(N);
    break;
  case ISD::FrameIndex: {
    SelectFI(N);
    return;
  }
  case ISD::TRUNCATE: {
    // In case of right shift + trunc we can remove the shift.
    if ((N->getOperand(0)->getValueType(0) == MVT::i16) &&
        ((N->getOperand(0).getOpcode() == ISD::SRL) ||
        (N->getOperand(0).getOpcode() == ISD::SRA)) &&
        dyn_cast<ConstantSDNode>(N->getOperand(0).getOperand(1)) &&
        N->getOperand(0).getConstantOperandVal(1) == 8) {
      SDValue SubRegHi = CurDAG->getTargetConstant(RL78::sub_hi, dl, MVT::i8);
      SDNode *Hi = CurDAG->getMachineNode(TargetOpcode::EXTRACT_SUBREG, dl,
                                          MVT::i8,
                                 N->getOperand(0)->getOperand(0), SubRegHi);
      ReplaceNode(N, Hi);
      return;
    }
  } break;
  case ISD::SHL: {
    // SHLW AX, 1 is 2 bytes, we can replace it with ADDW AX, AX (1 byte)
    if (N->getOperand(1).getOpcode() == ISD::Constant &&
        N->getConstantOperandVal(1) == 1 && N->getValueType(0) == MVT::i16) {
      SDLoc DL(N);
      EVT VT = MVT::i16;
      unsigned Opc = RL78::ADDW_AX_rp;
      SDNode *MN = CurDAG->getMachineNode(Opc, DL, VT, N->getOperand(0),
                                          N->getOperand(0));
      ReplaceNode(N, MN);
      return;
    }
    break;
  }
  case ISD::AND: {
    // The low bits of a word, or a field of it: SHLW and SHRW, where AND
    // works on one byte at a time (XCH A, X; AND A, #byte; XCH A, X;
    // CLRB A) after the shift that brings the field down.
    auto *C = dyn_cast<ConstantSDNode>(N->getOperand(1));
    if (N->getValueType(0) != MVT::i16 || !C || !isMask_64(C->getZExtValue()))
      break;
    unsigned Bits = llvm::countr_one(C->getZExtValue());
    if (Bits >= 8 || any_of(N->users(), [](const SDNode *U) {
          return U->getOpcode() == RL78ISD::CMP;
        }))
      break;
    SDValue X = N->getOperand(0);
    unsigned From = 0;
    if (X.getOpcode() == ISD::SRL && X.hasOneUse() &&
        isa<ConstantSDNode>(X.getOperand(1)) &&
        X.getConstantOperandVal(1) + Bits <= 16) {
      From = X.getConstantOperandVal(1);
      X = X.getOperand(0);
    }
    if (unsigned Up = 16 - Bits - From)
      X = SDValue(CurDAG->getMachineNode(
                      RL78::SHLW_rp_n, dl, MVT::i16, X,
                      CurDAG->getTargetConstant(Up, dl, MVT::i8)),
                  0);
    ReplaceNode(N, CurDAG->getMachineNode(
                       RL78::SHRW_AX_n, dl, MVT::i16, X,
                       CurDAG->getTargetConstant(16 - Bits, dl, MVT::i8)));
    return;
  }
  case ISD::BUILD_PAIR: {
    SDLoc DL(N);
    if (N->getValueType(0) == MVT::i16) {
      SDValue RC, SubReg0, SubReg1;
      RC = CurDAG->getTargetConstant(RL78::RL78RPRegsRegClassID, DL, MVT::i16);
      SubReg0 = CurDAG->getTargetConstant(RL78::sub_lo, DL, MVT::i16);
      SubReg1 = CurDAG->getTargetConstant(RL78::sub_hi, DL, MVT::i16);
      const SDValue Ops[] = {RC, N->getOperand(0), SubReg0, N->getOperand(1),
                             SubReg1};
      ReplaceNode(N, CurDAG->getMachineNode(TargetOpcode::REG_SEQUENCE, DL,
                                            N->getValueType(0), Ops));
      return;
    } else {
      llvm_unreachable("Unhandled value type for BUILD_PAIR");
    }
    break;
  }
  }
  // N->dump(CurDAG);
  SelectCode(N);
}

/// createRL78ISelDag - This pass converts a legalized DAG into a
/// RL78-specific DAG, ready for instruction scheduling.
///
FunctionPass *llvm::createRL78ISelDag(RL78TargetMachine &TM,
                                       CodeGenOptLevel OptLevel) {
  return new RL78DAGToDAGISelLegacy(TM, OptLevel);
}

char RL78DAGToDAGISelLegacy::ID = 0;

INITIALIZE_PASS(RL78DAGToDAGISelLegacy, DEBUG_TYPE, PASS_NAME, false, false)
