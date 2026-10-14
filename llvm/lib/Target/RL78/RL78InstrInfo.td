//===-- RL78InstrInfo.td - Target Description for RL78 Target -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RL78 instructions in TableGen format: the
// SelectionDAG nodes, operands and predicates here, the hardware instructions
// in RL78InstrISA.td and the pseudos of code generation in
// RL78InstrPseudo.td.
//
//===----------------------------------------------------------------------===//

include "RL78InstrFormats.td"
include "RL78RegisterInfo.td"

//===----------------------------------------------------------------------===//
// Predicates
//===----------------------------------------------------------------------===//

def isS3Core : Predicate<"Subtarget->isRL78S3CoreType()">,
               AssemblerPredicate<(all_of FeatureMulDiv), "the S3 core">;
def isNotS3Core : Predicate<"!Subtarget->isRL78S3CoreType()">;
def isNotS1Core : Predicate<"!Subtarget->isRL78S1CoreType()">,
                  AssemblerPredicate<(all_of FeatureRegBanks),
                                     "the S2 or S3 core">;
def isOptForSize : Predicate<"shouldOptForSize(MF)">;
def isOptForSpeed : Predicate<"!shouldOptForSize(MF)">;

//===----------------------------------------------------------------------===//
// SelectionDAG nodes
//===----------------------------------------------------------------------===//

// Addresses: the low 16 bits (or 8 bits) of a symbol, and a far address made
// of a segment and a near address.
def SDTPtr : SDTypeProfile<1, 1, [SDTCisVT<0, i16>, SDTCisPtrTy<1>]>;
def RL78Low16 : SDNode<"RL78ISD::LOW16", SDTPtr>;
def RL78Low8 : SDNode<"RL78ISD::LOW8", SDTPtr>;
def SDTRL78FarOp : SDTypeProfile<1, 2, [SDTCisVT<0, i16>, SDTCisVT<1, i16>,
                                        SDTCisVT<2, i16>]>;
def RL78Hi16 : SDNode<"RL78ISD::HI16", SDTRL78FarOp>;

def SDTXCHW : SDTypeProfile<2, 2, [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>,
                                   SDTCisSameAs<0, 3>, SDTCisInt<0>]>;
def xchw : SDNode<"RL78ISD::XCHW", SDTXCHW, []>;

// AND, OR, XOR of a byte in memory with a constant.
def andmem : SDNode<"RL78ISD::ANDMEM", SDTIntBinOp,
                    [SDNPCommutative, SDNPAssociative]>;
def ormem : SDNode<"RL78ISD::ORMEM", SDTIntBinOp,
                   [SDNPCommutative, SDNPAssociative]>;
def xormem : SDNode<"RL78ISD::XORMEM", SDTIntBinOp,
                    [SDNPCommutative, SDNPAssociative]>;
def inc : SDNode<"RL78ISD::INC", SDTUnaryOp, [SDNPMemOperand]>;

// The words of a value shifted to the right by one, from the top: the bit
// that leaves a word is the glue.
def rl78srlc : SDNode<"RL78ISD::SRLC", SDTIntUnaryOp, [SDNPOutGlue]>;
def rl78srac : SDNode<"RL78ISD::SRAC", SDTIntUnaryOp, [SDNPOutGlue]>;
def rl78rorwc : SDNode<"RL78ISD::RORWC", SDTIntUnaryOp,
                       [SDNPInGlue, SDNPOutGlue]>;
// The word that a rotate to the right by one started with: its top bit is
// the bit that left the last one.
def rl78cy15 : SDNode<"RL78ISD::CY15", SDTIntUnaryOp, [SDNPInGlue]>;

// The number of leading zeros of a word, 16 for zero, in a byte.
def rl78ctlz : SDNode<"RL78ISD::CTLZ16",
                      SDTypeProfile<1, 1, [SDTCisVT<0, i8>, SDTCisVT<1, i16>]>>;

// A load that may be left out: where an instruction is skipped, or a value
// is loaded only when it is chosen, a volatile or atomic load would not
// always happen.
def skippable_load : PatFrag<(ops node:$ptr), (load node:$ptr), [{
  return cast<LoadSDNode>(N)->isSimple();
}]>;

// A compare; the flags are the glue result.
def SDTCMP : SDTypeProfile<0, 3, [SDTCisInt<0>, SDTCisSameAs<0, 1>,
                                  SDTCisInt<2>]>;
def cmp : SDNode<"RL78ISD::CMP", SDTCMP, [SDNPOutGlue]>;
// The compare of the low words of a 32-bit compare (SKNZ + CMPW).
def SDTRL78LowCmp : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisVT<1, i16>]>;
def RL78lowcmp : SDNode<"RL78ISD::LOWCMP", SDTRL78LowCmp,
                        [SDNPOptInGlue, SDNPOutGlue]>;

// DIVWU: BCAX / HLDE, quotient in BCAX and remainder in HLDE.
def SDTDIVWU : SDTypeProfile<4, 4, [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>,
                                    SDTCisSameAs<0, 3>, SDTCisSameAs<0, 4>,
                                    SDTCisSameAs<0, 5>, SDTCisSameAs<0, 6>,
                                    SDTCisSameAs<0, 7>, SDTCisInt<0>]>;
def divwu : SDNode<"RL78ISD::DIVWU", SDTDIVWU, []>;

// MACHU, MACH: MACR + AX * BC.
def SDTMACHU : SDTypeProfile<2, 4, [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>,
                                    SDTCisSameAs<0, 3>, SDTCisSameAs<0, 4>,
                                    SDTCisSameAs<0, 5>, SDTCisInt<0>]>;
def machu : SDNode<"RL78ISD::MACHU", SDTMACHU, []>;
def mach : SDNode<"RL78ISD::MACH", SDTMACHU, []>;

// Bit operations through CY. The nodes of one sequence are glued, so that
// nothing that changes the flags (an address computation, say) comes between
// them.
def SDTMOV1TOCY : SDTypeProfile<0, 2, [SDTCisSameAs<0, 1>, SDTCisInt<0>]>;
def mov1tocy : SDNode<"RL78ISD::MOV1TOCY", SDTMOV1TOCY,
                      [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;
def SDTLOAD1TOCY : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisPtrTy<1>]>;
def load1tocy : SDNode<"RL78ISD::LOAD1TOCY", SDTLOAD1TOCY,
                       [SDNPHasChain, SDNPMayLoad, SDNPMemOperand,
                        SDNPOutGlue]>;
def store1fromcy : SDNode<"RL78ISD::STORE1FROMCY", SDTLOAD1TOCY,
                          [SDNPHasChain, SDNPMayStore, SDNPMemOperand,
                           SDNPInGlue]>;
def and1cy : SDNode<"RL78ISD::AND1CY", SDTLOAD1TOCY,
                    [SDNPHasChain, SDNPMayLoad, SDNPMemOperand, SDNPInGlue,
                     SDNPOutGlue]>;
def or1cy : SDNode<"RL78ISD::OR1CY", SDTLOAD1TOCY,
                   [SDNPHasChain, SDNPMayLoad, SDNPMemOperand, SDNPInGlue,
                    SDNPOutGlue]>;
def xor1cy : SDNode<"RL78ISD::XOR1CY", SDTLOAD1TOCY,
                    [SDNPHasChain, SDNPMayLoad, SDNPMemOperand, SDNPInGlue,
                     SDNPOutGlue]>;
def SDTNOT1CY : SDTypeProfile<0, 0, []>;
def not1cy : SDNode<"RL78ISD::NOT1CY", SDTNOT1CY,
                    [SDNPHasChain, SDNPInGlue, SDNPOutGlue]>;
def SDTSET1CLR1 : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisPtrTy<1>]>;
def set1 : SDNode<"RL78ISD::SET1", SDTSET1CLR1,
                  [SDNPHasChain, SDNPMayLoad, SDNPMayStore, SDNPMemOperand]>;
def clr1 : SDNode<"RL78ISD::CLR1", SDTSET1CLR1,
                  [SDNPHasChain, SDNPMayLoad, SDNPMayStore, SDNPMemOperand]>;

// Calls and returns.
def SDT_RL78CallSeqStart : SDCallSeqStart<[SDTCisVT<0, i16>,
                                           SDTCisVT<1, i16>]>;
def SDT_RL78CallSeqEnd : SDCallSeqEnd<[SDTCisVT<0, i16>, SDTCisVT<1, i16>]>;
def callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_RL78CallSeqStart,
                           [SDNPHasChain, SDNPOutGlue]>;
def callseq_end : SDNode<"ISD::CALLSEQ_END", SDT_RL78CallSeqEnd,
                         [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;
def SDTRL78Call : SDTypeProfile<0, -1, [SDTCisVT<0, iPTR>]>;
def call : SDNode<"RL78ISD::CALL", SDTRL78Call,
                  [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue, SDNPVariadic]>;
def callt : SDNode<"RL78ISD::CALLT", SDTRL78Call,
                   [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue, SDNPVariadic]>;
def tailcall : SDNode<"RL78ISD::TAIL_CALL", SDTRL78Call,
                      [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                       SDNPVariadic]>;
def SDTRL78Ret : SDTypeProfile<0, 0, []>;
def ret : SDNode<"RL78ISD::RET", SDTRL78Ret,
                 [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
def reti : SDNode<"RL78ISD::RETI", SDTRL78Ret,
                  [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
def retb : SDNode<"RL78ISD::RETB", SDTRL78Ret,
                  [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

// Branches on the flags and on a bit.
def SDTRL78brcc : SDTypeProfile<0, 2, [SDTCisVT<0, OtherVT>, SDTCisVT<1, i8>]>;
def RL78brcc : SDNode<"RL78ISD::BRCC", SDTRL78brcc,
                      [SDNPHasChain, SDNPInGlue]>;
def SDTRL78btbf : SDTypeProfile<0, 4, [SDTCisVT<2, i8>, SDTCisVT<3, i8>,
                                       SDTCisVT<0, OtherVT>, SDTCisVT<1, i8>]>;
def RL78btbf : SDNode<"RL78ISD::BTBF", SDTRL78btbf, [SDNPHasChain]>;

// Selects on the flags and on a bit; a load from one of two addresses.
def SDTRL78selectcc : SDTypeProfile<1, 3, [SDTCisSameAs<0, 1>, SDTCisInt<0>,
                                           SDTCisVT<3, i8>]>;
def SDTRL78selectccBTBF : SDTypeProfile<1, 5, [SDTCisSameAs<0, 1>,
                                               SDTCisInt<0>, SDTCisVT<3, i8>,
                                               SDTCisVT<4, i8>,
                                               SDTCisVT<5, i8>]>;
def RL78selectcc : SDNode<"RL78ISD::SELECTCC", SDTRL78selectcc, [SDNPInGlue]>;
def RL78selectccBTBF : SDNode<"RL78ISD::SELECTCCBTBF", SDTRL78selectccBTBF>;
def SDTRL78load_selectcc : SDTypeProfile<1, 3, [SDTCisInt<0>,
                                                SDTCisVT<1, iPTR>,
                                                SDTCisVT<2, iPTR>,
                                                SDTCisVT<3, i8>]>;
def RL78load_selectcc : SDNode<"RL78ISD::LOAD_SELECTCC", SDTRL78load_selectcc,
                               [SDNPHasChain, SDNPInGlue]>;

// __delay_cycles
def RL78delay_cycles_1_4
    : SDNode<"RL78ISD::DELAY_CYCLES_1_4", SDTypeProfile<0, 1, [SDTCisInt<0>]>,
             [SDNPSideEffect, SDNPHasChain]>;
def RL78delay_cycles_5
    : SDNode<"RL78ISD::DELAY_CYCLES_5", SDTypeProfile<0, 0, []>,
             [SDNPSideEffect, SDNPHasChain]>;
def RL78delay_cycles_6_1279
    : SDNode<"RL78ISD::DELAY_CYCLES_6_1279",
             SDTypeProfile<0, 1, [SDTCisInt<0>]>,
             [SDNPSideEffect, SDNPHasChain]>;

// To truncate, extract the low subregister.
def : Pat<(i8 (trunc i16:$src)), (EXTRACT_SUBREG i16:$src, sub_lo)>;

//===----------------------------------------------------------------------===//
// Addressing modes
//===----------------------------------------------------------------------===//

def ADDRr : ComplexPattern<iPTR, 1, "SelectADDRr", []>;
def ADDRrr : ComplexPattern<iPTR, 2, "SelectADDRrr", [], []>;
def ADDRri8 : ComplexPattern<iPTR, 2, "SelectADDRri<255>", [], []>;
def ADDRr8i16 : ComplexPattern<iPTR, 2, "SelectADDRr8i16", [], []>;
// i16 instead of iPTR for far data.
def ADDRSPi : ComplexPattern<i16, 2, "SelectADDRSPi", [frameindex], []>;
// The slot of an argument passed on the stack (never written).
def ADDRArgSP : ComplexPattern<i16, 2, "SelectADDRArgSP", [frameindex], []>;
def ADDRABS16 : ComplexPattern<iPTR, 1, "SelectADDRABS16", [], []>;
let WantsParent = true in
def SADDR : ComplexPattern<iPTR, 1, "SelectSaddr", [], []>;
def SFR : ComplexPattern<iPTR, 1, "SelectSFR", [], []>;
def ESADDRr : ComplexPattern<iPTR, 2, "SelectESADDRr", []>;
def ESADDRABS16 : ComplexPattern<iPTR, 2, "SelectESADDRABS16", [], []>;

//===----------------------------------------------------------------------===//
// Assembler operand classes and operands shared by the hardware instructions
//===----------------------------------------------------------------------===//

def RL78ABS8AsmOperand : AsmOperandClass { let Name = "ABS8"; }
def RL78MEMDirectAddr16AsmOperand : AsmOperandClass { let Name = "ABS16"; }
def RL78MEMDirectAddr20AsmOperand : AsmOperandClass { let Name = "ABS20"; }
def RL78SfrAsmOperand : AsmOperandClass { let Name = "Sfr"; }
def RL78SfrpAsmOperand : AsmOperandClass { let Name = "Sfrp"; }
def RL78EsAddrAsmOperand : AsmOperandClass { let Name = "EsAddr16"; }
def RL78brtargetRel8AsmOperand : AsmOperandClass { let Name = "brtargetRel8"; }
def RL78brtargetRel16AsmOperand : AsmOperandClass {
  let Name = "brtargetRel16";
}

// SEL RBn
def RL78SELRBxAsmOperand : AsmOperandClass { let Name = "SELRBx"; }
def SELRBx : Operand<i8> {
  let PrintMethod = "printSELRBxOperand";
  let ParserMatchClass = RL78SELRBxAsmOperand;
  let EncoderMethod = "getRBOpValue";
}

// A bit number.
def Imm0_7Operand : AsmOperandClass {
  let Name = "Imm07";
  let PredicateMethod = "isImmInRange<0,7>";
}
def bitimm : Operand<i8> {
  let ParserMatchClass = Imm0_7Operand;
  let PrintMethod = "printBitOperand";
  let EncoderMethod = "getBitOpValue";
}

// Shift counts.
def Imm1_7Operand : AsmOperandClass {
  let Name = "Imm17";
  let PredicateMethod = "isImmInRange<1,7>";
}
def shift8imm : Operand<i8> {
  let ParserMatchClass = Imm1_7Operand;
  let PrintMethod = "printShiftOperand";
  let EncoderMethod = "getShift8OpValue";
}
def Imm1_15Operand : AsmOperandClass {
  let Name = "Imm115";
  let PredicateMethod = "isImmInRange<1,15>";
}
def shift16imm : Operand<i8> {
  let ParserMatchClass = Imm1_15Operand;
  let PrintMethod = "printShiftOperand";
  let EncoderMethod = "getShift16OpValue";
}

//===----------------------------------------------------------------------===//
// Operands of the pseudos
//===----------------------------------------------------------------------===//

def brtarget : Operand<OtherVT>;
// A condition (RL78CC).
def CCOp : Operand<i8>;
// Addresses: a CALLT table entry, saddr, !addr16, !!addr20, an sfr.
def ABS5 : Operand<iPTR>;
def ABS8 : Operand<iPTR>;
def ABS16 : Operand<iPTR>;
def ABS20 : Operand<iPTR>;
def Sfr : Operand<iPTR>;
// [HL]
def HLAddr : Operand<iPTR> { let MIOperandInfo = (ops RL78HL); }
// [SP+byte]; a frame index in the SP operand until frame index elimination.
def STACKSlot : Operand<iPTR> { let MIOperandInfo = (ops RL78SPReg, i8imm); }
// ES:[HL] and ES:!addr16, the segment in a pair register (the low half is
// moved to ES).
def EsHlRegAddr : Operand<iPTR> {
  let MIOperandInfo = (ops RL78RPRegs, RL78RPRegs);
}
def EsAddr16 : Operand<iPTR> { let MIOperandInfo = (ops RL78RPRegs, i16imm); }

include "RL78InstrISA.td"
include "RL78InstrPseudo.td"
