//===-- RL78InstrFormats.td - RL78 Instruction Formats ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

class InstRL78<dag outs, dag ins, string asmstr, list<dag> pattern>
   : Instruction 
{
  let Namespace = "RL78";

  dag OutOperandList = outs;
  dag InOperandList = ins;
  let AsmString   = asmstr;
  let Pattern = pattern;

  // OBS: this changes the conservative default (of 1) as most of the RL78 instructions don't have side effects,
  // meaning that the instructions that do have side effects have to be marked with hasSideEffects = 1 explicitly
  let hasSideEffects = 0;
}

class InstRL78_8bit<field bits<8> inst, dag outs, dag ins, string asmstr, list<dag> pattern> 
  : InstRL78<outs, ins, asmstr, pattern>
{
  field bits<8> Inst = inst;
  // Lets the disassembler reject an encoding without failing the whole decode.
  // TableGen requires it to have the same width as Inst.
  field bits<8> SoftFail = 0;
  let Size = 1;
}

class InstRL78_16bit<field bits<16> inst, dag outs, dag ins, string asmstr, list<dag> pattern> 
  : InstRL78<outs, ins, asmstr, pattern>
{
  field bits<16> Inst = inst;
  // Lets the disassembler reject an encoding without failing the whole decode.
  // TableGen requires it to have the same width as Inst.
  field bits<16> SoftFail = 0;
  let Size = 2;
}

class InstRL78_24bit<field bits<24> inst, dag outs, dag ins, string asmstr, list<dag> pattern> 
  : InstRL78<outs, ins, asmstr, pattern>
{
  field bits<24> Inst = inst;
  // Lets the disassembler reject an encoding without failing the whole decode.
  // TableGen requires it to have the same width as Inst.
  field bits<24> SoftFail = 0;
  let Size = 3;
}

class InstRL78_32bit<field bits<32> inst, dag outs, dag ins, string asmstr, list<dag> pattern> 
  : InstRL78<outs, ins, asmstr, pattern>
{
  field bits<32> Inst = inst;
  // Lets the disassembler reject an encoding without failing the whole decode.
  // TableGen requires it to have the same width as Inst.
  field bits<32> SoftFail = 0;
  let Size = 4;
}

class InstRL78_40bit<field bits<40> inst, dag outs, dag ins, string asmstr, list<dag> pattern> 
  : InstRL78<outs, ins, asmstr, pattern>
{
  field bits<40> Inst = inst;
  // Lets the disassembler reject an encoding without failing the whole decode.
  // TableGen requires it to have the same width as Inst.
  field bits<40> SoftFail = 0;
  let Size = 5;
}

// Pseudo instructions.
class Pseudo<dag outs, dag ins, string asmstr, list<dag> pattern>
   : InstRL78<outs, ins, asmstr, pattern> {
  let isCodeGenOnly = 1;
  let isPseudo = 1;
}

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
  // Encoded by the TableGen'erated encoder (the older definitions above are
  // still encoded by hand in RL78MCCodeEmitter).
  let TSFlags{0} = 1;
}

