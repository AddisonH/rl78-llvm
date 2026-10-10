//===-- RL78AsmPrinter.cpp - RL78 LLVM assembly writer ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a printer that converts from our internal representation
// of machine-dependent LLVM code to GAS-format RL78 assembly language.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RL78InstPrinter.h"
#include "MCTargetDesc/RL78MCExpr.h"
#include "MCTargetDesc/RL78TargetStreamer.h"
#include "RL78TargetMachine.h"
#include "TargetInfo/RL78TargetInfo.h"
#include "RL78.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineModuleInfoImpls.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/SaveAndRestore.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

namespace {
class RL78AsmPrinter : public AsmPrinter {
  RL78TargetStreamer &getTargetStreamer() {
    return static_cast<RL78TargetStreamer &>(*OutStreamer->getTargetStreamer());
  }

  // This flag controls if the overridden lowerConstant() simply calls the base
  // implementation or not. By default it is set as lowerConstant() could be called
  // from another context than from emitGlobalVariable() which we (can) override
  // (e.g. it is called from emitGlobalAlias() that does an emitAssignment() with
  // the returned expression => use base implementation by default).
  bool useBaseLowerConstant = true;

public:
  explicit RL78AsmPrinter(TargetMachine &TM,
                          std::unique_ptr<MCStreamer> Streamer)
      : AsmPrinter(TM, std::move(Streamer)) {}

  StringRef getPassName() const override { return "RL78 Assembly Printer"; }

  void printOperand(const MachineInstr *MI, int opNum, raw_ostream &OS);
  void printMemOperand(const MachineInstr *MI, int opNum, raw_ostream &OS,
                       const char *Modifier = nullptr);

  void emitStartOfAsmFile(Module &) override;
  void emitFunctionBodyStart() override;
  void emitFunctionBodyEnd() override;
  void emitBasicBlockStart(const MachineBasicBlock &MBB) override;
  void emitInstruction(const MachineInstr *MI) override;
  void emitHardware(const MachineInstr *MI);
  void emitGlobalVariable(const GlobalVariable *GV) override;

  const MCExpr *lowerConstant(const Constant *CV,
                              const Constant *BaseCV = nullptr,
                              uint64_t Offset = 0) override;

  static const char *getRegisterName(unsigned RegNo) {
    return RL78InstPrinter::getRegisterName(RegNo);
  }

  bool PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                       const char *ExtraCode, raw_ostream &O) override;

private:
  // The CFA is described with relative .cfi_adjust_cfa_offset directives as
  // SP-changing instructions are printed, so after a block that leaves the
  // frame (an epilogue followed by another exit block) the offset must be
  // reset to the next block's own entry offset.
  DenseMap<const MachineBasicBlock *, int> CFAEntryOffset;
  int CFAOffset = 0;
  static int getCFAAdjustment(const MachineInstr &MI);
  void computeCFAEntryOffsets();

  void emitInterruptVectorSymbol(uint64_t Specs);
  const MCExpr *lowerConstantGV(const GlobalValue *GV, int DstAS = -1,
                                const MCExpr *BaseExpr = nullptr) const;
  const MCExpr *baseLowerConstant(const Constant *CV);
};
} // end of anonymous namespace

void RL78AsmPrinter::emitHardware(const MachineInstr *MI) {
  MCInst TmpInst;
  LowerRL78MachineInstrToMCInst(MI, TmpInst, *this);
  SmallVector<MCInst, 3> Hardware;
  lowerToHardware(TmpInst, Hardware, *MF->getSubtarget().getInstrInfo(),
                  *OutContext.getRegisterInfo());
  for (const MCInst &I : Hardware)
    EmitToStreamer(*OutStreamer, I);
}

void RL78AsmPrinter::emitInstruction(const MachineInstr *MI) {
  switch (MI->getOpcode()) {
  default:
    break;
  case RL78::ADJCALLSTACKDOWN:
  case RL78::ADJCALLSTACKUP:
  case RL78::CALL_STACK_SETUP:
  case RL78::CALL_STACK_DESTROY:
    return;
  }
  
  // MI->dump();
  if (MI->getOpcode() == TargetOpcode::BUNDLE) {
    MachineBasicBlock::const_instr_iterator I = MI->getIterator();
    MachineBasicBlock::const_instr_iterator E = MI->getParent()->instr_end();
    while (++I != E && I->isInsideBundle()) {
      assert(!I->isBundle() && "No nested bundle!");
      emitHardware(&*I);
    }
  } else {
    emitHardware(MI);
  }

  if (hasDebugInfo()) {
    if (int Adj = getCFAAdjustment(*MI)) {
      OutStreamer->emitCFIAdjustCfaOffset(Adj);
      CFAOffset += Adj;
    }
  }
}

/// Change of the CFA offset (bytes allocated on the stack) by \p MI, as
/// described in the frame information.
int RL78AsmPrinter::getCFAAdjustment(const MachineInstr &MI) {
  switch (MI.getOpcode()) {
  default:
    return 0;
  case RL78::PUSH_rp:
    return 2;
  case RL78::POP_rp:
    return -2;
  case RL78::SUBW_SP_i8:
  case RL78::SUBW_AX_i16:
    if (MI.getFlag(MachineInstr::FrameSetup) && MI.getNumOperands() >= 3 &&
        MI.getOperand(2).isImm())
      return MI.getOperand(2).getImm();
    return 0;
  case RL78::ADDW_SP_i8:
  case RL78::ADDW_AX_i16:
    if (MI.getFlag(MachineInstr::FrameDestroy) && MI.getNumOperands() >= 3 &&
        MI.getOperand(2).isImm())
      return -(int)MI.getOperand(2).getImm();
    return 0;
  }
}

/// Offset on entry to every reachable block, following the CFG from the
/// entry block (where it is 0).
void RL78AsmPrinter::computeCFAEntryOffsets() {
  CFAEntryOffset.clear();
  CFAOffset = 0;
  SmallVector<const MachineBasicBlock *, 16> Worklist;
  CFAEntryOffset[&MF->front()] = 0;
  Worklist.push_back(&MF->front());
  while (!Worklist.empty()) {
    const MachineBasicBlock *MBB = Worklist.pop_back_val();
    int Offset = CFAEntryOffset[MBB];
    for (const MachineInstr &MI : *MBB)
      Offset += getCFAAdjustment(MI);
    for (const MachineBasicBlock *Succ : MBB->successors())
      if (CFAEntryOffset.try_emplace(Succ, Offset).second)
        Worklist.push_back(Succ);
  }
}

void RL78AsmPrinter::emitBasicBlockStart(const MachineBasicBlock &MBB) {
  AsmPrinter::emitBasicBlockStart(MBB);
  if (!hasDebugInfo())
    return;
  auto It = CFAEntryOffset.find(&MBB);
  if (It != CFAEntryOffset.end() && It->second != CFAOffset) {
    OutStreamer->emitCFIAdjustCfaOffset(It->second - CFAOffset);
    CFAOffset = It->second;
  }
}

void RL78AsmPrinter::emitStartOfAsmFile(Module &M) {
  MCSectionELF *TextSection = OutStreamer->getContext().getELFSection(
      ".text", ELF::SHT_PROGBITS, ELF::SHF_EXECINSTR | ELF::SHF_ALLOC);
  TextSection->setAlignment(Align(1));
  // If none of the defined functions has callt attribute
  // there's noting to do here.
  if (none_of(M, [](const Function &F) {
        return !F.isDeclaration() && F.hasFnAttribute("callt");
      }))
    return;
  OutStreamer->pushSection();
  MCSectionELF *Callt = OutStreamer->getContext().getELFSection(
      ".callt0", ELF::SHT_PROGBITS, ELF::SHF_ALLOC);
  OutStreamer->switchSection(Callt);
  emitAlignment(Align(2));
  //
  for (auto F = M.begin(), E = M.end(); F != E; ++F) {
    if (F->isDeclaration() || !F->hasFnAttribute("callt"))
      continue;
    MCSymbol *CurrentFnSym = getSymbol(&*F);
    auto calltSym =
        OutContext.getOrCreateSymbol(Twine("@") + CurrentFnSym->getName());
    OutStreamer->emitSymbolAttribute(calltSym, MCSA_Global);
    OutStreamer->emitLabel(calltSym);
    const MCSymbolRefExpr *FnStartRef = MCSymbolRefExpr::create(
        CurrentFnSym, /*LOW16?,*/ OutStreamer->getContext());
    OutStreamer->emitValue(FnStartRef, 2);
  }

  OutStreamer->endSection(Callt);
  OutStreamer->popSection();
}

void RL78AsmPrinter::emitInterruptVectorSymbol(uint64_t Specs) {
  if (Specs & 0xFE) {
    auto vect = OutContext.getOrCreateSymbol(
        Twine("___vector_") + Twine::utohexstr(Specs & 0xFE) + Twine("_"));
    RL78ReportError(vect->isUndefined() && !vect->isVariable(),
                    "Redefinition of the 0x" +
                        Twine::utohexstr(Specs & 0xFE).str() +
                        " entry in the interrupt table!");
    getTargetStreamer().getStreamer().emitLabel(vect);
    getTargetStreamer().getStreamer().emitSymbolAttribute(vect, MCSA_Global);
  }
}

void RL78AsmPrinter::emitFunctionBodyStart() {
  if (hasDebugInfo())
    computeCFAEntryOffsets();
  if (!MF->getFunction().hasFnAttribute("interrupt") &&
      !MF->getFunction().hasFnAttribute("brk_interrupt"))
    return;

  if (MF->getFunction().hasFnAttribute("brk_interrupt")) {
    // Vector address for the BRK_cg interrupt.
    emitInterruptVectorSymbol(0x7e);
    return;
  }

  uint64_t Specs;
  StringRef SpecsstringInterrupt =
      MF->getFunction().getFnAttribute("interrupt").getValueAsString();
  std::string VectStr = "Vect_";
  size_t LastVect = SpecsstringInterrupt.find(VectStr, 0);
  while (LastVect != std::string::npos) {
    size_t CurrentVect = SpecsstringInterrupt.find(VectStr, LastVect + 1);
    if (CurrentVect != std::string::npos) {
      SpecsstringInterrupt
          .substr(LastVect + VectStr.length(),
                  CurrentVect - LastVect - VectStr.length())
          .getAsInteger(0, Specs);
    } else {
      SpecsstringInterrupt
          .substr(LastVect + VectStr.length(),
                  SpecsstringInterrupt.size() - (LastVect + VectStr.length()))
          .getAsInteger(0, Specs);
    }
    // Apply vector start offset.
    emitInterruptVectorSymbol(Specs);
    LastVect = CurrentVect;
  }
}

void RL78AsmPrinter::emitFunctionBodyEnd() {
  if (MF->getFunction().hasFnAttribute("inline_asm")) {
    // Since we marked with naked the inline_asm function, we need to add a
    // return to it's end.
    getTargetStreamer().getStreamer().emitInstruction(MCInstBuilder(RL78::RET),
                                                      getSubtargetInfo());
  }
}

void RL78AsmPrinter::printOperand(const MachineInstr *MI, int opNum,
                                  raw_ostream &O) {
  const DataLayout &DL = getDataLayout();
  const MachineOperand &MO = MI->getOperand(opNum);
  RL78MCExpr::VariantKind TF = (RL78MCExpr::VariantKind)MO.getTargetFlags();

  bool CloseParen = RL78MCExpr::printVariantKind(O, TF);

  switch (MO.getType()) {
  case MachineOperand::MO_Register:
    O << StringRef(getRegisterName(MO.getReg())).lower();
    break;

  case MachineOperand::MO_Immediate:
    O << (int)MO.getImm();
    break;
  case MachineOperand::MO_MachineBasicBlock:
    MO.getMBB()->getSymbol()->print(O, MAI);
    return;
  case MachineOperand::MO_GlobalAddress:
    getSymbol(MO.getGlobal())->print(O, MAI);
    break;
  case MachineOperand::MO_BlockAddress:
    O << GetBlockAddressSymbol(MO.getBlockAddress())->getName();
    break;
  case MachineOperand::MO_ExternalSymbol:
    O << MO.getSymbolName();
    break;
  case MachineOperand::MO_ConstantPoolIndex:
    GetCPISymbol(MO.getIndex())->print(O, MAI);
    break;
  case MachineOperand::MO_Metadata:
    MO.getMetadata()->printAsOperand(O, MMI->getModule());
    break;
  default:
    llvm_unreachable("<unknown operand type>");
  }
  if (CloseParen)
    O << ")";
}

void RL78AsmPrinter::printMemOperand(const MachineInstr *MI, int opNum,
                                     raw_ostream &O, const char *Modifier) {
  printOperand(MI, opNum, O);
}

/// PrintAsmOperand - Print out an operand for an inline asm expression.
///
bool RL78AsmPrinter::PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                                     const char *ExtraCode, raw_ostream &O) {
  // Currently only register operands are supported (without any modifiers).
  if ((ExtraCode && ExtraCode[0]) ||
      (MI->getOperand(OpNo).getType() != MachineOperand::MO_Register))
    return true;

  printOperand(MI, OpNo, O);
  return false;
}

// When a global variable is emitted, we want the specialized behavior of
// lowerConstant(), so clear the 'useBaseLowerConstant' flag.
void RL78AsmPrinter::emitGlobalVariable(const GlobalVariable *GV) {
  llvm::SaveAndRestore<bool> SAR(useBaseLowerConstant, false);
  AsmPrinter::emitGlobalVariable(GV);
}

// This is used from the specialized lowerConstant() when it needs the
// expression constructed by the base implementation (possibly recursively).
const MCExpr *RL78AsmPrinter::baseLowerConstant(const Constant *CV) {
  llvm::SaveAndRestore<bool> SAR(useBaseLowerConstant, true);
  return AsmPrinter::lowerConstant(CV);
}

enum class ConstType : uint8_t {
  DATA, RODATA, CODE
};

static ConstType getConstGVType(const GlobalValue *GV) {
  if (GV->getValueType()->isFunctionTy())
    return ConstType::CODE;

  if (const auto V = dyn_cast<GlobalVariable>(GV); V->isConstant())
    return ConstType::RODATA;

  return ConstType::DATA;
}

const MCExpr *RL78AsmPrinter::lowerConstantGV(const GlobalValue *GV, int DstAS,
                                              const MCExpr *BaseExpr) const {
  auto &Ctx = OutContext;
  if (!BaseExpr)
    BaseExpr = MCSymbolRefExpr::create(getSymbol(GV), Ctx);

  const auto &DL = GV->getParent()->getDataLayout();
  const auto SrcSize = DL.getPointerSize(GV->getType()->getAddressSpace());
  const auto DstSize = DstAS < 0 ? SrcSize : DL.getPointerSize(DstAS);
  const auto GVType = getConstGVType(GV);
  const auto lowPart = RL78MCExpr::create(GVType == ConstType::RODATA
                         && SrcSize == 2
                                ? RL78MCExpr::VK_RL78_SMRLW
                                : RL78MCExpr::VK_RL78_LOWW,
                            BaseExpr, Ctx);
  if (DstSize == 2)
    return lowPart;

  if (DstSize != 4)
    llvm_unreachable("Unexpected pointer size.");

  // Near -> far address space cast here.
  OutStreamer->emitValue(lowPart, 2);
  const MCExpr *segPart = nullptr;
  if (SrcSize == 4) {
    segPart = RL78MCExpr::create(
        RL78MCExpr::VK_RL78_LOW,
        RL78MCExpr::create(RL78MCExpr::VK_RL78_HIGHW, BaseExpr, Ctx), Ctx);
  } else {
    segPart = MCConstantExpr::create(GVType == ConstType::CODE ? 0x0 : 0xF, Ctx);
  }
  OutStreamer->emitValue(segPart, 1);
  OutStreamer->emitValue(MCConstantExpr::create(0, Ctx), 1);

  // Note: As a convention, returning a null MCExpr from lowerConstant()
  //       indicates that it already emitted the lowered value(s),
  //       so its caller shouldn't do anything else.
  return nullptr;
}

const MCExpr *RL78AsmPrinter::lowerConstant(const Constant *CV,
                                             const Constant *BaseCV,
                                             uint64_t Offset) {
  if (useBaseLowerConstant)
    return AsmPrinter::lowerConstant(CV, BaseCV, Offset);

  const Constant *Op = nullptr;
  unsigned DstAS = 0;
  unsigned SrcAS = 0;
  const MCExpr *BaseExpr = nullptr;

  if (const ConstantExpr *CE = dyn_cast<ConstantExpr>(CV)) {
    switch (CE->getOpcode()) {
    case Instruction::AddrSpaceCast:
      Op = CE->getOperand(0);
      DstAS = CE->getType()->getPointerAddressSpace();
      SrcAS = Op->getType()->getPointerAddressSpace();
      if (TM.isNoopAddrSpaceCast(SrcAS, DstAS))
        return lowerConstant(Op, BaseCV, Offset);
      break;
    case Instruction::IntToPtr:
      Op = CE->getOperand(0);
      break;
    case Instruction::GetElementPtr:
      BaseExpr = baseLowerConstant(CV);
      return lowerConstantGV(cast<GlobalValue>(CE->getOperand(0)), -1, BaseExpr);
    case Instruction::PtrToInt:
      if (auto CE0 = dyn_cast<ConstantExpr>(CE->getOperand(0));
          CE0 && CE0->getOpcode() == Instruction::AddrSpaceCast)
        return baseLowerConstant(CE0->getOperand(0));
    }
  }

  if (const auto GV = dyn_cast<GlobalValue>(CV))
    return lowerConstantGV(GV, -1);

  // If a no-op addr space cast.
  if (Op) {
    // Handle the absolute address case.
    int64_t Constant;
    BaseExpr = baseLowerConstant(Op);
    if (DstAS != SrcAS && BaseExpr->evaluateAsAbsolute(Constant)) {
      Constant = Constant & 0xFF'FFFF;
      switch (DstAS) {
      case RL78AS::Default:
      case RL78AS::Near:
        return MCConstantExpr::create(Constant & 0xFFFF, OutContext);
      case RL78AS::FarCode:
        assert(SrcAS == RL78AS::Near || SrcAS == RL78AS::Default);
        return MCConstantExpr::create(Constant, OutContext);
      case RL78AS::FarData:
        assert(SrcAS == RL78AS::Near || SrcAS == RL78AS::Default);
        assert(Constant <= 0xFFFF);
        return MCConstantExpr::create((Constant & 0xFFFF) | 0x0F'0000,
                                      OutContext);
      default:
        llvm_unreachable("Unexpected RL78 address space");
        break;
      }
    }
    // Handle the relocatable address case.
    if (const auto GV = dyn_cast<GlobalValue>(Op)) {
      return lowerConstantGV(GV, DstAS);
    }
    else if (const ConstantExpr *CE = dyn_cast<ConstantExpr>(Op);
             CE && CE->getOpcode() == Instruction::GetElementPtr) {
      return lowerConstantGV(cast<GlobalValue>(CE->getOperand(0)),
                             DstAS, BaseExpr);
    }
  }

  // Otherwise, default to base implementation (might be already calculated).
  return BaseExpr ? BaseExpr : baseLowerConstant(CV);
}

// Force static initialization.
extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRL78AsmPrinter() {
  RegisterAsmPrinter<RL78AsmPrinter> X(getTheRL78Target());
}
