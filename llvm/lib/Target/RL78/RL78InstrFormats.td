//===-- RL78InstrFormats.td - RL78 Instruction Formats ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// A hardware instruction: one form of the RL78 Software Manual's operation
// list (R01US0015), with the exact register class for each register operand.
// Byte I of the encoding is Inst{8*I+7-8*I}, so the first byte is in the low
// bits and little-endian data fields (adrl adrh) are contiguous.
class RL78Inst<int size, dag outs, dag ins, string asmstr,
               list<dag> pattern = []> : Instruction {
  let Namespace = "RL78";
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
  let Size = size;
  let hasSideEffects = 0;
  let mayLoad = 0;
  let mayStore = 0;
  let DecoderNamespace = "RL78";
  field bits<40> Inst;
  field bits<40> SoftFail = 0;
  // A hardware instruction (RL78II::Hardware).
  let TSFlags{0} = 1;
  // Operands of a single-register class are not encoded: the disassembler
  // supplies the register (Decode<Class>RegisterClass without a value).
  bits<0> a;
  bits<0> ad;
  bits<0> as;
  bits<0> ax;
  bits<0> axd;
  bits<0> axs;
  bits<0> x;
  bits<0> hl;
  bits<0> es;
  bits<0> cs;
  bits<0> psw;
  bits<0> sp;
  bits<0> sd;
  bits<0> ss;
  bits<0> base;
}

// An instruction whose $rd and $rs are fixed registers (A, AX, ...).
class RL78FixedRdRs {
  bits<0> rd;
  bits<0> rs;
}

// An instruction for code generation only, with exact operand classes like
// the hardware instructions. Size is that of the hardware instructions it
// becomes when that is known in advance, 0 otherwise.
class RL78Pseudo<int size, dag outs, dag ins, list<dag> pattern = []>
    : Instruction {
  let Namespace = "RL78";
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = "";
  let Pattern = pattern;
  let Size = size;
  let isCodeGenOnly = 1;
  let isPseudo = 1;
  let hasSideEffects = 0;
  let mayLoad = 0;
  let mayStore = 0;
  // Stands for exactly one hardware instruction (RL78II::OneInst): a
  // conditional skip may be placed in front of it.
  bit OneInst = 0;
  let TSFlags{1} = OneInst;
}
