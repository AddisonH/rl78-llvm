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
  let DecoderMethod = "decodeSaddr";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}
def saddrp8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrpOpValue";
  let DecoderMethod = "decodeSaddr";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}

// sfr (FFF00H-FFFFFH), sfrp: the low byte of a fixed address.
def sfr8 : Operand<iPTR> {
  let PrintMethod = "printSfrOperand";
  let ParserMatchClass = RL78SfrAsmOperand;
  let EncoderMethod = "getSfrOpValue";
  let DecoderMethod = "decodeSfr";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}
def sfrp8 : Operand<iPTR> {
  let PrintMethod = "printSfrpOperand";
  let ParserMatchClass = RL78SfrpAsmOperand;
  let EncoderMethod = "getSfrOpValue";
  let DecoderMethod = "decodeSfr";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}

// !addr16 (F0000H-FFFFFH), of a byte or of a word.
def addr16 : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16OpValue";
  let DecoderMethod = "decodeAddr16";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}
def addr16w : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16wOpValue";
  let DecoderMethod = "decodeAddr16";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
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
class EncodedReg<RegisterClass RC, string Method, string Decoder = "">
    : RegisterOperand<RC> {
  let EncoderMethod = Method;
  let DecoderMethod = Decoder;
}
// [HL+B]/[HL+C]: 1 for C (most forms), 1 for B (XCH).
def idxC : EncodedReg<RL78BCReg, "getIsCOpValue", "decodeIsC">;
def idxB : EncodedReg<RL78BCReg, "getIsBOpValue", "decodeIsB">;
// [DE]/[HL]: 1 for HL (MOV, MOVW), 1 for DE (XCH); [DE+byte]/[HL+byte] in
// MOV and MOVW: 1 for DE, 2 for HL.
def rpHL : EncodedReg<RL78DEHL, "getIsHLOpValue", "decodeIsHL">;
def rpDE : EncodedReg<RL78DEHL, "getIsDEOpValue", "decodeIsDE">;
def rpDisp : EncodedReg<RL78DEHL, "getDEHLDispOpValue", "decodeDEHLDisp">;
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
def memBw : MemOperand<"printMemWord", MemBwAsmOperand, (ops RL78BReg8, waddr16)> {
  // The base address (the register is added to it).
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}
def memCw : MemOperand<"printMemWord", MemCwAsmOperand, (ops RL78CReg8, waddr16)> {
  // The base address (the register is added to it).
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}
def memBCw : MemOperand<"printMemWord", MemBCwAsmOperand, (ops RL78BCRP, waddr16)> {
  // The base address (the register is added to it).
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_DATA_ADDR";
}

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

// [HL] and [HL+byte] (1 to 255): a load or store through a pointer is one or
// the other.
def MemHL : ComplexPattern<iPTR, 1, "SelectMemHL", [], []>;
def MemHLi : ComplexPattern<iPTR, 2, "SelectMemHLi", [], []>;

// Op is the operation's row in the opcode map (ADD 0 ... XOR 7, CMP 4): its
// opcodes are Op<<4 | form. CMP writes only the flags; the others write A (or
// r, or saddr) and the flags. ADDC and SUBC also read CY.
multiclass RL78Alu8<string Mn, bits<4> Op, bit IsCmp,
                    SDPatternOperator Node = null_frag> {
  defvar A = !if(IsCmp, (outs), (outs RL78AReg:$rd));
  defvar Dst = !if(IsCmp, "$rs", "$rd");

  let Constraints = !if(IsCmp, "", "$rs = $rd") in {
  // Mn A, #byte          Op C data
  def _A_i8 : RL78Inst<2, A, (ins RL78AReg:$rs, imm8:$imm),
                       Mn # " " # Dst # ", $imm",
      [(set i8:$rd, (Node i8:$rs, (i8 imm:$imm)))]>, RL78FixedRdRs {
    bits<8> imm;
    let Inst{7-0} = {Op, 1, 1, 0, 0};
    let Inst{15-8} = imm;
  }
  // Mn A, r              61 Op8+r     (r: X, C, B, E, D, L, H)
  def _A_r : RL78Inst<2, A, (ins RL78AReg:$rs, RL78XBCEDHLReg:$r),
                      Mn # " " # Dst # ", $r",
      [(set i8:$rd, (Node i8:$rs, i8:$r))]>, RL78FixedRdRs {
    bits<3> r;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 1, r};
  }
  let mayLoad = 1 in {
  // Mn A, saddr          Op B saddr
  def _A_saddr : RL78Inst<2, A, (ins RL78AReg:$rs, saddr8:$addr),
                          Mn # " " # Dst # ", $addr",
      [(set i8:$rd, (Node i8:$rs, (load SADDR:$addr)))]>, RL78FixedRdRs {
    bits<8> addr;
    let Inst{7-0} = {Op, 1, 0, 1, 1};
    let Inst{15-8} = addr;
  }
  // Mn A, !addr16        Op F adrl adrh
  def _A_abs16 : RL78Inst<3, A, (ins RL78AReg:$rs, addr16:$addr),
                          Mn # " " # Dst # ", $addr",
      [(set i8:$rd, (Node i8:$rs, (load ADDRABS16:$addr)))]>, RL78FixedRdRs {
    bits<16> addr;
    let Inst{7-0} = {Op, 1, 1, 1, 1};
    let Inst{23-8} = addr;
  }
  // Mn A, [HL]           Op D
  def _A_mHL : RL78Inst<1, A, (ins RL78AReg:$rs, (memHL $hl):$addr),
                        Mn # " " # Dst # ", $addr",
      [(set i8:$rd, (Node i8:$rs, (load MemHL:$addr)))]>, RL78FixedRdRs {
    let Inst{7-0} = {Op, 1, 1, 0, 1};
  }
  // Mn A, [HL+byte]      Op E adr
  def _A_mHLi : RL78Inst<2, A, (ins RL78AReg:$rs, (memHLi $hl, $disp):$addr),
                         Mn # " " # Dst # ", $addr",
      [(set i8:$rd, (Node i8:$rs, (load MemHLi:$addr)))]>, RL78FixedRdRs {
    bits<8> disp;
    let Inst{7-0} = {Op, 1, 1, 1, 0};
    let Inst{15-8} = disp;
  }
  // Mn A, [HL+B]/[HL+C]  61 8+Op 0/2
  def _A_mHLr : RL78Inst<2, A, (ins RL78AReg:$rs, (memHLr $hl, $idx):$addr),
                         Mn # " " # Dst # ", $addr",
      [(set i8:$rd, (Node i8:$rs, (load ADDRrr:$addr)))]>, RL78FixedRdRs {
    bits<1> idx;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {1, Op{2-0}, 0, 0, idx, 0};
  }
  // Mn A, ES:!addr16     11 Op F adrl adrh
  def _A_eabs16 : RL78Inst<4, A, (ins RL78AReg:$rs, (esaddr16 $es, $adr):$addr),
                           Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 1};
    let Inst{31-16} = adr;
  }
  // Mn A, ES:[HL]        11 Op D
  def _A_emHL : RL78Inst<2, A, (ins RL78AReg:$rs, (esmemHL $es, $hl):$addr),
                         Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 0, 1};
  }
  // Mn A, ES:[HL+byte]   11 Op E adr
  def _A_emHLi : RL78Inst<3, A,
                          (ins RL78AReg:$rs, (esmemHLi $es, $hl, $disp):$addr),
                          Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<8> disp;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 0};
    let Inst{23-16} = disp;
  }
  // Mn A, ES:[HL+B]/[HL+C]  11 61 8+Op 0/2
  def _A_emHLr : RL78Inst<3, A,
                          (ins RL78AReg:$rs, (esmemHLr $es, $hl, $idx):$addr),
                          Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
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
defm ADD : RL78Alu8<"add", 0, 0, add>;
defm SUB : RL78Alu8<"sub", 2, 0, sub>;
defm AND : RL78Alu8<"and", 5, 0, and>;
defm OR  : RL78Alu8<"or", 6, 0, or>;
defm XOR : RL78Alu8<"xor", 7, 0, xor>;
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

// CMP, CMPW, CMP0 set CY when the first operand is below the second
// (unsigned) and Z when they are equal.
def RL78ucmp : PatFrag<(ops node:$l, node:$r), (cmp node:$l, node:$r, (i8 0))>;

// After a compare, CY ^= the sign bit of each operand makes CY "less than"
// for signed operands; a negative constant operand inverts CY instead.
def RL78xorsigncy : SDNode<"RL78ISD::XORSIGNCY",
                           SDTypeProfile<0, 1, [SDTCisInt<0>]>,
                           [SDNPInGlue, SDNPOutGlue]>;
def RL78notcy : SDNode<"RL78ISD::NOTCY", SDTypeProfile<0, 0, []>,
                       [SDNPInGlue, SDNPOutGlue]>;

def : Pat<(RL78ucmp i8:$a, (i8 imm:$i)), (CMP_A_i8 $a, imm:$i)>;
def : Pat<(RL78ucmp i8:$a, i8:$r), (CMP_A_r $a, $r)>;
def : Pat<(RL78ucmp i8:$a, (load SADDR:$addr)), (CMP_A_saddr $a, SADDR:$addr)>;
def : Pat<(RL78ucmp i8:$a, (load ADDRABS16:$addr)),
          (CMP_A_abs16 $a, ADDRABS16:$addr)>;
def : Pat<(RL78ucmp i8:$a, (load MemHL:$addr)), (CMP_A_mHL $a, MemHL:$addr)>;
def : Pat<(RL78ucmp i8:$a, (load MemHLi:$addr)), (CMP_A_mHLi $a, MemHLi:$addr)>;
def : Pat<(RL78ucmp i8:$a, (load ADDRrr:$addr)), (CMP_A_mHLr $a, ADDRrr:$addr)>;
def : Pat<(RL78ucmp (load SADDR:$addr), (i8 imm:$i)),
          (CMP_saddr_i8 SADDR:$addr, imm:$i)>;
def : Pat<(RL78ucmp (load ADDRABS16:$addr), (i8 imm:$i)),
          (CMP_abs16_i8 ADDRABS16:$addr, imm:$i)>;

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
                         Mn # " " # Dst # ", $imm">, RL78FixedRdRs {
    bits<16> imm;
    let Inst{7-0} = {Op, 0, 1, 0, 0};
    let Inst{23-8} = imm;
  }
  // Mn AX, rp            Op 1+rp
  def _AX_rp : RL78Inst<1, AX, (ins RL78AXRP:$rs, Rp:$rp),
                        Mn # " " # Dst # ", $rp">, RL78FixedRdRs {
    bits<3> rp;
    let Inst{7-0} = {Op, 0, rp{2-1}, 1};
  }
  let mayLoad = 1 in {
  // Mn AX, saddrp        Op 6 saddr
  def _AX_saddrp : RL78Inst<2, AX, (ins RL78AXRP:$rs, saddrp8:$addr),
                            Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<8> addr;
    let Inst{7-0} = {Op, 0, 1, 1, 0};
    let Inst{15-8} = addr;
  }
  // Mn AX, !addr16       Op 2 adrl adrh
  def _AX_abs16 : RL78Inst<3, AX, (ins RL78AXRP:$rs, addr16w:$addr),
                           Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<16> addr;
    let Inst{7-0} = {Op, 0, 0, 1, 0};
    let Inst{23-8} = addr;
  }
  // Mn AX, [HL+byte]     61 Op9 adr
  def _AX_mHLi : RL78Inst<3, AX, (ins RL78AXRP:$rs, (memHLi $hl, $disp):$addr),
                          Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<8> disp;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 1, 0, 0, 1};
    let Inst{23-16} = disp;
  }
  // Mn AX, ES:!addr16    11 Op2 adrl adrh
  def _AX_eabs16 : RL78Inst<4, AX, (ins RL78AXRP:$rs, (esaddr16w $es, $adr):$addr),
                            Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 0, 0, 1, 0};
    let Inst{31-16} = adr;
  }
  // Mn AX, ES:[HL+byte]  11 61 Op9 adr
  def _AX_emHLi : RL78Inst<4, AX,
                           (ins RL78AXRP:$rs, (esmemHLi $es, $hl, $disp):$addr),
                           Mn # " " # Dst # ", $addr">, RL78FixedRdRs {
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

multiclass RL78Alu16Sel<string I, SDPatternOperator Node> {
  def : Pat<(Node i16:$a, (i16 imm:$i)),
            (!cast<Instruction>(I # "_AX_i16") $a, imm:$i)>;
  def : Pat<(Node i16:$a, i16:$rp), (!cast<Instruction>(I # "_AX_rp") $a, $rp)>;
  def : Pat<(Node i16:$a, (load SADDR:$addr)),
            (!cast<Instruction>(I # "_AX_saddrp") $a, SADDR:$addr)>;
  def : Pat<(Node i16:$a, (load ADDRABS16:$addr)),
            (!cast<Instruction>(I # "_AX_abs16") $a, ADDRABS16:$addr)>;
  def : Pat<(Node i16:$a, (load ADDRri8:$addr)),
            (!cast<Instruction>(I # "_AX_mHLi") $a, ADDRri8:$addr)>;
}
defm : RL78Alu16Sel<"ADDW", add>;
defm : RL78Alu16Sel<"SUBW", sub>;
// The carry out is in CY either way.
defm : RL78Alu16Sel<"ADDW", addc>;
defm : RL78Alu16Sel<"SUBW", subc>;
defm : RL78Alu16Sel<"CMPW", RL78ucmp>;

// SKNZ, then CMPW of the low words: one instruction for code generation, so
// that nothing is placed between the two.
let Uses = [CCreg], Defs = [CCreg] in {
def LowCMPW_rp_imm
    : RL78Pseudo<5, (outs), (ins RL78AXRP:$rsrc, i16imm:$imm16),
                 [(RL78lowcmp i16:$rsrc, (i16 imm:$imm16))]>;
def LowCMPW_rp_rp
    : RL78Pseudo<3, (outs), (ins RL78AXRP:$rsrc, RL78BCDEHL:$rsrc2),
                 [(RL78lowcmp i16:$rsrc, i16:$rsrc2)]>;
let mayLoad = 1 in {
def LowCMPW_rp_saddr
    : RL78Pseudo<4, (outs), (ins RL78AXRP:$rsrc, ABS8:$addr),
                 [(RL78lowcmp i16:$rsrc, (load SADDR:$addr))]>;
def LowCMPW_rp_abs16
    : RL78Pseudo<5, (outs), (ins RL78AXRP:$rsrc, ABS16:$addr),
                 [(RL78lowcmp i16:$rsrc, (load ADDRABS16:$addr))]>;
def LowCMPW_rp_memri
    : RL78Pseudo<5, (outs), (ins RL78AXRP:$rsrc, memHLi:$addr),
                 [(RL78lowcmp i16:$rsrc, (load ADDRri8:$addr))]>;
}
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

multiclass RL78IncDecSel<string I, ValueType VT, int By, string R, string S> {
  def : Pat<(add VT:$r, By), (!cast<Instruction>(I # R) $r)>;
  def : Pat<(store (add (VT (load SADDR:$addr)), By), SADDR:$addr),
            (!cast<Instruction>(I # S) SADDR:$addr)>;
  def : Pat<(store (add (VT (load ADDRABS16:$addr)), By), ADDRABS16:$addr),
            (!cast<Instruction>(I # "_abs16") ADDRABS16:$addr)>;
  def : Pat<(store (add (VT (load ADDRri8:$addr)), By), ADDRri8:$addr),
            (!cast<Instruction>(I # "_mHLi") ADDRri8:$addr)>;
}
defm : RL78IncDecSel<"INC", i8, 1, "_r", "_saddr">;
// x | 1 with bit 0 of x known to be clear.
def : Pat<(inc i8:$r), (INC_r $r)>;
defm : RL78IncDecSel<"DEC", i8, -1, "_r", "_saddr">;
defm : RL78IncDecSel<"INCW", i16, 1, "_rp", "_saddrp">;
defm : RL78IncDecSel<"DECW", i16, -1, "_rp", "_saddrp">;
// Two steps on any register pair are two bytes; ADDW AX, #2 is three and
// needs the value in AX, where a loop usually has something else.
def : Pat<(add i16:$r, 2), (INCW_rp (INCW_rp $r))>;
def : Pat<(add i16:$r, -2), (DECW_rp (DECW_rp $r))>;

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
// Z is set when the operands are equal; CY when they differ or A or X is 0.
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
    : RL78Inst<2, (outs R:$rd), (ins R:$rs, Cnt:$cnt), Mn # " $rd, $cnt">,
      RL78FixedRdRs {
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
let isCodeGenOnly = 1 in
def SHL_r_n : RL78Inst<2, (outs shlReg:$rd), (ins shlReg:$rs, shift8imm:$cnt),
                       "shl $rd, $cnt"> {
  bits<4> cnt;
  bits<4> rs;
  let Inst{7-0} = 0x31;
  let Inst{15-8} = {cnt, rs};
  let Constraints = "$rs = $rd";
}
// SHLW AX/BC, cnt        31 cnt<<4|D/C
let isCodeGenOnly = 1 in
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
    : RL78Inst<2, (outs R:$rd), (ins R:$rs), Mn # " $rd, 1">, RL78FixedRdRs {
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
let isCodeGenOnly = 1 in
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
let isCodeGenOnly = 1 in
def MOV_r_abs16 : RL78Inst<3, (outs lowAbs:$r), (ins addr16:$addr), "mov $r, $addr"> {
  bits<8> r;
  bits<16> addr;
  let Inst{7-0} = r;
  let Inst{23-8} = addr;
  let mayLoad = 1;
}
// MOV r, ES:!addr16      11 8F/D9/F9/E9 adrl adrh
let isCodeGenOnly = 1 in
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
                       (ins RL78AReg:$as, RL78XReg:$rs), "xch $ad, $rd">,
              RL78FixedRdRs {
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
let isCodeGenOnly = 1 in
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
let isCodeGenOnly = 1 in
def MOVW_rp_abs16 : RL78Inst<3, (outs rpAbs:$rp), (ins addr16w:$addr),
                             "movw $rp, $addr"> {
  bits<8> rp;
  bits<16> addr;
  let Inst{7-0} = rp;
  let Inst{23-8} = addr;
  let mayLoad = 1;
}
// MOVW rp, ES:!addr16    11 AF/DB/EB/FB adrl adrh
let isCodeGenOnly = 1 in
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
let isCodeGenOnly = 1 in
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

//===----------------------------------------------------------------------===//
// Bit manipulation (manual 6.9): MOV1, AND1, OR1, XOR1, SET1, CLR1, NOT1
//===----------------------------------------------------------------------===//

// 71 {Hi, bit, Sel, L}: Hi Sel select the location (saddr 0 0, sfr 0 1,
// A 1 1, [HL] 1 0), L the operation: MOV1 x.bit, CY 1; SET1 2; CLR1 3;
// MOV1 CY, x.bit 4; AND1 5; OR1 6; XOR1 7. PSW.bit is sfr.bit with sfr FAH.
multiclass RL78BitOp<string Mn, bits<3> L, string Pre, string Post,
                     dag Outs, dag InsPre, dag InsPost, dag OutsA, bit RMW> {
  defvar Ld = !or(RMW, !ne(Pre, ""));
  defvar St = !or(RMW, !eq(Pre, ""));
  // saddr.bit             71 {0 bit 0 L} saddr
  def _saddr_b : RL78Inst<3, Outs, !con(InsPre, (ins saddr8:$addr, bitimm:$bn), InsPost),
                          Mn # " " # Pre # "$addr$bn" # Post> {
    bits<8> addr;
    bits<3> bn;
    let Inst{7-0} = 0x71;
    let Inst{15-8} = {0, bn, 0, L};
    let Inst{23-16} = addr;
    let mayLoad = Ld;
    let mayStore = St;
  }
  // sfr.bit               71 {0 bit 1 L} sfr
  def _sfr_b : RL78Inst<3, Outs, !con(InsPre, (ins sfr8:$addr, bitimm:$bn), InsPost),
                        Mn # " " # Pre # "$addr$bn" # Post> {
    bits<8> addr;
    bits<3> bn;
    let Inst{7-0} = 0x71;
    let Inst{15-8} = {0, bn, 1, L};
    let Inst{23-16} = addr;
    let mayLoad = Ld;
    let mayStore = St;
    let hasSideEffects = 1;
  }
  // A.bit                 71 {1 bit 1 L}
  def _A_b : RL78Inst<2, OutsA, !con(InsPre, (ins RL78AReg:$a, bitimm:$bn), InsPost),
                      Mn # " " # Pre # "$a$bn" # Post> {
    bits<3> bn;
    let Inst{7-0} = 0x71;
    let Inst{15-8} = {1, bn, 1, L};
    let Constraints = !if(!empty(OutsA), "", "$a = $ad");
  }
  // [HL].bit              71 {1 bit 0 L}
  def _mHL_b : RL78Inst<2, Outs, !con(InsPre, (ins (memHL $hl):$addr, bitimm:$bn), InsPost),
                        Mn # " " # Pre # "$addr$bn" # Post> {
    bits<3> bn;
    let Inst{7-0} = 0x71;
    let Inst{15-8} = {1, bn, 0, L};
    let mayLoad = Ld;
    let mayStore = St;
  }
  // ES:[HL].bit           11 71 {1 bit 0 L}
  def _emHL_b : RL78Inst<3, Outs,
                         !con(InsPre, (ins (esmemHL $es, $hl):$addr, bitimm:$bn), InsPost),
                         Mn # " " # Pre # "$addr$bn" # Post> {
    bits<3> bn;
    let Inst{15-0} = 0x7111;
    let Inst{23-16} = {1, bn, 0, L};
    let mayLoad = Ld;
    let mayStore = St;
  }
}

// MOV1, AND1, OR1, XOR1 CY, x.bit
let Defs = [CCreg] in {
defm MOV1_CY : RL78BitOp<"mov1", 4, "cy, ", "", (outs), (ins), (ins), (outs), 0>;
let Uses = [CCreg] in {
defm AND1_CY : RL78BitOp<"and1", 5, "cy, ", "", (outs), (ins), (ins), (outs), 0>;
defm OR1_CY : RL78BitOp<"or1", 6, "cy, ", "", (outs), (ins), (ins), (outs), 0>;
defm XOR1_CY : RL78BitOp<"xor1", 7, "cy, ", "", (outs), (ins), (ins), (outs), 0>;
}
}
// MOV1 x.bit, CY
let Uses = [CCreg] in
defm MOV1 : RL78BitOp<"mov1", 1, "", ", cy", (outs), (ins), (ins),
                      (outs RL78AReg:$ad), 0>;
// SET1, CLR1 x.bit
defm SET1 : RL78BitOp<"set1", 2, "", "", (outs), (ins), (ins),
                      (outs RL78AReg:$ad), 1>;
defm CLR1 : RL78BitOp<"clr1", 3, "", "", (outs), (ins), (ins),
                      (outs RL78AReg:$ad), 1>;

// SET1/CLR1 !addr16.bit  71 {0 bit 0/1 000} adrl adrh (and behind ES:)
multiclass RL78BitAbs<string Mn, bit Sel> {
  let mayLoad = 1, mayStore = 1 in {
  def _abs16_b : RL78Inst<4, (outs), (ins addr16:$addr, bitimm:$bn), Mn # " $addr$bn"> {
    bits<16> addr;
    bits<3> bn;
    let Inst{7-0} = 0x71;
    let Inst{15-8} = {0, bn, Sel, 0, 0, 0};
    let Inst{31-16} = addr;
  }
  def _eabs16_b : RL78Inst<5, (outs), (ins (esaddr16 $es, $adr):$addr, bitimm:$bn),
                           Mn # " $addr$bn"> {
    bits<16> adr;
    bits<3> bn;
    let Inst{15-0} = 0x7111;
    let Inst{23-16} = {0, bn, Sel, 0, 0, 0};
    let Inst{39-24} = adr;
  }
  }
}
defm SET1 : RL78BitAbs<"set1", 0>;
defm CLR1 : RL78BitAbs<"clr1", 1>;

// SET1 CY 71 80, CLR1 CY 71 88, NOT1 CY 71 C0
let Defs = [CCreg] in {
def SET1_CY : RL78Inst<2, (outs), (ins), "set1 cy"> { let Inst{15-0} = 0x8071; }
def CLR1_CY : RL78Inst<2, (outs), (ins), "clr1 cy"> { let Inst{15-0} = 0x8871; }
let Uses = [CCreg] in
def NOT1_CY : RL78Inst<2, (outs), (ins), "not1 cy"> { let Inst{15-0} = 0xC071; }
}

//===----------------------------------------------------------------------===//
// Branch targets and conditions
//===----------------------------------------------------------------------===//

// $addr20 (8-bit displacement), $!addr20 (16-bit displacement), !addr16 and
// !!addr20 (absolute code addresses).
def brtarget8 : Operand<OtherVT> {
  let PrintMethod = "printBranchTarget8";
  let ParserMatchClass = RL78brtargetRel8AsmOperand;
  let EncoderMethod = "getRel8OpValue";
  let OperandType = "OPERAND_PCREL";
}
def brtarget16 : Operand<OtherVT> {
  let PrintMethod = "printBranchTarget16";
  let ParserMatchClass = RL78brtargetRel16AsmOperand;
  let EncoderMethod = "getRel16OpValue";
  let OperandType = "OPERAND_PCREL";
}
def code16 : Operand<iPTR> {
  let PrintMethod = "printCode16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getCode16OpValue";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_CODE_ADDR";
}
def code20 : Operand<iPTR> {
  let PrintMethod = "printABS20Operand";
  let ParserMatchClass = RL78MEMDirectAddr20AsmOperand;
  let EncoderMethod = "getCode20OpValue";
  let OperandNamespace = "RL78Op";
  let OperandType = "OPERAND_CODE_ADDR";
}
// CALLT [addr5]: a table entry, 00080H-000BEH (even).
def CalltAsmOperand : AsmOperandClass {
  let Name = "Callt";
  let RenderMethod = "addABS5Operands";
}
def callt5 : Operand<iPTR> {
  let PrintMethod = "printABS5Operand";
  let ParserMatchClass = CalltAsmOperand;
  let EncoderMethod = "getCalltOpValue";
  let DecoderMethod = "decodeCallt";
}

// Conditions (RL78CC::CondCodes) that a form encodes.
class CondAsmOperand<string N> : AsmOperandClass { let Name = N; }
class CondOperand<string Print, string Asm, string Enc, string Dec = "">
    : Operand<i8> {
  let PrintMethod = Print;
  let ParserMatchClass = CondAsmOperand<Asm>;
  let EncoderMethod = Enc;
  let DecoderMethod = Dec;
}
// BC, BNC, BZ, BNZ; SKC, SKNC, SKZ, SKNZ
def condCZ : CondOperand<"printCCOperand", "CondCZ", "getBccOpValue", "decodeBcc">;
def condSkCZ : CondOperand<"printCCOperand", "CondCZ", "getMachineOpValueImm">;
// BH, BNH; SKH, SKNH
def condH : CondOperand<"printCCOperand", "CondH", "getHccOpValue", "decodeHcc">;
// BT, BF: true (Z), false (NZ)
def condTF : CondOperand<"printBitCondOperand", "CondTF", "getBtBfOpValue", "decodeBtBf">;

//===----------------------------------------------------------------------===//
// Branches (manual 6.12, 6.13, 6.14)
//===----------------------------------------------------------------------===//

let isBranch = 1, isTerminator = 1 in {
let isBarrier = 1 in {
// BR $addr20             EF adr
def BR_rel8 : RL78Inst<2, (outs), (ins brtarget8:$dst), "br $dst"> {
  bits<8> dst;
  let Inst{7-0} = 0xEF;
  let Inst{15-8} = dst;
}
// BR $!addr20            EE adrl adrh
def BR_rel16 : RL78Inst<3, (outs), (ins brtarget16:$dst), "br $dst"> {
  bits<16> dst;
  let Inst{7-0} = 0xEE;
  let Inst{23-8} = dst;
}
// BR !addr16             ED adrl adrh
def BR_abs16 : RL78Inst<3, (outs), (ins code16:$dst), "br $dst"> {
  bits<16> dst;
  let Inst{7-0} = 0xED;
  let Inst{23-8} = dst;
}
// BR !!addr20            EC adrl adrh adrs
def BR_abs20 : RL78Inst<4, (outs), (ins code20:$dst), "br !!$dst"> {
  bits<24> dst;
  let Inst{7-0} = 0xEC;
  let Inst{31-8} = dst;
}
// BR AX                  61 CB
let isIndirectBranch = 1 in
def BR_AX : RL78Inst<2, (outs), (ins RL78AXRP:$ax), "br $ax"> {
  let Inst{15-0} = 0xCB61;
}
}

let Uses = [CCreg] in {
// BC/BZ/BNC/BNZ $addr20  DC/DD/DE/DF adr
def Bcc_rel8 : RL78Inst<2, (outs), (ins brtarget8:$dst, condCZ:$cc), "b$cc $dst"> {
  bits<8> dst;
  bits<2> cc;
  let Inst{7-0} = {1, 1, 0, 1, 1, 1, cc};
  let Inst{15-8} = dst;
}
// BH/BNH $addr20         61 C3/D3 adr
def BHcc_rel8 : RL78Inst<3, (outs), (ins brtarget8:$dst, condH:$cc), "b$cc $dst"> {
  bits<8> dst;
  bits<1> cc;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, 0, cc, 0, 0, 1, 1};
  let Inst{23-16} = dst;
}
}

// BT/BF x.bit, $addr20    31 {Hi bit TF Lo} [addr] adr; Hi Lo select the
// location (saddr 0 0, sfr 1 0, A 0 1, [HL] 1 1). TF is 01 for BT, 10 for BF,
// 00 for BTCLR (which also clears the bit).
multiclass RL78BitBranch<string Mn, dag Cond, string CondAsm, bit Clr> {
  def _saddr_b : RL78Inst<4, (outs), !con((ins saddr8:$addr, bitimm:$bn, brtarget8:$dst), Cond),
                          Mn # CondAsm # " $addr$bn, $dst"> {
    bits<8> addr;
    bits<3> bn;
    bits<8> dst;
    bits<2> cc;
    let Inst{7-0} = 0x31;
    let Inst{15-8} = {0, bn, 0, !if(Clr, 0, cc{1}), !if(Clr, 0, cc{0}), 0};
    let Inst{23-16} = addr;
    let Inst{31-24} = dst;
    let mayLoad = 1;
    let mayStore = Clr;
  }
  def _sfr_b : RL78Inst<4, (outs), !con((ins sfr8:$addr, bitimm:$bn, brtarget8:$dst), Cond),
                        Mn # CondAsm # " $addr$bn, $dst"> {
    bits<8> addr;
    bits<3> bn;
    bits<8> dst;
    bits<2> cc;
    let Inst{7-0} = 0x31;
    let Inst{15-8} = {1, bn, 0, !if(Clr, 0, cc{1}), !if(Clr, 0, cc{0}), 0};
    let Inst{23-16} = addr;
    let Inst{31-24} = dst;
    let mayLoad = 1;
    let mayStore = Clr;
    let hasSideEffects = 1;
  }
  def _A_b : RL78Inst<3, !if(Clr, (outs RL78AReg:$ad), (outs)),
                      !con((ins RL78AReg:$a, bitimm:$bn, brtarget8:$dst), Cond),
                      Mn # CondAsm # " $a$bn, $dst"> {
    bits<3> bn;
    bits<8> dst;
    bits<2> cc;
    let Inst{7-0} = 0x31;
    let Inst{15-8} = {0, bn, 0, !if(Clr, 0, cc{1}), !if(Clr, 0, cc{0}), 1};
    let Inst{23-16} = dst;
    let Constraints = !if(Clr, "$a = $ad", "");
  }
  def _mHL_b : RL78Inst<3, (outs), !con((ins (memHL $hl):$addr, bitimm:$bn, brtarget8:$dst), Cond),
                        Mn # CondAsm # " $addr$bn, $dst"> {
    bits<3> bn;
    bits<8> dst;
    bits<2> cc;
    let Inst{7-0} = 0x31;
    let Inst{15-8} = {1, bn, 0, !if(Clr, 0, cc{1}), !if(Clr, 0, cc{0}), 1};
    let Inst{23-16} = dst;
    let mayLoad = 1;
    let mayStore = Clr;
  }
  def _emHL_b : RL78Inst<4, (outs),
                         !con((ins (esmemHL $es, $hl):$addr, bitimm:$bn, brtarget8:$dst), Cond),
                         Mn # CondAsm # " $addr$bn, $dst"> {
    bits<3> bn;
    bits<8> dst;
    bits<2> cc;
    let Inst{15-0} = 0x3111;
    let Inst{23-16} = {1, bn, 0, !if(Clr, 0, cc{1}), !if(Clr, 0, cc{0}), 1};
    let Inst{31-24} = dst;
    let mayLoad = 1;
    let mayStore = Clr;
  }
}
defm BTF : RL78BitBranch<"b", (ins condTF:$cc), "$cc", 0>;
defm BTCLR : RL78BitBranch<"btclr", (ins), "", 1>;
} // isBranch, isTerminator

// SKC/SKNC/SKZ/SKNZ      61 C8/D8/E8/F8
// SKH/SKNH               61 E3/F3
// Skip the next instruction when the condition holds.
let Uses = [CCreg], hasSideEffects = 1 in {
def SKcc : RL78Inst<2, (outs), (ins condSkCZ:$cc), "sk$cc"> {
  bits<2> cc;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, cc, 1, 0, 0, 0};
}
def SKHcc : RL78Inst<2, (outs), (ins condH:$cc), "sk$cc"> {
  bits<1> cc;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, 1, cc, 0, 0, 1, 1};
}
}

//===----------------------------------------------------------------------===//
// Calls, returns, stack (manual 6.10, 6.11)
//===----------------------------------------------------------------------===//

let isCall = 1, Uses = [SPreg], Defs = [SPreg] in {
// CALL AX/BC/DE/HL       61 CA/DA/EA/FA
def CALL_rp : RL78Inst<2, (outs), (ins RL78RPRegs:$rp, variable_ops), "call $rp"> {
  bits<3> rp;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, rp{2-1}, 1, 0, 1, 0};
}
// CALL $!addr20          FE adrl adrh
def CALL_rel16 : RL78Inst<3, (outs), (ins brtarget16:$dst, variable_ops), "call $dst"> {
  bits<16> dst;
  let Inst{7-0} = 0xFE;
  let Inst{23-8} = dst;
}
// CALL !addr16           FD adrl adrh
def CALL_abs16 : RL78Inst<3, (outs), (ins code16:$dst, variable_ops), "call $dst"> {
  bits<16> dst;
  let Inst{7-0} = 0xFD;
  let Inst{23-8} = dst;
}
// CALL !!addr20          FC adrl adrh adrs
def CALL_abs20 : RL78Inst<4, (outs), (ins code20:$dst, variable_ops), "call !!$dst"> {
  bits<24> dst;
  let Inst{7-0} = 0xFC;
  let Inst{31-8} = dst;
}
// CALLT [addr5]          61 {1 i2-i0 0 1 i4-i3}, i = (addr5 - 80H) / 2
def CALLT : RL78Inst<2, (outs), (ins callt5:$entry, variable_ops), "callt $entry"> {
  bits<5> entry;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, entry{2-0}, 0, 1, entry{4-3}};
}
// BRK                    61 CC
let hasSideEffects = 1 in
def BRK : RL78Inst<2, (outs), (ins), "brk"> { let Inst{15-0} = 0xCC61; }
}

let isReturn = 1, isTerminator = 1, isBarrier = 1, Uses = [SPreg],
    Defs = [SPreg] in {
// RET                    D7
def RET : RL78Inst<1, (outs), (ins), "ret"> { let Inst{7-0} = 0xD7; }
let hasSideEffects = 1 in {
// RETI                   61 FC
def RETI : RL78Inst<2, (outs), (ins), "reti"> { let Inst{15-0} = 0xFC61; }
// RETB                   61 EC
def RETB : RL78Inst<2, (outs), (ins), "retb"> { let Inst{15-0} = 0xEC61; }
}
}

let Uses = [SPreg], Defs = [SPreg] in {
// PUSH AX/BC/DE/HL       C1/C3/C5/C7
let mayStore = 1 in
def PUSH_rp : RL78Inst<1, (outs), (ins RL78RPRegs:$rp), "push $rp"> {
  bits<3> rp;
  let Inst{7-0} = {1, 1, 0, 0, 0, rp{2-1}, 1};
}
// POP AX/BC/DE/HL        C0/C2/C4/C6
let mayLoad = 1 in
def POP_rp : RL78Inst<1, (outs RL78RPRegs:$rp), (ins), "pop $rp"> {
  bits<3> rp;
  let Inst{7-0} = {1, 1, 0, 0, 0, rp{2-1}, 0};
}
// PUSH PSW               61 DD
// POP PSW                61 CD
let mayStore = 1 in
def PUSH_PSW : RL78Inst<2, (outs), (ins RL78RegPSW:$psw), "push $psw"> {
  let Inst{15-0} = 0xDD61;
}
let mayLoad = 1, hasSideEffects = 1 in
def POP_PSW : RL78Inst<2, (outs RL78RegPSW:$psw), (ins), "pop $psw"> {
  let Inst{15-0} = 0xCD61;
}
}

//===----------------------------------------------------------------------===//
// CPU control (manual 6.15)
//===----------------------------------------------------------------------===//

let hasSideEffects = 1 in {
// A NOP is only ever asked for (delays, the instruction after a divide).
def NOP : RL78Inst<1, (outs), (ins), "nop"> { let Inst{7-0} = 0x00; }
// SEL RBn                61 CF/DF/EF/FF
let Predicates = [isNotS1Core] in
def SEL_RBn : RL78Inst<2, (outs), (ins SELRBx:$rb), "sel $rb"> {
  bits<2> rb;
  let Inst{7-0} = 0x61;
  let Inst{15-8} = {1, 1, rb, 1, 1, 1, 1};
}
// HALT 61 ED, STOP 61 FD
def HALT : RL78Inst<2, (outs), (ins), "halt"> { let Inst{15-0} = 0xED61; }
def STOP : RL78Inst<2, (outs), (ins), "stop"> { let Inst{15-0} = 0xFD61; }
// EI is SET1 PSW.7 (71 7A FA), DI is CLR1 PSW.7 (71 7B FA).
def EI : RL78Inst<3, (outs), (ins), "ei"> { let Inst{23-0} = 0xFA7A71; }
def DI : RL78Inst<3, (outs), (ins), "di"> { let Inst{23-0} = 0xFA7B71; }
}

//===----------------------------------------------------------------------===//
// Multiply, divide, multiply-accumulate (manual 6.5)
//===----------------------------------------------------------------------===//

// MULU X                 D6        AX = A * X
def MULU_X : RL78Inst<1, (outs RL78AXRP:$ax), (ins RL78AReg:$a, RL78XReg:$x), "mulu $x"> {
  let Inst{7-0} = 0xD6;
}
// The S3 core's multiply/divide unit; operands and results in fixed
// registers. CE FB Op.
class RL78MulDiv<string Mn, bits<8> Op> : RL78Inst<3, (outs), (ins), Mn> {
  let Inst{15-0} = 0xFBCE;
  let Inst{23-16} = Op;
}
let Predicates = [isS3Core] in {
// MULHU 01, MULH 02: BCAX = AX * BC
let Uses = [RP0, RP2], Defs = [RP0, RP2, CCreg] in {
def MULHU : RL78MulDiv<"mulhu", 0x01>;
def MULH : RL78MulDiv<"mulh", 0x02>;
}
// DIVHU 03: AX = AX / DE, DE = AX % DE
let Uses = [RP0, RP4], Defs = [RP0, RP4, CCreg] in
def DIVHU : RL78MulDiv<"divhu", 0x03>;
// DIVWU 0B: BCAX = BCAX / HLDE, HLDE = BCAX % HLDE
let Uses = [RP0, RP2, RP4, RP6], Defs = [RP0, RP2, RP4, RP6, CCreg] in
def DIVWU : RL78MulDiv<"divwu", 0x0B>;
// MACHU 05, MACH 06: MACR += AX * BC
let Uses = [RP0, RP2, MACRL, MACRH], Defs = [MACRL, MACRH, CCreg] in {
def MACHU : RL78MulDiv<"machu", 0x05>;
def MACH : RL78MulDiv<"mach", 0x06>;
}
} // Predicates = [isS3Core]

//===----------------------------------------------------------------------===//
// Per-register forms for the assembler and disassembler
//===----------------------------------------------------------------------===//

// Where the register is not a field of the opcode but selects it (MOV r,
// saddr is 8D for A, D8 for X ...), code generation uses one definition with
// the register class (the isCodeGenOnly ones above, whose register operand's
// encoder method gives the opcode) and the assembler and disassembler one
// definition per register, so that every opcode byte is fixed.
class RL78LoadReg<int size, RegisterClass R, dag Ops, string Mn>
    : RL78Inst<size, (outs R:$r), Ops, Mn # " $r, $addr"> {
  bits<0> r;
  let mayLoad = 1;
}
multiclass RL78LoadLow<RegisterClass R, string N, bits<8> Saddr, bits<8> Abs> {
  // MOV r, saddr; MOV r, !addr16; MOV r, ES:!addr16
  def MOV_ # N # _saddr : RL78LoadReg<2, R, (ins saddr8:$addr), "mov"> {
    bits<8> addr;
    let Inst{7-0} = Saddr;
    let Inst{15-8} = addr;
  }
  def MOV_ # N # _abs16 : RL78LoadReg<3, R, (ins addr16:$addr), "mov"> {
    bits<16> addr;
    let Inst{7-0} = Abs;
    let Inst{23-8} = addr;
  }
  def MOV_ # N # _eabs16 : RL78LoadReg<4, R, (ins (esaddr16 $es, $adr):$addr), "mov"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = Abs;
    let Inst{31-16} = adr;
  }
}
defm "" : RL78LoadLow<RL78XReg, "X", 0xD8, 0xD9>;
defm "" : RL78LoadLow<RL78AReg, "A", 0x8D, 0x8F>;
defm "" : RL78LoadLow<RL78CReg8, "C", 0xF8, 0xF9>;
defm "" : RL78LoadLow<RL78BReg8, "B", 0xE8, 0xE9>;

multiclass RL78LoadPair<RegisterClass R, string N, bits<8> Saddrp, bits<8> Abs> {
  // MOVW rp, saddrp; MOVW rp, !addr16; MOVW rp, ES:!addr16
  def MOVW_ # N # _saddrp : RL78LoadReg<2, R, (ins saddrp8:$addr), "movw"> {
    bits<8> addr;
    let Inst{7-0} = Saddrp;
    let Inst{15-8} = addr;
  }
  def MOVW_ # N # _abs16 : RL78LoadReg<3, R, (ins addr16w:$addr), "movw"> {
    bits<16> addr;
    let Inst{7-0} = Abs;
    let Inst{23-8} = addr;
  }
  def MOVW_ # N # _eabs16 : RL78LoadReg<4, R, (ins (esaddr16w $es, $adr):$addr), "movw"> {
    bits<16> adr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = Abs;
    let Inst{31-16} = adr;
  }
}
defm "" : RL78LoadPair<RL78AXRP, "AX", 0xAD, 0xAF>;
defm "" : RL78LoadPair<RL78BCRP, "BC", 0xDA, 0xDB>;
defm "" : RL78LoadPair<RL78DERP, "DE", 0xEA, 0xEB>;
defm "" : RL78LoadPair<RL78HL, "HL", 0xFA, 0xFB>;

// MOVW BC/DE/HL, SP      DB/EB/FB F8 FF
class RL78MovwFromSP<RegisterClass R, bits<8> Opc>
    : RL78Inst<3, (outs R:$r), (ins RL78SPReg:$sp), "movw $r, $sp"> {
  bits<0> r;
  let Inst{7-0} = Opc;
  let Inst{23-8} = 0xFFF8;
}
def MOVW_BC_SP : RL78MovwFromSP<RL78BCRP, 0xDB>;
def MOVW_DE_SP : RL78MovwFromSP<RL78DERP, 0xEB>;
def MOVW_HL_SP : RL78MovwFromSP<RL78HL, 0xFB>;

// SHL A/B/C, cnt         31 cnt<<4|9/8/7
// SHLW AX/BC, cnt        31 cnt<<4|D/C
let Defs = [CCreg] in {
def SHL_A_n : RL78Shift<"shl", RegisterOperand<RL78AReg>, shift8imm, 0x9>;
def SHL_B_n : RL78Shift<"shl", RegisterOperand<RL78BReg8>, shift8imm, 0x8>;
def SHL_C_n : RL78Shift<"shl", RegisterOperand<RL78CReg8>, shift8imm, 0x7>;
def SHLW_AX_n : RL78Shift<"shlw", RegisterOperand<RL78AXRP>, shift16imm, 0xD>;
def SHLW_BC_n : RL78Shift<"shlw", RegisterOperand<RL78BCRP>, shift16imm, 0xC>;
}

//===----------------------------------------------------------------------===//
// Selection patterns that use instructions of several sections
//===----------------------------------------------------------------------===//

// Signed compares: the sign bit of a 16-bit value in AX is A.7.
def : Pat<(RL78xorsigncy i8:$a), (XOR1_CY_A_b $a, 7)>;
def : Pat<(RL78xorsigncy i16:$ax), (XOR1_CY_A_b (EXTRACT_SUBREG $ax, sub_hi), 7)>;
def : Pat<(RL78notcy), (NOT1_CY)>;

// Compares with 0.
def : Pat<(RL78ucmp i8:$r, 0), (CMP0_r $r)>;
def : Pat<(RL78ucmp (i8 (load SADDR:$addr)), 0), (CMP0_saddr SADDR:$addr)>;
def : Pat<(RL78ucmp (i8 (load ADDRABS16:$addr)), 0),
          (CMP0_abs16 ADDRABS16:$addr)>;

//===----------------------------------------------------------------------===//
// Loads, stores and immediates
//===----------------------------------------------------------------------===//

def MemRP : ComplexPattern<iPTR, 1, "SelectMemRP", [], []>;
def MemRPi : ComplexPattern<iPTR, 2, "SelectMemRPi", [], []>;
def MemRPi0 : ComplexPattern<iPTR, 2, "SelectMemRPi0", [], []>;
def MemRPw : ComplexPattern<iPTR, 1, "SelectMemRPw", [], []>;
def MemRPiw : ComplexPattern<iPTR, 2, "SelectMemRPiw", [], []>;
def MemBCw : ComplexPattern<iPTR, 2, "SelectMemBCw", [], []>;
def MemHLr : ComplexPattern<iPTR, 2, "SelectMemHLr", [], []>;

def : Pat<(i8 imm:$i), (MOV_r_i8 imm:$i)>;
def : Pat<(i16 imm:$i), (MOVW_rp_i16 imm:$i)>;
foreach Addr = [tglobaladdr, tblockaddress, tjumptable, tconstpool] in {
  def : Pat<(RL78Low16 Addr:$a), (MOVW_rp_i16 Addr:$a)>;
  def : Pat<(RL78Low8 Addr:$a), (MOVW_rp_i16 Addr:$a)>;
}

// Bytes: memory to A (saddr and !addr16 also to X, C, B), A or #byte to
// memory.
def : Pat<(i8 (load SADDR:$a)), (MOV_r_saddr SADDR:$a)>;
def : Pat<(i8 (load ADDRABS16:$a)), (MOV_r_abs16 ADDRABS16:$a)>;
def : Pat<(i8 (atomic_load ADDRABS16:$a)), (MOV_r_abs16 ADDRABS16:$a)>;
def : Pat<(i8 (load SFR:$a)), (MOV_A_sfr SFR:$a)>;
def : Pat<(i8 (load MemRP:$a)), (MOV_A_mRP MemRP:$a)>;
def : Pat<(i8 (load MemRPi:$a)), (MOV_A_mRPi MemRPi:$a)>;
def : Pat<(i8 (load MemHLr:$a)), (MOV_A_mHLr MemHLr:$a)>;
def : Pat<(i8 (load MemBCw:$a)), (MOV_A_mBCw MemBCw:$a)>;
def : Pat<(i8 (load ADDRr8i16:$a)), (MOV_A_mBw ADDRr8i16:$a)>;

def : Pat<(store i8:$v, SADDR:$a), (MOV_saddr_A SADDR:$a, $v)>;
def : Pat<(store i8:$v, ADDRABS16:$a), (MOV_abs16_A ADDRABS16:$a, $v)>;
def : Pat<(store i8:$v, SFR:$a), (MOV_sfr_A SFR:$a, $v)>;
def : Pat<(store i8:$v, MemRP:$a), (MOV_mRP_A MemRP:$a, $v)>;
def : Pat<(store i8:$v, MemRPi:$a), (MOV_mRPi_A MemRPi:$a, $v)>;
def : Pat<(store i8:$v, MemHLr:$a), (MOV_mHLr_A MemHLr:$a, $v)>;
def : Pat<(store i8:$v, MemBCw:$a), (MOV_mBCw_A MemBCw:$a, $v)>;
def : Pat<(store i8:$v, ADDRr8i16:$a), (MOV_mBw_A ADDRr8i16:$a, $v)>;

def : Pat<(store (i8 imm:$i), SADDR:$a), (MOV_saddr_i8 SADDR:$a, imm:$i)>;
def : Pat<(store (i8 imm:$i), ADDRABS16:$a), (MOV_abs16_i8 ADDRABS16:$a, imm:$i)>;
def : Pat<(store (i8 imm:$i), SFR:$a), (MOV_sfr_i8 SFR:$a, imm:$i)>;
def : Pat<(store (i8 imm:$i), MemRPi0:$a), (MOV_mRPi_i8 MemRPi0:$a, imm:$i)>;
def : Pat<(store (i8 imm:$i), MemBCw:$a), (MOV_mBCw_i8 MemBCw:$a, imm:$i)>;
def : Pat<(store (i8 imm:$i), ADDRr8i16:$a), (MOV_mBw_i8 ADDRr8i16:$a, imm:$i)>;
def : Pat<(store (i8 0), SADDR:$a), (CLRB_saddr SADDR:$a)>;
def : Pat<(store (i8 0), ADDRABS16:$a), (CLRB_abs16 ADDRABS16:$a)>;
def : Pat<(store (i8 1), SADDR:$a), (ONEB_saddr SADDR:$a)>;
def : Pat<(store (i8 1), ADDRABS16:$a), (ONEB_abs16 ADDRABS16:$a)>;

// Words: memory to AX (saddrp and !addr16 to any pair), AX to memory.
def : Pat<(i16 (load SADDR:$a)), (MOVW_rp_saddrp SADDR:$a)>;
def : Pat<(i16 (load ADDRABS16:$a)), (MOVW_rp_abs16 ADDRABS16:$a)>;
def : Pat<(i16 (load SFR:$a)), (MOVW_AX_sfrp SFR:$a)>;
def : Pat<(i16 (load MemRPw:$a)), (MOVW_AX_mRP MemRPw:$a)>;
def : Pat<(i16 (load MemRPiw:$a)), (MOVW_AX_mRPi MemRPiw:$a)>;
def : Pat<(i16 (load MemBCw:$a)), (MOVW_AX_mBCw MemBCw:$a)>;
def : Pat<(i16 (load ADDRr8i16:$a)), (MOVW_AX_mBw ADDRr8i16:$a)>;

def : Pat<(store i16:$v, SADDR:$a), (MOVW_saddrp_AX SADDR:$a, $v)>;
def : Pat<(store i16:$v, ADDRABS16:$a), (MOVW_abs16_AX ADDRABS16:$a, $v)>;
def : Pat<(store i16:$v, SFR:$a), (MOVW_sfrp_AX SFR:$a, $v)>;
def : Pat<(store i16:$v, MemRPw:$a), (MOVW_mRP_AX MemRPw:$a, $v)>;
def : Pat<(store i16:$v, MemRPiw:$a), (MOVW_mRPi_AX MemRPiw:$a, $v)>;
def : Pat<(store i16:$v, MemBCw:$a), (MOVW_mBCw_AX MemBCw:$a, $v)>;
def : Pat<(store i16:$v, ADDRr8i16:$a), (MOVW_mBw_AX ADDRr8i16:$a, $v)>;
def : Pat<(store (i16 imm:$i), SADDR:$a), (MOVW_saddrp_i16 SADDR:$a, imm:$i)>;
def : Pat<(store (i16 imm:$i), SFR:$a), (MOVW_sfrp_i16 SFR:$a, imm:$i)>;

// The stack: MOV/MOVW with [SP+byte], through A and AX. The frame index is in
// the place of SP until frame index elimination. (The allocator's spill code
// uses the *_stack_slot pseudos, which take any register.)
def : Pat<(i8 (load ADDRSPi:$a)), (MOV_A_mSPi ADDRSPi:$a)>;
def : Pat<(store i8:$v, ADDRSPi:$a), (MOV_mSPi_A ADDRSPi:$a, $v)>;
def : Pat<(store (i8 imm:$i), ADDRSPi:$a), (MOV_mSPi_i8 ADDRSPi:$a, imm:$i)>;
def : Pat<(i16 (load ADDRSPi:$a)), (MOVW_AX_mSPi ADDRSPi:$a)>;
def : Pat<(store i16:$v, ADDRSPi:$a), (MOVW_mSPi_AX ADDRSPi:$a, $v)>;

//===----------------------------------------------------------------------===//
// 8-bit operations on saddr, bit operations, control
//===----------------------------------------------------------------------===//

multiclass RL78SaddrOpSel<string I, SDPatternOperator Node> {
  def : Pat<(store (Node (load SADDR:$a), (i8 imm:$i)), SADDR:$a),
            (!cast<Instruction>(I # "_saddr_i8") SADDR:$a, imm:$i)>;
}
defm : RL78SaddrOpSel<"ADD", add>;
defm : RL78SaddrOpSel<"ADDC", addc>;
defm : RL78SaddrOpSel<"SUB", sub>;
defm : RL78SaddrOpSel<"SUBC", subc>;
defm : RL78SaddrOpSel<"AND", and>;
defm : RL78SaddrOpSel<"OR", or>;
defm : RL78SaddrOpSel<"XOR", xor>;

// SET1/CLR1 of a bit in memory; CY from, into, and combined with a bit.
multiclass RL78BitMemSel<string I, SDPatternOperator Node, bit HasAbs,
                         bit HasSfr> {
  def : Pat<(Node (i8 imm:$b), SADDR:$a),
            (!cast<Instruction>(I # "_saddr_b") SADDR:$a, imm:$b)>;
  def : Pat<(Node (i8 imm:$b), ADDRr:$a),
            (!cast<Instruction>(I # "_mHL_b") ADDRr:$a, imm:$b)>;
  if HasAbs then
  def : Pat<(Node (i8 imm:$b), ADDRABS16:$a),
            (!cast<Instruction>(I # "_abs16_b") ADDRABS16:$a, imm:$b)>;
  if HasSfr then
  def : Pat<(Node (i8 imm:$b), SFR:$a),
            (!cast<Instruction>(I # "_sfr_b") SFR:$a, imm:$b)>;
}
defm : RL78BitMemSel<"SET1", set1, 1, 1>;
defm : RL78BitMemSel<"CLR1", clr1, 1, 1>;
defm : RL78BitMemSel<"AND1_CY", and1cy, 0, 0>;
defm : RL78BitMemSel<"OR1_CY", or1cy, 0, 0>;
defm : RL78BitMemSel<"XOR1_CY", xor1cy, 0, 0>;
defm : RL78BitMemSel<"MOV1_CY", load1tocy, 0, 1>;
defm : RL78BitMemSel<"MOV1", store1fromcy, 0, 1>;
def : Pat<(mov1tocy i8:$a, (i8 imm:$b)), (MOV1_CY_A_b $a, imm:$b)>;
def : Pat<(mov1tocy (i8 (load SADDR:$a)), (i8 imm:$b)),
          (MOV1_CY_saddr_b SADDR:$a, imm:$b)>;
def : Pat<(mov1fromcy i8:$a, (i8 imm:$b), CCreg), (MOV1_A_b $a, imm:$b)>;
def : Pat<(not1cy), (NOT1_CY)>;

def : Pat<(int_rl78_nop), (NOP)>;
def : Pat<(int_rl78_halt), (HALT)>;
def : Pat<(int_rl78_stop), (STOP)>;
def : Pat<(int_rl78_ei), (EI)>;
def : Pat<(int_rl78_di), (DI)>;
def : Pat<(int_rl78_brk), (BRK)>;
def : Pat<(ret), (RET)>;
def : Pat<(reti), (RETI)>;
def : Pat<(retb), (RETB)>;

//===----------------------------------------------------------------------===//
// 16-bit operations made of two 8-bit ones
//===----------------------------------------------------------------------===//

// A 16-bit rotate by one: MOV1 CY, A.7 + ROLWC AX, 1 to the left and
// SHRW AX, 1 + MOV1 A.7, CY to the right.
let Constraints = "$rs = $rd", Defs = [CCreg] in {
def ROLW_AX_1 : RL78Pseudo<4, (outs RL78AXRP:$rd), (ins RL78AXRP:$rs)>;
def RORW_AX_1 : RL78Pseudo<4, (outs RL78AXRP:$rd), (ins RL78AXRP:$rs)>;
}

// A word rotated to the right by one through CY, for the words below the
// top one of a shift to the right by one: RORC A, 1 on each byte.
let Constraints = "$rs = $rd", Defs = [CCreg], Uses = [CCreg] in
def RORWC_AX_1 : RL78Pseudo<6, (outs RL78AXRP:$rd), (ins RL78AXRP:$rs),
                            [(set i16:$rd, (rl78rorwc i16:$rs))]>;
def : Pat<(rl78srlc i16:$x), (SHRW_AX_n $x, 1)>;
def : Pat<(rl78srac i16:$x), (SARW_AX_n $x, 1)>;

// CY into bit 15 of AX (MOV1 A.7, CY): the bit that went round in a rotate
// of several words to the right by one.
let Constraints = "$rs = $rd", Uses = [CCreg], OneInst = 1 in
def MOV1_AX_15_CY : RL78Pseudo<2, (outs RL78AXRP:$rd), (ins RL78AXRP:$rs),
                               [(set i16:$rd, (rl78cy15 i16:$rs))]>;

// A word at [HL+byte] whose second byte is also in reach.
def MemHLw : ComplexPattern<iPTR, 2, "SelectMemHLw", [], []>;

// AND, OR, XOR and the add/subtract with carry of the upper words of 32-bit
// values have no 16-bit form: the operation is done on A, then on X with
// XCH A, X around it (RL78InstrInfo::expandPostRAPseudo). Node is the
// operation on registers and constants, MemNode with a word in memory.
multiclass RL78Wide<SDPatternOperator Node, SDPatternOperator MemNode,
                    bit Carry = 0> {
  let Constraints = "$rs = $rd" in {
  def _AX_rp : RL78Pseudo<6, (outs RL78AXRP:$rd),
                          (ins RL78AXRP:$rs, RL78BCDEHL:$rp),
                          [(set i16:$rd, (Node i16:$rs, i16:$rp))]>;
  // With carry, #0 and #FFFFH are INCW/DECW under a branch when the carry
  // out is unused (custom inserter).
  let usesCustomInserter = Carry in
  def _AX_i16 : RL78Pseudo<6, (outs RL78AXRP:$rd),
                           (ins RL78AXRP:$rs, i16imm:$imm),
                           [(set i16:$rd, (Node i16:$rs, (i16 imm:$imm)))]>;
  let mayLoad = 1 in {
  def _AX_mHLi : RL78Pseudo<6, (outs RL78AXRP:$rd),
                            (ins RL78AXRP:$rs, memHLi:$addr),
                            [(set i16:$rd,
                              (MemNode i16:$rs, (load MemHLw:$addr)))]>;
  def _AX_abs16 : RL78Pseudo<8, (outs RL78AXRP:$rd),
                             (ins RL78AXRP:$rs, addr16w:$addr),
                             [(set i16:$rd,
                               (MemNode i16:$rs, (load ADDRABS16:$addr)))]>;
  }
  }
}
let Defs = [CCreg] in {
defm AND16 : RL78Wide<and, andmem>;
defm OR16 : RL78Wide<or, ormem>;
defm XOR16 : RL78Wide<xor, xormem>;
let Uses = [CCreg] in {
defm ADDE : RL78Wide<adde, adde, 1>;
defm SUBE : RL78Wide<sube, sube, 1>;
}
}
def : Pat<(andmem i16:$a, i16:$rp), (AND16_AX_rp $a, $rp)>;
def : Pat<(ormem i16:$a, i16:$rp), (OR16_AX_rp $a, $rp)>;
def : Pat<(xormem i16:$a, i16:$rp), (XOR16_AX_rp $a, $rp)>;

// A value of several words added to itself (its shift to the left by one,
// RL78TargetLowering::ReplaceNodeResults): SHLW AX, 1 for the lowest word,
// then the carry goes through each word above with ROLWC.
let AddedComplexity = 20 in {
def : Pat<(addc i16:$x, i16:$x), (SHLW_AX_n $x, 1)>;
def : Pat<(adde i16:$x, i16:$x), (ROLWC_rp_1 $x)>;
}

// The high half of an i32 add of a 16-bit constant is adde(hi, 0): only the
// carry. ADDE_rp_imm turns that into BNC + INCW, but when hi is a load the
// commuted memory form adde(0, (load ...)) wins on complexity and adds the
// carry byte by byte through A (x[i]++ on a 32-bit counter in memory: 15
// instructions instead of 7). Prefer the immediate form for 0 and -1.
def immCarryOnly : PatLeaf<(imm), [{
  uint64_t V = N->getZExtValue() & 0xFFFF;
  return V == 0 || V == 0xFFFF;
}]>;
let AddedComplexity = 100 in
def : Pat<(adde i16:$rsrc, (i16 immCarryOnly:$imm)),
          (ADDE_AX_i16 $rsrc, imm:$imm)>;

// ~x is -1 - x: MOVW AX, #FFFFH and SUBW AX, rp are shorter than two XORs.
let AddedComplexity = 10 in
def : Pat<(not i16:$x), (SUBW_AX_rp (MOVW_rp_i16 -1), $x)>;

//===----------------------------------------------------------------------===//
// Shifts by a constant, rotates by one, extensions
//===----------------------------------------------------------------------===//

def : Pat<(shl i8:$r, (i8 imm:$n)), (SHL_r_n $r, imm:$n)>;
def : Pat<(srl i8:$a, (i8 imm:$n)), (SHR_A_n $a, imm:$n)>;
def : Pat<(sra i8:$a, (i8 imm:$n)), (SAR_A_n $a, imm:$n)>;
def : Pat<(shl i16:$rp, (i8 imm:$n)), (SHLW_rp_n $rp, imm:$n)>;
def : Pat<(srl i16:$ax, (i8 imm:$n)), (SHRW_AX_n $ax, imm:$n)>;
def : Pat<(sra i16:$ax, (i8 imm:$n)), (SARW_AX_n $ax, imm:$n)>;
def : Pat<(int_rl78_rol1 i8:$a), (ROL_A_1 $a)>;
def : Pat<(int_rl78_ror1 i8:$a), (ROR_A_1 $a)>;

// A byte extended to a word: the byte in the low half and 0 in the high
// half, or the byte in A and SARW AX, 8.
def : Pat<(i16 (zext i8:$r)),
          (INSERT_SUBREG (INSERT_SUBREG (i16 (IMPLICIT_DEF)), $r, sub_lo),
                         (MOV_r_i8 0), sub_hi)>;
def : Pat<(i16 (anyext i8:$r)),
          (INSERT_SUBREG (INSERT_SUBREG (i16 (IMPLICIT_DEF)), $r, sub_lo),
                         (MOV_r_i8 0), sub_hi)>;
def : Pat<(i16 (sext i8:$r)),
          (SARW_AX_n (INSERT_SUBREG (i16 (IMPLICIT_DEF)), $r, sub_hi), 8)>;

//===----------------------------------------------------------------------===//
// The ES: forms
//===----------------------------------------------------------------------===//

// A far address is (RL78Hi16 segment, near address). Each of these matches
// one and yields the ES operand (the result of a MOV ES, ...; see
// RL78AssignES) followed by the operands of the near form.
def ESAbs16 : ComplexPattern<iPTR, 2, "SelectESAbs16", [], []>;
def ESMemHL : ComplexPattern<iPTR, 2, "SelectESMemHL", [], []>;
def ESMemHLi : ComplexPattern<iPTR, 3, "SelectESMemHLi", [], []>;
def ESMemHLi0 : ComplexPattern<iPTR, 3, "SelectESMemHLi0", [], []>;
def ESMemHLr : ComplexPattern<iPTR, 3, "SelectESMemHLr", [], []>;
def ESMemRP : ComplexPattern<iPTR, 2, "SelectESMemRP", [], []>;
def ESMemRPi : ComplexPattern<iPTR, 3, "SelectESMemRPi", [], []>;
def ESMemRPi0 : ComplexPattern<iPTR, 3, "SelectESMemRPi0", [], []>;
def ESMemBCw : ComplexPattern<iPTR, 3, "SelectESMemBCw", [], []>;
def ESMemBw : ComplexPattern<iPTR, 3, "SelectESMemBw", [], []>;
def ESHL : ComplexPattern<iPTR, 2, "SelectESHL", [], []>;

multiclass RL78Alu8ESSel<string I, SDPatternOperator Node> {
  def : Pat<(Node i8:$a, (load ESAbs16:$m)),
            (!cast<Instruction>(I # "_A_eabs16") $a, ESAbs16:$m)>;
  def : Pat<(Node i8:$a, (load ESMemHL:$m)),
            (!cast<Instruction>(I # "_A_emHL") $a, ESMemHL:$m)>;
  def : Pat<(Node i8:$a, (load ESMemHLi:$m)),
            (!cast<Instruction>(I # "_A_emHLi") $a, ESMemHLi:$m)>;
  def : Pat<(Node i8:$a, (load ESMemHLr:$m)),
            (!cast<Instruction>(I # "_A_emHLr") $a, ESMemHLr:$m)>;
}
defm : RL78Alu8ESSel<"ADD", add>;
defm : RL78Alu8ESSel<"SUB", sub>;
defm : RL78Alu8ESSel<"AND", and>;
defm : RL78Alu8ESSel<"OR", or>;
defm : RL78Alu8ESSel<"XOR", xor>;
defm : RL78Alu8ESSel<"CMP", RL78ucmp>;
def : Pat<(RL78ucmp (load ESAbs16:$m), (i8 imm:$i)),
          (CMP_eabs16_i8 ESAbs16:$m, imm:$i)>;
def : Pat<(RL78ucmp (i8 (load ESAbs16:$m)), 0), (CMP0_eabs16 ESAbs16:$m)>;

multiclass RL78Alu16ESSel<string I, SDPatternOperator Node> {
  def : Pat<(Node i16:$a, (load ESAbs16:$m)),
            (!cast<Instruction>(I # "_AX_eabs16") $a, ESAbs16:$m)>;
  def : Pat<(Node i16:$a, (load ESMemHLi0:$m)),
            (!cast<Instruction>(I # "_AX_emHLi") $a, ESMemHLi0:$m)>;
}
defm : RL78Alu16ESSel<"ADDW", add>;
defm : RL78Alu16ESSel<"SUBW", sub>;
defm : RL78Alu16ESSel<"ADDW", addc>;
defm : RL78Alu16ESSel<"SUBW", subc>;
defm : RL78Alu16ESSel<"CMPW", RL78ucmp>;

multiclass RL78IncDecESSel<string I, ValueType VT, int By> {
  def : Pat<(store (add (VT (load ESAbs16:$m)), By), ESAbs16:$m),
            (!cast<Instruction>(I # "_eabs16") ESAbs16:$m)>;
  def : Pat<(store (add (VT (load ESMemHLi0:$m)), By), ESMemHLi0:$m),
            (!cast<Instruction>(I # "_emHLi") ESMemHLi0:$m)>;
}
defm : RL78IncDecESSel<"INC", i8, 1>;
defm : RL78IncDecESSel<"DEC", i8, -1>;
defm : RL78IncDecESSel<"INCW", i16, 1>;
defm : RL78IncDecESSel<"DECW", i16, -1>;

def : Pat<(i8 (load ESAbs16:$m)), (MOV_r_eabs16 ESAbs16:$m)>;
def : Pat<(i8 (load ESMemRP:$m)), (MOV_A_emRP ESMemRP:$m)>;
def : Pat<(i8 (load ESMemRPi:$m)), (MOV_A_emRPi ESMemRPi:$m)>;
def : Pat<(i8 (load ESMemHLr:$m)), (MOV_A_emHLr ESMemHLr:$m)>;
def : Pat<(i8 (load ESMemBCw:$m)), (MOV_A_emBCw ESMemBCw:$m)>;
def : Pat<(i8 (load ESMemBw:$m)), (MOV_A_emBw ESMemBw:$m)>;
def : Pat<(store i8:$v, ESAbs16:$m), (MOV_eabs16_A ESAbs16:$m, $v)>;
def : Pat<(store i8:$v, ESMemRP:$m), (MOV_emRP_A ESMemRP:$m, $v)>;
def : Pat<(store i8:$v, ESMemRPi:$m), (MOV_emRPi_A ESMemRPi:$m, $v)>;
def : Pat<(store i8:$v, ESMemHLr:$m), (MOV_emHLr_A ESMemHLr:$m, $v)>;
def : Pat<(store i8:$v, ESMemBCw:$m), (MOV_emBCw_A ESMemBCw:$m, $v)>;
def : Pat<(store i8:$v, ESMemBw:$m), (MOV_emBw_A ESMemBw:$m, $v)>;
def : Pat<(store (i8 imm:$i), ESAbs16:$m), (MOV_eabs16_i8 ESAbs16:$m, imm:$i)>;
def : Pat<(store (i8 imm:$i), ESMemRPi0:$m),
          (MOV_emRPi_i8 ESMemRPi0:$m, imm:$i)>;
def : Pat<(store (i8 imm:$i), ESMemBCw:$m), (MOV_emBCw_i8 ESMemBCw:$m, imm:$i)>;
def : Pat<(store (i8 imm:$i), ESMemBw:$m), (MOV_emBw_i8 ESMemBw:$m, imm:$i)>;
def : Pat<(store (i8 0), ESAbs16:$m), (CLRB_eabs16 ESAbs16:$m)>;
def : Pat<(store (i8 1), ESAbs16:$m), (ONEB_eabs16 ESAbs16:$m)>;

def : Pat<(i16 (load ESAbs16:$m)), (MOVW_rp_eabs16 ESAbs16:$m)>;
def : Pat<(i16 (load ESMemRP:$m)), (MOVW_AX_emRP ESMemRP:$m)>;
def : Pat<(i16 (load ESMemRPi:$m)), (MOVW_AX_emRPi ESMemRPi:$m)>;
def : Pat<(i16 (load ESMemBCw:$m)), (MOVW_AX_emBCw ESMemBCw:$m)>;
def : Pat<(i16 (load ESMemBw:$m)), (MOVW_AX_emBw ESMemBw:$m)>;
def : Pat<(store i16:$v, ESAbs16:$m), (MOVW_eabs16_AX ESAbs16:$m, $v)>;
def : Pat<(store i16:$v, ESMemRP:$m), (MOVW_emRP_AX ESMemRP:$m, $v)>;
def : Pat<(store i16:$v, ESMemRPi:$m), (MOVW_emRPi_AX ESMemRPi:$m, $v)>;
def : Pat<(store i16:$v, ESMemBCw:$m), (MOVW_emBCw_AX ESMemBCw:$m, $v)>;
def : Pat<(store i16:$v, ESMemBw:$m), (MOVW_emBw_AX ESMemBw:$m, $v)>;

def : Pat<(set1 (i8 imm:$b), ESAbs16:$m), (SET1_eabs16_b ESAbs16:$m, imm:$b)>;
def : Pat<(set1 (i8 imm:$b), ESHL:$m), (SET1_emHL_b ESHL:$m, imm:$b)>;
def : Pat<(clr1 (i8 imm:$b), ESAbs16:$m), (CLR1_eabs16_b ESAbs16:$m, imm:$b)>;
def : Pat<(clr1 (i8 imm:$b), ESHL:$m), (CLR1_emHL_b ESHL:$m, imm:$b)>;

// SEL RBn.
def : Pat<(sel_rb i8:$rb), (SEL_RBn i8:$rb)>;
