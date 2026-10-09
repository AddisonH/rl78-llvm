//===-- RL78InstrISA.td - RL78 hardware instructions -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The RL78 instruction set as the RL78 Family User's Manual: Software
// (R01US0015) lists it: one definition per instruction form, named
// MNEMONIC_operand_operand after the manual's operand list, with the exact
// register class of every register the instruction reads or writes.
//
// Operand spelling in the names:
//   A, X, AX, ...   that register (an operand of a single-register class)
//   r, rp           a register field (8-bit, 16-bit)
//   i8, i16         #byte, #word
//   saddr, saddrp   saddr (FFE20H-FFF1FH), a byte or a word
//   sfr, sfrp       sfr (FFF00H-FFFFFH), a byte or a word
//   abs16           !addr16
//   mHL, mHLi       [HL], [HL+byte]
//   mHLr            [HL+B], [HL+C]
//   mRP, mRPi       [DE] or [HL], [DE+byte] or [HL+byte]
//   mSPi            [SP+byte]
//   mBw, mCw, mBCw  word[B], word[C], word[BC]
//   e...            the same behind the ES: prefix (11H)
//
// Memory operands are made of sub-operands (base register, index register,
// displacement, address); instructions name them, e.g. (memHLi $hl, $disp),
// and each named sub-operand that is encoded has its own encoder method, so
// a fixup knows the byte its field occupies.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Encoded fields
//===----------------------------------------------------------------------===//

// #byte, and the byte displacement of [HL+byte], [DE+byte], [SP+byte].
def imm8 : Operand<i8> {
  let EncoderMethod = "getImm8OpValue";
  let OperandType = "OPERAND_IMMEDIATE";
}
def disp8 : Operand<i8> { let EncoderMethod = "getImm8OpValue"; }

// #word
def imm16 : Operand<i16> {
  let EncoderMethod = "getImm16OpValue";
  let OperandType = "OPERAND_IMMEDIATE";
}

// saddr (FFE20H-FFF1FH), saddrp (a word there): the low byte.
def saddr8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrOpValue";
}
def saddrp8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrpOpValue";
}

// sfr (FFF00H-FFFFFH), sfrp: the low byte of a fixed address.
def sfr8 : Operand<iPTR> {
  let PrintMethod = "printSfrOperand";
  let ParserMatchClass = RL78SfrAsmOperand;
  let EncoderMethod = "getSfrOpValue";
}
def sfrp8 : Operand<iPTR> {
  let PrintMethod = "printSfrOperand";
  let ParserMatchClass = RL78SfrpAsmOperand;
  let EncoderMethod = "getSfrOpValue";
}

// !addr16 (F0000H-FFFFFH), of a byte or of a word.
def addr16 : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16OpValue";
}
def addr16w : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16wOpValue";
}

// The 16-bit part of an ES:!addr16 (ES supplies bits 19-16).
def faddr16 : Operand<i16> { let EncoderMethod = "getFarAddr16OpValue"; }
def faddr16w : Operand<i16> { let EncoderMethod = "getFarAddr16wOpValue"; }
// The base address of word[B], word[C], word[BC], with and without ES:. It
// need not be even, for byte or word accesses: the index is added to it.
def waddr16 : Operand<i16> { let EncoderMethod = "getAddr16OpValue"; }
def ewaddr16 : Operand<i16> { let EncoderMethod = "getFarAddr16OpValue"; }

// Registers whose encoding is not their number. Each returns what the
// instructions using it place in their opcode.
class EncodedReg<RegisterClass RC, string Method> : RegisterOperand<RC> {
  let EncoderMethod = Method;
}
// [HL+B]/[HL+C]: 1 for C (most forms), 1 for B (XCH).
def idxC : EncodedReg<RL78BCReg, "getIsCOpValue">;
def idxB : EncodedReg<RL78BCReg, "getIsBOpValue">;
// [DE]/[HL]: 1 for HL (MOV, MOVW), 1 for DE (XCH); [DE+byte]/[HL+byte] in
// MOV and MOVW: 1 for DE, 2 for HL.
def rpHL : EncodedReg<RL78DEHL, "getIsHLOpValue">;
def rpDE : EncodedReg<RL78DEHL, "getIsDEOpValue">;
def rpDisp : EncodedReg<RL78DEHL, "getDEHLDispOpValue">;
// MOV r, saddr / !addr16 (r: X, A, C, B) and MOVW rp, saddrp / !addr16:
// the whole opcode byte.
def lowSaddr : EncodedReg<RL78Low, "getLowSaddrOpcode">;
def lowAbs : EncodedReg<RL78Low, "getLowAbsOpcode">;
def rpSaddrp : EncodedReg<RL78RPRegs, "getRpSaddrpOpcode">;
def rpAbs : EncodedReg<RL78RPRegs, "getRpAbsOpcode">;
def rpAbsNoAX : EncodedReg<RL78BCDEHL, "getRpAbsOpcode">;
// SHL r and SHLW rp.
def shlReg : EncodedReg<RL78ABCReg, "getShlRegOpValue">;
def shlwReg : EncodedReg<RL78AXBCRP, "getShlwRegOpValue">;

//===----------------------------------------------------------------------===//
// Memory operands
//===----------------------------------------------------------------------===//

class MemAsmOperand<string N> : AsmOperandClass { let Name = N; }
def MemHLiAsmOperand : MemAsmOperand<"MemHLi">;
def MemHLAsmOperand : MemAsmOperand<"MemHL"> {
  let SuperClasses = [MemHLiAsmOperand];
}
def MemHLrAsmOperand : MemAsmOperand<"MemHLr">;
def MemRPiAsmOperand : MemAsmOperand<"MemRPi">;
def MemRPAsmOperand : MemAsmOperand<"MemRP"> {
  let SuperClasses = [MemRPiAsmOperand];
}
def MemSPiAsmOperand : MemAsmOperand<"MemSPi">;
def MemBwAsmOperand : MemAsmOperand<"MemBw">;
def MemCwAsmOperand : MemAsmOperand<"MemCw">;
def MemBCwAsmOperand : MemAsmOperand<"MemBCw">;
def ESMemHLiAsmOperand : MemAsmOperand<"ESMemHLi">;
def ESMemHLAsmOperand : MemAsmOperand<"ESMemHL"> {
  let SuperClasses = [ESMemHLiAsmOperand];
}
def ESMemHLrAsmOperand : MemAsmOperand<"ESMemHLr">;
def ESMemRPiAsmOperand : MemAsmOperand<"ESMemRPi">;
def ESMemRPAsmOperand : MemAsmOperand<"ESMemRP"> {
  let SuperClasses = [ESMemRPiAsmOperand];
}
def ESMemBwAsmOperand : MemAsmOperand<"ESMemBw">;
def ESMemCwAsmOperand : MemAsmOperand<"ESMemCw">;
def ESMemBCwAsmOperand : MemAsmOperand<"ESMemBCw">;

class MemOperand<string Print, AsmOperandClass Asm, dag Ops>
    : Operand<iPTR> {
  let PrintMethod = Print;
  let ParserMatchClass = Asm;
  let MIOperandInfo = Ops;
}

// ES:!addr16
def esaddr16 : MemOperand<"printEsAddr16Operand", RL78EsAddrAsmOperand,
                          (ops RL78RegES, faddr16)>;
def esaddr16w : MemOperand<"printEsAddr16Operand", RL78EsAddrAsmOperand,
                           (ops RL78RegES, faddr16w)>;

def memHL : MemOperand<"printMemReg", MemHLAsmOperand, (ops RL78HL)>;
def memHLi : MemOperand<"printMemRegDisp", MemHLiAsmOperand, (ops RL78HL, disp8)>;
def memHLr : MemOperand<"printMemRegReg", MemHLrAsmOperand, (ops RL78HL, idxC)>;
def memHLrX : MemOperand<"printMemRegReg", MemHLrAsmOperand, (ops RL78HL, idxB)>;
def memRP : MemOperand<"printMemReg", MemRPAsmOperand, (ops rpHL)>;
def memRPX : MemOperand<"printMemReg", MemRPAsmOperand, (ops rpDE)>;
def memRPi : MemOperand<"printMemRegDisp", MemRPiAsmOperand, (ops rpDisp, disp8)>;
def memRPiX : MemOperand<"printMemRegDisp", MemRPiAsmOperand, (ops rpDE, disp8)>;
def memSPi : MemOperand<"printMemRegDisp", MemSPiAsmOperand, (ops RL78SPReg, disp8)>;
def memBw : MemOperand<"printMemWord", MemBwAsmOperand, (ops RL78BReg8, waddr16)>;
def memCw : MemOperand<"printMemWord", MemCwAsmOperand, (ops RL78CReg8, waddr16)>;
def memBCw : MemOperand<"printMemWord", MemBCwAsmOperand, (ops RL78BCRP, waddr16)>;

def esmemHL : MemOperand<"printESMemReg", ESMemHLAsmOperand, (ops RL78RegES, RL78HL)>;
def esmemHLi : MemOperand<"printESMemRegDisp", ESMemHLiAsmOperand,
                          (ops RL78RegES, RL78HL, disp8)>;
def esmemHLr : MemOperand<"printESMemRegReg", ESMemHLrAsmOperand,
                          (ops RL78RegES, RL78HL, idxC)>;
def esmemHLrX : MemOperand<"printESMemRegReg", ESMemHLrAsmOperand,
                           (ops RL78RegES, RL78HL, idxB)>;
def esmemRP : MemOperand<"printESMemReg", ESMemRPAsmOperand, (ops RL78RegES, rpHL)>;
def esmemRPX : MemOperand<"printESMemReg", ESMemRPAsmOperand, (ops RL78RegES, rpDE)>;
def esmemRPi : MemOperand<"printESMemRegDisp", ESMemRPiAsmOperand,
                          (ops RL78RegES, rpDisp, disp8)>;
def esmemRPiX : MemOperand<"printESMemRegDisp", ESMemRPiAsmOperand,
                           (ops RL78RegES, rpDE, disp8)>;
def esmemBw : MemOperand<"printESMemWord", ESMemBwAsmOperand,
                         (ops RL78RegES, RL78BReg8, ewaddr16)>;
def esmemCw : MemOperand<"printESMemWord", ESMemCwAsmOperand,
                         (ops RL78RegES, RL78CReg8, ewaddr16)>;
def esmemBCw : MemOperand<"printESMemWord", ESMemBCwAsmOperand,
                          (ops RL78RegES, RL78BCRP, ewaddr16)>;

//===----------------------------------------------------------------------===//
// 8-bit operations (manual 6.3): ADD, ADDC, SUB, SUBC, AND, OR, XOR, CMP
//===----------------------------------------------------------------------===//

// Op is the operation's row in the opcode map (ADD 0 ... XOR 7, CMP 4): its
// opcodes are Op<<4 | form. CMP writes only the flags; the others write A (or
// r, or saddr) and the flags. ADDC and SUBC also read CY.
multiclass RL78Alu8<string Mn, bits<4> Op, bit IsCmp> {
  defvar A = !if(IsCmp, (outs), (outs RL78AReg:$rd));
  defvar Dst = !if(IsCmp, "$rs", "$rd");

  let Constraints = !if(IsCmp, "", "$rs = $rd") in {
  // Mn A, #byte          Op C data
  def _A_i8 : RL78Inst<2, A, (ins RL78AReg:$rs, imm8:$imm),
                       Mn # " " # Dst # ", $imm"> {
    bits<8> imm;
    let Inst{7-0} = {Op, 1, 1, 0, 0};
    let Inst{15-8} = imm;
  }
  // Mn A, r              61 Op8+r     (r: X, C, B, E, D, L, H)
  def _A_r : RL78Inst<2, A, (ins RL78AReg:$rs, RL78XBCEDHLReg:$r),
                      Mn # " " # Dst # ", $r"> {
    bits<3> r;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 1, r};
  }
  let mayLoad = 1 in {
  // Mn A, saddr          Op B saddr
  def _A_saddr : RL78Inst<2, A, (ins RL78AReg:$rs, saddr8:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 1, 0, 1, 1};
    let Inst{15-8} = addr;
  }
  // Mn A, !addr16        Op F adrl adrh
  def _A_abs16 : RL78Inst<3, A, (ins RL78AReg:$rs, addr16:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Op, 1, 1, 1, 1};
    let Inst{23-8} = addr;
  }
  // Mn A, [HL]           Op D
  def _A_mHL : RL78Inst<1, A, (ins RL78AReg:$rs, (memHL $hl):$addr),
                        Mn # " " # Dst # ", $addr"> {
    let Inst{7-0} = {Op, 1, 1, 0, 1};
  }
  // Mn A, [HL+byte]      Op E adr
  def _A_mHLi : RL78Inst<2, A, (ins RL78AReg:$rs, (memHLi $hl, $disp):$addr),
                         Mn # " " # Dst # ", $addr"> {
    bits<8> disp;
    let Inst{7-0} = {Op, 1, 1, 1, 0};
    let Inst{15-8} = disp;
  }
  // Mn A, [HL+B]/[HL+C]  61 8+Op 0/2
  def _A_mHLr : RL78Inst<2, A, (ins RL78AReg:$rs, (memHLr $hl, $idx):$addr),
                         Mn # " " # Dst # ", $addr"> {
    bits<1> idx;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {1, Op{2-0}, 0, 0, idx, 0};
  }
  // Mn A, ES:!addr16     11 Op F adrl adrh
  def _A_eabs16 : RL78Inst<4, A, (ins RL78AReg:$rs, (esaddr16 $es, $adr):$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 1};
    let Inst{31-16} = adr;
  }
  // Mn A, ES:[HL]        11 Op D
  def _A_emHL : RL78Inst<2, A, (ins RL78AReg:$rs, (esmemHL $es, $hl):$addr),
                         Mn # " " # Dst # ", $addr"> {
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 0, 1};
  }
  // Mn A, ES:[HL+byte]   11 Op E adr
  def _A_emHLi : RL78Inst<3, A,
                          (ins RL78AReg:$rs, (esmemHLi $es, $hl, $disp):$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> disp;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 0};
    let Inst{23-16} = disp;
  }
  // Mn A, ES:[HL+B]/[HL+C]  11 61 8+Op 0/2
  def _A_emHLr : RL78Inst<3, A,
                          (ins RL78AReg:$rs, (esmemHLr $es, $hl, $idx):$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<1> idx;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = {1, Op{2-0}, 0, 0, idx, 0};
  }
  } // mayLoad
  } // Constraints

  // Mn r, A              61 Op0+r     (r: X, A, C, B, E, D, L, H)
  def _r_A : RL78Inst<2, !if(IsCmp, (outs), (outs RL78Reg:$rd)),
                      (ins RL78Reg:$r, RL78AReg:$a),
                      Mn # " " # !if(IsCmp, "$r", "$rd") # ", $a"> {
    bits<3> r;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 0, r};
    let Constraints = !if(IsCmp, "", "$r = $rd");
  }

  // Mn saddr, #byte      Op A saddr data
  def _saddr_i8 : RL78Inst<3, (outs), (ins saddr8:$addr, imm8:$imm),
                           Mn # " $addr, $imm"> {
    bits<8> addr;
    bits<8> imm;
    let Inst{7-0} = {Op, 1, 0, 1, 0};
    let Inst{15-8} = addr;
    let Inst{23-16} = imm;
    let mayLoad = 1;
    let mayStore = !not(IsCmp);
  }
}

let Defs = [CCreg] in {
defm ADD : RL78Alu8<"add", 0, 0>;
defm SUB : RL78Alu8<"sub", 2, 0>;
defm AND : RL78Alu8<"and", 5, 0>;
defm OR  : RL78Alu8<"or", 6, 0>;
defm XOR : RL78Alu8<"xor", 7, 0>;
defm CMP : RL78Alu8<"cmp", 4, 1>;
let Uses = [CCreg] in {
defm ADDC : RL78Alu8<"addc", 1, 0>;
defm SUBC : RL78Alu8<"subc", 3, 0>;
}

let mayLoad = 1 in {
// CMP !addr16, #byte     40 adrl adrh data
def CMP_abs16_i8 : RL78Inst<4, (outs), (ins addr16:$addr, imm8:$imm),
                            "cmp $addr, $imm"> {
  bits<16> addr;
  bits<8> imm;
  let Inst{7-0} = 0x40;
  let Inst{23-8} = addr;
  let Inst{31-24} = imm;
}
// CMP ES:!addr16, #byte  11 40 adrl adrh data
def CMP_eabs16_i8 : RL78Inst<5, (outs), (ins (esaddr16 $es, $adr):$addr, imm8:$imm),
                             "cmp $addr, $imm"> {
  bits<16> adr;
  bits<8> imm;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = 0x40;
  let Inst{31-16} = adr;
  let Inst{39-32} = imm;
}
}
} // Defs = [CCreg]

//===----------------------------------------------------------------------===//
// 16-bit operations (manual 6.4): ADDW, SUBW, CMPW
//===----------------------------------------------------------------------===//

// Op is the row in the opcode map: ADDW 0, SUBW 2, CMPW 4. Rp is the class of
// rp in Mn AX, rp (ADDW AX, AX exists, SUBW and CMPW AX, AX do not).
multiclass RL78Alu16<string Mn, bits<4> Op, bit IsCmp, RegisterClass Rp> {
  defvar AX = !if(IsCmp, (outs), (outs RL78AXRP:$rd));
  defvar Dst = !if(IsCmp, "$rs", "$rd");

  let Constraints = !if(IsCmp, "", "$rs = $rd") in {
  // Mn AX, #word         Op 4 datal datah
  def _AX_i16 : RL78Inst<3, AX, (ins RL78AXRP:$rs, imm16:$imm),
                         Mn # " " # Dst # ", $imm"> {
    bits<16> imm;
    let Inst{7-0} = {Op, 0, 1, 0, 0};
    let Inst{23-8} = imm;
  }
  // Mn AX, rp            Op 1+rp
  def _AX_rp : RL78Inst<1, AX, (ins RL78AXRP:$rs, Rp:$rp),
                        Mn # " " # Dst # ", $rp"> {
    bits<3> rp;
    let Inst{7-0} = {Op, 0, rp{2-1}, 1};
  }
  let mayLoad = 1 in {
  // Mn AX, saddrp        Op 6 saddr
  def _AX_saddrp : RL78Inst<2, AX, (ins RL78AXRP:$rs, saddrp8:$addr),
                            Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 0, 1, 1, 0};
    let Inst{15-8} = addr;
  }
  // Mn AX, !addr16       Op 2 adrl adrh
  def _AX_abs16 : RL78Inst<3, AX, (ins RL78AXRP:$rs, addr16w:$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Op, 0, 0, 1, 0};
    let Inst{23-8} = addr;
  }
  // Mn AX, [HL+byte]     61 Op9 adr
  def _AX_mHLi : RL78Inst<3, AX, (ins RL78AXRP:$rs, (memHLi $hl, $disp):$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> disp;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 1, 0, 0, 1};
    let Inst{23-16} = disp;
  }
  // Mn AX, ES:!addr16    11 Op2 adrl adrh
  def _AX_eabs16 : RL78Inst<4, AX, (ins RL78AXRP:$rs, (esaddr16w $es, $adr):$addr),
                            Mn # " " # Dst # ", $addr"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 0, 0, 1, 0};
    let Inst{31-16} = adr;
  }
  // Mn AX, ES:[HL+byte]  11 61 Op9 adr
  def _AX_emHLi : RL78Inst<4, AX,
                           (ins RL78AXRP:$rs, (esmemHLi $es, $hl, $disp):$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<8> disp;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = {Op, 1, 0, 0, 1};
    let Inst{31-24} = disp;
  }
  } // mayLoad
  }
}

let Defs = [CCreg] in {
defm ADDW : RL78Alu16<"addw", 0, 0, RL78RPRegs>;
defm SUBW : RL78Alu16<"subw", 2, 0, RL78BCDEHL>;
defm CMPW : RL78Alu16<"cmpw", 4, 1, RL78BCDEHL>;
}

// ADDW SP, #byte         10 data
// SUBW SP, #byte         20 data
// The flags are unchanged.
let Constraints = "$ss = $sd" in {
def ADDW_SP_i8 : RL78Inst<2, (outs RL78SPReg:$sd), (ins RL78SPReg:$ss, imm8:$imm),
                          "addw $sd, $imm"> {
  bits<8> imm;
  let Inst{7-0} = 0x10;
  let Inst{15-8} = imm;
}
def SUBW_SP_i8 : RL78Inst<2, (outs RL78SPReg:$sd), (ins RL78SPReg:$ss, imm8:$imm),
                          "subw $sd, $imm"> {
  bits<8> imm;
  let Inst{7-0} = 0x20;
  let Inst{15-8} = imm;
}
}

//===----------------------------------------------------------------------===//
// Increment and decrement (manual 6.6): INC, DEC, INCW, DECW
//===----------------------------------------------------------------------===//

// INC/DEC change Z and AC, not CY; INCW/DECW change no flag.
// Op8 is the row of the register forms (INC 8, DEC 9), Mem the row of the
// saddr and !addr16 forms (INC A, DEC B), Mem2 the second byte of the
// [HL+byte] form (61 Mem2). W: the word forms.
multiclass RL78IncDec<string Mn, bits<4> Op8, bits<4> Mem, bits<8> Mem2,
                      bit W, RegisterClass R, Operand Saddr, Operand Abs,
                      Operand ESAbs> {
  // Mn r                 Op8 r   (INCW rp: Mem 1+rp)
  def !if(W, "_rp", "_r") : RL78Inst<1, (outs R:$rd), (ins R:$rs),
                                     Mn # " $rd"> {
    bits<3> rs;
    let Inst{7-0} = !if(W, {Mem, 0, rs{2-1}, 1}, {Op8, 0, rs});
    let Constraints = "$rs = $rd";
  }
  let mayLoad = 1, mayStore = 1 in {
  // Mn saddr             Mem 4 saddr   (INCW saddrp: Mem 6)
  def !if(W, "_saddrp", "_saddr") : RL78Inst<2, (outs), (ins Saddr:$addr),
                                             Mn # " $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Mem, 0, 1, W, 0};
    let Inst{15-8} = addr;
  }
  // Mn !addr16           Mem 0 adrl adrh   (INCW: Mem 2)
  def _abs16 : RL78Inst<3, (outs), (ins Abs:$addr), Mn # " $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Mem, 0, 0, W, 0};
    let Inst{23-8} = addr;
  }
  // Mn [HL+byte]         61 Mem2 adr
  def _mHLi : RL78Inst<3, (outs), (ins (memHLi $hl, $disp):$addr), Mn # " $addr"> {
    bits<8> disp;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = Mem2;
    let Inst{23-16} = disp;
  }
  // Mn ES:!addr16        11 Mem 0 adrl adrh
  def _eabs16 : RL78Inst<4, (outs), (ins (ESAbs $es, $adr):$addr), Mn # " $addr"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Mem, 0, 0, W, 0};
    let Inst{31-16} = adr;
  }
  // Mn ES:[HL+byte]      11 61 Mem2 adr
  def _emHLi : RL78Inst<4, (outs), (ins (esmemHLi $es, $hl, $disp):$addr),
                        Mn # " $addr"> {
    bits<8> disp;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = Mem2;
    let Inst{31-24} = disp;
  }
  }
}

let Defs = [CCreg] in {
defm INC : RL78IncDec<"inc", 8, 0xA, 0x59, 0, RL78Reg, saddr8, addr16, esaddr16>;
defm DEC : RL78IncDec<"dec", 9, 0xB, 0x69, 0, RL78Reg, saddr8, addr16, esaddr16>;
}
defm INCW : RL78IncDec<"incw", 0, 0xA, 0x79, 1, RL78RPRegs, saddrp8, addr16w,
                       esaddr16w>;
defm DECW : RL78IncDec<"decw", 0, 0xB, 0x89, 1, RL78RPRegs, saddrp8, addr16w,
                       esaddr16w>;

//===----------------------------------------------------------------------===//
// CMP0, CLRB, ONEB (manual 6.1, 6.3): X, A, C, B, saddr, !addr16
//===----------------------------------------------------------------------===//

// Op is the row: ONEB E, CMP0 D, CLRB F. CMP0 reads its operand and writes
// the flags; CLRB and ONEB write it.
multiclass RL78ByteOp<string Mn, bits<4> Op, bit IsCmp> {
  // Mn r                 Op r     (r: X, A, C, B)
  def _r : RL78Inst<1, !if(IsCmp, (outs), (outs RL78Low:$r)),
                    !if(IsCmp, (ins RL78Low:$r), (ins)), Mn # " $r"> {
    bits<3> r;
    let Inst{7-0} = {Op, 0, r};
  }
  let mayLoad = IsCmp, mayStore = !not(IsCmp) in {
  // Mn saddr             Op 4 saddr
  def _saddr : RL78Inst<2, (outs), (ins saddr8:$addr), Mn # " $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 0, 1, 0, 0};
    let Inst{15-8} = addr;
  }
  // Mn !addr16           Op 5 adrl adrh
  def _abs16 : RL78Inst<3, (outs), (ins addr16:$addr), Mn # " $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Op, 0, 1, 0, 1};
    let Inst{23-8} = addr;
  }
  // Mn ES:!addr16        11 Op 5 adrl adrh
  def _eabs16 : RL78Inst<4, (outs), (ins (esaddr16 $es, $adr):$addr), Mn # " $addr"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 0, 1, 0, 1};
    let Inst{31-16} = adr;
  }
  }
}

let Defs = [CCreg] in
defm CMP0 : RL78ByteOp<"cmp0", 0xD, 1>;
let isReMaterializable = 1 in {
defm CLRB : RL78ByteOp<"clrb", 0xF, 0>;
defm ONEB : RL78ByteOp<"oneb", 0xE, 0>;
}

// CLRW AX/BC             F6/F7
// ONEW AX/BC             E6/E7
let isReMaterializable = 1 in {
def CLRW_rp : RL78Inst<1, (outs RL78AXBCRP:$rp), (ins), "clrw $rp"> {
  bits<3> rp;
  let Inst{7-0} = {1, 1, 1, 1, 0, 1, 1, rp{1}};
}
def ONEW_rp : RL78Inst<1, (outs RL78AXBCRP:$rp), (ins), "onew $rp"> {
  bits<3> rp;
  let Inst{7-0} = {1, 1, 1, 0, 0, 1, 1, rp{1}};
}
}

// CMPS X, [HL+byte]      61 DE adr
// CMPS X, ES:[HL+byte]   11 61 DE adr
// Z is set when the operands are equal or either is zero.
let Defs = [CCreg], mayLoad = 1 in {
def CMPS_X_mHLi : RL78Inst<3, (outs), (ins RL78XReg:$x, (memHLi $hl, $disp):$addr),
                           "cmps $x, $addr"> {
  bits<8> disp;
  let Inst{15-0} = 0xDE61;
  let Inst{23-16} = disp;
}
def CMPS_X_emHLi : RL78Inst<4, (outs),
                            (ins RL78XReg:$x, (esmemHLi $es, $hl, $disp):$addr),
                            "cmps $x, $addr"> {
  bits<8> disp;
  let Inst{23-0} = 0xDE6111;
  let Inst{31-24} = disp;
}
}

// MOVS [HL+byte], X      61 CE adr
// MOVS ES:[HL+byte], X   11 61 CE adr
// Also sets Z (X or A zero) and CY (X zero), so it reads A.
let Defs = [CCreg], Uses = [R1], mayStore = 1 in {
def MOVS_mHLi_X : RL78Inst<3, (outs), (ins (memHLi $hl, $disp):$addr, RL78XReg:$x),
                           "movs $addr, $x"> {
  bits<8> disp;
  let Inst{15-0} = 0xCE61;
  let Inst{23-16} = disp;
}
def MOVS_emHLi_X : RL78Inst<4, (outs),
                            (ins (esmemHLi $es, $hl, $disp):$addr, RL78XReg:$x),
                            "movs $addr, $x"> {
  bits<8> disp;
  let Inst{23-0} = 0xCE6111;
  let Inst{31-24} = disp;
}
}

//===----------------------------------------------------------------------===//
// Shifts and rotates (manual 6.7, 6.8)
//===----------------------------------------------------------------------===//

// 31 cnt<<4|Low; the count is 1-7 (bytes) or 1-15 (words). All write CY.
class RL78Shift<string Mn, RegisterOperand R, Operand Cnt, bits<4> Low>
    : RL78Inst<2, (outs R:$rd), (ins R:$rs, Cnt:$cnt), Mn # " $rd, $cnt"> {
  bits<4> cnt;
  let Inst{7-0} = 0x31;
  let Inst{15-8} = {cnt, Low};
  let Constraints = "$rs = $rd";
}

let Defs = [CCreg] in {
def SHR_A_n : RL78Shift<"shr", RegisterOperand<RL78AReg>, shift8imm, 0xA>;
def SHRW_AX_n : RL78Shift<"shrw", RegisterOperand<RL78AXRP>, shift16imm, 0xE>;
def SAR_A_n : RL78Shift<"sar", RegisterOperand<RL78AReg>, shift8imm, 0xB>;
def SARW_AX_n : RL78Shift<"sarw", RegisterOperand<RL78AXRP>, shift16imm, 0xF>;
// SHL A/B/C, cnt         31 cnt<<4|9/8/7
def SHL_r_n : RL78Inst<2, (outs shlReg:$rd), (ins shlReg:$rs, shift8imm:$cnt),
                       "shl $rd, $cnt"> {
  bits<4> cnt;
  bits<4> rs;
  let Inst{7-0} = 0x31;
  let Inst{15-8} = {cnt, rs};
  let Constraints = "$rs = $rd";
}
// SHLW AX/BC, cnt        31 cnt<<4|D/C
def SHLW_rp_n : RL78Inst<2, (outs shlwReg:$rd), (ins shlwReg:$rs, shift16imm:$cnt),
                         "shlw $rd, $cnt"> {
  bits<4> cnt;
  bits<4> rs;
  let Inst{7-0} = 0x31;
  let Inst{15-8} = {cnt, rs};
  let Constraints = "$rs = $rd";
}
}

// Rotate A (AX, BC) by one bit: 61 Op.
class RL78Rotate<string Mn, RegisterClass R, bits<8> Op>
    : RL78Inst<2, (outs R:$rd), (ins R:$rs), Mn # " $rd, 1"> {
  let Inst{7-0} = 0x61;
  let Inst{15-8} = Op;
  let Constraints = "$rs = $rd";
}
let Defs = [CCreg] in {
def ROR_A_1 : RL78Rotate<"ror", RL78AReg, 0xDB>;
def ROL_A_1 : RL78Rotate<"rol", RL78AReg, 0xEB>;
let Uses = [CCreg] in {
def RORC_A_1 : RL78Rotate<"rorc", RL78AReg, 0xFB>;
def ROLC_A_1 : RL78Rotate<"rolc", RL78AReg, 0xDC>;
// ROLWC AX/BC, 1         61 EE/FE
def ROLWC_rp_1 : RL78Inst<2, (outs RL78AXBCRP:$rd), (ins RL78AXBCRP:$rs),
                          "rolwc $rd, 1"> {
  bits<3> rs;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, 1, rs{1}, 1, 1, 1, 0};
  let Constraints = "$rs = $rd";
}
}
}

//===----------------------------------------------------------------------===//
// 8-bit data transfer (manual 6.1): MOV, XCH
//===----------------------------------------------------------------------===//

let isMoveImm = 1, isReMaterializable = 1 in
// MOV r, #byte           5r data
def MOV_r_i8 : RL78Inst<2, (outs RL78Reg:$r), (ins imm8:$imm), "mov $r, $imm"> {
  bits<3> r;
  bits<8> imm;
  let Inst{7-0} = {0, 1, 0, 1, 0, r};
  let Inst{15-8} = imm;
}

// MOV A, r               6r   (r: X, C, B, E, D, L, H)
// MOV r, A               7r
let isMoveReg = 1 in {
def MOV_A_r : RL78Inst<1, (outs RL78AReg:$a), (ins RL78XBCEDHLReg:$r), "mov $a, $r"> {
  bits<3> r;
  let Inst{7-0} = {0, 1, 1, 0, 0, r};
}
def MOV_r_A : RL78Inst<1, (outs RL78XBCEDHLReg:$r), (ins RL78AReg:$a), "mov $r, $a"> {
  bits<3> r;
  let Inst{7-0} = {0, 1, 1, 1, 0, r};
}
}

// Shapes of the moves through A and AX; each definition gives its bytes.
class RL78LoadA<int size, dag Ops>
    : RL78Inst<size, (outs RL78AReg:$a), Ops, "mov $a, $addr"> {
  let mayLoad = 1;
}
class RL78StoreA<int size, dag Ops>
    : RL78Inst<size, (outs), !con(Ops, (ins RL78AReg:$a)), "mov $addr, $a"> {
  let mayStore = 1;
}
class RL78StoreI8<int size, dag Ops>
    : RL78Inst<size, (outs), !con(Ops, (ins imm8:$imm)), "mov $addr, $imm"> {
  bits<8> imm;
  let mayStore = 1;
}
class RL78LoadAX<int size, dag Ops>
    : RL78Inst<size, (outs RL78AXRP:$ax), Ops, "movw $ax, $addr"> {
  let mayLoad = 1;
}
class RL78StoreAX<int size, dag Ops>
    : RL78Inst<size, (outs), !con(Ops, (ins RL78AXRP:$ax)), "movw $addr, $ax"> {
  let mayStore = 1;
}

// MOV saddr, #byte       CD saddr data
def MOV_saddr_i8 : RL78StoreI8<3, (ins saddr8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0xCD;
  let Inst{15-8} = addr;
  let Inst{23-16} = imm;
}
// MOV sfr, #byte         CE sfr data
def MOV_sfr_i8 : RL78StoreI8<3, (ins sfr8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0xCE;
  let Inst{15-8} = addr;
  let Inst{23-16} = imm;
  let hasSideEffects = 1;
}
// MOV !addr16, #byte     CF adrl adrh data
def MOV_abs16_i8 : RL78StoreI8<4, (ins addr16:$addr)> {
  bits<16> addr;
  let Inst{7-0} = 0xCF;
  let Inst{23-8} = addr;
  let Inst{31-24} = imm;
}
// MOV ES:!addr16, #byte  11 CF adrl adrh data
def MOV_eabs16_i8 : RL78StoreI8<5, (ins (esaddr16 $es, $adr):$addr)> {
  bits<16> adr;
  let Inst{15-0} = 0xCF11;
  let Inst{31-16} = adr;
  let Inst{39-32} = imm;
}

// MOV r, saddr           8D/D8/F8/E8 saddr   (r: A, X, C, B)
def MOV_r_saddr : RL78Inst<2, (outs lowSaddr:$r), (ins saddr8:$addr), "mov $r, $addr"> {
  bits<8> r;
  bits<8> addr;
  let Inst{7-0} = r;
  let Inst{15-8} = addr;
  let mayLoad = 1;
}
// MOV saddr, A           9D saddr
def MOV_saddr_A : RL78StoreA<2, (ins saddr8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0x9D;
  let Inst{15-8} = addr;
}
// MOV A, sfr             8E sfr
// MOV sfr, A             9E sfr
let hasSideEffects = 1 in {
def MOV_A_sfr : RL78LoadA<2, (ins sfr8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0x8E;
  let Inst{15-8} = addr;
}
def MOV_sfr_A : RL78StoreA<2, (ins sfr8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0x9E;
  let Inst{15-8} = addr;
}
}
// MOV r, !addr16         8F/D9/F9/E9 adrl adrh   (r: A, X, C, B)
def MOV_r_abs16 : RL78Inst<3, (outs lowAbs:$r), (ins addr16:$addr), "mov $r, $addr"> {
  bits<8> r;
  bits<16> addr;
  let Inst{7-0} = r;
  let Inst{23-8} = addr;
  let mayLoad = 1;
}
// MOV r, ES:!addr16      11 8F/D9/F9/E9 adrl adrh
def MOV_r_eabs16 : RL78Inst<4, (outs lowAbs:$r), (ins (esaddr16 $es, $adr):$addr),
                            "mov $r, $addr"> {
  bits<8> r;
  bits<16> adr;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = r;
  let Inst{31-16} = adr;
  let mayLoad = 1;
}
// MOV !addr16, A         9F adrl adrh
def MOV_abs16_A : RL78StoreA<3, (ins addr16:$addr)> {
  bits<16> addr;
  let Inst{7-0} = 0x9F;
  let Inst{23-8} = addr;
}
// MOV ES:!addr16, A      11 9F adrl adrh
def MOV_eabs16_A : RL78StoreA<4, (ins (esaddr16 $es, $adr):$addr)> {
  bits<16> adr;
  let Inst{15-0} = 0x9F11;
  let Inst{31-16} = adr;
}

// The registers PSW, ES and CS are also the sfrs FFFFAH, FFFFDH, FFFFCH:
// MOV A, PSW is MOV A, sfr with sfr = FAH.
class RL78MovSpecial<dag outs, dag ins, string asm, bits<16> Enc>
    : RL78Inst<2, outs, ins, asm> {
  let Inst{15-0} = Enc;
}
let hasSideEffects = 1 in {
// MOV PSW, #byte         CE FA data
def MOV_PSW_i8 : RL78Inst<3, (outs RL78RegPSW:$psw), (ins imm8:$imm), "mov $psw, $imm"> {
  bits<8> imm;
  let Inst{15-0} = 0xFACE;
  let Inst{23-16} = imm;
}
// MOV A, PSW             8E FA
// MOV PSW, A             9E FA
def MOV_A_PSW : RL78MovSpecial<(outs RL78AReg:$a), (ins RL78RegPSW:$psw),
                               "mov $a, $psw", 0xFA8E>;
def MOV_PSW_A : RL78MovSpecial<(outs RL78RegPSW:$psw), (ins RL78AReg:$a),
                               "mov $psw, $a", 0xFA9E>;
// MOV CS, #byte          CE FC data
def MOV_CS_i8 : RL78Inst<3, (outs RL78RegCS:$cs), (ins imm8:$imm), "mov $cs, $imm"> {
  bits<8> imm;
  let Inst{15-0} = 0xFCCE;
  let Inst{23-16} = imm;
}
// MOV A, CS              8E FC
// MOV CS, A              9E FC
def MOV_A_CS : RL78MovSpecial<(outs RL78AReg:$a), (ins RL78RegCS:$cs),
                              "mov $a, $cs", 0xFC8E>;
def MOV_CS_A : RL78MovSpecial<(outs RL78RegCS:$cs), (ins RL78AReg:$a),
                              "mov $cs, $a", 0xFC9E>;
}
// MOV ES, #byte          41 data
def MOV_ES_i8 : RL78Inst<2, (outs RL78RegES:$es), (ins imm8:$imm), "mov $es, $imm"> {
  bits<8> imm;
  let Inst{7-0} = 0x41;
  let Inst{15-8} = imm;
}
// MOV ES, saddr          61 B8 saddr
def MOV_ES_saddr : RL78Inst<3, (outs RL78RegES:$es), (ins saddr8:$addr), "mov $es, $addr"> {
  bits<8> addr;
  let Inst{15-0} = 0xB861;
  let Inst{23-16} = addr;
  let mayLoad = 1;
}
// MOV A, ES              8E FD
// MOV ES, A              9E FD
def MOV_A_ES : RL78MovSpecial<(outs RL78AReg:$a), (ins RL78RegES:$es),
                              "mov $a, $es", 0xFD8E>;
def MOV_ES_A : RL78MovSpecial<(outs RL78RegES:$es), (ins RL78AReg:$a),
                              "mov $es, $a", 0xFD9E>;

// [DE], [HL]: the opcodes for HL are those for DE + 2. [DE+byte], [HL+byte]
// likewise; rpDisp encodes DE as 1, HL as 2, rpHL HL as 1.

// MOV A, [DE]/[HL]       89/8B
def MOV_A_mRP : RL78LoadA<1, (ins (memRP $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = {1, 0, 0, 0, 1, 0, rp, 1};
}
// MOV [DE]/[HL], A       99/9B
def MOV_mRP_A : RL78StoreA<1, (ins (memRP $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = {1, 0, 0, 1, 1, 0, rp, 1};
}
// MOV [DE+byte]/[HL+byte], #byte   CA/CC adr data
def MOV_mRPi_i8 : RL78StoreI8<3, (ins (memRPi $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = {1, 1, 0, 0, 1, rp, 0};
  let Inst{15-8} = disp;
  let Inst{23-16} = imm;
}
// MOV A, [DE+byte]/[HL+byte]       8A/8C adr
def MOV_A_mRPi : RL78LoadA<2, (ins (memRPi $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = {1, 0, 0, 0, 1, rp, 0};
  let Inst{15-8} = disp;
}
// MOV [DE+byte]/[HL+byte], A       9A/9C adr
def MOV_mRPi_A : RL78StoreA<2, (ins (memRPi $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = {1, 0, 0, 1, 1, rp, 0};
  let Inst{15-8} = disp;
}
// MOV A, [HL+B]/[HL+C]   61 C9/E9
def MOV_A_mHLr : RL78LoadA<2, (ins (memHLr $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, idx, 0, 1, 0, 0, 1};
}
// MOV [HL+B]/[HL+C], A   61 D9/F9
def MOV_mHLr_A : RL78StoreA<2, (ins (memHLr $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, idx, 1, 1, 0, 0, 1};
}

// word[B], word[C], word[BC]: Ld, St, Imm are the opcodes of MOV A, w;
// MOV w, A; MOV w, #byte.
multiclass RL78MovWord<Operand Mem, Operand ESMem, bits<8> Ld, bits<8> St,
                       bits<8> Imm> {
  def "MOV_A_" # NAME : RL78LoadA<3, (ins (Mem $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = Ld;
    let Inst{23-8} = wa;
  }
  def "MOV_" # NAME # "_A" : RL78StoreA<3, (ins (Mem $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = St;
    let Inst{23-8} = wa;
  }
  def "MOV_" # NAME # "_i8" : RL78StoreI8<4, (ins (Mem $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = Imm;
    let Inst{23-8} = wa;
    let Inst{31-24} = imm;
  }
  def "MOV_A_e" # NAME : RL78LoadA<4, (ins (ESMem $es, $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = Ld;
    let Inst{31-16} = wa;
  }
  def "MOV_e" # NAME # "_A" : RL78StoreA<4, (ins (ESMem $es, $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = St;
    let Inst{31-16} = wa;
  }
  def "MOV_e" # NAME # "_i8" : RL78StoreI8<5, (ins (ESMem $es, $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = Imm;
    let Inst{31-16} = wa;
    let Inst{39-32} = imm;
  }
}
// MOV A, word[B] 09, MOV word[B], A 18, MOV word[B], #byte 19; word[C] 29,
// 28, 38; word[BC] 49, 48, 39.
defm mBw : RL78MovWord<memBw, esmemBw, 0x09, 0x18, 0x19>;
defm mCw : RL78MovWord<memCw, esmemCw, 0x29, 0x28, 0x38>;
defm mBCw : RL78MovWord<memBCw, esmemBCw, 0x49, 0x48, 0x39>;

// MOV [SP+byte], #byte   C8 adr data
def MOV_mSPi_i8 : RL78StoreI8<3, (ins (memSPi $sp, $disp):$addr)> {
  bits<8> disp;
  let Inst{7-0} = 0xC8;
  let Inst{15-8} = disp;
  let Inst{23-16} = imm;
}
// MOV A, [SP+byte]       88 adr
def MOV_A_mSPi : RL78LoadA<2, (ins (memSPi $sp, $disp):$addr)> {
  bits<8> disp;
  let Inst{7-0} = 0x88;
  let Inst{15-8} = disp;
}
// MOV [SP+byte], A       98 adr
def MOV_mSPi_A : RL78StoreA<2, (ins (memSPi $sp, $disp):$addr)> {
  bits<8> disp;
  let Inst{7-0} = 0x98;
  let Inst{15-8} = disp;
}

// The ES: forms of the [DE], [HL] moves.
// MOV A, ES:[DE]/[HL]    11 89/8B
def MOV_A_emRP : RL78LoadA<2, (ins (esmemRP $es, $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 0, 0, 1, 0, rp, 1};
}
// MOV ES:[DE]/[HL], A    11 99/9B
def MOV_emRP_A : RL78StoreA<2, (ins (esmemRP $es, $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 0, 1, 1, 0, rp, 1};
}
// MOV ES:[DE+byte]/[HL+byte], #byte   11 CA/CC adr data
def MOV_emRPi_i8 : RL78StoreI8<4, (ins (esmemRPi $es, $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 1, 0, 0, 1, rp, 0};
  let Inst{23-16} = disp;
  let Inst{31-24} = imm;
}
// MOV A, ES:[DE+byte]/[HL+byte]       11 8A/8C adr
def MOV_A_emRPi : RL78LoadA<3, (ins (esmemRPi $es, $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 0, 0, 1, rp, 0};
  let Inst{23-16} = disp;
}
// MOV ES:[DE+byte]/[HL+byte], A       11 9A/9C adr
def MOV_emRPi_A : RL78StoreA<3, (ins (esmemRPi $es, $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 0, 1, 1, rp, 0};
  let Inst{23-16} = disp;
}
// MOV A, ES:[HL+B]/[HL+C]   11 61 C9/E9
def MOV_A_emHLr : RL78LoadA<3, (ins (esmemHLr $es, $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{15-0} = 0x6111;
  let Inst{23-16} = {1, 1, idx, 0, 1, 0, 0, 1};
}
// MOV ES:[HL+B]/[HL+C], A   11 61 D9/F9
def MOV_emHLr_A : RL78StoreA<3, (ins (esmemHLr $es, $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{15-0} = 0x6111;
  let Inst{23-16} = {1, 1, idx, 1, 1, 0, 0, 1};
}

// XCH A, X               08
// XCH A, r               61 8r    (r: C, B, E, D, L, H)
let Constraints = "$as = $ad, $rs = $rd" in {
def XCH_A_X : RL78Inst<1, (outs RL78AReg:$ad, RL78XReg:$rd),
                       (ins RL78AReg:$as, RL78XReg:$rs), "xch $ad, $rd"> {
  let Inst{7-0} = 0x08;
}
def XCH_A_r : RL78Inst<2, (outs RL78AReg:$ad, RL78BCEDHLReg:$rd),
                       (ins RL78AReg:$as, RL78BCEDHLReg:$rs), "xch $ad, $rd"> {
  bits<3> rs;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 0, 0, 0, 1, rs};
}
}
// XCH A, memory          61 Op ... (and 11 61 Op ... for ES:)
class RL78XchA<int size, dag Ops>
    : RL78Inst<size, (outs RL78AReg:$ad), !con((ins RL78AReg:$as), Ops),
               "xch $ad, $addr"> {
  let Constraints = "$as = $ad";
  let mayLoad = 1;
  let mayStore = 1;
}
// XCH A, saddr           61 A8 saddr
def XCH_A_saddr : RL78XchA<3, (ins saddr8:$addr)> {
  bits<8> addr;
  let Inst{15-0} = 0xA861;
  let Inst{23-16} = addr;
}
// XCH A, sfr             61 AB sfr
def XCH_A_sfr : RL78XchA<3, (ins sfr8:$addr)> {
  bits<8> addr;
  let Inst{15-0} = 0xAB61;
  let Inst{23-16} = addr;
  let hasSideEffects = 1;
}
// XCH A, !addr16         61 AA adrl adrh
def XCH_A_abs16 : RL78XchA<4, (ins addr16:$addr)> {
  bits<16> addr;
  let Inst{15-0} = 0xAA61;
  let Inst{31-16} = addr;
}
// XCH A, ES:!addr16      11 61 AA adrl adrh
def XCH_A_eabs16 : RL78XchA<5, (ins (esaddr16 $es, $adr):$addr)> {
  bits<16> adr;
  let Inst{23-0} = 0xAA6111;
  let Inst{39-24} = adr;
}
// XCH A, [DE]/[HL]       61 AE/AC   (rpDE: 1 for DE)
def XCH_A_mRP : RL78XchA<2, (ins (memRPX $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 0, 1, 0, 1, 1, rp, 0};
}
// XCH A, [DE+byte]/[HL+byte]  61 AF/AD adr
def XCH_A_mRPi : RL78XchA<3, (ins (memRPiX $rp, $disp):$addr)> {
  bits<1> rp;
  bits<8> disp;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 0, 1, 0, 1, 1, rp, 1};
  let Inst{23-16} = disp;
}
// XCH A, [HL+B]/[HL+C]   61 B9/A9   (idxB: 1 for B)
def XCH_A_mHLr : RL78XchA<2, (ins (memHLrX $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 0, 1, idx, 1, 0, 0, 1};
}
// XCH A, ES:[DE]/[HL]    11 61 AE/AC
def XCH_A_emRP : RL78XchA<3, (ins (esmemRPX $es, $rp):$addr)> {
  bits<1> rp;
  let Inst{15-0} = 0x6111;
  let Inst{23-16} = {1, 0, 1, 0, 1, 1, rp, 0};
}
// XCH A, ES:[DE+byte]/[HL+byte]  11 61 AF/AD adr
def XCH_A_emRPi : RL78XchA<4, (ins (esmemRPiX $es, $rp, $disp):$addr)> {
  bits<1> rp;
  bits<8> disp;
  let Inst{15-0} = 0x6111;
  let Inst{23-16} = {1, 0, 1, 0, 1, 1, rp, 1};
  let Inst{31-24} = disp;
}
// XCH A, ES:[HL+B]/[HL+C]   11 61 B9/A9
def XCH_A_emHLr : RL78XchA<3, (ins (esmemHLrX $es, $hl, $idx):$addr)> {
  bits<1> idx;
  let Inst{15-0} = 0x6111;
  let Inst{23-16} = {1, 0, 1, idx, 1, 0, 0, 1};
}

//===----------------------------------------------------------------------===//
// 16-bit data transfer (manual 6.2): MOVW, XCHW
//===----------------------------------------------------------------------===//

let isMoveImm = 1, isReMaterializable = 1 in
// MOVW rp, #word         30+rp datal datah
def MOVW_rp_i16 : RL78Inst<3, (outs RL78RPRegs:$rp), (ins imm16:$imm), "movw $rp, $imm"> {
  bits<3> rp;
  bits<16> imm;
  let Inst{7-0} = {0, 0, 1, 1, 0, rp};
  let Inst{23-8} = imm;
}
// MOVW saddrp, #word     C9 saddr datal datah
def MOVW_saddrp_i16 : RL78Inst<4, (outs), (ins saddrp8:$addr, imm16:$imm),
                               "movw $addr, $imm"> {
  bits<8> addr;
  bits<16> imm;
  let Inst{7-0} = 0xC9;
  let Inst{15-8} = addr;
  let Inst{31-16} = imm;
  let mayStore = 1;
}
// MOVW sfrp, #word       CB sfr datal datah
def MOVW_sfrp_i16 : RL78Inst<4, (outs), (ins sfrp8:$addr, imm16:$imm),
                             "movw $addr, $imm"> {
  bits<8> addr;
  bits<16> imm;
  let Inst{7-0} = 0xCB;
  let Inst{15-8} = addr;
  let Inst{31-16} = imm;
  let mayStore = 1;
  let hasSideEffects = 1;
}
// MOVW rp, saddrp        AD/DA/EA/FA saddr
def MOVW_rp_saddrp : RL78Inst<2, (outs rpSaddrp:$rp), (ins saddrp8:$addr),
                              "movw $rp, $addr"> {
  bits<8> rp;
  bits<8> addr;
  let Inst{7-0} = rp;
  let Inst{15-8} = addr;
  let mayLoad = 1;
}
// MOVW saddrp, AX        BD saddr
def MOVW_saddrp_AX : RL78StoreAX<2, (ins saddrp8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0xBD;
  let Inst{15-8} = addr;
}
// MOVW AX, sfrp          AE sfr
// MOVW sfrp, AX          BE sfr
let hasSideEffects = 1 in {
def MOVW_AX_sfrp : RL78LoadAX<2, (ins sfrp8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0xAE;
  let Inst{15-8} = addr;
}
def MOVW_sfrp_AX : RL78StoreAX<2, (ins sfrp8:$addr)> {
  bits<8> addr;
  let Inst{7-0} = 0xBE;
  let Inst{15-8} = addr;
}
}
// MOVW AX, rp            11+rp   (rp: BC, DE, HL)
// MOVW rp, AX            10+rp
let isMoveReg = 1 in {
def MOVW_AX_rp : RL78Inst<1, (outs RL78AXRP:$ax), (ins RL78BCDEHL:$rp), "movw $ax, $rp"> {
  bits<3> rp;
  let Inst{7-0} = {0, 0, 0, 1, 0, rp{2-1}, 1};
}
def MOVW_rp_AX : RL78Inst<1, (outs RL78BCDEHL:$rp), (ins RL78AXRP:$ax), "movw $rp, $ax"> {
  bits<3> rp;
  let Inst{7-0} = {0, 0, 0, 1, 0, rp{2-1}, 0};
}
}
// MOVW rp, !addr16       AF/DB/EB/FB adrl adrh
def MOVW_rp_abs16 : RL78Inst<3, (outs rpAbs:$rp), (ins addr16w:$addr),
                             "movw $rp, $addr"> {
  bits<8> rp;
  bits<16> addr;
  let Inst{7-0} = rp;
  let Inst{23-8} = addr;
  let mayLoad = 1;
}
// MOVW rp, ES:!addr16    11 AF/DB/EB/FB adrl adrh
def MOVW_rp_eabs16 : RL78Inst<4, (outs rpAbs:$rp), (ins (esaddr16w $es, $adr):$addr),
                              "movw $rp, $addr"> {
  bits<8> rp;
  bits<16> adr;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = rp;
  let Inst{31-16} = adr;
  let mayLoad = 1;
}
// MOVW !addr16, AX       BF adrl adrh
def MOVW_abs16_AX : RL78StoreAX<3, (ins addr16w:$addr)> {
  bits<16> addr;
  let Inst{7-0} = 0xBF;
  let Inst{23-8} = addr;
}
// MOVW ES:!addr16, AX    11 BF adrl adrh
def MOVW_eabs16_AX : RL78StoreAX<4, (ins (esaddr16w $es, $adr):$addr)> {
  bits<16> adr;
  let Inst{15-0} = 0xBF11;
  let Inst{31-16} = adr;
}
// MOVW AX, [DE]/[HL]     A9/AB
def MOVW_AX_mRP : RL78LoadAX<1, (ins (memRP $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = {1, 0, 1, 0, 1, 0, rp, 1};
}
// MOVW [DE]/[HL], AX     B9/BB
def MOVW_mRP_AX : RL78StoreAX<1, (ins (memRP $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = {1, 0, 1, 1, 1, 0, rp, 1};
}
// MOVW AX, [DE+byte]/[HL+byte]   AA/AC adr
def MOVW_AX_mRPi : RL78LoadAX<2, (ins (memRPi $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = {1, 0, 1, 0, 1, rp, 0};
  let Inst{15-8} = disp;
}
// MOVW [DE+byte]/[HL+byte], AX   BA/BC adr
def MOVW_mRPi_AX : RL78StoreAX<2, (ins (memRPi $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = {1, 0, 1, 1, 1, rp, 0};
  let Inst{15-8} = disp;
}
// MOVW AX, ES:[DE]/[HL]  11 A9/AB
def MOVW_AX_emRP : RL78LoadAX<2, (ins (esmemRP $es, $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 1, 0, 1, 0, rp, 1};
}
// MOVW ES:[DE]/[HL], AX  11 B9/BB
def MOVW_emRP_AX : RL78StoreAX<2, (ins (esmemRP $es, $rp):$addr)> {
  bits<1> rp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 1, 1, 1, 0, rp, 1};
}
// MOVW AX, ES:[DE+byte]/[HL+byte]  11 AA/AC adr
def MOVW_AX_emRPi : RL78LoadAX<3, (ins (esmemRPi $es, $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 1, 0, 1, rp, 0};
  let Inst{23-16} = disp;
}
// MOVW ES:[DE+byte]/[HL+byte], AX  11 BA/BC adr
def MOVW_emRPi_AX : RL78StoreAX<3, (ins (esmemRPi $es, $rp, $disp):$addr)> {
  bits<2> rp;
  bits<8> disp;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = {1, 0, 1, 1, 1, rp, 0};
  let Inst{23-16} = disp;
}

// word[B], word[C], word[BC]: Ld and St are the opcodes of MOVW AX, w and
// MOVW w, AX.
multiclass RL78MovwWord<Operand Mem, Operand ESMem, bits<8> Ld, bits<8> St> {
  def "MOVW_AX_" # NAME : RL78LoadAX<3, (ins (Mem $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = Ld;
    let Inst{23-8} = wa;
  }
  def "MOVW_" # NAME # "_AX" : RL78StoreAX<3, (ins (Mem $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = St;
    let Inst{23-8} = wa;
  }
  def "MOVW_AX_e" # NAME : RL78LoadAX<4, (ins (ESMem $es, $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = Ld;
    let Inst{31-16} = wa;
  }
  def "MOVW_e" # NAME # "_AX" : RL78StoreAX<4, (ins (ESMem $es, $base, $wa):$addr)> {
    bits<16> wa;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = St;
    let Inst{31-16} = wa;
  }
}
// MOVW AX, word[B] 59, MOVW word[B], AX 58; word[C] 69, 68; word[BC] 79, 78.
defm mBw : RL78MovwWord<memBw, esmemBw, 0x59, 0x58>;
defm mCw : RL78MovwWord<memCw, esmemCw, 0x69, 0x68>;
defm mBCw : RL78MovwWord<memBCw, esmemBCw, 0x79, 0x78>;

// MOVW AX, [SP+byte]     A8 adr
def MOVW_AX_mSPi : RL78LoadAX<2, (ins (memSPi $sp, $disp):$addr)> {
  bits<8> disp;
  let Inst{7-0} = 0xA8;
  let Inst{15-8} = disp;
}
// MOVW [SP+byte], AX     B8 adr
def MOVW_mSPi_AX : RL78StoreAX<2, (ins (memSPi $sp, $disp):$addr)> {
  bits<8> disp;
  let Inst{7-0} = 0xB8;
  let Inst{15-8} = disp;
}

// SP is the sfr pair FFFF8H: MOVW SP, AX is MOVW sfrp, AX with sfrp = F8H,
// MOVW BC, SP is MOVW BC, !FFF8H.
// MOVW SP, #word         CB F8 datal datah
def MOVW_SP_i16 : RL78Inst<4, (outs RL78SPReg:$sp), (ins imm16:$imm), "movw $sp, $imm"> {
  bits<16> imm;
  let Inst{15-0} = 0xF8CB;
  let Inst{31-16} = imm;
}
// MOVW SP, AX            BE F8
def MOVW_SP_AX : RL78Inst<2, (outs RL78SPReg:$sp), (ins RL78AXRP:$ax), "movw $sp, $ax"> {
  let Inst{15-0} = 0xF8BE;
}
// MOVW AX, SP            AE F8
def MOVW_AX_SP : RL78Inst<2, (outs RL78AXRP:$ax), (ins RL78SPReg:$sp), "movw $ax, $sp"> {
  let Inst{15-0} = 0xF8AE;
}
// MOVW BC/DE/HL, SP      DB/EB/FB F8 FF
def MOVW_rp_SP : RL78Inst<3, (outs rpAbsNoAX:$rp), (ins RL78SPReg:$sp), "movw $rp, $sp"> {
  bits<8> rp;
  let Inst{7-0} = rp;
  let Inst{23-8} = 0xFFF8;
}

// XCHW AX, rp            31+rp   (rp: BC, DE, HL)
def XCHW_AX_rp : RL78Inst<1, (outs RL78AXRP:$axd, RL78BCDEHL:$rpd),
                          (ins RL78AXRP:$axs, RL78BCDEHL:$rps), "xchw $axd, $rpd"> {
  bits<3> rps;
  let Inst{7-0} = {0, 0, 1, 1, 0, rps{2-1}, 1};
  let Constraints = "$axs = $axd, $rps = $rpd";
}
