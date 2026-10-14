//===-- RL78MCExpr.cpp - RL78 specific MC expression classes --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the implementation of the assembly expression modifiers
// accepted by the RL78 architecture (e.g. "%hi", "%lo", ...).
//
//===----------------------------------------------------------------------===//

#include "RL78MCExpr.h"
#include "RL78.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCObjectStreamer.h"
#include "llvm/MC/MCSymbolELF.h"
#include "llvm/MC/MCValue.h"
#include "llvm/ADT/StringExtras.h"
#include <set>

using namespace llvm;

#define DEBUG_TYPE "RL78mcexpr"

const RL78MCExpr *RL78MCExpr::create(VariantKind Kind, const MCExpr *Expr,
                                     MCContext &Ctx, SMLoc OperatorLoc) {
  if (Kind == VK_RL78_BITPOSITIONAL) {
    if (Expr->getKind() != MCExpr::ExprKind::Binary)
      llvm_unreachable("Bad VK_RL78_BITPOSITIONAL expression");
    const MCBinaryExpr *BinExpr = cast<MCBinaryExpr>(Expr);
    return new (Ctx) RL78MCExpr(Kind, BinExpr->getLHS(), BinExpr->getRHS());
  }
  return new (Ctx) RL78MCExpr(Kind, Expr, OperatorLoc);
}

void RL78MCExpr::printImpl(raw_ostream &OS, const MCAsmInfo *MAI) const {
  bool closeParen = printVariantKind(OS, VKind);

  MAI->printExpr(OS, *getSubExpr());

  if (closeParen)
    OS << ')';
}

bool RL78MCExpr::printVariantKind(raw_ostream &OS, VariantKind Kind) {
  bool closeParen = true;
  switch (Kind) {
  default:
    closeParen = false;
    break;
  case VK_RL78_HIGH:
    OS << "HIGH(";
    break;
  case VK_RL78_LOW:
    OS << "LOW(";
    break;
  case VK_RL78_HIGHW:
    OS << "HIGHW(";
    break;
  case VK_RL78_LOWW:
    OS << "LOWW(";
    break;
  case VK_RL78_MIRHW:
    OS << "MIRHW(";
    break;
  case VK_RL78_MIRLW:
    OS << "MIRLW(";
    break;
  case VK_RL78_SMRLW:
    OS << "SMRLW(";
    break;
  case VK_RL78_STARTOF:
    OS << "STARTOF(";
    break;
  case VK_RL78_SIZEOF:
    OS << "SIZEOF(";
    break;
  }
  return closeParen;
}

bool RL78MCExpr::getFixupForKind(RL78MCExpr::VariantKind Kind, RL78::Fixups &Fixup,
                                         bool IsPopPush, unsigned FixupFromOp) {
  switch (Kind) {
  default:
    return false;
  case VK_RL78_SADW:
    if (IsPopPush)
      // Can't be PopPush, since we are generating it in a single place
      return false;
    else {
      // Allow the op to decide between fixup_RL78_DIR8UW_SAD
      //  and fixup_RL78_DIR8U_SAD
      Fixup = (RL78::Fixups)FixupFromOp;
      return true;
    }
  case VK_RL78_HIGH:
    if (IsPopPush)
      Fixup = RL78::fixup_RL78_OPABSlowH;
    else
      Fixup = RL78::fixup_RL78_OPlowH;
    return true;
  case VK_RL78_LOW:
    if (IsPopPush)
      Fixup = RL78::fixup_RL78_OPABSlowL;
    else
      Fixup = RL78::fixup_RL78_OPlowL;
    return true;
  case VK_RL78_HIGHW:
    if (IsPopPush)
      Fixup = RL78::fixup_RL78_OPABShighW;
    else
      Fixup = RL78::fixup_RL78_OPhighW;
    return true;
  case VK_RL78_LOWW:
    if (IsPopPush)
      Fixup = RL78::fixup_RL78_OPABSlowW;
    else
      Fixup = RL78::fixup_RL78_OPlowW;
    return true;
  case VK_RL78_MIRHW:
    if (IsPopPush)
      return false;
    else
      Fixup = RL78::fixup_RL78_OPhighW_MIR;
    return true;
  case VK_RL78_MIRLW:
    if (IsPopPush)
      return false;
    else
      Fixup = RL78::fixup_RL78_OPlowW_MIR;
    return true;
  case VK_RL78_SMRLW:
    if (IsPopPush)
      return false;
    Fixup = RL78::fixup_RL78_OPlowW_SMIR;
    return true;
  case VK_RL78_STARTOF:
    if (IsPopPush)
      return false;
    else
      Fixup = RL78::fixup_RL78_OPscttop;
    return true;
  case VK_RL78_SIZEOF:
    if (IsPopPush)
      return false;
    else
      Fixup = RL78::fixup_RL78_OPsctsize;
    return true;
  case VK_RL78_FUNCTION:
    if (IsPopPush)
      return false;
    else
      Fixup = RL78::fixup_RL78_DIR16U;
    return true;
  }
}

bool GetAbsValueForVariant(RL78MCExpr::VariantKind Kind, int64_t &AbsVal) {
  switch (Kind) {
  default:
    llvm_unreachable("Unhandled RL78MCExpr::VariantKind");
  case RL78MCExpr::VK_RL78_None:
    llvm_unreachable("VK_RL78_None is invalid");
  case RL78MCExpr::VK_RL78_HIGH:
    AbsVal = (AbsVal >> 8) & 0xFF;
    break;
  case RL78MCExpr::VK_RL78_LOW:
    AbsVal = AbsVal & 0xFF;
    break;
  case RL78MCExpr::VK_RL78_HIGHW:
    AbsVal = (AbsVal >> 16) & 0xFFFF;
    break;
  case RL78MCExpr::VK_RL78_LOWW:
    AbsVal = AbsVal & 0xFFFF;
    break;
  case RL78MCExpr::VK_RL78_MIRHW:
  case RL78MCExpr::VK_RL78_MIRLW:
  case RL78MCExpr::VK_RL78_SMRLW:
  case RL78MCExpr::VK_RL78_STARTOF:
  case RL78MCExpr::VK_RL78_SIZEOF:
  case RL78MCExpr::VK_RL78_BITPOSITIONAL:
    return false;
  }
  return true;
}


bool RL78MCExpr::evaluateAsRelocatableImpl(MCValue &Res,
                                           const MCAssembler *Asm) const {
  if (!getSubExpr()->evaluateAsRelocatable(Res, Asm))
    return false;

  // Fold HIGH/LOW/HIGHW/LOWW of an absolute value. LLVM 17 did this only
  // outside fixup evaluation (Fixup == nullptr); fixups never carry these
  // operators (createFixupsForExpression turns them into OP* relocations), so
  // the distinction is gone along with the parameter.
  if (Res.isAbsolute()) {
    int64_t AbsVal = Res.getConstant();
    if (!GetAbsValueForVariant(VKind, AbsVal))
      return false;
    Res = MCValue::get(AbsVal);
    return true;
  }

  // We want to defer it for relocatable expressions since the constant is
  // applied to the whole symbol value.
  //
  // The specifier given to MCValue is only intended to aid debugging when
  // inspecting MCValue objects. It shouldn't be relied upon for decision
  // making.
  Res.setSpecifier(VKind);
  return true;
}

void RL78MCExpr::visitUsedExpr(MCStreamer &Streamer) const {
  Streamer.visitUsedExpr(*getSubExpr());
}

bool RL78MCExpr::isTargetExpr(const MCExpr *expression) {
  switch (expression->getKind())
  {
  case MCExpr::Target:
          return true;
  case MCExpr::Binary: {
      const MCBinaryExpr *BinaryExpr = static_cast<const MCBinaryExpr *>(expression);
      return isTargetExpr(BinaryExpr->getLHS()) || 
             isTargetExpr(BinaryExpr->getRHS());
  }
  case MCExpr::Unary: {
      const MCUnaryExpr *UnaryExpr = static_cast<const MCUnaryExpr *>(expression);
      return isTargetExpr(UnaryExpr->getSubExpr());
  }
  default:
    return false;   
  }
}

bool ExecuteOperation(int64_t &Result, int64_t LHS, int64_t RHS,
                      MCBinaryExpr::Opcode Op) {
  switch (Op) {
  case MCBinaryExpr::AShr:
    Result = LHS >> RHS;
    break;
  case MCBinaryExpr::Add:
    Result = LHS + RHS;
    break;
  case MCBinaryExpr::And:
    Result = LHS & RHS;
    break;
  case MCBinaryExpr::Div:
    if (RHS == 0)
      return false;
    Result = LHS / RHS;
    break;
  case MCBinaryExpr::Mod:
    if (RHS == 0)
      return false;
    Result = LHS % RHS;
    break;
  case MCBinaryExpr::EQ:
    Result = LHS == RHS;
    break;
  case MCBinaryExpr::GT:
    Result = LHS > RHS;
    break;
  case MCBinaryExpr::GTE:
    Result = LHS >= RHS;
    break;
  case MCBinaryExpr::LAnd:
    Result = LHS && RHS;
    break;
  case MCBinaryExpr::LOr:
    Result = LHS || RHS;
    break;
  case MCBinaryExpr::LShr:
    Result = uint64_t(LHS) >> uint64_t(RHS);
    break;
  case MCBinaryExpr::LT:
    Result = LHS < RHS;
    break;
  case MCBinaryExpr::LTE:
    Result = LHS <= RHS;
    break;
  case MCBinaryExpr::Mul:
    Result = LHS * RHS;
    break;
  case MCBinaryExpr::NE:
    Result = LHS != RHS;
    break;
  case MCBinaryExpr::Or:
    Result = LHS | RHS;
    break;
  case MCBinaryExpr::Shl:
    Result = uint64_t(LHS) << uint64_t(RHS);
    break;
  case MCBinaryExpr::Sub:
    Result = LHS - RHS;
    break;
  case MCBinaryExpr::Xor:
    Result = LHS ^ RHS;
    break;
  default:
    return false;
  }
  return true;
}

bool RL78MCExpr::FoldBitPositionalExpression(const MCExpr *Value,
                                             MCValue &AddressValue,
                                             int64_t &BitPosition,
                                             MCContext &Ctx) {
  // At this point we assume that somewhere in the expression there is a bit
  // positional.
  switch (Value->getKind()) {
  case MCExpr::Target: {
    const RL78MCExpr *TargetExpr = static_cast<const RL78MCExpr *>(Value);
    if (TargetExpr->getVariantKind() == VK_RL78_BITPOSITIONAL) {
      return TargetExpr->getBitPositionalAddressSubExpr()
                 ->evaluateAsRelocatable(AddressValue, nullptr) &&
             TargetExpr->getBitPositionalBitPostionSubExpr()
                 ->evaluateAsAbsolute(BitPosition);
    }
    break;
  }
  case MCExpr::Binary: {
    const MCBinaryExpr *BinaryExpr = static_cast<const MCBinaryExpr *>(Value);
    MCBinaryExpr::Opcode Op = BinaryExpr->getOpcode();
    // The order counts:
    // Const + Addr.Bitpos -> (Const + Addr).Bitpos
    // Addr.Bitpos + Const  -> Addr.(Bitpos + Const)

    MCValue RHSAddressValue, LHSAddressValue;
    int64_t RHSBitPosition = -1, LHSBitPosition = -1;
    int64_t AbsAddress;

    if (FoldBitPositionalExpression(BinaryExpr->getRHS(), RHSAddressValue,
                                    RHSBitPosition, Ctx) &&
        FoldBitPositionalExpression(BinaryExpr->getLHS(), LHSAddressValue,
                                    LHSBitPosition, Ctx)) {

      // Forbidden combinations:
      // A1.X OpCode A2.X
      // A1.X OpCode Sym
      // Sym AnyOpExceptSub Sym.B
      // If we have a bit position, but RHS/LHS finds another
      if ((LHSBitPosition != -1 && RHSBitPosition != -1) ||
          (LHSBitPosition != -1 && !RHSAddressValue.isAbsolute()) ||
          (!LHSAddressValue.isAbsolute() && !RHSAddressValue.isAbsolute() &&
              Op != MCBinaryExpr::Sub) ||
          ((BitPosition != -1) && ((LHSBitPosition != -1) || (RHSBitPosition != -1))))
        return false;

      BitPosition = RHSBitPosition != -1 ? RHSBitPosition : LHSBitPosition;

      if (LHSBitPosition == -1) {
        if (LHSAddressValue.isAbsolute() && RHSAddressValue.isAbsolute() &&
            ExecuteOperation(AbsAddress, LHSAddressValue.getConstant(),
                             RHSAddressValue.getConstant(), Op)) {
          // Const AnyOp Const(.B)
          AddressValue = MCValue::get(AbsAddress);
          return true;
        } else if (LHSAddressValue.isAbsolute() &&
                   !RHSAddressValue.isAbsolute() && Op == MCBinaryExpr::Add) {
          // Const + Sym(.B)
          AddressValue = MCValue::get(
              RHSAddressValue.getAddSym(), RHSAddressValue.getSubSym(),
              RHSAddressValue.getConstant() + LHSAddressValue.getConstant());
          return true;
        } else if (!LHSAddressValue.isAbsolute() &&
                   RHSAddressValue.isAbsolute() && Op == MCBinaryExpr::Sub) {
          // Sym - Const(.B)
          AddressValue = MCValue::get(
              LHSAddressValue.getAddSym(), LHSAddressValue.getSubSym(),
              LHSAddressValue.getConstant() - RHSAddressValue.getConstant());
          return true;
        }
      }

      if (!LHSAddressValue.isAbsolute() && !RHSAddressValue.isAbsolute() &&
          Op == MCBinaryExpr::Sub && !LHSAddressValue.getSubSym() &&
          !RHSAddressValue.getSubSym() && LHSBitPosition == -1) {
        // Sym - Sym(.B)
        AddressValue = MCValue::get(
            LHSAddressValue.getAddSym(), RHSAddressValue.getAddSym(),
            LHSAddressValue.getConstant() - RHSAddressValue.getConstant());
        BitPosition = RHSBitPosition;
        return true;
      }

      // SYM.B OpCode Const
      if (LHSBitPosition != -1 &&
          ExecuteOperation(BitPosition, LHSBitPosition,
                           RHSAddressValue.getConstant(), Op)) {
        AddressValue = LHSAddressValue;
        return true;
      }

      // Const + Const.B
      if (RHSBitPosition != -1 && LHSAddressValue.isAbsolute() &&
          RHSAddressValue.isAbsolute() &&
          ExecuteOperation(AbsAddress, LHSAddressValue.getConstant(),
                           RHSAddressValue.getConstant(), Op)) {
        AddressValue = MCValue::get(AbsAddress);
        return true;
      }
    }
    return false;
  }
  case MCExpr::Unary: {
    const MCUnaryExpr *UnaryExpr = static_cast<const MCUnaryExpr *>(Value);
    // we ignore the +, but error out on any other
    if (UnaryExpr->getOpcode() == MCUnaryExpr::Plus) {
      return FoldBitPositionalExpression(UnaryExpr->getSubExpr(), AddressValue,
                                         BitPosition, Ctx);
    } else {
      return false;
    }
  }
  default:
    break;
  }
  return Value->evaluateAsRelocatable(AddressValue, nullptr);
}

RL78MCExpr::ConversionStatus RL78MCExpr::HandleBinaryRelAbsOp(
    const MCExpr *SymWithPossibleOffset, int64_t Abs,
    RL78MCExpr::ConversionStatus &CurrentStatus, bool &NeedsPop,
    SmallVectorImpl<MCFixup> &fixups, MCContext &Ctx, SMLoc Loc, int64_t offset,
    bool IsAdd) {
  if (Abs == 0) {
    // If offset modification is 0, do nothing.
    CurrentStatus.SymWithPossibleOffset = SymWithPossibleOffset;

  } else if (SymWithPossibleOffset) {
    // If it's not yet a nullptr, we can simply add/sub the offset
    if (IsAdd)
      CurrentStatus.SymWithPossibleOffset = MCBinaryExpr::createAdd(
          SymWithPossibleOffset, MCConstantExpr::create(Abs, Ctx), Ctx);
    else
      CurrentStatus.SymWithPossibleOffset = MCBinaryExpr::createSub(
          SymWithPossibleOffset, MCConstantExpr::create(Abs, Ctx), Ctx);
  } else {
    // Otherwise the symbol's value is on the operator stack already: push
    // the constant (a SYM relocation against no symbol) and operate.
    NeedsPop = true;
    CurrentStatus.VariantKind = RL78MCExpr::VK_RL78_IMM_SYM;
    fixups.push_back(RL78::createFixup(offset, MCConstantExpr::create(Abs, Ctx),
                                       RL78::Fixups::fixup_RL78_SYM));
    fixups.push_back(
        RL78::createFixup(offset, MCConstantExpr::create(0, Ctx), (IsAdd ? RL78::Fixups::fixup_RL78_OPadd
                                            : RL78::Fixups::fixup_RL78_OPsub)));
  }
  return CurrentStatus;
}

// Checking what VariantKind was used by the ConversionStatus and get its
// position.
RL78MCExpr::ConversionStatus RL78MCExpr::ConvertExpressionToFixups(
    const MCExpr *Expression, SmallVectorImpl<MCFixup> &fixups, bool &NeedsPop,
    unsigned FixupFromOp, MCContext &Ctx, SMLoc Loc, int64_t offset,
    RL78::Fixups &DirectFixup) {
  ConversionStatus CurrentStatus;
  ConversionStatus DefaultStatus = {/*Success*/ false,
                                    /*SymWithPossibleOffset*/ nullptr,
                                    /*Constant*/ 0,
                                    /*IsAbsolute*/ false,
                                    /*AllowOnlyAbsPlusMinus*/ false,
                                    /*VariantKind*/ RL78MCExpr::VK_RL78_None,
                                    /*WasSizeOfPlusStartOf*/ false,
                                    /*Loc*/ Loc};

  std::set<RL78MCExpr::VariantKind> VariantSet1 = {};
  std::set<RL78MCExpr::VariantKind> VariantSet2 = {};

  switch (Expression->getKind()) {
  case MCExpr::Constant: {
    const MCConstantExpr *ConstExpr = cast<MCConstantExpr>(Expression);
    DefaultStatus.Success = true;
    DefaultStatus.Constant = ConstExpr->getValue();
    DefaultStatus.IsAbsolute = true;
    return DefaultStatus;
  }

  case MCExpr::SymbolRef: {
    const MCSymbolRefExpr *SymExpr = cast<MCSymbolRefExpr>(Expression);
    DefaultStatus.Success = true;
    DefaultStatus.SymWithPossibleOffset = SymExpr;
    return DefaultStatus;
  }

  case MCExpr::Target: {
    const RL78MCExpr *TargetExpr = cast<RL78MCExpr>(Expression);
    const MCExpr *SubExpr = TargetExpr->getSubExpr();
    RL78::Fixups Fixup;
    SMLoc OpLoc = TargetExpr->getOperatorLoc().isValid()
                      ? TargetExpr->getOperatorLoc()
                      : Loc;
    ConversionStatus SubStatus =
        ConvertExpressionToFixups(SubExpr, fixups, NeedsPop, FixupFromOp, Ctx,
                                  OpLoc, offset, DirectFixup);
    CurrentStatus.VariantKind = TargetExpr->getVariantKind();
    CurrentStatus.WasSizeOfPlusStartOf = SubStatus.WasSizeOfPlusStartOf;
    CurrentStatus.Loc =
        SubStatus.Success || !SubStatus.Loc.isValid() ? OpLoc : SubStatus.Loc;

    if (!SubStatus.Success ||
        !TargetExpr->getFixupForKind(
            Fixup, SubStatus.VariantKind != RL78MCExpr::VK_RL78_None,
            FixupFromOp)) {
      CurrentStatus.SymWithPossibleOffset = nullptr;
      return CurrentStatus;
    }

    // FXIME: hack which needs to be deleted when we get rid of the plt.
    // Remove DirectFixup from param list.
    if (CurrentStatus.VariantKind == VK_RL78_FUNCTION) {
      DirectFixup = Fixup;
      // The function's symbol, possibly with an offset (e.g. "f+64" after a
      // comparison with a function address was folded).
      if (!SubStatus.SymWithPossibleOffset)
        return CurrentStatus;
      DefaultStatus.Success = true;
      DefaultStatus.SymWithPossibleOffset = SubStatus.SymWithPossibleOffset;
      return DefaultStatus;
    }
    if ((CurrentStatus.VariantKind == VK_RL78_MIRLW ||
         CurrentStatus.VariantKind == VK_RL78_MIRHW ||
         CurrentStatus.VariantKind == VK_RL78_SMRLW) ||
        !SubStatus.IsAbsolute) {
      const std::set<RL78MCExpr::VariantKind> CurrentExprSet1 = {
          VK_RL78_HIGH, VK_RL78_LOW, VK_RL78_HIGHW, VK_RL78_LOWW};
      const std::set<RL78MCExpr::VariantKind> SubExprSet1 = {
          VK_RL78_MIRHW, VK_RL78_MIRLW, VK_RL78_SMRLW};
      const std::set<RL78MCExpr::VariantKind> CurrentExprSet2 = {
          VK_RL78_MIRHW, VK_RL78_MIRLW, VK_RL78_SMRLW};
      const std::set<RL78MCExpr::VariantKind> SubExprSet2 = {
          VK_RL78_HIGH,  VK_RL78_LOW,   VK_RL78_HIGHW, VK_RL78_LOWW,
          VK_RL78_MIRHW, VK_RL78_MIRLW, VK_RL78_SMRLW};
      // Note 1. Operation is possible when X is not relocatable terms operated
      // on by MIRHW, MIRLW, SMRLW, or DATAPOS. Note 2. Operation is possible
      // when X is not relocatable terms operated on by HIGH, LOW, HIGHW, LOWW,
      // MIRHW, MIRLW, SMRLW, or DATAPOS.

      if ((CurrentExprSet1.find(CurrentStatus.VariantKind) !=
                  CurrentExprSet1.end() &&
              SubExprSet1.find(SubStatus.VariantKind) != SubExprSet1.end()) ||
          (CurrentExprSet2.find(CurrentStatus.VariantKind) !=
                  CurrentExprSet2.end() &&
              SubExprSet2.find(SubStatus.VariantKind) != SubExprSet2.end()))
        return DefaultStatus;

      CurrentStatus.Success = true;
      CurrentStatus.IsAbsolute = false;
      CurrentStatus.AllowOnlyAbsPlusMinus = true;
      if (TargetExpr->getVariantKind() != RL78MCExpr::VK_RL78_SADW) {
        NeedsPop = (CurrentStatus.VariantKind != VK_RL78_FUNCTION);
        const MCExpr *ExprValue = nullptr;

        if (SubStatus.VariantKind == RL78MCExpr::VK_RL78_None) {
          if (SubStatus.SymWithPossibleOffset)
            ExprValue = SubStatus.SymWithPossibleOffset;
          else
            ExprValue = MCConstantExpr::create(SubStatus.Constant, Ctx);
        } else
          ExprValue = MCConstantExpr::create(0, Ctx);

        fixups.push_back(RL78::createFixup(offset, ExprValue ? ExprValue : MCConstantExpr::create(0, Ctx), Fixup));
      } else {
        CurrentStatus.SymWithPossibleOffset = SubExpr;
      }
    } else {
      CurrentStatus.Success = GetAbsValueForVariant(CurrentStatus.VariantKind,
                                                    CurrentStatus.Constant);
      CurrentStatus.IsAbsolute = true;
    }
    return CurrentStatus;
  }

  case MCExpr::Binary: {
    const MCBinaryExpr *BinaryExpr =
        static_cast<const MCBinaryExpr *>(Expression);
    MCBinaryExpr::Opcode Op = BinaryExpr->getOpcode();

    ConversionStatus LHS =
        ConvertExpressionToFixups(BinaryExpr->getLHS(), fixups, NeedsPop,
                                  FixupFromOp, Ctx, Loc, offset, DirectFixup);

    ConversionStatus RHS = ConvertExpressionToFixups(
        BinaryExpr->getRHS(), fixups, NeedsPop, FixupFromOp, Ctx,
        BinaryExpr->getLoc(),
        offset, DirectFixup);

    if (!LHS.Success || !RHS.Success || LHS.WasSizeOfPlusStartOf ||
        RHS.WasSizeOfPlusStartOf)
      return !RHS.Success ? RHS : LHS;

    // Based on the CC-RL manual 5.1.14 (Table 5.8)
    // If both are absolute, all operations are permitted.
    if (LHS.IsAbsolute && RHS.IsAbsolute) {
      CurrentStatus.Success = ExecuteOperation(CurrentStatus.Constant,
                                               LHS.Constant, RHS.Constant, Op);
      CurrentStatus.IsAbsolute = true;
      return CurrentStatus;
    } else {
      const MCExpr *SymWithPossibleOffset = LHS.IsAbsolute
                                                ? RHS.SymWithPossibleOffset
                                                : LHS.SymWithPossibleOffset;
      int64_t Abs = LHS.IsAbsolute ? LHS.Constant : RHS.Constant;
      DefaultStatus.Loc = BinaryExpr->getLoc();
      switch (Op) {
      case llvm::MCBinaryExpr::Add:
        if (!LHS.IsAbsolute && !RHS.IsAbsolute) {
          // STARTOF + SIZEOF is permitted as an exception
          if ((LHS.VariantKind == RL78MCExpr::VK_RL78_STARTOF &&
                  RHS.VariantKind == RL78MCExpr::VK_RL78_SIZEOF) ||
              (RHS.VariantKind == RL78MCExpr::VK_RL78_STARTOF &&
                  LHS.VariantKind == RL78MCExpr::VK_RL78_SIZEOF)) {
            NeedsPop = true;
            fixups.push_back(RL78::createFixup(offset, MCConstantExpr::create(0, Ctx), RL78::Fixups::fixup_RL78_OPadd));
            CurrentStatus.Success = true;
            CurrentStatus.WasSizeOfPlusStartOf = true;
            CurrentStatus.VariantKind = RL78MCExpr::VK_RL78_STARTOF;
            return CurrentStatus;
          }
          return DefaultStatus;
        } else {
          // ABS + REL
          // REL + ABS
          CurrentStatus.Success = true;
          return HandleBinaryRelAbsOp(SymWithPossibleOffset, Abs, CurrentStatus,
                                      NeedsPop, fixups, Ctx, Loc, offset, true);
        }
        break;
      case llvm::MCBinaryExpr::Sub:
        if (LHS.IsAbsolute) {
          // ABS - REL
          DefaultStatus.Loc = LHS.Loc;
          return DefaultStatus;
        } else if (RHS.IsAbsolute) {
          // REL - ABS
          CurrentStatus.Success = true;
          return HandleBinaryRelAbsOp(SymWithPossibleOffset, Abs, CurrentStatus,
                                      NeedsPop, fixups, Ctx, Loc, offset,
                                      false);
        } else if (LHS.AllowOnlyAbsPlusMinus || RHS.AllowOnlyAbsPlusMinus ||
                   !LHS.SymWithPossibleOffset || !RHS.SymWithPossibleOffset) {
          return DefaultStatus;
        } else {
          // REL - REL
          NeedsPop = true;
          CurrentStatus.Success = true;
          CurrentStatus.VariantKind = VK_RL78_REL_DIFF;
          fixups.push_back(
              RL78::createFixup(offset, LHS.SymWithPossibleOffset, RL78::Fixups::fixup_RL78_SYM));
          fixups.push_back(
              RL78::createFixup(offset, RHS.SymWithPossibleOffset, RL78::Fixups::fixup_RL78_SYM));
          fixups.push_back(RL78::createFixup(offset, MCConstantExpr::create(0, Ctx), RL78::Fixups::fixup_RL78_OPsub));
          return CurrentStatus;
        }
        break;
      default:
        return DefaultStatus;
      }
    }

    return DefaultStatus;
  }
  case MCExpr::Unary: {
    const MCUnaryExpr *UnaryExpr = static_cast<const MCUnaryExpr *>(Expression);
    DefaultStatus.Loc = UnaryExpr->getLoc();
    int64_t Res;
    if (UnaryExpr->getOpcode() == MCUnaryExpr::Plus)
      return ConvertExpressionToFixups(
          UnaryExpr->getSubExpr(), fixups, NeedsPop, FixupFromOp, Ctx,
          UnaryExpr->getLoc(), offset, DirectFixup);
    if (UnaryExpr->getSubExpr()->evaluateAsAbsolute(Res)) {
      if (UnaryExpr->getOpcode() == MCUnaryExpr::Minus)
        Res = -Res;
      else if (UnaryExpr->getOpcode() == MCUnaryExpr::Not)
        Res = ~Res;
      else
        return DefaultStatus;
      CurrentStatus.Success = true;
      CurrentStatus.IsAbsolute = true;
      CurrentStatus.Constant = Res;
      CurrentStatus.Loc = UnaryExpr->getLoc();
      return CurrentStatus;
    } else
      return DefaultStatus;
  }
  case MCExpr::Specifier: // Not made for RL78.
    break;
  }
  return DefaultStatus;
}


void RL78MCExpr::createFixupsForExpression(const MCExpr *expression,
                                           int64_t offset,
                                           unsigned resultSizeInBits,
                                           SmallVectorImpl<MCFixup> &fixups,
                                           bool IsTopLevelExpression,
                                           unsigned FixupFromOp,
                                           MCContext &Ctx,
                                           SMLoc Loc) {
      RL78::Fixups PopFixup, DirectFixup;
      switch (resultSizeInBits) {
      case 3:
        PopFixup = RL78::fixup_RL78_ABS3U;
        DirectFixup = RL78::fixup_RL78_DIR3U;
        break;
      case 8:
        PopFixup = RL78::fixup_RL78_ABS8U;
        DirectFixup = RL78::fixup_RL78_DIR8U;
        break;
      case 16:
        PopFixup = RL78::fixup_RL78_ABS16U;
        DirectFixup = RL78::fixup_RL78_DIR16U;
        break;
      case 24:
        PopFixup = RL78::fixup_RL78_ABS20U;
        DirectFixup = RL78::fixup_RL78_DIR20U;
        break;
      case 32:
        PopFixup = RL78::fixup_RL78_ABS32U;
        DirectFixup = RL78::fixup_RL78_DIR32U;
        break;
      default:
        llvm_unreachable("Unhandled RL78MCExpr ResultSize");
        break;
      }

      if (FixupFromOp != 0)
        DirectFixup = (RL78::Fixups)FixupFromOp;

      // SymbolRefs can use the DirectFixups, no need for the queue based ones.
      bool NeedsPop = false;

      ConversionStatus Status = ConvertExpressionToFixups(expression, fixups, NeedsPop, FixupFromOp,
                                    Ctx, Loc, offset, DirectFixup);

      if (!Status.Success) {
        LLVM_DEBUG(expression->dump());
        Ctx.reportError(Status.Loc, "invalid expression");
        return;
      }

      if (NeedsPop) {
        // ConvertExpressionToFixups takes care of the push fixups.
        fixups.push_back(RL78::createFixup(offset, MCConstantExpr::create(0, Ctx), PopFixup));
      } else {
        if (!Status.SymWithPossibleOffset) {
          Ctx.reportError(Status.Loc, "error during expression evaluation");
          return;
        }
        fixups.push_back(RL78::createFixup(offset, Status.SymWithPossibleOffset, DirectFixup));
      }
}