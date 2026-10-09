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
//   saddr, abs16    saddr (FFE20H-FFF1FH), !addr16
//   mHL, mHLi       [HL], [HL+byte]
//   mHLr            [HL+B], [HL+C]
//   e...            the same behind the ES: prefix (11H)
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Operands
//===----------------------------------------------------------------------===//

// #byte
def imm8 : Operand<i8> {
  let EncoderMethod = "getImm8OpValue";
  let OperandType = "OPERAND_IMMEDIATE";
}

// #word
def imm16 : Operand<i16> {
  let EncoderMethod = "getImm16OpValue";
  let OperandType = "OPERAND_IMMEDIATE";
}

// saddr: FFE20H-FFF1FH, encoded as the low byte.
def saddr8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrOpValue";
}

// saddrp: a word in the saddr area (even address).
def saddrp8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrpOpValue";
}

// !addr16 of a word (even address).
def addr16w : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16wOpValue";
}

// ES:!addr16 of a word.
def esaddr16w : Operand<iPTR> {
  let PrintMethod = "printEsAddr16Operand";
  let ParserMatchClass = RL78EsAddrAsmOperand;
  let EncoderMethod = "getESAddr16wOpValue";
  let MIOperandInfo = (ops RL78RegES, i16imm);
}

// !addr16: F0000H-FFFFFH.
def addr16 : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
  let EncoderMethod = "getAddr16OpValue";
}

// ES:!addr16
def esaddr16 : Operand<iPTR> {
  let PrintMethod = "printEsAddr16Operand";
  let ParserMatchClass = RL78EsAddrAsmOperand;
  let EncoderMethod = "getESAddr16OpValue";
  let MIOperandInfo = (ops RL78RegES, i16imm);
}

def MemHLiAsmOperand : AsmOperandClass { let Name = "MemHLi"; }
def MemHLAsmOperand : AsmOperandClass {
  let Name = "MemHL";
  let SuperClasses = [MemHLiAsmOperand];
}
def MemHLrAsmOperand : AsmOperandClass { let Name = "MemHLr"; }
def ESMemHLiAsmOperand : AsmOperandClass { let Name = "ESMemHLi"; }
def ESMemHLAsmOperand : AsmOperandClass {
  let Name = "ESMemHL";
  let SuperClasses = [ESMemHLiAsmOperand];
}
def ESMemHLrAsmOperand : AsmOperandClass { let Name = "ESMemHLr"; }

// [HL]
def memHL : Operand<iPTR> {
  let PrintMethod = "printMemReg";
  let ParserMatchClass = MemHLAsmOperand;
  let MIOperandInfo = (ops RL78HL);
}

// [HL+byte]
def memHLi : Operand<iPTR> {
  let PrintMethod = "printMemRegDisp";
  let ParserMatchClass = MemHLiAsmOperand;
  let EncoderMethod = "getMemDisp8OpValue";
  let MIOperandInfo = (ops RL78HL, i8imm);
}

// [HL+B], [HL+C]
def memHLr : Operand<iPTR> {
  let PrintMethod = "printMemRegReg";
  let ParserMatchClass = MemHLrAsmOperand;
  let EncoderMethod = "getMemIndexOpValue";
  let MIOperandInfo = (ops RL78HL, RL78BCReg);
}

// ES:[HL]
def esmemHL : Operand<iPTR> {
  let PrintMethod = "printESMemReg";
  let ParserMatchClass = ESMemHLAsmOperand;
  let MIOperandInfo = (ops RL78RegES, RL78HL);
}

// ES:[HL+byte]
def esmemHLi : Operand<iPTR> {
  let PrintMethod = "printESMemRegDisp";
  let ParserMatchClass = ESMemHLiAsmOperand;
  let EncoderMethod = "getESMemDisp8OpValue";
  let MIOperandInfo = (ops RL78RegES, RL78HL, i8imm);
}

// ES:[HL+B], ES:[HL+C]
def esmemHLr : Operand<iPTR> {
  let PrintMethod = "printESMemRegReg";
  let ParserMatchClass = ESMemHLrAsmOperand;
  let EncoderMethod = "getESMemIndexOpValue";
  let MIOperandInfo = (ops RL78RegES, RL78HL, RL78BCReg);
}

//===----------------------------------------------------------------------===//
// 8-bit operations (manual 6.3): ADD, ADDC, SUB, SUBC, AND, OR, XOR, CMP
//===----------------------------------------------------------------------===//

// Op is the operation's row in the opcode map (ADD 0 ... XOR 7, CMP 4): its
// opcodes are Op<<4 | form. CMP writes only the flags; the others write A (or
// r, or saddr) and the flags. ADDC and SUBC also read CY.
multiclass RL78Alu8<string Mn, bits<4> Op, bit IsCmp> {
  defvar A = !if(IsCmp, (outs), (outs RL78AReg:$rd));
  defvar Dst = !if(IsCmp, "$rs", "$rd");
  defvar Tie = !if(IsCmp, "", "$rs = $rd");

  let Constraints = Tie in {
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
  // Mn A, saddr          Op B saddr
  def _A_saddr : RL78Inst<2, A, (ins RL78AReg:$rs, saddr8:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 1, 0, 1, 1};
    let Inst{15-8} = addr;
    let mayLoad = 1;
  }
  // Mn A, !addr16        Op F adrl adrh
  def _A_abs16 : RL78Inst<3, A, (ins RL78AReg:$rs, addr16:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Op, 1, 1, 1, 1};
    let Inst{23-8} = addr;
    let mayLoad = 1;
  }
  // Mn A, [HL]           Op D
  def _A_mHL : RL78Inst<1, A, (ins RL78AReg:$rs, memHL:$addr),
                        Mn # " " # Dst # ", $addr"> {
    let Inst{7-0} = {Op, 1, 1, 0, 1};
    let mayLoad = 1;
  }
  // Mn A, [HL+byte]      Op E adr
  def _A_mHLi : RL78Inst<2, A, (ins RL78AReg:$rs, memHLi:$addr),
                         Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 1, 1, 1, 0};
    let Inst{15-8} = addr;
    let mayLoad = 1;
  }
  // Mn A, [HL+B]/[HL+C]  61 8+Op 0/2
  def _A_mHLr : RL78Inst<2, A, (ins RL78AReg:$rs, memHLr:$addr),
                         Mn # " " # Dst # ", $addr"> {
    bits<2> addr;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {1, Op{2-0}, 0, 0, addr};
    let mayLoad = 1;
  }
  // Mn A, ES:!addr16     11 Op F adrl adrh
  def _A_eabs16 : RL78Inst<4, A, (ins RL78AReg:$rs, esaddr16:$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 1};
    let Inst{31-16} = addr;
    let mayLoad = 1;
  }
  // Mn A, ES:[HL]        11 Op D
  def _A_emHL : RL78Inst<2, A, (ins RL78AReg:$rs, esmemHL:$addr),
                         Mn # " " # Dst # ", $addr"> {
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 0, 1};
    let mayLoad = 1;
  }
  // Mn A, ES:[HL+byte]   11 Op E adr
  def _A_emHLi : RL78Inst<3, A, (ins RL78AReg:$rs, esmemHLi:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 1, 1, 1, 0};
    let Inst{23-16} = addr;
    let mayLoad = 1;
  }
  // Mn A, ES:[HL+B]/[HL+C]  11 61 8+Op 0/2
  def _A_emHLr : RL78Inst<3, A, (ins RL78AReg:$rs, esmemHLr:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<2> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = {1, Op{2-0}, 0, 0, addr};
    let mayLoad = 1;
  }
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

// CMP !addr16, #byte     40 adrl adrh data
def CMP_abs16_i8 : RL78Inst<4, (outs), (ins addr16:$addr, imm8:$imm),
                            "cmp $addr, $imm"> {
  bits<16> addr;
  bits<8> imm;
  let Inst{7-0} = 0x40;
  let Inst{23-8} = addr;
  let Inst{31-24} = imm;
  let mayLoad = 1;
}
// CMP ES:!addr16, #byte  11 40 adrl adrh data
def CMP_eabs16_i8 : RL78Inst<5, (outs), (ins esaddr16:$addr, imm8:$imm),
                             "cmp $addr, $imm"> {
  bits<16> addr;
  bits<8> imm;
  let Inst{7-0} = 0x11;
  let Inst{15-8} = 0x40;
  let Inst{31-16} = addr;
  let Inst{39-32} = imm;
  let mayLoad = 1;
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
  // Mn AX, saddrp        Op 6 saddr
  def _AX_saddrp : RL78Inst<2, AX, (ins RL78AXRP:$rs, saddrp8:$addr),
                            Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = {Op, 0, 1, 1, 0};
    let Inst{15-8} = addr;
    let mayLoad = 1;
  }
  // Mn AX, !addr16       Op 2 adrl adrh
  def _AX_abs16 : RL78Inst<3, AX, (ins RL78AXRP:$rs, addr16w:$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = {Op, 0, 0, 1, 0};
    let Inst{23-8} = addr;
    let mayLoad = 1;
  }
  // Mn AX, [HL+byte]     61 Op9 adr
  def _AX_mHLi : RL78Inst<3, AX, (ins RL78AXRP:$rs, memHLi:$addr),
                          Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = {Op, 1, 0, 0, 1};
    let Inst{23-16} = addr;
    let mayLoad = 1;
  }
  // Mn AX, ES:!addr16    11 Op2 adrl adrh
  def _AX_eabs16 : RL78Inst<4, AX, (ins RL78AXRP:$rs, esaddr16w:$addr),
                            Mn # " " # Dst # ", $addr"> {
    bits<16> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 0, 0, 1, 0};
    let Inst{31-16} = addr;
    let mayLoad = 1;
  }
  // Mn AX, ES:[HL+byte]  11 61 Op9 adr
  def _AX_emHLi : RL78Inst<4, AX, (ins RL78AXRP:$rs, esmemHLi:$addr),
                           Mn # " " # Dst # ", $addr"> {
    bits<8> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = {Op, 1, 0, 0, 1};
    let Inst{31-24} = addr;
    let mayLoad = 1;
  }
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
// [HL+byte] form (61 Mem2).
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
  def _mHLi : RL78Inst<3, (outs), (ins memHLi:$addr), Mn # " $addr"> {
    bits<8> addr;
    let Inst{7-0} = 0x61;
    let Inst{15-8} = Mem2;
    let Inst{23-16} = addr;
  }
  // Mn ES:!addr16        11 Mem 0 adrl adrh
  def _eabs16 : RL78Inst<4, (outs), (ins ESAbs:$addr), Mn # " $addr"> {
    bits<16> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Mem, 0, 0, W, 0};
    let Inst{31-16} = addr;
  }
  // Mn ES:[HL+byte]      11 61 Mem2 adr
  def _emHLi : RL78Inst<4, (outs), (ins esmemHLi:$addr), Mn # " $addr"> {
    bits<8> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = 0x61;
    let Inst{23-16} = Mem2;
    let Inst{31-24} = addr;
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
  def _eabs16 : RL78Inst<4, (outs), (ins esaddr16:$addr), Mn # " $addr"> {
    bits<16> addr;
    let Inst{7-0} = 0x11;
    let Inst{15-8} = {Op, 0, 1, 0, 1};
    let Inst{31-16} = addr;
  }
  }
}

let Defs = [CCreg] in
defm CMP0 : RL78ByteOp<"cmp0", 0xD, 1>;
defm CLRB : RL78ByteOp<"clrb", 0xF, 0>;
let isReMaterializable = 1 in
defm ONEB : RL78ByteOp<"oneb", 0xE, 0>;

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
def CMPS_X_mHLi : RL78Inst<3, (outs), (ins RL78XReg:$x, memHLi:$addr),
                           "cmps $x, $addr"> {
  bits<8> addr;
  let Inst{15-0} = 0xDE61;
  let Inst{23-16} = addr;
}
def CMPS_X_emHLi : RL78Inst<4, (outs), (ins RL78XReg:$x, esmemHLi:$addr),
                            "cmps $x, $addr"> {
  bits<8> addr;
  let Inst{23-0} = 0xDE6111;
  let Inst{31-24} = addr;
}
}

// MOVS [HL+byte], X      61 CE adr
// MOVS ES:[HL+byte], X   11 61 CE adr
// Also sets Z (X or A zero) and CY (X zero), so it reads A.
let Defs = [CCreg], Uses = [R1], mayStore = 1 in {
def MOVS_mHLi_X : RL78Inst<3, (outs), (ins memHLi:$addr, RL78XReg:$x),
                           "movs $addr, $x"> {
  bits<8> addr;
  let Inst{15-0} = 0xCE61;
  let Inst{23-16} = addr;
}
def MOVS_emHLi_X : RL78Inst<4, (outs), (ins esmemHLi:$addr, RL78XReg:$x),
                            "movs $addr, $x"> {
  bits<8> addr;
  let Inst{23-0} = 0xCE6111;
  let Inst{31-24} = addr;
}
}
