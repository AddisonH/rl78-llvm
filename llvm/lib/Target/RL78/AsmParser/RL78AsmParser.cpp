//===-- RL78AsmParser.cpp - Parse RL78 assembly to MCInst instructions --===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#include "MCTargetDesc/RL78AsmBackend.h"
#include "MCTargetDesc/RL78MCExpr.h"
#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "MCTargetDesc/RL78TargetStreamer.h"
#include "RL78.h"
#include "TargetInfo/RL78TargetInfo.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCObjectFileInfo.h"
#include "llvm/MC/MCParser/AsmLexer.h"
#include "llvm/MC/MCParser/MCAsmParser.h"
#include "llvm/MC/MCParser/MCParsedAsmOperand.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/SMLoc.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/MemoryBuffer.h"
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>

using namespace llvm;
#define DEBUG_TYPE "rl78-asm-parser"

namespace {

class RL78Operand;

class RL78AsmParser : public MCTargetAsmParser {
  MCAsmParser &Parser;

  /// @name Auto-generated Match Functions
  /// {

#define GET_ASSEMBLER_HEADER
#include "RL78GenAsmMatcher.inc"

  /// }

  // Public interface of the MCTargetAsmParser.
  bool matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode,
                               OperandVector &Operands, MCStreamer &Out,
                               uint64_t &ErrorInfo,
                               bool MatchingInlineAsm) override;
  ParseStatus tryParseRegister(MCRegister &RegNo, SMLoc &StartLoc,
                                        SMLoc &EndLoc) override;
  bool parseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) override;

  bool parseInstruction(ParseInstructionInfo &Info, StringRef Name,
                        SMLoc NameLoc, OperandVector &Operands) override;

  unsigned validateTargetOperandClass(MCParsedAsmOperand &Op,
                                      unsigned Kind) override;

  bool parsePrimaryExpr(const MCExpr *&Res, SMLoc &EndLoc) override;
  bool parseBitPositional(const MCExpr *&Res, SMLoc FirstTokenLoc,
                          std::pair<StringRef, StringRef> Parts);

  int64_t getSymbolAliasValue(StringRef name);

  // Custom parse functions for RL78 specific operands.

  ParseStatus parseMEMOperand(OperandVector &Operands);
  ParseStatus parseStackSlotOperand(OperandVector &Operands);

  ParseStatus parseRegOffsetAddrOperand(OperandVector &Operands,
                                                 StringRef Mnemonic);
  ParseStatus parseRegOffsetAddrOperand(OperandVector &Operands);
  ParseStatus parseRegRegAddrOperand(OperandVector &Operands);

  ParseStatus parseEsRegRegRegOperand(OperandVector &Operands);
  ParseStatus RegBrackets(OperandVector &Operands, StringRef Mnemonic);
  ParseStatus parseEsRegRegAddrOperand(OperandVector &Operands);
  ParseStatus parseEsRegRegAddrAndDotOperand(OperandVector &Operands,
                                                      StringRef Mnemonic);
  bool tokenHasNoDotOrHasSemicolon();
  const MCExpr *parseAddressBeforeDot(StringRef BeforeDot, SMLoc Loc);
  ParseStatus parseOperand(OperandVector &Operands, StringRef Name);

  bool tryParseBCCorSCC(OperandVector &Operands, StringRef Name, SMLoc NameLoc);

  ParseStatus ParseOpeandRBx(OperandVector &Operands);

  ParseStatus ParseRegister(OperandVector &Operands,
                                     StringRef Mnemonic);
   
  ParseStatus parseDotIncludingOperand(OperandVector &Operands,
                                                StringRef Mnemonic);

  ParseStatus ParseShiftIntegerOperand(OperandVector &Operands,
                                                StringRef Mnemonic);

  bool searchSymbolAlias(StringRef name, MCRegister &Register, unsigned &RegKind);

  /// Returns true if Tok is matched to a register and returns register in
  /// RegNo.
  bool matchRegisterName(const AsmToken &Tok, MCRegister &Register,
                         unsigned &RegKind);
  bool matchRegisterNameByName(StringRef name, MCRegister &Register,
                               unsigned &RegKind);

private:
  void eatToEndOfStatement();

  RL78TargetStreamer *getTargetStreamerPtr() {
    MCTargetStreamer *TS = getParser().getStreamer().getTargetStreamer();
    return static_cast<RL78TargetStreamer *>(TS);
  }

public:
  RL78AsmParser(const MCSubtargetInfo &sti, MCAsmParser &parser,
                const MCInstrInfo &MII)
      : MCTargetAsmParser(sti, MII), Parser(parser) {
    // Initialize the set of available features.
    setAvailableFeatures(ComputeAvailableFeatures(getSTI().getFeatureBits()));
  }

  ~RL78AsmParser() override;
};

} // end anonymous namespace

namespace {

/// RL78Operand - Instances of this class represent a parsed RL78 machine
/// instruction.
class RL78Operand : public MCParsedAsmOperand {
public:
  enum RegisterKind {
    rk_None,
    rk_Reg,
    rk_RegPair,
  };

private:
  enum KindTy {
    k_Token,
    k_Register,
    k_Immediate,
    k_cc,
    k_Imm07,
    k_Imm17,
    k_Imm115,
    k_selrbx,
    k_Abs16,
    k_Abs8,
    k_Abs5,
    k_Abs20,
    k_MemoryReg,
    k_MemoryImm,
    k_STACKSlot,
    k_RegOffsetAddr,
    k_RegBorCOffsetAddr,
    k_RegRegAddr,
    k_EsRegRegReg,
    k_HLAddr,
    k_EsRegRegAddr,
    k_EsRegBorCRegAddr,
    k_EsHlRegAddr,
    k_brtargetRel8,
    k_brtargetRel16,
    k_brtargetAbs16,
    k_sfr,
    k_sfrp,
    k_EsAddr16
  } Kind;

  SMLoc StartLoc, EndLoc;

  struct Token {
    const char *Data;
    unsigned Length;
  };

  struct RegOp {
    unsigned RegNum;
    RegisterKind Kind;
  };

  struct RegRegAddrOp {
    RegOp RPReg;
    RegOp Reg;
  };

  struct EsRegRegRegOp {
    RegOp ESReg;
    RegOp RPReg;
    RegOp Reg;
  };

  struct STACKSlotNoOp {
    RegOp SPreg;
    const MCExpr *Val;
  };

  struct RegOffsetAddrOp {
    RegOp RPReg;
    const MCExpr *Val;
  };

  struct RegBorCOffsetAddrOp {
    RegOp Reg;
    const MCExpr *Val;
  };

  struct HLAddrOp {
    RegOp HlReg;
  };

  struct EsRegRegAddrOp {
    RegOp ESReg;
    RegOp RPReg;
    const MCExpr *Val;
  };
  struct EsRegBorCRegAddrOp {
    RegOp ESReg;
    RegOp Reg;
    const MCExpr *Val;
  };
  struct EsHlRegAddrOp {
    RegOp RL78RegES;
    RegOp RL78HL;
  };

  struct ImmOp {
    const MCExpr *Val;
  };

  struct Abs16Op {
    const MCExpr *Val;
  };
  struct Abs8Op {
    const MCExpr *Val;
  };

  struct Abs5Op {
    const MCExpr *Val;
  };

  struct Abs20Op {
    const MCExpr *Val;
  };

  struct Rel8Op {
    const MCExpr *Val;
  };

  struct Rel16Op {
    const MCExpr *Val;
  };

  struct brtargetAbs16Op {
    const MCExpr *Val;
  };

  struct brtargetRel8Op {
    const MCExpr *Val;
  };
  struct brtargetRel16Op {
    const MCExpr *Val;
  };

  struct sfrOp {
    const MCExpr *Val;
  };
  struct sfrpOp {
    const MCExpr *Val;
  };

  struct CCOp {
    const MCExpr *Val;
  };
  struct Imm07Op {
    const MCExpr *Val;
  };
  struct Imm17Op {
    const MCExpr *Val;
  };
  struct Imm115Op {
    const MCExpr *Val;
  };
  struct SELRBxOp {
    const MCExpr *Val;
  };

  struct EsAddr16Op {
    RegOp ESReg;
    const MCExpr *Val;
  };

  struct MemOp {
    unsigned Base;
    unsigned OffsetReg;
    const MCExpr *Off;
  };

  union {
    struct Token Tok;
    struct RegOp Reg;
    struct ImmOp Imm;
    struct MemOp Mem;
    struct Abs5Op Abs5;
    struct Abs8Op Abs8;
    struct Abs16Op Abs16;
    struct Abs20Op Abs20;
    struct brtargetRel8Op brtargetRel8;
    struct brtargetRel16Op brtargetRel16;
    struct brtargetAbs16Op brtargetAbs16;
    struct STACKSlotNoOp STACKSlotNo;
    struct RegRegAddrOp RegRegAddr;
    struct RegOffsetAddrOp RegOffsetAddr;
    struct RegBorCOffsetAddrOp RegBorCOffsetAddr;
    struct EsRegRegAddrOp EsRegRegAddr;
    struct EsHlRegAddrOp EsHlRegAddr;
    struct HLAddrOp HLAddr;
    struct sfrOp sfr;
    struct sfrpOp sfrp;
    struct EsAddr16Op EsAddr16;
    struct EsRegRegRegOp EsRegRegReg;
    struct EsRegBorCRegAddrOp EsRegBorCRegAddr;
    struct SELRBxOp SELRBx;
    struct Imm07Op Imm07;
    struct Imm17Op Imm17;
    struct Imm115Op Imm115;
    struct CCOp CC;
  };

public:
  RL78Operand(KindTy K) : MCParsedAsmOperand(), Kind(K) {}
  bool isABS8() { return Kind == k_Abs8; }
  bool isSELRBx() { return Kind == k_selrbx; }
  bool isABS16() { return Kind == k_Abs16; }
  bool isABS20() { return Kind == k_Abs20; }
  bool isbrtargetRel8() { return Kind == k_brtargetRel8; }
  bool isbrtargetRel16() { return Kind == k_brtargetRel16; }
  bool isToken() const override { return Kind == k_Token; }
  bool isReg() const override { return Kind == k_Register; }
  bool isImm() const override { return Kind == k_Immediate; }
  bool isImm07() const { return Kind == k_Imm07; }
  bool isImm17() const { return Kind == k_Imm17; }
  bool isImm115() const { return Kind == k_Imm115; }

  bool isMem() const override { return isMEMrr() || isMEMri(); }
  bool isMEMrr() const { return Kind == k_MemoryReg; }
  bool isMEMri() const { return Kind == k_MemoryImm; }

  // The registers that are sfrs: SPL, SPH, PSW, CS, ES, PMC, MEM.
  static int64_t getSfrAddress(unsigned Reg) {
    switch (Reg) {
    case RL78::SPL:
      return 0xFFFF8;
    case RL78::SPH:
      return 0xFFFF9;
    case RL78::PSW:
      return 0xFFFFA;
    case RL78::CS:
      return 0xFFFFC;
    case RL78::ES:
      return 0xFFFFD;
    case RL78::PMC:
      return 0xFFFFE;
    case RL78::MEM:
      return 0xFFFFF;
    }
    return 0;
  }
  bool isSfr() const {
    return Kind == k_sfr || (Kind == k_Register && getSfrAddress(Reg.RegNum));
  }
  bool isSfrp() const { return Kind == k_sfrp; }
  bool isEsAddr16() const { return Kind == k_EsAddr16; }

  StringRef getToken() const {
    assert(Kind == k_Token && "Invalid access!");
    return StringRef(Tok.Data, Tok.Length);
  }

  template <int N, int M> bool isImmInRange() const {
    const MCConstantExpr *MCE;

    if (isImm())
      MCE = dyn_cast<MCConstantExpr>(getImm());
    else if (isImm17())
      MCE = dyn_cast<MCConstantExpr>(getImm17());
    else if (isImm07())
      MCE = dyn_cast<MCConstantExpr>(getImm07());
    else if (isImm115())
      MCE = dyn_cast<MCConstantExpr>(getImm115());
    else
      return false;
    if (!MCE)
      return false;
    int64_t Val = MCE->getValue();
    return (Val >= N && Val <= M);
  }
  unsigned getStackSlotNoReg() const {
    assert((Kind == k_STACKSlot) && "Invalid access!");
    assert((STACKSlotNo.SPreg.RegNum == RL78::SPreg) && "Invalid Register!");
    return STACKSlotNo.SPreg.RegNum;
  }

  const MCExpr *getStackSlotNoImm() const {
    assert((Kind == k_STACKSlot) && "Invalid access!");
    return STACKSlotNo.Val;
  }

  unsigned getRegBorCOffsetAddrReg() const {
    assert((Kind == k_RegBorCOffsetAddr) && "Invalid access!");
    return RegBorCOffsetAddr.Reg.RegNum;
  }

  const MCExpr *gettRegBorCOffsetAddrImm() const {
    assert((Kind == k_RegBorCOffsetAddr) && "Invalid access!");
    return RegBorCOffsetAddr.Val;
  }

  unsigned getRegOffsetAddrReg() const {
    assert((Kind == k_RegOffsetAddr) && "Invalid access!");
    return RegOffsetAddr.RPReg.RegNum;
  }

  unsigned getHLAddrReg() const {
    assert((Kind == k_HLAddr) && "Invalid access!");
    return HLAddr.HlReg.RegNum;
  }

  const MCExpr *gettRegOffsetAddrImm() const {
    assert((Kind == k_RegOffsetAddr) && "Invalid access!");
    return RegOffsetAddr.Val;
  }

  unsigned getRegRegAddrRpReg() const {
    assert((Kind == k_RegRegAddr) && "Invalid access!");
    return RegRegAddr.RPReg.RegNum;
  }
  unsigned getRegRegAddrRReg() const {
    assert((Kind == k_RegRegAddr) && "Invalid access!");
    return RegRegAddr.Reg.RegNum;
  }

  unsigned getEsRegRegRegEsReg() const {
    assert((Kind == k_EsRegRegReg) && "Invalid access!");
    return EsRegRegReg.ESReg.RegNum;
  }
  unsigned getEsRegRegRegRpReg() const {
    assert((Kind == k_EsRegRegReg) && "Invalid access!");
    return EsRegRegReg.RPReg.RegNum;
  }
  unsigned getEsRegRegRegRReg() const {
    assert((Kind == k_EsRegRegReg) && "Invalid access!");
    return EsRegRegReg.Reg.RegNum;
  }

  unsigned getEsRegRegAddrEsReg() const {
    assert((Kind == k_EsRegRegAddr) && "Invalid access!");
    return EsRegRegAddr.ESReg.RegNum;
  }
  unsigned getEsRegRegAddrRpReg() const {
    assert((Kind == k_EsRegRegAddr) && "Invalid access!");
    return EsRegRegAddr.RPReg.RegNum;
  }

  const MCExpr *gettEsRegRegAddrImm() const {
    assert((Kind == k_EsRegRegAddr) && "Invalid access!");
    return EsRegRegAddr.Val;
  }

  unsigned getEsRegBorCRegAddrEsReg() const {
    assert((Kind == k_EsRegBorCRegAddr) && "Invalid access!");
    return EsRegBorCRegAddr.ESReg.RegNum;
  }
  unsigned getEsRegBorCRegAddrReg() const {
    assert((Kind == k_EsRegBorCRegAddr) && "Invalid access!");
    return EsRegBorCRegAddr.Reg.RegNum;
  }

  const MCExpr *gettEsRegBorCRegAddrImm() const {
    assert((Kind == k_EsRegBorCRegAddr) && "Invalid access!");
    return EsRegBorCRegAddr.Val;
  }

  unsigned getEsHlRegAddrEsReg() const {
    assert((Kind == k_EsHlRegAddr) && "Invalid access!");
    return EsHlRegAddr.RL78RegES.RegNum;
  }
  unsigned getEsHlRegAddrHlReg() const {
    assert((Kind == k_EsHlRegAddr) && "Invalid access!");
    return EsHlRegAddr.RL78HL.RegNum;
  }

  MCRegister getReg() const override {
    assert((Kind == k_Register) && "Invalid access!");
    return Reg.RegNum;
  }

  const MCExpr *getImm() const {
    assert((Kind == k_Immediate) && "Invalid access!");
    return Imm.Val;
  }
  const MCExpr *getAbs5() const {
    assert((Kind == k_Abs5) && "Invalid access!");
    return Abs5.Val;
  }
  const MCExpr *getCC() const {
    assert((Kind == k_cc) && "Invalid access!");
    return CC.Val;
  }
  const MCExpr *getImm07() const {
    assert((Kind == k_Imm07) && "Invalid access!");
    return Imm07.Val;
  }
  const MCExpr *getImm17() const {
    assert((Kind == k_Imm17) && "Invalid access!");
    return Imm17.Val;
  }
  const MCExpr *getImm115() const {
    assert((Kind == k_Imm115) && "Invalid access!");
    return Imm115.Val;
  }
  const MCExpr *getSELRBx() const {
    assert((Kind == k_selrbx) && "Invalid access!");
    return SELRBx.Val;
  }

  const MCExpr *getAbs16() const {
    assert((Kind == k_Abs16) && "Invalid access!");
    return Abs16.Val;
  }
  const MCExpr *getAbs8() const {
    assert((Kind == k_Abs8) && "Invalid access!");
    return Abs8.Val;
  }
  const MCExpr *getAbs20() const {
    assert((Kind == k_Abs20) && "Invalid access!");
    return Abs20.Val;
  }

  const MCExpr *getSfr() const {
    assert((Kind == k_sfr) && "Invalid access!");
    return sfr.Val;
  }

  const MCExpr *getSfrp() const {
    assert((Kind == k_sfrp) && "Invalid access!");
    return sfrp.Val;
  }

  unsigned getEsAddr16EsReg() const {
    assert((Kind == k_EsAddr16) && "Invalid access!");
    return EsAddr16.ESReg.RegNum;
  }
  const MCExpr *getEsAddr16Addr() const {
    assert((Kind == k_EsAddr16) && "Invalid access!");
    return EsAddr16.Val;
  }

  const MCExpr *getbrtargetAbs16() const {
    assert((Kind == k_brtargetAbs16) && "Invalid access!");
    return brtargetAbs16.Val;
  }

  const MCExpr *getbrtargetRel8() const {
    assert((Kind == k_brtargetRel8) && "Invalid access!");
    return brtargetRel8.Val;
  }

  const MCExpr *getbrtargetRel16() const {
    assert((Kind == k_brtargetRel16) && "Invalid access!");
    return brtargetRel16.Val;
  }

  unsigned getMemBase() const {
    assert((Kind == k_MemoryReg || Kind == k_MemoryImm) && "Invalid access!");
    return Mem.Base;
  }

  unsigned getMemOffsetReg() const {
    assert((Kind == k_MemoryReg) && "Invalid access!");
    return Mem.OffsetReg;
  }

  const MCExpr *getMemOff() const {
    assert((Kind == k_MemoryImm) && "Invalid access!");
    return Mem.Off;
  }

  /// getStartLoc - Get the location of the first token of this operand.
  SMLoc getStartLoc() const override { return StartLoc; }
  /// getEndLoc - Get the location of the last token of this operand.
  SMLoc getEndLoc() const override { return EndLoc; }

  void print(raw_ostream &OS, const MCAsmInfo &MAI) const override {
    switch (Kind) {
    case k_Token:
      OS << "Token: " << getToken() << "\n";
      break;
    case k_Register:
      OS << "Reg: #" << getReg() << "\n";
      break;
    case k_Immediate:
      OS << "Imm: " << getImm() << "\n";
      break;
    case k_MemoryReg:
      OS << "Mem: " << getMemBase() << "+" << getMemOffsetReg() << "\n";
      break;
    case k_MemoryImm:
      assert(getMemOff() != nullptr);
      OS << "Mem: " << getMemBase() << "+";
      MAI.printExpr(OS, *getMemOff());
      OS << "\n";
      break;
    default:
      break;
    }
  }

  void addRegOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getReg()));
  }

  void addImmOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getImm();
    addExpr(Inst, Expr);
  }

  void addImm07Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getImm07();
    addExpr(Inst, Expr);
  }

  void addImm17Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getImm17();
    addExpr(Inst, Expr);
  }

  void addImm115Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getImm115();
    addExpr(Inst, Expr);
  }

  void addSELRBxOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getSELRBx();
    addExpr(Inst, Expr);
  }

  void addABS8Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getAbs8();
    addExpr(Inst, Expr);
  }

  void addABS5Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getAbs5();
    addExpr(Inst, Expr);
  }

  void addABS16Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getAbs16();
    addExpr(Inst, Expr);
  }

  void addABS20Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getAbs20();
    addExpr(Inst, Expr);
  }

  void addSfrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    if (Kind == k_Register) {
      Inst.addOperand(MCOperand::createImm(getSfrAddress(Reg.RegNum)));
      return;
    }
    const MCExpr *Expr = getSfr();
    addExpr(Inst, Expr);
  }

  void addSfrpOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getSfrp();
    addExpr(Inst, Expr);
  }

  void addEsAddr16Operands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getEsAddr16EsReg()));
    const MCExpr *Expr = getEsAddr16Addr();
    addExpr(Inst, Expr);
  }

  void addbrtargetRel8Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getbrtargetRel8();
    addExpr(Inst, Expr);
  }

  void addbrtargetRel16Operands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    const MCExpr *Expr = getbrtargetRel16();
    addExpr(Inst, Expr);
  }

  void addSTACKSlotNoOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getStackSlotNoReg()));
    const MCExpr *Expr = getStackSlotNoImm();
    addExpr(Inst, Expr);
  }

  void addRegBorCOffsetAddrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getRegBorCOffsetAddrReg()));
    const MCExpr *Expr = gettRegBorCOffsetAddrImm();
    addExpr(Inst, Expr);
  }
  void addRegOffsetAddrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getRegOffsetAddrReg()));
    const MCExpr *Expr = gettRegOffsetAddrImm();
    addExpr(Inst, Expr);
  }

  void addEsRegRegAddrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 3 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getEsRegRegAddrEsReg()));
    Inst.addOperand(MCOperand::createReg(getEsRegRegAddrRpReg()));
    const MCExpr *Expr = gettEsRegRegAddrImm();
    addExpr(Inst, Expr);
  }

  void addEsRegBorCRegAddrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 3 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getEsRegBorCRegAddrEsReg()));
    Inst.addOperand(MCOperand::createReg(getEsRegBorCRegAddrReg()));
    const MCExpr *Expr = gettEsRegBorCRegAddrImm();
    addExpr(Inst, Expr);
  }

  // Memory operands of the hardware instructions (RL78InstrISA.td).
  static bool isZero(const MCExpr *E) {
    auto *CE = dyn_cast<MCConstantExpr>(E);
    return CE && CE->getValue() == 0;
  }
  // [HL]; also [HL+0], which the parser does not tell from it.
  bool isMemHL() const {
    return (Kind == k_HLAddr && HLAddr.HlReg.RegNum == RL78::RP6) ||
           (Kind == k_RegOffsetAddr && RegOffsetAddr.RPReg.RegNum == RL78::RP6 &&
            isZero(RegOffsetAddr.Val));
  }
  bool isMemHLi() const {
    return (Kind == k_HLAddr && HLAddr.HlReg.RegNum == RL78::RP6) ||
           (Kind == k_RegOffsetAddr && RegOffsetAddr.RPReg.RegNum == RL78::RP6);
  }
  bool isMemHLr() const {
    return Kind == k_RegRegAddr && RegRegAddr.RPReg.RegNum == RL78::RP6 &&
           (RegRegAddr.Reg.RegNum == RL78::R2 ||
            RegRegAddr.Reg.RegNum == RL78::R3);
  }
  bool isESMemHL() const {
    return (Kind == k_EsHlRegAddr && EsHlRegAddr.RL78HL.RegNum == RL78::RP6) ||
           (Kind == k_EsRegRegAddr && EsRegRegAddr.RPReg.RegNum == RL78::RP6 &&
            isZero(EsRegRegAddr.Val));
  }
  bool isESMemHLi() const {
    return (Kind == k_EsHlRegAddr && EsHlRegAddr.RL78HL.RegNum == RL78::RP6) ||
           (Kind == k_EsRegRegAddr && EsRegRegAddr.RPReg.RegNum == RL78::RP6);
  }
  bool isESMemHLr() const {
    return Kind == k_EsRegRegReg && EsRegRegReg.RPReg.RegNum == RL78::RP6 &&
           (EsRegRegReg.Reg.RegNum == RL78::R2 ||
            EsRegRegReg.Reg.RegNum == RL78::R3);
  }
  // Conditions, as tryParseBCCorSCC makes them: B and SK take C, NC, Z,
  // NZ or (with a 61 prefix) H, NH; BT and BF are Z and NZ.
  int64_t getCondValue() const {
    return cast<MCConstantExpr>(CC.Val)->getValue();
  }
  // CALLT [addr5]: an even address in 80H-BEH.
  bool isCallt() const {
    if (Kind != k_Abs5)
      return false;
    auto *CE = dyn_cast<MCConstantExpr>(Abs5.Val);
    if (!CE)
      return true;
    int64_t V = CE->getValue();
    return V >= 0x80 && V <= 0xBE && V % 2 == 0;
  }
  bool isCondCZ() const {
    return Kind == k_cc && getCondValue() <= RL78CC::RL78CC_NZ;
  }
  bool isCondH() const {
    return Kind == k_cc && (getCondValue() == RL78CC::RL78CC_H ||
                            getCondValue() == RL78CC::RL78CC_NH);
  }
  bool isCondTF() const {
    return Kind == k_cc && (getCondValue() == RL78CC::RL78CC_Z ||
                            getCondValue() == RL78CC::RL78CC_NZ);
  }
  void addCondCZOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createImm(getCondValue()));
  }
  void addCondHOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createImm(getCondValue()));
  }
  void addCondTFOperands(MCInst &Inst, unsigned N) const {
    Inst.addOperand(MCOperand::createImm(getCondValue()));
  }

  static bool isDEorHL(unsigned Reg) {
    return Reg == RL78::RP4 || Reg == RL78::RP6;
  }
  // [DE], [HL] (and [DE+0], [HL+0]); [DE+byte], [HL+byte].
  bool isMemRP() const {
    return (Kind == k_HLAddr && HLAddr.HlReg.RegNum == RL78::RP6) ||
           (Kind == k_RegOffsetAddr && isDEorHL(RegOffsetAddr.RPReg.RegNum) &&
            isZero(RegOffsetAddr.Val));
  }
  bool isMemRPi() const {
    return (Kind == k_HLAddr && HLAddr.HlReg.RegNum == RL78::RP6) ||
           (Kind == k_RegOffsetAddr && isDEorHL(RegOffsetAddr.RPReg.RegNum));
  }
  bool isMemSPi() const { return Kind == k_STACKSlot; }
  // word[B], word[C], word[BC]
  bool isMemBw() const {
    return Kind == k_RegBorCOffsetAddr && RegBorCOffsetAddr.Reg.RegNum == RL78::R3;
  }
  bool isMemCw() const {
    return Kind == k_RegBorCOffsetAddr && RegBorCOffsetAddr.Reg.RegNum == RL78::R2;
  }
  bool isMemBCw() const {
    return Kind == k_RegOffsetAddr && RegOffsetAddr.RPReg.RegNum == RL78::RP2;
  }
  bool isESMemRP() const {
    return (Kind == k_EsHlRegAddr && EsHlRegAddr.RL78HL.RegNum == RL78::RP6) ||
           (Kind == k_EsRegRegAddr && isDEorHL(EsRegRegAddr.RPReg.RegNum) &&
            isZero(EsRegRegAddr.Val));
  }
  bool isESMemRPi() const {
    return (Kind == k_EsHlRegAddr && EsHlRegAddr.RL78HL.RegNum == RL78::RP6) ||
           (Kind == k_EsRegRegAddr && isDEorHL(EsRegRegAddr.RPReg.RegNum));
  }
  bool isESMemBw() const {
    return Kind == k_EsRegBorCRegAddr && EsRegBorCRegAddr.Reg.RegNum == RL78::R3;
  }
  bool isESMemCw() const {
    return Kind == k_EsRegBorCRegAddr && EsRegBorCRegAddr.Reg.RegNum == RL78::R2;
  }
  bool isESMemBCw() const {
    return Kind == k_EsRegRegAddr && EsRegRegAddr.RPReg.RegNum == RL78::RP2;
  }
  unsigned getRPBase() const {
    if (Kind == k_HLAddr)
      return HLAddr.HlReg.RegNum;
    if (Kind == k_RegOffsetAddr)
      return RegOffsetAddr.RPReg.RegNum;
    if (Kind == k_EsHlRegAddr)
      return EsHlRegAddr.RL78HL.RegNum;
    assert(Kind == k_EsRegRegAddr && "not a [rp+byte] operand");
    return EsRegRegAddr.RPReg.RegNum;
  }
  void addDisp(MCInst &Inst) const {
    if (const MCExpr *Disp = getMemDisp())
      addExpr(Inst, Disp);
    else
      Inst.addOperand(MCOperand::createImm(0));
  }
  void addMemRPOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getRPBase()));
  }
  void addMemRPiOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(getRPBase()));
    addDisp(Inst);
  }
  void addMemSPiOperands(MCInst &Inst, unsigned N) const {
    addSTACKSlotNoOperands(Inst, N);
  }
  void addMemBwOperands(MCInst &Inst, unsigned N) const {
    addRegBorCOffsetAddrOperands(Inst, N);
  }
  void addMemCwOperands(MCInst &Inst, unsigned N) const {
    addRegBorCOffsetAddrOperands(Inst, N);
  }
  void addMemBCwOperands(MCInst &Inst, unsigned N) const {
    addRegOffsetAddrOperands(Inst, N);
  }
  void addESMemRPOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::ES));
    Inst.addOperand(MCOperand::createReg(getRPBase()));
  }
  void addESMemRPiOperands(MCInst &Inst, unsigned N) const {
    assert(N == 3 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::ES));
    Inst.addOperand(MCOperand::createReg(getRPBase()));
    addDisp(Inst);
  }
  void addESMemBwOperands(MCInst &Inst, unsigned N) const {
    addEsRegBorCRegAddrOperands(Inst, N);
  }
  void addESMemCwOperands(MCInst &Inst, unsigned N) const {
    addEsRegBorCRegAddrOperands(Inst, N);
  }
  void addESMemBCwOperands(MCInst &Inst, unsigned N) const {
    addEsRegRegAddrOperands(Inst, N);
  }

  const MCExpr *getMemDisp() const {
    if (Kind == k_RegOffsetAddr)
      return RegOffsetAddr.Val;
    if (Kind == k_EsRegRegAddr)
      return EsRegRegAddr.Val;
    return nullptr;
  }
  void addMemHLOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
  }
  void addMemHLiOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
    if (const MCExpr *Disp = getMemDisp())
      addExpr(Inst, Disp);
    else
      Inst.addOperand(MCOperand::createImm(0));
  }
  void addMemHLrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
    Inst.addOperand(MCOperand::createReg(RegRegAddr.Reg.RegNum));
  }
  void addESMemHLOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::ES));
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
  }
  void addESMemHLiOperands(MCInst &Inst, unsigned N) const {
    assert(N == 3 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::ES));
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
    if (const MCExpr *Disp = getMemDisp())
      addExpr(Inst, Disp);
    else
      Inst.addOperand(MCOperand::createImm(0));
  }
  void addESMemHLrOperands(MCInst &Inst, unsigned N) const {
    assert(N == 3 && "Invalid number of operands!");
    Inst.addOperand(MCOperand::createReg(RL78::ES));
    Inst.addOperand(MCOperand::createReg(RL78::RP6));
    Inst.addOperand(MCOperand::createReg(EsRegRegReg.Reg.RegNum));
  }

  void addExpr(MCInst &Inst, const MCExpr *Expr) const {
    // Add as immediate when possible.  Null MCExpr = 0.
    if (!Expr)
      Inst.addOperand(MCOperand::createImm(0));
    else if (const MCConstantExpr *CE = dyn_cast<MCConstantExpr>(Expr))
      Inst.addOperand(MCOperand::createImm(CE->getValue()));
    else
      Inst.addOperand(MCOperand::createExpr(Expr));
  }

  static std::unique_ptr<RL78Operand> CreateToken(StringRef Str, SMLoc S) {
    auto Op = std::make_unique<RL78Operand>(k_Token);
    Op->Tok.Data = Str.data();
    Op->Tok.Length = Str.size();
    Op->StartLoc = S;
    Op->EndLoc = S;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateReg(unsigned RegNum, unsigned Kind,
                                                SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Register);
    Op->Reg.RegNum = RegNum;
    Op->Reg.Kind = (RL78Operand::RegisterKind)Kind;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateSTACKSlotNo(unsigned RegNum,
                                                        unsigned Kind,
                                                        const MCExpr *Val,
                                                        SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_STACKSlot);
    Op->STACKSlotNo.SPreg.RegNum = RegNum;
    Op->STACKSlotNo.SPreg.Kind = (RL78Operand::RegisterKind)Kind;
    Op->STACKSlotNo.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateRegOffsetAddr(unsigned RPRegNum,
                                                          unsigned RPRegKind,
                                                          const MCExpr *Val,
                                                          SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_RegOffsetAddr);
    Op->RegOffsetAddr.RPReg.RegNum = RPRegNum;
    Op->RegOffsetAddr.RPReg.Kind = (RL78Operand::RegisterKind)RPRegKind;
    Op->RegOffsetAddr.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand>
  CreateRegBorCOffsetAddr(unsigned RegNum, unsigned RegKind, const MCExpr *Val,
                          SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_RegBorCOffsetAddr);
    Op->RegBorCOffsetAddr.Reg.RegNum = RegNum;
    Op->RegBorCOffsetAddr.Reg.Kind = (RL78Operand::RegisterKind)RegKind;
    Op->RegBorCOffsetAddr.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand>
  CreateHLAddr(unsigned RPRegNum, unsigned RPRegKind, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_HLAddr);
    Op->HLAddr.HlReg.RegNum = RPRegNum;
    Op->HLAddr.HlReg.Kind = (RL78Operand::RegisterKind)RPRegKind;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand>
  CreateRegRegAddr(unsigned RPRegNum, unsigned RPRegKind, unsigned RegNum,
                   unsigned RegKind, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_RegRegAddr);
    Op->RegRegAddr.RPReg.RegNum = RPRegNum;
    Op->RegRegAddr.RPReg.Kind = (RL78Operand::RegisterKind)RPRegKind;
    Op->RegRegAddr.Reg.RegNum = RegNum;
    Op->RegRegAddr.Reg.Kind = (RL78Operand::RegisterKind)RegKind;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand>
  CreateEsRegRegAddr(unsigned ESRegNum, unsigned ESKind, unsigned RPRegNum,
                     unsigned RPKind, const MCExpr *Val, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_EsRegRegAddr);
    Op->EsRegRegAddr.ESReg.RegNum = ESRegNum;
    Op->EsRegRegAddr.ESReg.Kind = (RL78Operand::RegisterKind)ESKind;
    Op->EsRegRegAddr.RPReg.RegNum = RPRegNum;
    Op->EsRegRegAddr.RPReg.Kind = (RL78Operand::RegisterKind)RPKind;
    Op->EsRegRegAddr.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand>
  CreateEsRegBorCRegAddr(unsigned ESRegNum, unsigned ESKind, unsigned RegNum,
                         unsigned Kind, const MCExpr *Val, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_EsRegBorCRegAddr);
    Op->EsRegBorCRegAddr.ESReg.RegNum = ESRegNum;
    Op->EsRegBorCRegAddr.ESReg.Kind = (RL78Operand::RegisterKind)ESKind;
    Op->EsRegBorCRegAddr.Reg.RegNum = RegNum;
    Op->EsRegBorCRegAddr.Reg.Kind = (RL78Operand::RegisterKind)Kind;
    Op->EsRegBorCRegAddr.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand>
  CreateEsRegRegReg(unsigned ESRegNum, unsigned ESKind, unsigned RPRegNum,
                    unsigned RPKind, unsigned RegNum, unsigned Kind, SMLoc S,
                    SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_EsRegRegReg);
    Op->EsRegRegReg.ESReg.RegNum = ESRegNum;
    Op->EsRegRegReg.ESReg.Kind = (RL78Operand::RegisterKind)ESKind;
    Op->EsRegRegReg.RPReg.RegNum = RPRegNum;
    Op->EsRegRegReg.RPReg.Kind = (RL78Operand::RegisterKind)RPKind;
    Op->EsRegRegReg.Reg.RegNum = RegNum;
    Op->EsRegRegReg.Reg.Kind = (RL78Operand::RegisterKind)Kind;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand>
  CreateEsHlRegAddr(unsigned ESRegNum, unsigned ESKind, unsigned RPRegNum,
                    unsigned RPKind, SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_EsHlRegAddr);
    Op->EsHlRegAddr.RL78RegES.RegNum = ESRegNum;
    Op->EsHlRegAddr.RL78RegES.Kind = (RL78Operand::RegisterKind)ESKind;
    Op->EsHlRegAddr.RL78HL.RegNum = RPRegNum;
    Op->EsHlRegAddr.RL78HL.Kind = (RL78Operand::RegisterKind)RPKind;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateImm(const MCExpr *Val, SMLoc S,
                                                SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Immediate);
    Op->Imm.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateAbs5(const MCExpr *Val, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Abs5);
    Op->Abs5.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateAbs8(const MCExpr *Val, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Abs8);
    Op->Abs8.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateAbs16(const MCExpr *Val, SMLoc S,
                                                  SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Abs16);
    Op->Abs16.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateSfr(const MCExpr *Val, SMLoc S,
                                                SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_sfr);
    Op->sfr.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateSfrp(const MCExpr *Val, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_sfrp);
    Op->sfrp.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateEsAddr16(unsigned RegNum,
                                                     unsigned RegKind,
                                                     const MCExpr *Val, SMLoc S,
                                                     SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_EsAddr16);
    Op->EsAddr16.ESReg.RegNum = RegNum;
    Op->EsAddr16.ESReg.Kind = (RL78Operand::RegisterKind)RegKind;
    Op->EsAddr16.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateAbs20(const MCExpr *Val, SMLoc S,
                                                  SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Abs20);
    Op->Abs20.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreatebrtargetRel8(const MCExpr *Val,
                                                         SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_brtargetRel8);
    Op->brtargetRel8.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreatebrtargetRel16(const MCExpr *Val,
                                                          SMLoc S, SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_brtargetRel16);
    Op->brtargetRel16.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }

  static std::unique_ptr<RL78Operand> CreateSELRBx(const MCExpr *Val, SMLoc S,
                                                   SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_selrbx);
    Op->SELRBx.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand> CreateImm07(const MCExpr *Val, SMLoc S,
                                                  SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Imm07);
    Op->Imm07.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand> CreateImm17(const MCExpr *Val, SMLoc S,
                                                  SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Imm17);
    Op->Imm17.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand> CreateImm115(const MCExpr *Val, SMLoc S,
                                                   SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_Imm115);
    Op->Imm115.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<RL78Operand> CreateCC(const MCExpr *Val, SMLoc S,
                                               SMLoc E) {
    auto Op = std::make_unique<RL78Operand>(k_cc);
    Op->CC.Val = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
};
} // end anonymous namespace

static std::map<std::string, int> ccTono{

    // C/NC/Z/NZ/H/NH.
    {"c", RL78CC::RL78CC_C},  {"nc", RL78CC::RL78CC_NC},
    {"z", RL78CC::RL78CC_Z},  {"nz", RL78CC::RL78CC_NZ},
    {"h", RL78CC::RL78CC_H},  {"nh", RL78CC::RL78CC_NH},
    {"f", RL78CC::RL78CC_NZ}, {"t", RL78CC::RL78CC_Z}};

// Defined in the generated matcher.
static const char *getSubtargetFeatureName(uint64_t Val);

RL78AsmParser::~RL78AsmParser() = default;

bool RL78AsmParser::matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode,
                                            OperandVector &Operands,
                                            MCStreamer &Out,
                                            uint64_t &ErrorInfo,
                                            bool MatchingInlineAsm) {

  MCInst Inst;
  SmallVector<MCInst, 8> Instructions;
  FeatureBitset MissingFeatures;
  unsigned MatchResult = MatchInstructionImpl(Operands, Inst, ErrorInfo,
                                              MissingFeatures,
                                              MatchingInlineAsm);
  switch (MatchResult) {
  case Match_Success: {
    Inst.setLoc(IDLoc);
    Instructions.push_back(Inst);

    for (const MCInst &I : Instructions) {
      Out.emitInstruction(I, getSTI());
    }
    return false;
  }

  case Match_MissingFeature: {
    std::string Msg = "instruction requires:";
    for (unsigned I = 0, E = MissingFeatures.size(); I != E; ++I)
      if (MissingFeatures[I])
        Msg += std::string(" ") + getSubtargetFeatureName(I);
    return Error(IDLoc, Msg);
  }

  case Match_InvalidOperand: {
    SMLoc ErrorLoc = IDLoc;
    if (ErrorInfo != ~0ULL) {
      if (ErrorInfo >= Operands.size())
        return Error(IDLoc, "too few operands for instruction");

      ErrorLoc = ((RL78Operand &)*Operands[ErrorInfo]).getStartLoc();
      if (ErrorLoc == SMLoc())
        ErrorLoc = IDLoc;
    }

    return Error(ErrorLoc, "invalid operand for instruction");
  }
  case Match_MnemonicFail:
    return Error(IDLoc, "invalid instruction mnemonic");
  }
  llvm_unreachable("Implement any new match types added!");
}

bool RL78AsmParser::tryParseBCCorSCC(OperandVector &Operands, StringRef Name,
                                     SMLoc NameLoc) {

  // BC / BNC / BZ / BNZ / BH / BNH.
  // SC / SNC / SZ / SNZ / SH / SNH.
  // SK_cc.
  // BT/BF.
  StringRef mnemonic;
  StringRef operand;

  if (Name.substr(0, 1).compare("b") == 0 &&
      ccTono.find(Name.substr(1, Name.size()).str()) != ccTono.end()) {

    mnemonic = Name.substr(0, 1);
    operand = Name.substr(1, Name.size());

  } else if (Name.substr(0, 2).compare("sk") == 0 &&
             ccTono.find(Name.substr(2, Name.size()).str()) != ccTono.end()) {

    mnemonic = Name.substr(0, 2);
    operand = Name.substr(2, Name.size());

  } else
    return false;

  if (!mnemonic.empty() && !operand.empty()) {

    Operands.push_back(RL78Operand::CreateToken(mnemonic, NameLoc));
    SMLoc S = Parser.getTok().getLoc();
    SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
    const MCExpr *EVal;
    EVal = MCConstantExpr::create(ccTono[operand.str()], getContext());
    Operands.push_back(RL78Operand::CreateCC(EVal, S, E));
    return true;
  }

  return false;
}

void RL78AsmParser::eatToEndOfStatement() {
  auto& Lexer = getLexer();
  while (Lexer.isNot(AsmToken::EndOfStatement) && Lexer.isNot(AsmToken::Eof))
    Lexer.Lex();

  // Eat EOL.
  if (Lexer.is(AsmToken::EndOfStatement))
    Lexer.Lex();
}

bool RL78AsmParser::parseInstruction(ParseInstructionInfo &Info, StringRef Name,
                                     SMLoc NameLoc, OperandVector &Operands) {
  // Ensure that if the instruction occurs when relaxation is enabled,
  // relocations are forced for the file. Ideally this would be done when there
  // is enough information to reliably determine if the instruction itself may
  // cause relaxations. Unfortunately instruction processing stage occurs in the
  // same pass as relocation emission, so it's too late to set a 'sticky bit'
  // for the entire file.
  if (getSTI().hasFeature(RL78::FeatureRelax) && getTargetStreamerPtr()) {
    auto *Assembler = getTargetStreamerPtr()->getStreamer().getAssemblerPtr();
    if (Assembler != nullptr) {
      RL78AsmBackend &MAB =
          static_cast<RL78AsmBackend &>(Assembler->getBackend());
      MAB.setForceRelocs();
    }
  }

  // First verify if b_cc or s_cc.
  // If not, single mnemonic - push operand.
  if (!tryParseBCCorSCC(Operands, Name, NameLoc)) {
    // First operand in MCInst is instruction mnemonic.
    Operands.push_back(RL78Operand::CreateToken(Name, NameLoc));
  }

  // Read the remaining operands.
  if (getLexer().isNot(AsmToken::EndOfStatement)) {
    // Read the first operand.
    if (!parseOperand(Operands, Name).isSuccess()) {
      SMLoc Loc = getLexer().getLoc();
      Parser.eatToEndOfStatement();
      return Error(Loc, "unexpected token in argument list");
    }

    while (getLexer().is(AsmToken::Comma)) {
      Parser.Lex(); // Eat the comma.

      // Parse and remember the operand.
      if (!parseOperand(Operands, Name).isSuccess()) {
        SMLoc Loc = getLexer().getLoc();
        Parser.eatToEndOfStatement();
        return Error(Loc, "unexpected token in argument list");
      }
    }
  }

  if (getLexer().isNot(AsmToken::EndOfStatement)) {
    SMLoc Loc = getLexer().getLoc();
    Parser.eatToEndOfStatement();
    return Error(Loc, "unexpected token in argument list");
  }
  // Consume the EndOfStatement.
  Parser.Lex();
  return false;
}



static ParseStatus CheckAddressValueRange(StringRef Mnemonic,
                                                   OperandVector &Operands,
                                                   int64_t AddressValue,
                                                   MCContext &Context, SMLoc S,
                                                   SMLoc E) {
  const MCExpr *EVal = MCConstantExpr::create(AddressValue, Context);
  if (Mnemonic.compare("movw") != 0 && AddressValue > 0xfff1f &&
      AddressValue <= 0xfffff)
    Operands.push_back(RL78Operand::CreateSfr(EVal, S, E));
  else if (AddressValue > 0xfff1f && AddressValue <= 0xfffff &&
           AddressValue % 2 == 0)
    Operands.push_back(RL78Operand::CreateSfrp(EVal, S, E));
  else if (AddressValue >= 0xffe20 && AddressValue <= 0xfff1f)
    Operands.push_back(RL78Operand::CreateAbs8(EVal, S, E));
  else
    return ParseStatus::NoMatch;
  return ParseStatus::Success;
}

StringRef StripTempSymbolPrefix(StringRef Symbol) {
  // We are expecting names in the form of:
  // .L__$__{Symbol or RegName}__$__{Nr}
  StringRef Guard = "__$__";
  size_t Start = Symbol.find(Guard) + Guard.size();
  size_t End = Symbol.rfind(Guard);
  if (Start != StringRef::npos && End != StringRef::npos && Start != End) {
    return Symbol.substr(Start, End - Start);
  }

  return Symbol;
}

ParseStatus
RL78AsmParser::parseDotIncludingOperand(OperandVector &Operands,
                                        StringRef Mnemonic) {

  if (Mnemonic.compare("mov1") != 0 && Mnemonic.compare("and1") != 0 &&
      Mnemonic.compare("or1") != 0 && Mnemonic.compare("xor1") != 0 &&
      Mnemonic.compare("set1") != 0 && Mnemonic.compare("clr1") != 0 &&
      Mnemonic.compare("bt") != 0 && Mnemonic.compare("bf") != 0 &&
      Mnemonic.compare("btclr") != 0)
    return ParseStatus::NoMatch;

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const AsmToken &Token = getLexer().getTok();
  if ((Token.is(AsmToken::Identifier) &&
       (Token.getString().compare_insensitive("cy") == 0 ||
        Token.getString().compare_insensitive("es") == 0)) ||
      Token.is(AsmToken::LBrac))
    return ParseStatus::NoMatch;

  const MCExpr *Value;
  if (getParser().parseExpression(Value)) {
    Error(Token.getLoc(), "missing expression");
    return ParseStatus::NoMatch;
  }

  MCValue AddressMCValue;
  int64_t BitPosition = -1;
  if (Value->getKind() == MCExpr::SymbolRef) {
    // A plain symbol carries no bit position.
    return ParseStatus::NoMatch;
  } else {

    if (!RL78MCExpr::FoldBitPositionalExpression(Value, AddressMCValue,
                                                 BitPosition, getContext()) ||
        BitPosition == -1) {
      LLVM_DEBUG(Value->dump());
      Error(Token.getLoc(), "invalid expression");
      return ParseStatus::NoMatch;
    }

    if (AddressMCValue.isAbsolute() &&
        !CheckAddressValueRange(Mnemonic, Operands, AddressMCValue.getConstant(),
                               getContext(), S, E).isSuccess()) {
      LLVM_DEBUG(Value->dump());
      Error(Token.getLoc(), "invalid expression");
      return ParseStatus::NoMatch;
    } else if (!AddressMCValue.isAbsolute()) {
      unsigned RegAKind, RegBKind;
      MCRegister RegA, RegB;
      bool IsSymARegister = false;
      bool IsSymBRegister = false;
      StringRef SymAName, SymBName;
      MCSymbol *SymA, *SymB;

      if (AddressMCValue.getAddSym()) {
        SymAName = StripTempSymbolPrefix(
            AddressMCValue.getAddSym()->getName());
        IsSymARegister = matchRegisterNameByName(SymAName, RegA, RegAKind);
        SymA = getContext().lookupSymbol(SymAName);
      }

      if (AddressMCValue.getSubSym()) {
        SymBName = StripTempSymbolPrefix(
            AddressMCValue.getSubSym()->getName());
        IsSymBRegister = matchRegisterNameByName(SymBName, RegB, RegBKind);
      }

      // Registers can't be used in binary expressions and can't have constant
      // adds.
      if ((IsSymARegister || IsSymBRegister) &&
          AddressMCValue.getConstant() != 0) {
        Error(Token.getLoc(), "invalid expression");
        return ParseStatus::NoMatch;
      }
      const MCExpr *SymEVal;
      if (IsSymARegister || IsSymBRegister) {
        Operands.push_back(
            RL78Operand::CreateReg(IsSymARegister ? RegA : RegB,
                                   IsSymARegister ? RegAKind : RegBKind, S, E));
      } else if (AddressMCValue.getAddSym() && AddressMCValue.getSubSym()) {
        SymA = getContext().getOrCreateSymbol(SymAName);
        SymB = getContext().getOrCreateSymbol(SymBName);
        SymEVal = MCBinaryExpr::createAdd(
            MCSymbolRefExpr::create(SymA, getContext()),
            MCConstantExpr::create(AddressMCValue.getConstant(), getContext()),
            getContext());
        SymEVal = MCBinaryExpr::createSub(
            SymEVal, MCSymbolRefExpr::create(SymB, getContext()), getContext());

        Operands.push_back(RL78Operand::CreateAbs8(SymEVal, S, E));
      } else if (AddressMCValue.getAddSym()) {
        SymA = getContext().getOrCreateSymbol(SymAName);
        SymEVal = MCBinaryExpr::createAdd(
            MCSymbolRefExpr::create(SymA, getContext()),
            MCConstantExpr::create(AddressMCValue.getConstant(), getContext()),
            getContext());
        Operands.push_back(RL78Operand::CreateAbs8(SymEVal, S, E));
      } else {
        llvm_unreachable("Unexpected MCValue");
      }
    }
  }

  const MCExpr *EVal = MCConstantExpr::create(BitPosition, getContext());
  Operands.push_back(RL78Operand::CreateImm07(EVal, S, E));
  return ParseStatus::Success;
}

ParseStatus RL78AsmParser::ParseRegister(OperandVector &Operands,
                                                  StringRef Mnemonic) {

  ParseStatus ResTy = ParseStatus::NoMatch;
  unsigned RegKind;
  MCRegister Reg;
  if (matchRegisterName(Parser.getTok(), Reg, RegKind) &&
      !getLexer().peekTok().is(AsmToken::Colon)) {

    SMLoc S = Parser.getTok().getLoc();
    Parser.Lex(); // Eat the identifier token.
    SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
    Operands.push_back(RL78Operand::CreateReg(Reg, RegKind, S, E));

    ResTy = ParseStatus::Success;
  }

  return ResTy;
}

ParseStatus RL78AsmParser::ParseOpeandRBx(OperandVector &Operands) {

  ParseStatus ResTy = ParseStatus::NoMatch;

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const MCExpr *EVal;

  StringRef name = Parser.getTok().getString();
  if (name.compare_insensitive("rb0") == 0) {
    EVal = MCConstantExpr::create(0, getContext());
    Operands.push_back(RL78Operand::CreateSELRBx(EVal, S, E));
    ResTy = ParseStatus::Success;
    Parser.Lex();
  } else if (name.compare_insensitive("rb1") == 0) {
    EVal = MCConstantExpr::create(1, getContext());
    Operands.push_back(RL78Operand::CreateSELRBx(EVal, S, E));
    ResTy = ParseStatus::Success;
    Parser.Lex();
  } else if (name.compare_insensitive("rb2") == 0) {
    EVal = MCConstantExpr::create(2, getContext());
    Operands.push_back(RL78Operand::CreateSELRBx(EVal, S, E));
    ResTy = ParseStatus::Success;
    Parser.Lex();
  } else if (name.compare_insensitive("rb3") == 0) {
    EVal = MCConstantExpr::create(3, getContext());
    Operands.push_back(RL78Operand::CreateSELRBx(EVal, S, E));
    ResTy = ParseStatus::Success;
    Parser.Lex();
  }
  return ResTy;
}

ParseStatus
RL78AsmParser::ParseShiftIntegerOperand(OperandVector &Operands,
                                        StringRef Mnemonic) {

  ParseStatus ResTy = ParseStatus::NoMatch;

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const MCExpr *EVal;
  if (Mnemonic.compare("shr") == 0 || Mnemonic.compare("shl") == 0 ||
      Mnemonic.compare("sar") == 0) {
    std::unique_ptr<RL78Operand> Op;
    if (!getParser().parseExpression(EVal, E)) {
      Op = RL78Operand::CreateImm17(EVal, S, E);

      Operands.push_back(std::move(Op));
      ResTy = ParseStatus::Success;
    }
  } else if (Mnemonic.compare("shrw") == 0 || Mnemonic.compare("shlw") == 0 ||
             Mnemonic.compare("sarw") == 0 || Mnemonic.compare("shrw") == 0) {

    std::unique_ptr<RL78Operand> Op;
    if (!getParser().parseExpression(EVal, E)) {
      Op = RL78Operand::CreateImm115(EVal, S, E);

      Operands.push_back(std::move(Op));
      ResTy = ParseStatus::Success;
    }
  } else if (Mnemonic.compare("ror") == 0 || Mnemonic.compare("rol") == 0 ||
             Mnemonic.compare("rorc") == 0 || Mnemonic.compare("rolc") == 0 ||
             Mnemonic.compare("rolwc") == 0 || Mnemonic.compare("rorc") == 0) {

    Operands.push_back(RL78Operand::CreateToken(Parser.getTok().getString(),
                                                Parser.getTok().getLoc()));
    Parser.Lex();
    ResTy = ParseStatus::Success;
  }
  return ResTy;
}

bool RL78AsmParser::tokenHasNoDotOrHasSemicolon() {
  return getLexer().getTok().getString().find(".") == std::string::npos ||
         getLexer().getTok().getString().find(";") != std::string::npos;
}

/// The address part of an "!addr16.bit" operand that the lexer returned as
/// one token: a number in any radix the lexer accepts (0x.., 0b.., 0..,
/// decimal), an absolute alias (.equ/.set), or a symbol. Returns null after
/// reporting an error.
const MCExpr *RL78AsmParser::parseAddressBeforeDot(StringRef BeforeDot,
                                                   SMLoc Loc) {
  uint64_t Value;
  if (!BeforeDot.getAsInteger(0, Value))
    return MCConstantExpr::create(Value, getContext());
  if (BeforeDot.empty() || isDigit(BeforeDot[0])) {
    Error(Loc, "invalid address '" + BeforeDot + "'");
    return nullptr;
  }
  MCSymbol *Sym = getContext().lookupSymbol(BeforeDot);
  int64_t Alias;
  if (Sym && Sym->isVariable() &&
      Sym->getVariableValue()->evaluateAsAbsolute(Alias))
    return MCConstantExpr::create(Alias, getContext());
  return MCSymbolRefExpr::create(getContext().getOrCreateSymbol(BeforeDot),
                                 getContext());
}

ParseStatus RL78AsmParser::parseOperand(OperandVector &Operands,
                                                 StringRef Mnemonic) {
  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
  const MCExpr *Res;

  // SEL RB0
  if (ParseOpeandRBx(Operands).isSuccess())
    return ParseStatus::Success;
  // Register ax, special, or r8.
  if (ParseRegister(Operands, Mnemonic).isSuccess())
    return ParseStatus::Success;

  // Byte or word.
  if (getLexer().is(AsmToken::Hash)) {

    Parser.Lex(); // Eat the Hash token.
    SMLoc S = Parser.getTok().getLoc();
    SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
    const MCExpr *EVal;
    Parser.parseExpression(EVal, E);
    Operands.push_back(RL78Operand::CreateImm(EVal, S, E));
    return ParseStatus::Success;
  }
  if (getLexer().is(AsmToken::Dollar)) {

    AsmToken Excl = Parser.Lex();
    if (getLexer().is(AsmToken::Exclaim)) {
      Parser.Lex();
      SMLoc S = Parser.getTok().getLoc();
      SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
      const MCExpr *EVal;
      Parser.parseExpression(EVal, E);
      Operands.push_back(RL78Operand::CreatebrtargetRel16(EVal, S, E));
      return ParseStatus::Success;

    } else {
      SMLoc S = Parser.getTok().getLoc();
      SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
      const MCExpr *EVal;
      Parser.parseExpression(EVal, E);
      Operands.push_back(RL78Operand::CreatebrtargetRel8(EVal, S, E));
      return ParseStatus::Success;
    }
  }
  if (getLexer().is(AsmToken::Exclaim)) {
    AsmToken ExclFirst = Parser.getTok();
    AsmToken ExclSecond = Parser.Lex();
    if (getLexer().is(AsmToken::Exclaim)) {
      Parser.Lex();
      SMLoc S = Parser.getTok().getLoc();
      SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
      const MCExpr *EVal;
      Parser.parseExpression(EVal, E);
      Operands.push_back(
          RL78Operand::CreateToken(ExclFirst.getString(), ExclFirst.getLoc()));
      Operands.push_back(RL78Operand::CreateToken(ExclSecond.getString(),
                                                  ExclSecond.getLoc()));
      Operands.push_back(RL78Operand::CreateAbs20(EVal, S, E));
      return ParseStatus::Success;
    } else {

      SMLoc S = Parser.getTok().getLoc();
      SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
      const MCExpr *EVal;
      StringRef checkDot = getLexer().getTok().getString();

      size_t dot = checkDot.find(".");
      if (dot != std::string::npos &&
          checkDot.substr(dot + 1, checkDot.size())
                  .find_first_not_of("0123456789") == std::string::npos &&
          ((Mnemonic.compare("set1") == 0 || Mnemonic.compare("clr1") == 0) &&
           !getLexer().peekTok().is(AsmToken::LParen))) {
        EVal = parseAddressBeforeDot(checkDot.substr(0, dot), S);
        if (!EVal)
          return ParseStatus::Failure;

        Operands.push_back(RL78Operand::CreateAbs16(EVal, S, E));

        std::string Imm = checkDot.substr(dot + 1, checkDot.size()).str();
        const MCExpr *EVal;
        EVal = MCConstantExpr::create(std::stoi(Imm), getContext());
        SMLoc S = Parser.getTok().getLoc();
        SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
        Operands.push_back(RL78Operand::CreateImm07(EVal, S, E));
        Parser.Lex();
        return ParseStatus::Success;
      } else {
        StringRef checkDot = getLexer().getTok().getString();
        size_t dot = checkDot.find(".");
        if (dot == std::string::npos) {
          if (!Parser.parseExpression(EVal, E)) {
            MCValue AddressValue;
            int64_t BitPosition = -1;
            if (!RL78MCExpr::FoldBitPositionalExpression(
                    EVal, AddressValue, BitPosition, getContext()) ||
                BitPosition == -1) {
              Operands.push_back(RL78Operand::CreateAbs16(EVal, S, E));
              if (Mnemonic.compare("mov1") == 0 || Mnemonic.compare("and1") == 0 ||
                  Mnemonic.compare("or1") == 0 || Mnemonic.compare("xor1") == 0 ||
                  Mnemonic.compare("set1") == 0 || Mnemonic.compare("clr1") == 0 ||
                  Mnemonic.compare("bt") == 0 || Mnemonic.compare("bf") == 0 ||
                  Mnemonic.compare("btclr") == 0) {
                // The bit number follows the address as its own ".n"
                // token; anything else (e.g. "a03ah.3" after "0" when the
                // lexer split "0a03ah.3") is not a bit operand.
                StringRef checkDot = getLexer().getTok().getString();
                size_t dot = checkDot.find(".");
                if (dot == 0 && checkDot.size() > 1 &&
                    checkDot.drop_front().find_first_not_of("0123456789") ==
                        StringRef::npos) {
                  std::string Imm =
                      checkDot.substr(dot + 1, checkDot.size()).str();
                  const MCExpr *EVal;
                  EVal = MCConstantExpr::create(std::stoi(Imm), getContext());
                  SMLoc S = Parser.getTok().getLoc();
                  SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
                  Operands.push_back(RL78Operand::CreateImm07(EVal, S, E));
                  Parser.Lex();
                } else
                  return ParseStatus::NoMatch;
              }
            } else {
              const MCExpr *AddressExpr;
              if (AddressValue.isAbsolute()) {
                AddressExpr = MCConstantExpr::create(AddressValue.getConstant(),
                                                     getContext());
              } else {
                AddressExpr = MCSymbolRefExpr::create(AddressValue.getAddSym(),
                                                      getContext());
                if (AddressValue.getSubSym())
                  AddressExpr = MCBinaryExpr::createSub(
                      AddressExpr,
                      MCSymbolRefExpr::create(AddressValue.getSubSym(),
                                              getContext()),
                      getContext());
                if (AddressValue.getConstant())
                  AddressExpr = MCBinaryExpr::createAdd(
                      AddressExpr,
                      MCConstantExpr::create(AddressValue.getConstant(),
                                             getContext()),
                      getContext());
              }
              Operands.push_back(RL78Operand::CreateAbs16(AddressExpr, S, E));
              Operands.push_back(RL78Operand::CreateImm07(
                  MCConstantExpr::create(BitPosition, getContext()), S, E));
            }

            return ParseStatus::Success;
          }
        } else {
          // We expect set1 !addr16.imm.
          const MCExpr *EVal;

          SMLoc S = Parser.getTok().getLoc();
          SMLoc E = SMLoc::getFromPointer(S.getPointer() - 1);
          EVal = parseAddressBeforeDot(checkDot.substr(0, dot), S);
          if (!EVal)
            return ParseStatus::Failure;

          Operands.push_back(RL78Operand::CreateAbs16(EVal, S, E));

          std::string Imm = checkDot.substr(dot + 1, checkDot.size()).str();
          EVal = MCConstantExpr::create(std::stoi(Imm), getContext());
          S = Parser.getTok().getLoc();
          E = SMLoc::getFromPointer(S.getPointer() - 1);
          Operands.push_back(RL78Operand::CreateImm07(EVal, S, E));
          Parser.Lex();

          return ParseStatus::Success;
        }
      }
    }
  }

  if (parseDotIncludingOperand(Operands, Mnemonic).isSuccess())
    return ParseStatus::Success;

  // ES:!addr16.
  // ES : [DE].
  // ES : [DE + byte].
  // ES : [HL] ES : word[B].
  // ES : word[BC].
  if (parseEsRegRegAddrAndDotOperand(Operands, Mnemonic).isSuccess() &&
      tokenHasNoDotOrHasSemicolon())
    return ParseStatus::Success;

  if (ParseShiftIntegerOperand(Operands, Mnemonic).isSuccess())
    return ParseStatus::Success;

  // word[bc].
  // word[c].
  // word[b].
  if (parseRegOffsetAddrOperand(Operands, Mnemonic).isSuccess() &&
      tokenHasNoDotOrHasSemicolon())
    return ParseStatus::Success;

  if (RegBrackets(Operands, Mnemonic).isSuccess() &&
      tokenHasNoDotOrHasSemicolon())
    return ParseStatus::Success;

  StringRef checkDot = getLexer().getTok().getString();
  size_t dot = checkDot.find(".");
  if (dot == std::string::npos) {
    Parser.parseExpression(Res, E);
    if (Res) {
      int64_t value = 0;
      if (Res->getKind() == Res->Constant)
        value = ((dyn_cast<MCConstantExpr>(Res))->getValue());

      LLVM_DEBUG(dbgs() << "Value is :" << value);
      if (Mnemonic.compare("movw") != 0 && value >= 0xfff1f && value <= 0xfffff)
        Operands.push_back(RL78Operand::CreateSfr(Res, S, E));
      else if (value >= 0xfff1f && value <= 0xfffff && value % 2 == 0)
        Operands.push_back(RL78Operand::CreateSfrp(Res, S, E));
      else if (value >= 0xffe20 && value <= 0xfff1f)
        Operands.push_back(RL78Operand::CreateAbs8(Res, S, E));
      else
        Operands.push_back(RL78Operand::CreateAbs8(Res, S, E));
    }
  }

  // Handle bit position part of [HL].5 or ES:[HL].6 for example
  AsmToken Token = getLexer().getTok();
  StringRef TokenString = Token.getString();
  dot = TokenString.find('.');
  int64_t BitPositionValue;
  if (dot == 0) {
    if (Token.is(AsmToken::Real)) {
      // See if we have (0xf230+4).[0-7]
      if (TokenString.size() != 2 || TokenString[1] < '0' ||
          TokenString[1] > '7')
        return ParseStatus::NoMatch;
      BitPositionValue = TokenString[1] - '0';

    } else if (Token.is(AsmToken::Identifier)) {
      // Or (0xf230+4).SYM
      const MCSymbol *BitSym = getContext().lookupSymbol(
          TokenString.substr(1, TokenString.size() - 2));
      if (!BitSym || !BitSym->isVariable() ||
          !BitSym->getVariableValue()->evaluateAsAbsolute(BitPositionValue))
        return ParseStatus::NoMatch;
    } else {
      return ParseStatus::NoMatch;
    }
    const MCExpr *BitPosExpr =
        MCConstantExpr::create(BitPositionValue, getContext());
    Parser.Lex();
    SMLoc S = Parser.getTok().getLoc();
    SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
    Operands.push_back(RL78Operand::CreateImm07(BitPosExpr, S, E));
    return ParseStatus::Success;
  }

  return ParseStatus::Success;
}

// Unused.
ParseStatus RL78AsmParser::parseMEMOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}

// Unused.
ParseStatus
RL78AsmParser::parseStackSlotOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}

ParseStatus
RL78AsmParser::parseRegOffsetAddrOperand(OperandVector &Operands,
                                         StringRef Mnemonic) {

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const MCExpr *Res = nullptr;
  unsigned RegKind;
  MCRegister Reg;
  // Due to the fact that we can actually have an expression here and we might
  // parse it and lose it we need to check for dot.
  StringRef checkDot = getLexer().getTok().getString();
  size_t dot = checkDot.find(".");
  // In case we have a dot we stop as we will parse this later.
  if (getLexer().is(AsmToken::LBrac) || dot != std::string::npos)
    return ParseStatus::NoMatch;

  // Needed for word[bc].
  if (!getParser().parseExpression(Res, E)) {
    // A LBrac is what we actually want, but because we already parsed the
    // expression we also need to take care of the else case.
    if (getLexer().is(AsmToken::LBrac)) {

      Parser.Lex(); // Eat the '['.

      StringRef name = Parser.getTok().getString();
      if ((name.compare_insensitive("bc") == 0 || name.compare_insensitive("b") == 0 ||
           name.compare_insensitive("c") == 0) &&
          Res != nullptr) {
        if (!matchRegisterName(Parser.getTok(), Reg, RegKind))
          return ParseStatus::NoMatch;
        Parser.Lex(); // Eat the identifier token.

        if (getLexer().is(AsmToken::RBrac)) {
          if (name.compare_insensitive("bc") == 0)
            Operands.push_back(
                RL78Operand::CreateRegOffsetAddr(Reg, RegKind, Res, S, E));
          else
            Operands.push_back(RL78Operand::CreateRegBorCOffsetAddr(
                Reg, RegKind, Res, S, E));

          Parser.Lex(); // Eat the ']'.
          return ParseStatus::Success;
        }
      }
      return ParseStatus::NoMatch;
    } else {
      // We need this here because we already parsed the expression.
      if (Res) {
        int64_t value = 0;
        if (Res->getKind() == Res->Constant)
          value = ((dyn_cast<MCConstantExpr>(Res))->getValue());

        LLVM_DEBUG(dbgs() << "Value is :" << value);
        if (Mnemonic.compare("movw") != 0 && value >= 0xfff1f &&
            value <= 0xfffff)
          Operands.push_back(RL78Operand::CreateSfr(Res, S, E));
        else if (value >= 0xfff1f && value <= 0xfffff && value % 2 == 0)
          Operands.push_back(RL78Operand::CreateSfrp(Res, S, E));
        else if (value >= 0xffe20 && value <= 0xfff1f)
          Operands.push_back(RL78Operand::CreateAbs8(Res, S, E));
        else
          Operands.push_back(RL78Operand::CreateAbs8(Res, S, E));
        return ParseStatus::Success;
      }
    }
    return ParseStatus::NoMatch;
  }
  return ParseStatus::NoMatch;
}

ParseStatus
RL78AsmParser::parseRegOffsetAddrOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}
ParseStatus
RL78AsmParser::parseRegRegAddrOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}
ParseStatus
RL78AsmParser::parseEsRegRegRegOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}
ParseStatus
RL78AsmParser::parseEsRegRegAddrOperand(OperandVector &Operands) {
  return ParseStatus::NoMatch;
}
// ES:!addr16.
// ES : [DE].
// ES : [DE + byte].
// ES : [HL] ES : word[B].
// ES : word[BC].
ParseStatus
RL78AsmParser::parseEsRegRegAddrAndDotOperand(OperandVector &Operands,
                                              StringRef Mnemonic) {

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const MCExpr *Res = nullptr;
  unsigned RegESKind, RegKind;
  MCRegister RegES, Reg;

  if ((getLexer().getTok().getString() == "es" ||
       getLexer().getTok().getString() == "ES") &&
      getLexer().peekTok().is(AsmToken::Colon)) {

    if (!matchRegisterName(Parser.getTok(), RegES, RegESKind))
      return ParseStatus::NoMatch;

    Parser.Lex();

    if (getLexer().is(AsmToken::Colon))
      Parser.Lex(); // Eat the ':'.
    else
      return ParseStatus::NoMatch;

    if (getLexer().is(AsmToken::Exclaim)) {
      Parser.Lex(); // Eat the '!'.

      StringRef name = Parser.getTok().getString();
      size_t dot = name.find(".");
      if (dot != std::string::npos &&
          name.substr(dot + 1, name.size()).find_first_not_of("0123456789") ==
              std::string::npos &&
          (Mnemonic.compare("set1") == 0 || Mnemonic.compare("clr1") == 0)) {

        Res = parseAddressBeforeDot(name.substr(0, dot),
                                    Parser.getTok().getLoc());
        if (!Res)
          return ParseStatus::Failure;

        Operands.push_back(
            RL78Operand::CreateEsAddr16(RegES, RegESKind, Res, S, E));

        std::string Imm = name.substr(dot + 1, name.size()).str();
        const MCExpr *EVal;
        EVal = MCConstantExpr::create(std::stoi(Imm), getContext());
        SMLoc S = Parser.getTok().getLoc();
        SMLoc E =
            SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
        Operands.push_back(RL78Operand::CreateImm07(EVal, S, E));
        Parser.Lex(); // Eat the '!'.
        return ParseStatus::Success;

      }

      else {

        if (!getParser().parseExpression(Res, E)) {
          MCValue AddressValue;
          int64_t BitPosition = -1;
          if (!RL78MCExpr::FoldBitPositionalExpression(
                  Res, AddressValue, BitPosition, getContext()) ||
              BitPosition == -1) {
            Operands.push_back(
                RL78Operand::CreateEsAddr16(RegES, RegESKind, Res, S, E));
          } else {
            const MCExpr *AddressExpr;
            if (AddressValue.isAbsolute()) {
              AddressExpr = MCConstantExpr::create(AddressValue.getConstant(),
                                                   getContext());
            } else if (!AddressValue.getSubSym()) {
              AddressExpr = MCSymbolRefExpr::create(AddressValue.getAddSym(), getContext());
            } else {
              AddressExpr = MCBinaryExpr::createSub(
                  MCSymbolRefExpr::create(AddressValue.getAddSym(),
                                          getContext()),
                  MCSymbolRefExpr::create(AddressValue.getSubSym(),
                                          getContext()),
                  getContext());
            }
            Operands.push_back(RL78Operand::CreateEsAddr16(RegES, RegESKind,
                                                           AddressExpr, S, E));
            Operands.push_back(RL78Operand::CreateImm07(
                MCConstantExpr::create(BitPosition, getContext()), S, E));
          }
          return ParseStatus::Success;
        }
      }

    } else if (getLexer().is(AsmToken::LBrac)) {
      Parser.Lex();

      if (!matchRegisterName(Parser.getTok(), Reg, RegKind))
        return ParseStatus::NoMatch;
      Parser.Lex();

      if (getLexer().is(AsmToken::RBrac)) {
        AsmToken a = getLexer().peekTok();
        size_t dot = a.getString().find(".");
        if (dot == std::string::npos) {

          Res = MCConstantExpr::create(0, getContext());

          Operands.push_back(RL78Operand::CreateEsRegRegAddr(
              RegES, RegESKind, Reg, RegKind, Res, S, E));

          Parser.Lex(); // Eat the ']'.
          return ParseStatus::Success;
        } else {
          Parser.Lex(); // Eat the ']'.

          Operands.push_back(RL78Operand::CreateEsHlRegAddr(
              RegES, RegESKind, Reg, RegKind, S, E));
          return ParseStatus::Success;
        }
      } else if (getLexer().is(AsmToken::Plus)) {
        Parser.Lex(); // Eat the '+'
        unsigned Kind;
        MCRegister Reg2;
        if (matchRegisterName(Parser.getTok(), Reg2, Kind)) {

          Operands.push_back(RL78Operand::CreateEsRegRegReg(
              RegES, RegESKind, Reg, RegKind, Reg2, Kind, S, E));

          Parser.Lex();
          if (getLexer().is(AsmToken::RBrac)) {
            Parser.Lex(); // Eat the ']'.
            return ParseStatus::Success;
          }
        } else if (!getParser().parseExpression(Res, E)) {

          Operands.push_back(RL78Operand::CreateEsRegRegAddr(
              RegES, RegESKind, Reg, RegKind, Res, S, E));

          if (getLexer().is(AsmToken::RBrac)) {
            Parser.Lex(); // Eat the ']'.
            return ParseStatus::Success;
          }
        }
      }
    } else {
      if (!getParser().parseExpression(Res, E)) {
        if (getLexer().is(AsmToken::LBrac)) {
          Parser.Lex();
          if (!matchRegisterName(Parser.getTok(), Reg, RegKind))
            return ParseStatus::NoMatch;
          Parser.Lex();
          if (getLexer().is(AsmToken::RBrac)) {
            if (Reg == RL78::RP2)
              Operands.push_back(RL78Operand::CreateEsRegRegAddr(
                  RegES, RegESKind, Reg, RegKind, Res, S, E));
            else
              Operands.push_back(RL78Operand::CreateEsRegBorCRegAddr(
                  RegES, RegESKind, Reg, RegKind, Res, S, E));

            Parser.Lex(); // Eat the ']'.
            return ParseStatus::Success;

          } else
            return ParseStatus::Success;
        }
      }
    }
  }
  return ParseStatus::NoMatch;
}

ParseStatus RL78AsmParser::RegBrackets(OperandVector &Operands,
                                                StringRef Mnemonic) {

  ParseStatus ResTy = ParseStatus::NoMatch;

  SMLoc S = Parser.getTok().getLoc();
  SMLoc E = SMLoc::getFromPointer(Parser.getTok().getLoc().getPointer() - 1);
  const MCExpr *Res;
  if (Mnemonic.compare("callt") == 0) {

    if (getLexer().is(AsmToken::LBrac)) {
      Parser.Lex(); // Eat the '[' token.

      if (!getParser().parseExpression(Res, E)) {
        Operands.push_back(RL78Operand::CreateAbs5(Res, S, E));
        ResTy = ParseStatus::Success;
      }
      if (getLexer().is(AsmToken::RBrac)) {
        Parser.Lex();
        return ResTy;
      }
    }
  }
  if (getLexer().is(AsmToken::LBrac)) {
    unsigned Reg1Kind;
    MCRegister Reg1;

    Parser.Lex(); // Eat the '[' token.

    if (!matchRegisterName(Parser.getTok(), Reg1, Reg1Kind))
      return ParseStatus::NoMatch;

    Parser.Lex();

    if (getLexer().is(AsmToken::RBrac) &&
        getLexer().peekTok(true).getString().find(".") != std::string::npos &&
        Reg1 == RL78::RP6) {

      Operands.push_back(RL78Operand::CreateHLAddr(Reg1, Reg1Kind, S, E));
      Parser.Lex(); // Eat the ']' token.

      ResTy = ParseStatus::Success;
    } else if (getLexer().is(AsmToken::RBrac)) {

      Res = MCConstantExpr::create(0, getContext());

      if (Reg1 == RL78::SPreg)
        Operands.push_back(
            RL78Operand::CreateSTACKSlotNo(Reg1, Reg1Kind, Res, S, E));
      else
        Operands.push_back(
            RL78Operand::CreateRegOffsetAddr(Reg1, Reg1Kind, Res, S, E));

      Parser.Lex(); // Eat the ']'.
      return ParseStatus::Success;

    } else if (getLexer().is(AsmToken::Plus)) {
      Parser.Lex(); // Eat the '+'.

      unsigned Reg2Kind;
      MCRegister Reg2;
      if (matchRegisterName(Parser.getTok(), Reg2, Reg2Kind)) {

        Operands.push_back(RL78Operand::CreateRegRegAddr(
            Reg1, Reg1Kind, Reg2, Reg2Kind, S, E));
        Parser.Lex();
        ResTy = ParseStatus::Success;
      } else if (!getParser().parseExpression(Res, E)) {

        if (Reg1 == RL78::SPreg) {

          Operands.push_back(
              RL78Operand::CreateSTACKSlotNo(Reg1, Reg1Kind, Res, S, E));
        } else {
          Operands.push_back(
              RL78Operand::CreateRegOffsetAddr(Reg1, Reg1Kind, Res, S, E));
        }

        Parser.Lex();
        ResTy = ParseStatus::Success;
      }
    }

    if (getLexer().is(AsmToken::RBrac)) {

      Parser.Lex();
      return ResTy;
    }
  }

  return ResTy;
}

bool RL78AsmParser::matchRegisterName(const AsmToken &Tok, MCRegister &Register,
                                      unsigned &RegKind) {
  RegKind = RL78Operand::rk_None;
  StringRef name = Tok.getString();

  return matchRegisterNameByName(name, Register, RegKind);
}

bool RL78AsmParser::matchRegisterNameByName(StringRef name, MCRegister &Register,
                                            unsigned &RegKind) {
  RegKind = RL78Operand::rk_None;
  // Bank 0 registers:
  // X, A, C, B, E, D, L, H.

  if (name.compare_insensitive("x") == 0) {
    Register = RL78::R0;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("a") == 0) {
    Register = RL78::R1;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("c") == 0) {
    Register = RL78::R2;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("b") == 0) {
    Register = RL78::R3;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("e") == 0) {
    Register = RL78::R4;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("d") == 0) {
    Register = RL78::R5;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("l") == 0) {
    Register = RL78::R6;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("h") == 0) {
    Register = RL78::R7;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("ax") == 0) {
    Register = RL78::RP0;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("bc") == 0) {
    Register = RL78::RP2;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("de") == 0) {
    Register = RL78::RP4;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("hl") == 0) {
    Register = RL78::RP6;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("es") == 0) {
    Register = RL78::ES;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("cs") == 0) {
    Register = RL78::CS;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("sp") == 0) {
    Register = RL78::SPreg;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("cy") == 0) {
    Register = RL78::CY;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("psw") == 0) {
    Register = RL78::PSW;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("pmc") == 0) {
    Register = RL78::PMC;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("mem") == 0) {
    Register = RL78::MEM;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("spl") == 0) {
    Register = RL78::SPL;
    RegKind = RL78Operand::rk_Reg;
    return true;
  } else if (name.compare_insensitive("sph") == 0) {
    Register = RL78::SPH;
    RegKind = RL78Operand::rk_Reg;
    return true;
  }

  return searchSymbolAlias(name, Register, RegKind);
}

ParseStatus RL78AsmParser::tryParseRegister(MCRegister &Register, SMLoc &StartLoc,
                                  SMLoc &EndLoc) {
  const AsmToken &Tok = Parser.getTok();
  StartLoc = Tok.getLoc();
  EndLoc = Tok.getEndLoc();
  Register = 0;
  unsigned regKind = RL78Operand::rk_None;
  if (matchRegisterName(Tok, Register, regKind)) {
    Parser.Lex();
    return ParseStatus::Success;
  }

  return ParseStatus::NoMatch;
}

bool RL78AsmParser::parseRegister(MCRegister &RegNo, SMLoc &StartLoc,
                                   SMLoc &EndLoc) {
  if (!tryParseRegister(RegNo, StartLoc, EndLoc).isSuccess())
    return Error(StartLoc, "invalid register name");
  return false;
}

extern "C" void LLVMInitializeRL78AsmParser() {
  RegisterMCAsmParser<RL78AsmParser> A(getTheRL78Target());
}

#define GET_REGISTER_MATCHER
#define GET_SUBTARGET_FEATURE_NAME
#define GET_MATCHER_IMPLEMENTATION
#include "RL78GenAsmMatcher.inc"

unsigned RL78AsmParser::validateTargetOperandClass(MCParsedAsmOperand &GOp,
                                                   unsigned Kind) {
  return Match_InvalidOperand;
}
bool RL78AsmParser::searchSymbolAlias(StringRef name, MCRegister &Register,
                                      unsigned &RegKind) {
    MCSymbol *Sym = getContext().lookupSymbol(name);
    if (!Sym)
      return false;
    if (Sym->isVariable()) {
      const MCExpr *Expr = Sym->getVariableValue();
      if (Expr->getKind() == MCExpr::SymbolRef) {
        const MCSymbolRefExpr *Ref = static_cast<const MCSymbolRefExpr *>(Expr);
        StringRef DefSymbol = Ref->getSymbol().getName();

        LLVM_DEBUG(dbgs() << "Alias for register\n");
        if (matchRegisterNameByName(DefSymbol, Register, RegKind))
          return true;
      }
    }
  return false;
}

int64_t RL78AsmParser::getSymbolAliasValue(StringRef name) {
  int64_t DefSymbol = 0;

  MCSymbol *Sym = getContext().lookupSymbol(name);
  if (!Sym)
    return DefSymbol;
  if (Sym->isVariable()) {
    const MCExpr *Expr = Sym->getVariableValue();
    if (Expr->getKind() == MCExpr::Constant) {
      const MCConstantExpr *Ref = static_cast<const MCConstantExpr *>(Expr);
      DefSymbol = Ref->getValue();
    }
  }
  return DefSymbol;
}

/// The Renesas relocation operators, written OPERATOR(expression).
static std::optional<RL78MCExpr::VariantKind> matchOperator(StringRef Name) {
  return StringSwitch<std::optional<RL78MCExpr::VariantKind>>(Name)
      .CaseLower("high", RL78MCExpr::VK_RL78_HIGH)
      .CaseLower("low", RL78MCExpr::VK_RL78_LOW)
      .CaseLower("highw", RL78MCExpr::VK_RL78_HIGHW)
      .CaseLower("loww", RL78MCExpr::VK_RL78_LOWW)
      .CaseLower("mirhw", RL78MCExpr::VK_RL78_MIRHW)
      .CaseLower("mirlw", RL78MCExpr::VK_RL78_MIRLW)
      .CaseLower("smrlw", RL78MCExpr::VK_RL78_SMRLW)
      .CaseLower("startof", RL78MCExpr::VK_RL78_STARTOF)
      .CaseLower("sizeof", RL78MCExpr::VK_RL78_SIZEOF)
      .Default(std::nullopt);
}

/// True if \p Tok is ".n" with n a bit number, the form in which the lexer
/// returns the bit position that follows a number or a parenthesis.
static bool isBitSuffix(const AsmToken &Tok) {
  StringRef S = Tok.getString();
  return Tok.is(AsmToken::Real) && S.size() == 2 && S[0] == '.' &&
         S[1] >= '0' && S[1] <= '7';
}

/// Build the bit operand "address.bit" from an identifier token that
/// contains a dot. Returns false, with Res untouched, if the token is not
/// one (the bit part is neither a digit nor an absolute symbol).
bool RL78AsmParser::parseBitPositional(const MCExpr *&Res, SMLoc FirstTokenLoc,
                                       std::pair<StringRef, StringRef> Parts) {
  MCContext &Ctx = getContext();
  const MCExpr *AddressExpr;
  int64_t BitPositionValue;

  if (Parts.second.size() == 1 && Parts.second[0] >= '0' &&
      Parts.second[0] <= '7') {
    BitPositionValue = Parts.second[0] - '0';
  } else {
    const MCSymbol *BitSym = Ctx.lookupSymbol(Parts.second);
    if (!BitSym || !BitSym->isVariable() ||
        !BitSym->getVariableValue()->evaluateAsAbsolute(BitPositionValue))
      return false;
  }

  if (Parts.first.compare_insensitive("psw") == 0) {
    AddressExpr = MCConstantExpr::create(0xFFFFA, Ctx);
  } else {
    if (Parts.first.empty())
      return false;
    // The address part may turn out to be a register name (A.3), so a
    // symbol that does not exist yet is not created under its own name:
    // parseDotIncludingOperand strips the guard again.
    MCSymbol *AddressSymbol = Ctx.lookupSymbol(Parts.first);
    if (!AddressSymbol)
      AddressSymbol =
          Ctx.createNamedTempSymbol("__$__" + Parts.first + "__$__");
    AddressExpr = MCSymbolRefExpr::create(AddressSymbol, Ctx, FirstTokenLoc);
  }

  // RL78MCExpr takes the address and the bit as one "address && bit" node.
  Res = MCBinaryExpr::create(MCBinaryExpr::LAnd, AddressExpr,
                             MCConstantExpr::create(BitPositionValue, Ctx),
                             Ctx, FirstTokenLoc);
  Res = RL78MCExpr::create(RL78MCExpr::VK_RL78_BITPOSITIONAL, Res, Ctx);
  getParser().Lex();
  return true;
}

/// Primary expressions of the Renesas syntax on top of the generic ones:
/// relocation operators (LOWW(sym), HIGHW(sym), ...), PSW as an address,
/// and bit operands (sym.3, 0xFFE30.3, (sym+4).3).
bool RL78AsmParser::parsePrimaryExpr(const MCExpr *&Res, SMLoc &EndLoc) {
  AsmLexer &Lexer = getLexer();
  MCContext &Ctx = getContext();
  SMLoc FirstTokenLoc = Lexer.getLoc();
  AsmToken::TokenKind FirstTokenKind = Lexer.getKind();
  StringRef Token = Lexer.getTok().getString();

  switch (FirstTokenKind) {
  default:
    break;
  case AsmToken::Identifier: {
    if (std::optional<RL78MCExpr::VariantKind> Kind = matchOperator(Token);
        Kind && Lexer.peekTok().is(AsmToken::LParen)) {
      getParser().Lex(); // Eat the operator.
      getParser().Lex(); // Eat the '('.
      if (getParser().parseExpression(Res, EndLoc))
        return true;
      if (Lexer.isNot(AsmToken::RParen))
        return TokError("expected ')'");
      EndLoc = Lexer.getTok().getEndLoc();
      getParser().Lex(); // Eat the ')'.
      Res = RL78MCExpr::create(*Kind, Res, Ctx);
      return false;
    }
    if (Token.equals_insensitive("psw")) {
      Res = MCConstantExpr::create(0xFFFFA, Ctx);
      EndLoc = Lexer.getTok().getEndLoc();
      getParser().Lex();
      return false;
    }
    if (Token.contains('.') && !Ctx.lookupSymbol(Token) &&
        parseBitPositional(Res, FirstTokenLoc, Token.split('.')))
      return false;
    break;
  }
  }

  if (getParser().parsePrimaryExpr(Res, EndLoc, nullptr))
    return true;

  // 0xFFE30.3 and (0xF230+4).3: the lexer returns ".3" as a real number.
  if (FirstTokenKind != AsmToken::Integer &&
      FirstTokenKind != AsmToken::LParen)
    return false;
  const AsmToken &Next = Lexer.getTok();
  if (Next.isNot(AsmToken::Real))
    return false;
  if (!isBitSuffix(Next))
    return TokError("invalid bit position value");
  Res = MCBinaryExpr::create(
      MCBinaryExpr::LAnd, Res,
      MCConstantExpr::create(Next.getString()[1] - '0', Ctx), Ctx, EndLoc);
  Res = RL78MCExpr::create(RL78MCExpr::VK_RL78_BITPOSITIONAL, Res, Ctx);
  EndLoc = Next.getEndLoc();
  getParser().Lex();
  return false;
}
