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

// saddr: FFE20H-FFF1FH, encoded as the low byte.
def saddr8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
  let EncoderMethod = "getSaddrOpValue";
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
