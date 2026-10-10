//===-- RL78InstrInfo.td - Target Description for RL78 Target -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RL78 instructions in TableGen format.
//
//===----------------------------------------------------------------------===//


//===----------------------------------------------------------------------===//
// Instruction format superclass
//===----------------------------------------------------------------------===//

include "RL78InstrFormats.td"
include "RL78RegisterInfo.td"

//----------------------------------------------------------------------------
// Compiler-pseudos
//----------------------------------------------------------------------------

// To truncate, we can simply extract from a subregister.
def : Pat<(i8 (trunc i16:$src)),
          (EXTRACT_SUBREG i16:$src, sub_lo)>;

let usesCustomInserter = 1 in {


}

//===----------------------------------------------------------------------===//
// Address types
//===----------------------------------------------------------------------===//

def SDTPtr : SDTypeProfile<1, 1, [SDTCisVT<0, i16>, SDTCisPtrTy<1>]>;

def RL78Low16    : SDNode<"RL78ISD::LOW16", SDTPtr>;
def RL78Low8     : SDNode<"RL78ISD::LOW8", SDTPtr>;

def SDTRL78FarOp : SDTypeProfile<1, 2, [SDTCisVT<0, i16>, SDTCisVT<1, i16>,SDTCisVT<2, i16>]>;
def RL78Hi16     : SDNode<"RL78ISD::HI16", SDTRL78FarOp>;

//=============================================================================================================
def RL78ABS5AsmOperand : AsmOperandClass {
  let Name = "ABS5";
}

def ABS5 : Operand<iPTR> {
  let PrintMethod = "printABS5Operand";
  let ParserMatchClass = RL78ABS5AsmOperand;
}

//=============================================================================================================
def RL78ABS8AsmOperand : AsmOperandClass {
  let Name = "ABS8";
}

def ABS8 : Operand<iPTR> {
  let PrintMethod = "printABS8Operand";
  let ParserMatchClass = RL78ABS8AsmOperand;
}

//=============================================================================================================
def RL78MEMDirectAddr16AsmOperand : AsmOperandClass {
  let Name = "ABS16";
}

def ABS16 : Operand<iPTR> {
  let PrintMethod = "printABS16Operand";
  let ParserMatchClass = RL78MEMDirectAddr16AsmOperand;
}



//=============================================================================================================
def RL78MEMDirectAddr20AsmOperand : AsmOperandClass {
  let Name = "ABS20";
}

def ABS20 : Operand<iPTR> {
  let PrintMethod = "printABS20Operand";
  let ParserMatchClass = RL78MEMDirectAddr20AsmOperand;
}


//=============================================================================================================
 def RL78SfrAsmOperand : AsmOperandClass {
  let Name = "Sfr";
}

def Sfr : Operand<iPTR> {
  let PrintMethod = "printSfrOperand";
  let ParserMatchClass = RL78SfrAsmOperand;
}


//=============================================================================================================
 def RL78SfrpAsmOperand : AsmOperandClass {
  let Name = "Sfrp";
}

def Sfrp : Operand<iPTR> {
  let PrintMethod = "printSfrpOperand";
  let ParserMatchClass = RL78SfrpAsmOperand;
}


//=============================================================================================================

def ADDRr        : ComplexPattern<iPTR, 1, "SelectADDRr", []>;
def ADDRrr       : ComplexPattern<iPTR, 2, "SelectADDRrr", [], []>;
def ADDRri8      : ComplexPattern<iPTR, 2, "SelectADDRri<255>", [], []>;
def ADDRri16     : ComplexPattern<iPTR, 2, "SelectADDRri<65535>", [], []>;
def ADDRri16orBC : ComplexPattern<iPTR, 2, "SelectADDRri<65535, true>", [], []>;
def ADDRr8i16    : ComplexPattern<iPTR, 2, "SelectADDRr8i16", [], []>;
def ADDRSPi      : ComplexPattern<i16,  2, "SelectADDRSPi", [frameindex], []>; // i16 instead of iPTR for far data
def ADDRABS16    : ComplexPattern<iPTR, 1, "SelectADDRABS16", [], []>;
def SADDR        : ComplexPattern<iPTR, 1, "SelectSaddr", [], []>;
def SFR          : ComplexPattern<iPTR, 1, "SelectSFR", [], []>;

def ESADDRr        : ComplexPattern<iPTR, 2, "SelectESADDRr", []>;
def ESADDRrr       : ComplexPattern<iPTR, 3, "SelectESADDRrr", [], []>;
def ESADDRri8      : ComplexPattern<iPTR, 3, "SelectESADDRri<255>", [], []>;
def ESADDRri16     : ComplexPattern<iPTR, 3, "SelectESADDRri<65535>", [], []>;
def ESADDRri16orBC : ComplexPattern<iPTR, 3, "SelectESADDRri<65535, true>", [], []>;
def ESADDRr8i16    : ComplexPattern<iPTR, 3, "SelectESADDRr8i16", [], []>;
def ESADDRABS16    : ComplexPattern<iPTR, 2, "SelectESADDRABS16", [], []>;

//=============================================================================================================
// [HL]
// Needed as some instructions accept only [HL]
def RL78HLAddressOperand : AsmOperandClass {
  let Name = "HLAddr";
}

def HLAddr : Operand<iPTR> {
  let PrintMethod = "printHLMemOperand";
  let MIOperandInfo = (ops RL78HL);
  let ParserMatchClass = RL78HLAddressOperand;
}
//=============================================================================================================
def RL78STACKSlotAsmOperand : AsmOperandClass {
  let Name = "STACKSlotNo";
  let ParserMethod = "parseStackSlotOperand";
}

def STACKSlot : Operand<iPTR> {
  let PrintMethod = "printStackSlotOperand";
  let DecoderMethod = "decodeSTACKSlot";
  let MIOperandInfo = (ops RL78SPReg, i8imm);
  let ParserMatchClass = RL78STACKSlotAsmOperand;
}
//=============================================================================================================
def RL78RegOffsetAddrAsmOperand : AsmOperandClass {
  let Name = "RegOffsetAddr";
  let ParserMethod = "parseRegOffsetAddrOperand";
}

//Changing RL78RPRegs produces unwanted behaviour
def RegOffsetAddr : Operand<iPTR> {
  let PrintMethod = "printMemOperand";
  let DecoderMethod = "decodeRegOffsetAddr";
  let MIOperandInfo = (ops RL78RPRegs, i16imm);
  let ParserMatchClass = RL78RegOffsetAddrAsmOperand;
}
//=============================================================================================================
def RL78BorCRegOffsetAddrAsmOperand : AsmOperandClass {
  let Name = "RegBorCOffsetAddr";
  let ParserMethod = "parseRegOffsetAddrOperand";
}

def RegBorCOffsetAddr : Operand<iPTR> {
  let PrintMethod = "printMemOperand";
  let DecoderMethod = "decodeRegBorCOffsetAddr";
  let MIOperandInfo = (ops RL78Reg, i16imm);
  let ParserMatchClass = RL78BorCRegOffsetAddrAsmOperand;
}
//=============================================================================================================
def RL78RegRegAddrAsmOperand : AsmOperandClass {
  let Name = "RegRegAddr";
  let ParserMethod = "parseRegRegAddrOperand";
}

def RegRegAddr : Operand<iPTR> {
  let PrintMethod = "printRegSumMemOperand";
  let DecoderMethod = "decodeRegRegAddr";
  let MIOperandInfo = (ops RL78RPRegs, RL78Reg);
  let ParserMatchClass = RL78RegRegAddrAsmOperand;
}
//=============================================================================================================
def RL78EsRegRegAddrAsmOperand : AsmOperandClass {
  let Name = "EsRegRegAddr";
  let ParserMethod = "parseEsRegRegAddrOperand";
}

//TODO: we marked ES as being RL78RPRegs, fix this!
def EsRegRegAddr : Operand<iPTR> {
  let PrintMethod = "printEsRegMemOperand";
  let DecoderMethod = "decodeEsRegRegAddr";
  let MIOperandInfo = (ops RL78RPRegs, RL78RPRegs, i16imm);
  let ParserMatchClass = RL78EsRegRegAddrAsmOperand;

}
//=============================================================================================================
def RL78EsRegBorCRegAddrAsmOperand : AsmOperandClass {
  let Name = "EsRegBorCRegAddr";
  let ParserMethod = "parseEsRegRegAddrOperand";
}

def EsRegBorCRegAddr : Operand<iPTR> {
  let PrintMethod = "printEsRegMemOperand";
  let DecoderMethod = "decodeEsRegBorCRegAddr";
  let MIOperandInfo = (ops RL78RPRegs, RL78Reg, i16imm);
  let ParserMatchClass = RL78EsRegBorCRegAddrAsmOperand;

}
//=============================================================================================================
 //ES:[HL]
 def RL78EsHlRegAddrAsmOperand : AsmOperandClass {
  let Name = "EsHlRegAddr";
}

def EsHlRegAddr : Operand<iPTR> {
  let PrintMethod = "printEsRegHLOnlyMemOperand";
  let DecoderMethod = "decodeEsHlRegAddr";
  let MIOperandInfo = (ops RL78RPRegs, RL78RPRegs);
  let ParserMatchClass = RL78EsHlRegAddrAsmOperand;
}

//=============================================================================================================
 //ES:!addr16
 def RL78EsAddrAsmOperand : AsmOperandClass {
  let Name = "EsAddr16";
}

def EsAddr16 : Operand<iPTR> {
  let PrintMethod = "printEsAddr16Operand";
  let DecoderMethod = "decodeEsAddr16";
  let MIOperandInfo = (ops RL78RPRegs, i16imm);
  let ParserMatchClass = RL78EsAddrAsmOperand;
}
//=============================================================================================================
def EsRL78RegRegAsmOperand : AsmOperandClass {
  let Name = "EsRegRegReg";
  let ParserMethod = "parseEsRegRegRegOperand";
}

def EsRegRegReg : Operand<iPTR> {
  let PrintMethod = "printEsRegRegSumMemOperand";
  let DecoderMethod = "decodeEsRegRegReg";
  let MIOperandInfo = (ops RL78RPRegs, RL78RPRegs, RL78Reg);
  let ParserMatchClass = EsRL78RegRegAsmOperand;
}
//=============================================================================================================
def RL78SELRBxAsmOperand : AsmOperandClass {
  let Name = "SELRBx";
}
def SELRBx : Operand<i8> {
  let PrintMethod = "printSELRBxOperand";
  let ParserMatchClass = RL78SELRBxAsmOperand;
  let EncoderMethod = "getRBOpValue";
}
//=============================================================================================================
// Branch targets have OtherVT type.
def brtarget : Operand<OtherVT> {
}
//=============================================================================================================
def RL78brtargetRel8AsmOperand : AsmOperandClass {
  let Name = "brtargetRel8";
}

def brtargetRel8 : Operand<OtherVT> {
  let PrintMethod = "printRel8Operand";
  let ParserMatchClass = RL78brtargetRel8AsmOperand;
}
//=============================================================================================================
def RL78brtargetRel16AsmOperand : AsmOperandClass {
  let Name = "brtargetRel16";
}

def brtargetRel16 : Operand<OtherVT> {
  let PrintMethod = "printRel16Operand";
  let ParserMatchClass = RL78brtargetRel16AsmOperand;
}
//=============================================================================================================
def RL78CCAsmOperand : AsmOperandClass {
  let Name = "CCOp";
}

def CCOp : Operand<i8> {
  let PrintMethod = "printCCOperand";
  let ParserMatchClass = RL78CCAsmOperand;
}
//=============================================================================================================
class AsmImmRange<int Low, int High> : AsmOperandClass {
  let Name = "Imm" # Low # "_" # High;
  let DiagnosticType = "InvalidImm" # Low # "_" # High;
  let PredicateMethod = "isImmInRange<" # Low # "," # High # ">";
}

// AsmOperand classes to emit (or not) special diagnostics
def Imm0_7Operand : AsmOperandClass {
  let Name = "Imm07";
  let PredicateMethod = "isImmInRange<0,7>";
}
def bitimm  : Operand<i8> {
  let ParserMatchClass = Imm0_7Operand;
  let PrintMethod = "printBitOperand";
  let EncoderMethod = "getBitOpValue";
}
//=============================================================================================================
def i3imm  : Operand<i8> {
  let ParserMatchClass = Imm0_7Operand;
  let PrintMethod = "printBitOperand";
}
//=============================================================================================================
def Imm1_7Operand : AsmOperandClass {
  let Name = "Imm17";
  let PredicateMethod = "isImmInRange<1,7>";
}
def shift8imm  : Operand<i8> {
  let ParserMatchClass = Imm1_7Operand;
  let PrintMethod = "printShiftOperand";
  let EncoderMethod = "getShift8OpValue";
}
//=============================================================================================================
def Imm1_15Operand : AsmOperandClass {
  let Name = "Imm115";
  let PredicateMethod = "isImmInRange<1,15>";
}
def shift16imm  : Operand<i8> {
  let ParserMatchClass = Imm1_15Operand;
  let PrintMethod = "printShiftOperand";
  let EncoderMethod = "getShift16OpValue";
}
//=============================================================================================================

//===----------------------------------------------------------------------===//
// MOV instruction
//===----------------------------------------------------------------------===//


//MOV saddr, #byte  CD saddr data

let mayLoad = 0, mayStore = 0 in {

//MOV ES, #byte      41 data

//Instruction       Opcode
//MOV A, ES			8E FD

//Instruction       Opcode
//MOV ES, A			9E FD

//Instruction       Opcode
//MOV A, CS			8E FC

//Instruction       Opcode
//MOV CS, A			9E FC

//MOV CS, #byte      CE FC data

//Instruction       Opcode
//MOV A, X          60
//MOV A, C          62
//MOV A, B          63
//MOV A, E          64
//MOV A, D          65
//MOV A, L          66
//MOV A, H          67

//Instruction       Opcode
//MOV X, A          70
//MOV C, A          72
//MOV B, A          73
//MOV E, A          74
//MOV D, A          75
//MOV L, A          76
//MOV H, A          77

} // mayLoad = 0, mayStore = 0

//Instruction       Opcode
//MOV A, saddr      8D saddr
//MOV X, saddr      D8 saddr
//MOV B, saddr      E8 saddr
//MOV C, saddr      F8 saddr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_rlo_saddr : InstRL78_16bit<0x8D00,
        (outs RL78Reg:$rd), (ins ABS8:$addr),
        "mov $rd, $addr",
        []>;

//Instruction       Opcode
//MOV A, !addr16    8F adrl adrh
//MOV B, !addr16    E9 adrl adrh
//MOV C, !addr16    F9 adrl adrh
//MOV X, !addr16    D9 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_abs16 : InstRL78_24bit<0x8F0000,
        (outs RL78Reg:$rd), (ins ABS16:$addr),
        "mov $rd, $addr",
        []>;

//Instruction           Opcode
//MOV !addr16, #byte    CF adrl adrh data

//Instruction			Opcode
//MOV [SP+byte], #byte	C8 adr data
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_stack_slot_imm : InstRL78_24bit<0xC80000,
        (outs), (ins STACKSlot:$addr, i8imm:$imm),
        "mov $addr, $imm",
        []>;

//MOV sfr, #byte ;CE sfr data

let usesCustomInserter = 1 in {

//Instruction       Opcode
//MOV A, [HL+B]     61 C9
//MOV A, [HL+C]     61 E9
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_memrr : InstRL78_16bit<0x61C9,
        (outs RL78Reg:$rd), (ins RegRegAddr:$addr),
        "mov $rd, $addr",
        []>;

//Instruction       Opcode
//MOV [HL+B], A     61 D9
//MOV [HL+C], A     61 F9
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_memrr_r : InstRL78_16bit<0x61D9,
        (outs), (ins RegRegAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

//MOV saddr, A      9D saddr

//MOV word[B], #byte	19 adrl adrh data
//MOV word[C], #byte	38 adrl adrh data

//Instruction			Opcode
//MOV word[BC], #byte	39 adrl adrh data
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_ri_imm : InstRL78_32bit<0x39000000,
        (outs), (ins RegOffsetAddr:$addr, i8imm:$imm),
        "mov $addr, $imm",
        []>;

//MOV [DE+byte], #byte	CA adr data
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_memDEi_imm : InstRL78_24bit<0xCA0000,
        (outs), (ins RegOffsetAddr:$addr, i8imm:$imm),
        "mov $addr, $imm",
        []>;

let mayLoad = 0, mayStore = 1 in {

//MOV [HL+byte], #byte	CC adr data
let isCodeGenOnly = 1 in
def STORE8_memHLi_imm : InstRL78_24bit<0xCC0000,
        (outs), (ins RegOffsetAddr:$addr, i8imm:$imm),
        "mov $addr, $imm",
        []>;

} // mayLoad = 0, mayStore = 1

//Instruction       Opcode
//MOV A, [SP+byte]  88 adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_stack_slot : InstRL78_16bit<0x8800,
        (outs RL78Reg:$rd), (ins STACKSlot:$addr),
        "mov $rd, $addr",
        []>;

//Instruction       Opcode
//MOV !addr16, A    9F adrl adrh

//Instruction       Opcode
//MOV [SP+byte], A  98 adr
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_stack_slot_r : InstRL78_16bit<0x9800,
        (outs), (ins STACKSlot:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

//MOV A, word[B]    09 adrl adrh
//MOV A, word[C]    29 adrl adrh

//Instruction       Opcode
//MOV A, word[BC]   49 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_ri : InstRL78_24bit<0x490000,
        (outs RL78Reg:$rd), (ins RegOffsetAddr:$addr),
        "mov $rd, $addr",
        []>;

//MOV A, [DE]       89
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_memDE : InstRL78_8bit<0x89,
        (outs RL78Reg:$rd), (ins RegOffsetAddr:$addr),
        "mov $rd, $addr",
        []>;

let mayLoad = 1, mayStore = 0 in {

//MOV A, [HL]       8B
let isCodeGenOnly = 1 in
def LOAD8_r_memHL : InstRL78_8bit<0x8B,
        (outs RL78Reg:$rd), (ins RegOffsetAddr:$addr),
        "mov $rd, $addr",
        []>;

//MOV A, [DE+byte]  8A adr
let isCodeGenOnly = 1 in
def LOAD8_r_memDEi : InstRL78_16bit<0x8A00,
        (outs RL78Reg:$rd), (ins RegOffsetAddr:$addr),
        "mov $rd, $addr",
        []>;

//MOV A, [HL+byte]  8C adr
let isCodeGenOnly = 1 in
def LOAD8_r_memHLi : InstRL78_16bit<0x8C00,
        (outs RL78Reg:$rd), (ins RegOffsetAddr:$addr),
        "mov $rd, $addr",
        []>;

} // mayLoad = 1, mayStore = 0

//MOV word[B], A    18 adrl adrh
//MOV word[C], A    38 adrl adrh

//Instruction       Opcode
//MOV word[BC], A   48 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_ri_r : InstRL78_24bit<0x480000,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

//MOV [DE], A       99
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE8_memDE_r : InstRL78_8bit<0x99,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

let mayLoad = 0, mayStore = 1 in {

//MOV [HL], A       9B
let isCodeGenOnly = 1 in
def STORE8_memHL_r : InstRL78_8bit<0x9B,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

//MOV [DE+byte], A  9A adr
let isCodeGenOnly = 1 in
def STORE8_memDEi_r : InstRL78_16bit<0x9A00,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

//MOV [HL+byte], A  9C adr
let isCodeGenOnly = 1 in
def STORE8_memHLi_r : InstRL78_16bit<0x9C00,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "mov $addr, $rsrc",
        []>;

} // mayLoad = 0, mayStore = 1

let hasSideEffects = 1 in {

//MOV A, sfr ;8E sfr

//MOV sfr, A ;9E sfr

} // hasSideEffects = 1

} // usesCustomInserter = 1

let hasSideEffects = 1 in {

// mov A, PSW
let Uses = [CCreg] in {
let isCodeGenOnly = 1 in
def MOV_A_PSW_cg : InstRL78_16bit<0x8EFA,
        (outs RL78Reg:$dest), (ins),
        "mov $dest, PSW",
         [(set i8:$dest, (int_rl78_getpsw))]>;
}

// mov PSW, A
let Defs = [CCreg], Uses = [CCreg] in {
let isCodeGenOnly = 1 in
def MOV_PSW_A_cg : InstRL78_16bit<0x9EFA,
        (outs), (ins RL78Reg:$rsrc),
        "mov PSW, $rsrc",
         [(int_rl78_setpsw i8:$rsrc)]>;
}

//MOV PSW, #byte      CE FA data
let Defs = [CCreg], Uses = [CCreg], mayLoad = 0, mayStore = 1 in {
}

//MOV A, sfr ;8E sfr

let mayLoad = 0, mayStore = 1, isCodeGenOnly = 1 in {

//MOV sfr, A ;9E sfr

//MOV sfr_as_reg, #byte ;CE sfr data

} // mayLoad = 0, mayStore = 1, isCodeGenOnly = 1

} // hasSideEffects = 1

//MOV ES, saddr ;61 B8 saddr

//MOV ES:!addr16, #byte ;11 CF adrl adrh data

//MOV A, ES:!addr16 ;11 8F adrl adrh
//MOV B, ES:!addr16 ;11 E9 adrl adrh
//MOV C, ES:!addr16 ;11 F9 adrl adrh
//MOV X, ES:!addr16 ;11 D9 adrl adrh
let mayLoad = 1, mayStore = 0, usesCustomInserter = 1 in
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def MOV_r_esaddr16 : InstRL78_32bit<0x118f0000,
        (outs RL78Reg:$rd), (ins EsAddr16:$addr ),
        "mov $rd, $addr",
        []>;

let mayLoad = 0, mayStore = 1, usesCustomInserter = 1 in {

//MOV ES:!addr16, A ;11 9F adrl adrh

//MOV ES:[HL+B], A ;11 61 D9
//MOV ES:[HL+C], A ;11 61 F9

//MOV ES:word[B], #byte  ;11 19 adrl adrh data
//MOV ES:word[C], #byte  ;11 38 adrl adrh data

//MOV ES:word[BC], #byte ;11 39 adrl adrh data

// MOV es:word[B], A     11 18 adrl adrh
// MOV es:word[C], A     11 28 adrl adrh

// MOV es:word[BC], A     11 48 adrl adrh

}

let mayLoad = 0, mayStore = 1 in {

//Instruction           Opcode

// MOV es:[DE], A         11 99

// MOV es:[HL], A         11 9B

// MOV es:[DE+byte], A    11 9A adr


// MOV es:[HL+byte], A    11 9C adr


//MOV ES:[DE+byte], #byte ;11 CA adr data

//MOV ES:[HL+byte], #byte ;11 CC adr data
} // mayStore = 1

let mayLoad = 1, mayStore = 0, usesCustomInserter = 1 in {

//Instruction            Opcode
//MOV A, es:word[B]   11 09 adrl adrh
//MOV A, es:word[C]   11 29 adrl adrh

//MOV A, ES:[HL+B] ;11 61 C9
//MOV A, ES:[HL+C] ;11 61 E9
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_a_esmemRpr : InstRL78_24bit<0x1161C9,
        (outs RL78Reg:$rd), (ins EsRegRegReg:$addr),
        "mov $rd, $addr",
        []>;

//MOV A, es:word[BC]   11 49 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD8_r_esrpi : InstRL78_32bit<0x11490000,
        (outs RL78Reg:$rd), (ins EsRegRegAddr:$addr),
        "mov $rd, $addr",
        []>;
}

let mayLoad = 1, mayStore = 0 in {

//Instruction            Opcode
//MOV A, es:[DE]       11 89

//MOV A, es:[HL]       11 8B

//MOV A, es:[DE+byte]  11 8A adr

//MOV A, es:[HL+byte]  11 8C adr

} // mayLoad = 1, mayStore = 0

//===----------------------------------------------------------------------===//
// XCH instruction
//===----------------------------------------------------------------------===//

let mayLoad = 0, mayStore = 0 in {

let Constraints = "$rsrc = $rd, $rsrc2 = $rd2" in
{
//XCH A, r          61 8X (C..H -> A..F)
let isCodeGenOnly = 1 in
def XCH_A_r_cg  : InstRL78_16bit<0x618A,
        (outs RL78AReg:$rd, RL78XBCEDHLReg:$rd2), (ins RL78AReg:$rsrc, RL78XBCEDHLReg:$rsrc2),
        "xch $rd, $rsrc2",
        []>;
}

//Instruction       Opcode
//XCH A, X          08

} // mayLoad = 0, mayStore = 0

let mayLoad = 1, mayStore = 1 in {

//XCH A, saddr      61 A8 saddr

let Constraints = "$rsrc = $rd, $sfr = $sfr2", hasSideEffects = 1 in
{
//XCH A, sfr      61 AB saddr

//XCH A, sfr      61 AB saddr
}

let Constraints = "$rsrc = $rd" in {

//Instruction       Opcode
//XCH A, !addr16    61 AA adrl adrh

//let Constraints = "$rsrc = $rd" , $addr1 = $addr2 in {

//Instruction       Opcode
//XCH A, !addr16    61 AA adrl adrh
//def XCH_A_abs16_cg  : InstRL78_32bit<0x61AA0000,
//        (outs RL78AReg:$rd, ABS16:$addr1 ), (ins RL78AReg:$rsrc, ABS16:$addr2),
//        "xch $rd, $addr1",
//        []>;
//}

//Instruction       Opcode
//XCH A, [DE]       61 AE
//XCH A, [DE+byte]  61 AF adr
//XCH A, [HL]       61 AC
//XCH A, [HL+byte]  61 AD adr

//Instruction       Opcode
//XCH A, [HL+B]     61 B9
//XCH A, [HL+C]     61 A9

//XCH A, ES:!addr16 ;11 61 AA adrl adrh

//XCH A, ES:[DE] ;11 61 AE
//XCH A, ES:[HL] ;11 61 AC

//XCH A, ES:[HL+B] ;11 61 B9
//XCH A, ES:[HL+C] ;11 61 A9

//XCH A, ES:[DE+byte] ;11 61 AF adr
//XCH A, ES:[HL+byte] ;11 61 AD adr

} // Constraints = "$rsrc = $rd"

} // mayLoad = 1, mayStore = 1


// Initially we started with this as a pseudo instruction which expanded to:
// 2 x COPYs for to extract the sub_lo and sub_hi parts from the 16 bit reg
// XCH_A_r_cg
// 2 x INSERT_SUBREG of sub_lo and sub_hi back into an 16 reg
// this didn't generate the optimal code not even in simple cases,
// we had extra mov/xch instructions which we avoided by doing this:
let Constraints = "$rsrc = $rd", usesCustomInserter = 1, isCodeGenOnly = 1 in {
  let usesCustomInserter = 0 in
def BSWAP_rp : InstRL78_8bit<0x08,
        (outs RL78AXRP:$rd), (ins RL78AXRP:$rsrc),
        "xch a, x ;bswap $rd",
        [(set i16:$rd, (bswap i16:$rsrc))]>;
}

//===----------------------------------------------------------------------===//
// ONEB instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, isReMaterializable = 1, mayLoad = 0, mayStore = 0 in {
//Instruction       Opcode
//ONEB r            EX (X..B -> 0..3)
}

//ONEB saddr        E4 saddr

//Instruction       Opcode
//ONEB !addr16      E5 adrl adrh

//Instruction       Opcode
//ONEB ES:!addr16    11 E5 adrl adrh

//===----------------------------------------------------------------------===//
// CLRB instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, isReMaterializable = 1, mayLoad = 0, mayStore = 0 in {
//Instruction       Opcode
//CLRB r            FX (X..C -> 0..3)
}

//CLRB saddr        F4 saddr

//Instruction       Opcode
//CLRB addr16       F5 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def CLRB_abs16_cg  : InstRL78_24bit<0xF50000,
        (outs), (ins ABS16:$addr),
        "clrb $addr",
        []>;

//Instruction       Opcode
//CLRB ES:!addr16    11 F5 adrl adrh

//===----------------------------------------------------------------------===//
// MOVS instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag], mayLoad = 0, mayStore = 1 in {

//Instruction           Opcode
//MOVS [HL+byte], X     61 CE adr
let isCodeGenOnly = 1 in
def MOVS_memri_r : InstRL78_24bit<0x61CE00,
        (outs), (ins RegOffsetAddr:$addr, RL78Reg:$rsrc),
        "movs $addr, $rsrc",
        []>;

//MOVS ES:[HL+byte], X ;11 61 CE adr

} // Defs = [CCreg, Zflag], mayLoad = 0, mayStore = 1


//===----------------------------------------------------------------------===//
// MOVW instruction
//===----------------------------------------------------------------------===//


//MOVW saddrp, #word    C9 saddr datal datah

//MOVW sfrp,#word ;CB sfr datal datah

let mayLoad = 0, mayStore = 0 in {

//Instruction       Opcode
//MOVW SP, #word    CB F8 datal datah

//Instruction       Opcode
//MOVW AX, BC       13
//MOVW AX, DE       15
//MOVW AX, HL       17

//Instruction       Opcode
//MOVW BC, AX       12
//MOVW DE, AX       14
//MOVW HL, AX       16

//Instruction       Opcode
//MOVW BC, SP       DB adrl adrh
//MOVW DE, SP       EB adrl adrh
//MOVW HL, SP       FB adrl adrh
let isCodeGenOnly = 1 in
def MOVW_rp_sp  : InstRL78_24bit<0xDBF8FF,
        (outs RL78RPRegs:$rd), (ins RL78SPReg:$rsrc),
        "movw $rd, $rsrc",
        []>;

//MOVW AX, SP       AE F8

//Instruction       Opcode
//MOVW SP, AX       BE F8

} // mayLoad = 0, mayStore = 0

//Instruction           Opcode
//MOVW AX, !addr16      AF adrl adrh
//MOVW BC, !addr16      DB adrl adrh
//MOVW DE, !addr16      EB adrl adrh
//MOVW HL, !addr16      FB adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_abs16 : InstRL78_24bit<0xAF0000,
        (outs RL78RPRegs:$rd), (ins ABS16:$addr),
        "movw $rd, $addr",
        []>;

//Instruction        Opcode
//MOVW AX, saddrp    AD saddr
//MOVW BC, saddrp    DA saddr
//MOVW DE, saddrp    EA saddr
//MOVW HL, saddrp    FA saddr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_saddrp : InstRL78_16bit<0xAD00,
        (outs RL78RPRegs:$rd), (ins ABS8:$addr),
        "movw $rd, $addr",
        []>;

let usesCustomInserter = 1 in {

//MOVW AX, ES:!addr16   11 AF adrl adrh
//MOVW BC, ES:!addr16   11 DB adrl adrh
//MOVW DE, ES:!addr16   11 EB adrl adrh
//MOVW HL, ES:!addr16   11 FB adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_esaddr16 : InstRL78_32bit<0x11AF0000,
        (outs RL78RPRegs:$rd), (ins EsAddr16:$addr),
        "movw $rd, $addr",
        []>;


// The address of a stack slot: MOVW AX, SP and ADDW AX, #word.
let mayLoad = 0, mayStore = 0, usesCustomInserter = 0, Defs = [CCreg] in
def MOVW_rp_stack_slot : Pseudo<
        (outs RL78AXRP:$rd), (ins STACKSlot:$addr),
        ";movw $rd, $addr",
        []>;

//Instruction           Opcode
//MOVW !addr16, AX      BF adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_abs16_rp : InstRL78_24bit<0xBF0000,
        (outs), (ins ABS16:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

//Instruction           Opcode
//MOVW AX, word[B]      59 adrl adrh
//MOVW AX, word[C]      69 adrl adrh

//Instruction         Opcode
//MOVW AX, word[BC]   79 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_rpi : InstRL78_24bit<0x790000,
        (outs RL78RPRegs:$rd), (ins RegOffsetAddr:$addr),
        "movw $rd, $addr",
        []>;

//Instruction        Opcode
//MOVW saddrp, AX    BD saddr

//MOVW AX, [DE]       A9
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_memDE : InstRL78_8bit<0xA9,
        (outs RL78RPRegs:$rd), (ins RegOffsetAddr:$addr),
        "movw $rd, $addr",
        []>;

let mayLoad = 1, mayStore = 0 in {

//MOVW AX, [HL]       AB
let isCodeGenOnly = 1 in
def LOAD16_rp_memHL : InstRL78_8bit<0xAB,
        (outs RL78RPRegs:$rd), (ins RegOffsetAddr:$addr),
        "movw $rd, $addr",
        []>;

//MOVW AX, [DE+byte]  AA adr
let isCodeGenOnly = 1 in
def LOAD16_rp_memDEi : InstRL78_16bit<0xAA00,
        (outs RL78RPRegs:$rd), (ins RegOffsetAddr:$addr),
        "movw $rd, $addr",
        []>;

//MOVW AX, [HL+byte]  AC adr
let isCodeGenOnly = 1 in
def LOAD16_rp_memHLi : InstRL78_16bit<0xAC00,
        (outs RL78RPRegs:$rd), (ins RegOffsetAddr:$addr),
        "movw $rd, $addr",
        []>;

} // mayLoad = 1, mayStore = 0

//MOVW AX, es:word[B]   11 59 adrl adrh
//MOVW AX, es:word[C]   11 69 adrl adrh

//Instruction            Opcode
//MOVW AX, es:word[BC]   11 79 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_esrpi : InstRL78_32bit<0x11790000,
        (outs RL78RPRegs:$rd), (ins EsRegRegAddr:$addr),
        "movw $rd, $addr",
        []>;

let mayLoad = 1, mayStore = 0 in {

//MOVW AX, es:[DE]       11 A9
let isCodeGenOnly = 1 in
def LOAD16_rp_esmemDE : InstRL78_16bit<0x11A9,
        (outs RL78RPRegs:$rd), (ins EsRegRegAddr:$addr),
        "movw $rd, $addr",
        []>;

//MOVW AX, es:[HL]       11 AB
let isCodeGenOnly = 1 in
def LOAD16_rp_esmemHL : InstRL78_16bit<0x11AB,
        (outs RL78RPRegs:$rd), (ins EsRegRegAddr:$addr),
        "movw $rd, $addr",
        []>;

//MOVW AX, es:[DE+byte]  11 AA adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_esmemDEi : InstRL78_24bit<0x11AA00,
        (outs RL78RPRegs:$rd), (ins EsRegRegAddr:$addr),
        "movw $rd, $addr",
        []>;

//MOVW AX, es:[HL+byte]  11 AC adr
let isCodeGenOnly = 1 in
def LOAD16_rp_esmemHLi : InstRL78_24bit<0x11AC00,
        (outs RL78RPRegs:$rd), (ins EsRegRegAddr:$addr),
        "movw $rd, $addr",
        []>;

} // mayLoad = 1, mayStore = 0

//Instruction           Opcode
//MOVW word[B], AX     58 adrl adrh
//MOVW word[C], AX     68 adrl adrh

//MOVW word[BC], AX     78 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_rpi_rp : InstRL78_24bit<0x780000,
        (outs), (ins RegOffsetAddr:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;


//MOVW [DE], AX         B9
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_memDE_rp : InstRL78_8bit<0xB9,
        (outs), (ins RegOffsetAddr:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

let mayLoad = 0, mayStore = 1 in {

//MOVW [HL], AX         BB
let isCodeGenOnly = 1 in
def STORE16_memHL_rp : InstRL78_8bit<0xBB,
        (outs), (ins RegOffsetAddr:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

//MOVW [DE+byte], AX    BA adr
let isCodeGenOnly = 1 in
def STORE16_memDEi_rp : InstRL78_16bit<0xBA00,
        (outs), (ins RegOffsetAddr:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

//MOVW [HL+byte], AX    BC adr
let isCodeGenOnly = 1 in
def STORE16_memHLi_rp : InstRL78_16bit<0xBC00,
        (outs), (ins RegOffsetAddr:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

} // mayLoad = 0, mayStore = 1

let mayLoad = 0, mayStore = 1 in {

// MOVW es:word[B], AX     11 58 adrl adrh
// MOVW es:word[C], AX     11 68 adrl adrh

// MOVW es:word[BC], AX     11 78 adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_esrpi_rp : InstRL78_32bit<0x11780000,
       (outs), (ins EsRegRegAddr:$addr, RL78RPRegs:$rsrc),
       "movw $addr, $rsrc",
       []>;

// MOVW es:[DE], AX         11 B9
let isCodeGenOnly = 1 in
def STORE16_esmemDE_rp : InstRL78_16bit<0x11B9,
       (outs), (ins EsRegRegAddr:$addr, RL78RPRegs:$rsrc),
       "movw $addr, $rsrc",
       []>;

// MOVW es:[HL], AX         11 BB
let isCodeGenOnly = 1 in
def STORE16_esmemHL_rp : InstRL78_16bit<0x11BB,
       (outs), (ins EsRegRegAddr:$addr, RL78RPRegs:$rsrc),
       "movw $addr, $rsrc",
       []>;

// MOVW es:[DE+byte], AX    11 BA adr
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_esmemDEi_rp : InstRL78_24bit<0x11BA00,
       (outs), (ins EsRegRegAddr:$addr, RL78RPRegs:$rsrc),
       "movw $addr, $rsrc",
       []>;


// MOVW es:[HL+byte], AX    11 BC adr
let isCodeGenOnly = 1 in
def STORE16_esmemHLi_rp : InstRL78_24bit<0x11BC00,
       (outs), (ins EsRegRegAddr:$addr, RL78RPRegs:$rsrc),
       "movw $addr, $rsrc",
       []>;

} // mayLoad = 0, mayStore = 1

//MOVW AX, [SP+byte]    A8 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def LOAD16_rp_stack_slot : InstRL78_16bit<0xA800,
        (outs RL78RPRegs:$rd), (ins STACKSlot:$addr),
        "movw $rd, $addr",
        []>;

//MOVW [SP+byte], AX    B8 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 1 in
  def STORE16_stack_slot_rp : InstRL78_16bit<0xB800,
        (outs), (ins STACKSlot:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

//MOVW ES:!addr16, AX   ;11 BF adrl adrh

let hasSideEffects = 1 in {

//MOVW AX, sfrp ;AE sfr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def LOAD16_rp_sfrp : InstRL78_16bit<0xAE00,
        (outs RL78RPRegs:$rd), (ins Sfrp:$addr),
        "movw $rd, $addr",
        []>;

//MOVW sfrp, AX ;BE sfr
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 1 in
def STORE16_sfrp_rp : InstRL78_16bit<0xBE00,
        (outs), (ins Sfrp:$addr, RL78RPRegs:$rsrc),
        "movw $addr, $rsrc",
        []>;

} // hasSideEffects = 1

} // usesCustomInserter = 1

let hasSideEffects = 1, isCodeGenOnly = 1 in {

//MOVW AX, sfrp ;AE sfr

let mayLoad = 0, mayStore = 1 in {

//MOVW sfrp, AX ;BE sfr

//MOVW sfrp,#word ;CB sfr datal datah

} // mayLoad = 0, mayStore = 1

} // hasSideEffects = 1, isCodeGenOnly = 1

//===----------------------------------------------------------------------===//
// XCHW instruction
//===----------------------------------------------------------------------===//

def SDTXCHW : SDTypeProfile<2, 2,
  [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>, SDTCisSameAs<0, 3>, SDTCisInt<0>]>;

def xchw : SDNode<"RL78ISD::XCHW", SDTXCHW, []>;

let Constraints = "$rsrc = $rd, $rsrc2 = $rd2" in
{

//Instruction   Opcode
//XCHW AX, BC   33
//XCHW AX, DE   35
//XCHW AX, HL   37

  let usesCustomInserter = 1, isCodeGenOnly = 1 in {
    let usesCustomInserter = 0 in
def BSWAP32_rp  : InstRL78_24bit<0x083308,
        (outs RL78AXRP:$rd, RL78BCDEHL:$rd2), (ins RL78AXRP:$rsrc, RL78BCDEHL:$rsrc2),
        "xch a, x\n\txchw $rd, $rsrc2\n\txch a, x",
        [(set i16:$rd, i16:$rd2, (xchw i16:$rsrc, i16:$rsrc2))]>;
  }
}

//===----------------------------------------------------------------------===//
// ONEW instruction
//===----------------------------------------------------------------------===//

let isReMaterializable = 1, mayLoad = 0, mayStore = 0 in {

//Instruction   Opcode
//ONEW AX       E6
//ONEW BC       E7
}

//===----------------------------------------------------------------------===//
// CLRW instruction
//===----------------------------------------------------------------------===//

let isReMaterializable = 1, mayLoad = 0, mayStore = 0 in {

//Instruction   Opcode
//CLRW AX       F6
//CLRW BC       F7
}

//===----------------------------------------------------------------------===//
// ADD instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [CCreg, Zflag] in {

//Instruction       Opcode
//ADD A, #byte      0C data


//Instruction       Opcode
//ADD A, !addr16    0F adrl adrh

//Instruction       Opcode
//ADD A, [HL+byte]  0E adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def ADD_r_memri : InstRL78_16bit<0x0E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "add $rd, $addr",
        []>;

//ADD A, [HL]       0D
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
def ADD_r_memHL : InstRL78_8bit<0x0D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "add $rd, $addr",
        []>;

//Instruction       Opcode
//ADD A, [HL+B]     61 80
//ADD A, [HL+C]     61 82
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def ADD_r_memrr : InstRL78_16bit<0x6180,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegRegAddr:$addr),
        "add $rd, $addr",
        []>;

//Instruction       Opcode
//ADD A, X          61 08
//ADD A, C          61 0A
//ADD A, B          61 0B
//ADD A, E          61 0C
//ADD A, D          61 0D
//ADD A, L          61 0E
//ADD A, H          61 0F
//ADD X, A          61 00
//ADD A, A          61 01
//ADD C, A          61 02
//ADD B, A          61 03
//ADD E, A          61 04
//ADD D, A          61 05
//ADD L, A          61 06
//ADD H, A          61 07
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 0 in
def ADD_r_r  : InstRL78_16bit<0x6108,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
        "add $rd, $rsrc2",
        []>;

//ADD A, saddr      0B saddr

let mayLoad = 1, mayStore = 0 in {

//ADD A, ES:!addr16 ;11 0F adrl adrh


//ADD A, ES:[HL] ;11 0D

//ADD A, ES:[HL+B] ;11 61 80
//ADD A, ES:[HL+C] ;11 61 82

//ADD A, ES:[HL+byte] ;11 0E adr

} // mayLoad = 1, mayStore = 0

} // usesCustomInserter = 1, Defs = [CCreg, Zflag]

let Defs = [CCreg, Zflag] in {
//ADD saddr, #byte  0A saddr data
}

//===----------------------------------------------------------------------===//
// ADDC instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag], Uses = [CCreg] in {

//Instruction       Opcode
//ADDC A, #byte      1C data

//Instruction       Opcode
//ADDC A, X          61 18
//ADDC A, C          61 1A
//ADDC A, B          61 1B
//ADDC A, E          61 1C
//ADDC A, D          61 1D
//ADDC A, L          61 1E
//ADDC A, H          61 1F
//ADDC X, A          61 10
//ADDC A, A          61 11
//ADDC C, A          61 12
//ADDC B, A          61 13
//ADDC E, A          61 14
//ADDC D, A          61 15
//ADDC L, A          61 16
//ADDC H, A          61 17
let mayLoad = 0, mayStore = 0 in
let isCodeGenOnly = 1 in
def ADDC_r_r  : InstRL78_16bit<0x6118,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
        "addc $rd, $rsrc2",
        []>;

let mayLoad = 1, mayStore = 0 in {

//Instruction       Opcode
//ADDC A, !addr16    1F adrl adrh

//Instruction       Opcode
//ADDC A, [HL+byte]  1E adr
let isCodeGenOnly = 1 in
def ADDC_r_memri : InstRL78_16bit<0x1E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "addc $rd, $addr",
        []>;

//ADDC A, [HL]       1D
let isCodeGenOnly = 1 in
def ADDC_r_memHL : InstRL78_8bit<0x1D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "addc $rd, $addr",
        []>;

//Instruction       Opcode
//ADDC A, [HL+B]     61 90
//ADDC A, [HL+C]     61 92


//ADDC A, ES:!addr16 ;11 1F adrl adrh

//ADDC A, ES:[HL] ;11 1D

//ADDC A, ES:[HL+byte] ;11 1E adr


//ADDC A, ES:[HL+B] ;11 61 90
//ADDC A, ES:[HL+C] ;11 61 92

} // mayLoad = 1, mayStore = 0

//Instruction       Opcode
//ADDC saddr, #byte  1A saddr data

} // Defs = [CCreg, Zflag], Uses = [CCreg]


//===----------------------------------------------------------------------===//
// SUB instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [CCreg, Zflag] in {

//Instruction       Opcode
//SUB A, #byte      2C data

//Instruction       Opcode
//SUB A, !addr16    2F adrl adrh

//Instruction       Opcode
//SUB A, [HL+byte]  2E adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def SUB_r_memri : InstRL78_16bit<0x2E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "sub $rd, $addr",
        []>;

//SUB A, [HL]       2D
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
def SUB_r_memHL : InstRL78_8bit<0x2D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "sub $rd, $addr",
        []>;

//Instruction       Opcode
//SUB A, [HL+B]     61 A0
//SUB A, [HL+C]     61 A2
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def SUB_r_memrr : InstRL78_16bit<0x61A0,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegRegAddr:$addr),
        "sub $rd, $addr",
        []>;

//Instruction       Opcode
//SUB A, X          61 28
//SUB A, C          61 2A
//SUB A, B          61 2B
//SUB A, E          61 2C
//SUB A, D          61 2D
//SUB A, L          61 2E
//SUB A, H          61 2F
//SUB X, A          61 20
//SUB A, A          61 21
//SUB C, A          61 22
//SUB B, A          61 23
//SUB E, A          61 24
//SUB D, A          61 25
//SUB L, A          61 26
//SUB H, A          61 27

//SUB A, saddr      2B saddr

let mayLoad = 1, mayStore = 0 in {

//SUB A, ES:!addr16 ;11 2F adrl adrh

//SUB A, ES:[HL] ;11 2D

//SUB A, ES:[HL+B] ;11 61 A0
//SUB A, ES:[HL+C] ;11 61 A2

//SUB A, ES:[HL+byte] ;11 2E adr

} // mayLoad = 1, mayStore = 0

} // usesCustomInserter = 1, Defs = [CCreg, Zflag]

let Defs = [CCreg, Zflag] in {
//SUB saddr, #byte  2A saddr data
        }

//===----------------------------------------------------------------------===//
// SUBC instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag], Uses = [CCreg] in {

let mayLoad = 0, mayStore = 0 in {

//Instruction       Opcode
//SUBC A, #byte      3C data

//Instruction       Opcode
//SUBC A, X          61 38
//SUBC A, C          61 3A
//SUBC A, B          61 3B
//SUBC A, E          61 3C
//SUBC A, D          61 3D
//SUBC A, L          61 3E
//SUBC A, H          61 3F
//SUBC X, A          61 30
//SUBC A, A          61 31
//SUBC C, A          61 32
//SUBC B, A          61 33
//SUBC E, A          61 34
//SUBC D, A          61 35
//SUBC L, A          61 36
//SUBC H, A          61 37

} // mayLoad = 0, mayStore = 0

let mayLoad = 1, mayStore = 0 in {

//Instruction       Opcode
//SUBC A, !addr16    3F adrl adrh

//Instruction       Opcode
//SUBC A, [HL+byte]  3E adr
let isCodeGenOnly = 1 in
def SUBC_r_memri : InstRL78_16bit<0x3E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "subc $rd, $addr",
        []>;

//SUBC A, [HL]       3D
let isCodeGenOnly = 1 in
def SUBC_r_memHL : InstRL78_8bit<0x3D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "subc $rd, $addr",
        []>;

//Instruction       Opcode
//SUBC A, [HL+B]     61 b0
//SUBC A, [HL+C]     61 b2



//SUBC A, ES:!addr16 ;11 3F adrl adrh

//SUBC A, ES:[HL] ;11 3D

//SUBC A, ES:[HL+byte] ;11 3E adr

//SUBC A, ES:[HL+B] ;11 61 B0
//SUBC A, ES:[HL+C] ;11 61 B2

} // mayLoad = 1, mayStore = 0

//SUBC saddr, #byte  3A saddr data

} // Defs = [CCreg, Zflag], Uses = [CCreg]

//===----------------------------------------------------------------------===//
// AND instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag]  in {

//Instruction       Opcode
//AND A, #byte      5C data
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 0 in
def AND_r_imm : InstRL78_16bit<0x5C00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, i8imm:$imm8),
        "and $rd, $imm8",
        []>;

//Instruction       Opcode
//AND A, !addr16    5F adrl adrh

//Instruction       Opcode
//AND A, [HL+byte]  5E adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def AND_r_memri : InstRL78_16bit<0x5E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "and $rd, $addr",
        []>;

//AND A, [HL]       5D
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
def AND_r_memHL : InstRL78_8bit<0x5D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "and $rd, $addr",
        []>;

//Instruction       Opcode
//AND A, [HL+B]     61 D0
//AND A, [HL+C]     61 D2
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def AND_r_memrr : InstRL78_16bit<0x61D0,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegRegAddr:$addr),
        "and $rd, $addr",
        []>;

//Instruction       Opcode
//AND A, X          61 58
//AND A, C          61 5A
//AND A, B          61 5B
//AND A, E          61 5C
//AND A, D          61 5D
//AND A, L          61 5E
//AND A, H          61 5F
//AND X, A          61 50
//AND A, A          61 51
//AND C, A          61 52
//AND B, A          61 53
//AND E, A          61 54
//AND D, A          61 55
//AND L, A          61 56
//AND H, A          61 57
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 0 in
def AND_r_r : InstRL78_16bit<0x6158,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
        "and $rd, $rsrc2",
        []>;

//AND A, saddr      5B saddr

let mayLoad = 1, mayStore = 0 in {

//AND A, ES:!addr16 ;11 5F adrl adrh

//AND A, ES:[HL] ;11 5D

//AND A, ES:[HL+B] ;11 61 D0
//AND A, ES:[HL+C] ;11 61 D2

//AND A, ES:[HL+byte] ;11 5E adr

} // mayLoad = 1, mayStore = 0

}

let Defs = [CCreg, Zflag] in {
//AND saddr, #byte  5A saddr data
}

def andmem : SDNode<"RL78ISD::ANDMEM", SDTIntBinOp, [SDNPCommutative, SDNPAssociative]>;

let usesCustomInserter = 1, Constraints = "$rsrc = $rd" in {

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).



// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).
}

//===----------------------------------------------------------------------===//
// OR instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag] in {

//Instruction       Opcode
//OR A, #byte       6C data

//Instruction       Opcode
//OR A, !addr16     6F adrl adrh

//Instruction       Opcode
//OR A, [HL+byte]   6E adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def OR_r_memri : InstRL78_16bit<0x6E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "or $rd, $addr",
        []>;

//OR A, [HL]        6D
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
def OR_r_memHL : InstRL78_8bit<0x6D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "or $rd, $addr",
        []>;

//Instruction       Opcode
//OR A, [HL+B]      61 E0
//OR A, [HL+C]      61 E2
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def OR_r_memrr : InstRL78_16bit<0x61E0,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegRegAddr:$addr),
        "or $rd, $addr",
        []>;

//Instruction       Opcode
//OR A, X           61 68
//OR A, C           61 6A
//OR A, B           61 6B
//OR A, E           61 6C
//OR A, D           61 6D
//OR A, L           61 6E
//OR A, H           61 6F
//OR X, A           61 60
//OR A, A           61 61
//OR C, A           61 62
//OR B, A           61 63
//OR E, A           61 64
//OR D, A           61 65
//OR L, A           61 66
//OR H, A           61 67
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 0 in
def OR_r_r : InstRL78_16bit<0x6168,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
        "or $rd, $rsrc2",
        []>;

let mayLoad = 1, mayStore = 0 in {

//OR A, saddr       6B saddr

//OR A, ES:!addr16 ;11 6F adrl adrh

//OR A, ES:[HL] ;11 6D

//OR A, ES:[HL+B] ;11 61 E0
//OR A, ES:[HL+C] ;11 61 E2

//OR A, ES:[HL+byte] ;11 6E adr

} // mayLoad = 1, mayStore = 0

}

let Defs = [CCreg, Zflag] in {
//OR saddr, #byte   6A saddr data
}

def ormem : SDNode<"RL78ISD::ORMEM", SDTIntBinOp, [SDNPCommutative, SDNPAssociative]>;

let usesCustomInserter = 1, Constraints = "$rsrc = $rd" in {

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).



// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).
}

//===----------------------------------------------------------------------===//
// XOR instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag] in {

//Instruction       Opcode
//XOR A, #byte      7C data

//Instruction       Opcode
//XOR A, !addr16    7F adrl adrh
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def XOR_r_abs16 : InstRL78_24bit<0x7F0000,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, ABS16:$addr),
        "xor $rd, $addr",
        []>;

//Instruction       Opcode
//XOR A, [HL+byte]  7E adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def XOR_r_memri : InstRL78_16bit<0x7E00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "xor $rd, $addr",
        []>;

//XOR A, [HL]       7D
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
def XOR_r_memHL : InstRL78_8bit<0x7D,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr),
        "xor $rd, $addr",
        []>;

//Instruction       Opcode
//XOR A, [HL+B]     61 F0
//XOR A, [HL+C]     61 F2
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def XOR_r_memrr : InstRL78_16bit<0x61F0,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RegRegAddr:$addr),
        "xor $rd, $addr",
        []>;

//Instruction       Opcode
//XOR A, X          61 78
//XOR A, C          61 7A
//XOR A, B          61 7B
//XOR A, E          61 7C
//XOR A, D          61 7D
//XOR A, L          61 7E
//XOR A, H          61 7F
//XOR X, A          61 70
//XOR A, A          61 71
//XOR C, A          61 72
//XOR B, A          61 73
//XOR E, A          61 74
//XOR D, A          61 75
//XOR L, A          61 76
//XOR H, A          61 77
let isCodeGenOnly = 1 in
let mayLoad = 0, mayStore = 0 in
def XOR_r_r  : InstRL78_16bit<0x6178,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
        "xor $rd, $rsrc2",
        []>;

//XOR A, saddr      7B saddr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def XOR_r_saddr  : InstRL78_16bit<0x7B00,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, ABS8:$addr),
        "xor $rd, $addr",
        []>;

let mayLoad = 1, mayStore = 0 in {

//XOR A, ES:!addr16 ;11 7F adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def XOR_r_esaddr16 : InstRL78_32bit<0x117F0000,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, EsAddr16:$addr),
        "xor $rd, $addr",
        []>;

//XOR A, ES:[HL] ;11 7D

//XOR A, ES:[HL+B] ;11 61 F0
//XOR A, ES:[HL+C] ;11 61 F2

//XOR A, ES:[HL+byte] ;11 7E adr
}

} // mayLoad = 1, mayStore = 0

let Defs = [CCreg, Zflag] in {
//XOR saddr, #byte   7A saddr data
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def XOR_saddr_imm : InstRL78_24bit<0x7A0000,
        (outs), (ins ABS8:$src, i8imm:$imm8),
        "xor $src, $imm8",
        []>;
}

def xormem : SDNode<"RL78ISD::XORMEM", SDTIntBinOp, [SDNPCommutative, SDNPAssociative]>;

let usesCustomInserter = 1, Constraints = "$rsrc = $rd" in {

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).

// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).



// Clobbers CY; Z reflects only the last byte, so no Zflag (see
// RL78CMPWithZeroElimination).

}

//===----------------------------------------------------------------------===//
// CMP instructions
//===----------------------------------------------------------------------===//

def SDTCMP : SDTypeProfile<0, 3, [SDTCisInt<0>, SDTCisSameAs<0, 1>, SDTCisInt<2>]>;

//SDNPOutGlue -> write a flag result
def cmp : SDNode<"RL78ISD::CMP", SDTCMP, [SDNPOutGlue]>;

let usesCustomInserter = 1, Defs = [CCreg, Zflag] in {

//Instruction           Opcode
//CMP A, #byte          4C data
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def CMP_r_imm : InstRL78_16bit<0x4C00,
        (outs), (ins RL78Reg:$rsrc, i8imm:$imm, i8imm:$sign),
        "cmp $rsrc, $imm",
         []>;

//CMP saddr, #byte   4A saddr data
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def CMP_saddr_imm : InstRL78_24bit<0x4A0000,
        (outs), (ins ABS8:$addr, i8imm:$imm8, i8imm:$sign),
        "cmp $addr, $imm8",
        []>;

//Instruction           Opcode
//CMP !addr16, #byte    40 adrl adrh data
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_abs16_imm : InstRL78_32bit<0x40000000,
        (outs), (ins ABS16:$addr, i8imm:$imm, i8imm:$sign),
        "cmp $addr, $imm",
         []>;

//Instruction           Opcode
//CMP A, !addr16        4F adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_abs16 : InstRL78_24bit<0x4F0000,
        (outs), (ins RL78Reg:$rsrc, ABS16:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
         []>;

//Instruction           Opcode
//CMP A, [HL+byte]      4E adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_memri : InstRL78_16bit<0x4E00,
        (outs), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;

//CMP A, [HL]           4D
let mayLoad = 1, mayStore = 0 in
  let isCodeGenOnly = 1 in
  def CMP_r_memHL : InstRL78_8bit<0x4D,
        (outs), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;

//Instruction           Opcode
//CMP A, [HL+B]         61 C0
//CMP A, [HL+C]         61 C2
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_memrr : InstRL78_16bit<0x61C0,
        (outs), (ins RL78Reg:$rsrc, RegRegAddr:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;


//Instruction           Opcode
//CMP A, r              61 4r (X -> 8, C -> A ... H -> F)
//CMP r, A              61 40 (X -> 0, A -> 1 ... H -> 7)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def CMP_r_r : InstRL78_16bit<0x6148,
        (outs), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2, i8imm:$sign),
        "cmp $rsrc, $rsrc2",
         []>;

//CMP A, saddr          4B saddr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_saddr : InstRL78_16bit<0x4B00,
        (outs), (ins RL78Reg:$rsrc, ABS8:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
         []>;

let mayLoad = 1, mayStore = 0 in {

//CMP A, ES:!addr16 ;11 4F adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_esaddr16 : InstRL78_32bit<0x114F0000,
        (outs), (ins RL78Reg:$rsrc, EsAddr16:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;

//CMP A, ES:[HL] ;11 4D

//CMP A, ES:[HL+B] ;11 61 C0
//CMP A, ES:[HL+C] ;11 61 C2
   let isCodeGenOnly = 1 in
   let mayLoad = 1, mayStore = 0 in
   def CMP_r_esmemRpr : InstRL78_24bit<0x1161C0,
        (outs), (ins RL78Reg:$rsrc, EsRegRegReg:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;

//CMP A, ES:[HL+byte] ;11 4E adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_r_esmemHLi : InstRL78_24bit<0x114E00,
        (outs), (ins RL78Reg:$rsrc, EsRegRegAddr:$addr, i8imm:$sign),
        "cmp $rsrc, $addr",
        []>;

//CMP ES:!addr16, #byte ;11 40 adrl adrh data
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP_esaddr16_imm : InstRL78_40bit<0x1140000000,
        (outs), (ins EsAddr16:$addr, i8imm:$imm, i8imm:$sign),
        "cmp $addr, $imm",
        []>;

} // mayLoad = 1, mayStore = 0

} // usesCustomInserter = 1, Defs = [CCreg, Zflag]

//===----------------------------------------------------------------------===//
// CMP0 instruction
//===----------------------------------------------------------------------===//

let  usesCustomInserter = 1, Defs = [CCreg, Zflag] in {

//Instruction           Opcode
//CMP0 r                DX (X..B -> 0..3)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def CMP0_r_cg : InstRL78_8bit<0xD0,
        (outs), (ins RL78Reg:$rsrc, i8imm:$sign),
        "cmp0 $rsrc",
         []>;

//CMP0 saddr            D4 saddr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP0_saddr_cg : InstRL78_16bit<0xD400,
        (outs), (ins ABS8:$src, i8imm:$sign),
        "cmp0 $src",
         []>;

//Instruction           Opcode
//CMP0 !addr16          D5 adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMP0_abs16_cg : InstRL78_24bit<0xD50000,
        (outs), (ins ABS16:$addr, i8imm:$sign),
        "cmp0 $addr",
         []>;

//CMP0 ES:!addr16 ;11 D5 adrl adrh
let mayLoad = 1, mayStore = 0 in
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def CMP0_esaddr16 : InstRL78_32bit<0x11D50000,
        (outs), (ins EsAddr16:$addr, i8imm:$sign),
        "cmp0 $addr",
         []>;
}

//===----------------------------------------------------------------------===//
// CMPS instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag], mayLoad = 1, mayStore = 0 in {

//Instruction           Opcode
//CMPS X, [HL+byte]     61 DE adr
let isCodeGenOnly = 1 in
def CMPS_r_memri : InstRL78_24bit<0x61DE00,
        (outs), (ins RL78Reg:$rsrc, RegOffsetAddr:$addr, i8imm:$sign),
        "cmps $rsrc, $addr",
        []>;

//Instruction         Opcode
//CMPS X, ES:[HL+byte] ;11 61 DE adr

}

//===----------------------------------------------------------------------===//
// ADDW instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag] in {
//Instruction           Opcode
//ADDW AX, #word        04 datal datah
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def ADDW_rp_imm : InstRL78_24bit<0x040000,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i16imm:$imm16),
        "addw $rd, $imm16",
         []>;

//Instruction           Opcode
//ADDW  AX, AX          01
//ADDW  AX, BC          03
//ADDW  AX, DE          05
//ADDW  AX, HL          07
  // Commutable so TwoAddressInstructionPass can pick whichever source is
  // already in the tied register.
  let isCommutable = 1 in
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def ADDW_rp_rp : InstRL78_8bit<0x01,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2),
        "addw $rd, $rsrc2",
         []>;

//Instruction           Opcode
//ADDW  AX, saddrp      06 saddr

//Instruction           Opcode
//ADDW  AX, !addr16     02 adrl adrh

//Instruction           Opcode
//ADDW  AX, [HL+byte]   61 09 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def ADDW_rp_memri : InstRL78_24bit<0x610900,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RegOffsetAddr:$addr),
        "addw $rd, $addr",
        []>;
}

//ADDW SP, #byte    10 data

let Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag], mayLoad = 1, mayStore = 0, usesCustomInserter = 1 in {

//Instruction         Opcode
//ADDW AX, ES:[HL+byte] ;11 61 09 adr

//Instruction         Opcode
//ADDW AX, ES:!addr16 ;11 02 adrl adrh

}

//===----------------------------------------------------------------------===//
// ADDE pseudos
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [CCreg, Zflag], Uses = [CCreg] in {



}


//===----------------------------------------------------------------------===//
// SUBW instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag] in
{
//Instruction           Opcode
//SUBW AX, #word        24 datal datah
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SUBW_rp_imm : InstRL78_24bit<0x240000,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i16imm:$imm16),
        "subw $rd, $imm16",
         []>;

//Instruction           Opcode
//SUBW AX, BC           23
//SUBW AX, DE           25
//SUBW AX, HL           27
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SUBW_rp_rp : InstRL78_8bit<0x23,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2),
        "subw $rd, $rsrc2",
         []>;

//Instruction           Opcode
//SUBW AX, saddrp       26 saddr

//Instruction           Opcode
//SUBW AX, !addr16      22 adrl adrh

//Instruction           Opcode
//SUBW AX, [HL+byte]    61 29 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def SUBW_rp_memri : InstRL78_24bit<0x612900,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RegOffsetAddr:$addr),
        "subw $rd, $addr",
        []>;
}

//SUBW SP, #byte    20 data

let Constraints = "$rsrc = $rd", Defs = [CCreg, Zflag], mayLoad = 1, mayStore = 0, usesCustomInserter = 1 in {
//Instruction         Opcode
//SUBW AX, ES:[HL+byte] ;11 61 29 adr

//Instruction         Opcode
//SUBW AX, ES:!addr16 ;11 22 adrl adrh
}

//===----------------------------------------------------------------------===//
// SUBE pseudos
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [CCreg, Zflag], Uses = [CCreg] in {



}

//===----------------------------------------------------------------------===//
// CMPW instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [CCreg, Zflag] in
{
//Instruction        Opcode
//CMPW AX, #word     44 datal datah
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def CMPW_rp_imm : InstRL78_24bit<0x440000,
        (outs), (ins RL78RPRegs:$rsrc, i16imm:$imm16, i8imm:$sign),
        "cmpw $rsrc, $imm16",
         []>;

//Instruction           Opcode
//CMPW AX, BC           43
//CMPW AX, DE           45
//CMPW AX, HL           47
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def CMPW_rp_rp : InstRL78_8bit<0x43,
        (outs), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2, i8imm:$sign),
        "cmpw $rsrc, $rsrc2",
         []>;

//Instruction           Opcode
//CMPW AX, saddrp       46 saddr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMPW_rp_saddr : InstRL78_16bit<0x4600,
        (outs), (ins RL78RPRegs:$rsrc, ABS8:$addr, i8imm:$sign),
        "cmpw $rsrc, $addr",
         []>;

//Instruction           Opcode
//CMPW AX, !addr16      42 adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMPW_rp_abs16 : InstRL78_24bit<0x420000,
        (outs), (ins RL78RPRegs:$rsrc, ABS16:$addr, i8imm:$sign),
        "cmpw $rsrc, $addr",
        []>;

//Instruction         Opcode
//CMPW AX, [HL+byte]  61 49 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMPW_rp_memri : InstRL78_24bit<0x614900,
        (outs), (ins RL78RPRegs:$rsrc, RegOffsetAddr:$addr, i8imm:$sign),
        "cmpw $rsrc, $addr",
        []>;

let mayLoad = 1, mayStore = 0 in {

//Instruction         Opcode
//CMPW AX, ES:[HL+byte] ;11 61 49 adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def CMPW_rp_esmemHLi : InstRL78_32bit<0x11614900,
        (outs), (ins RL78RPRegs:$rsrc, EsRegRegAddr:$addr, i8imm:$sign),
        "cmpw $rsrc, $addr",
        []>;

//Instruction         Opcode
//CMPW AX, ES:!addr16 ;11 42 adrl adrh
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def CMPW_rp_esaddr16 : InstRL78_32bit<0x11420000,
        (outs), (ins RL78RPRegs:$rsrc, EsAddr16:$addr, i8imm:$sign),
        "cmpw $rsrc, $addr",
        []>;

} // mayLoad = 1, mayStore = 0

} // usesCustomInserter = 1, Defs = [CCreg, Zflag]

//===----------------------------------------------------------------------===//
// MULU instruction
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, isCodeGenOnly = 1 in
{
// We only use the low part of the result (R0), high part is discarded however
// it is still clobbered by the instruction.
let Defs = [R1] in {
  let usesCustomInserter = 0 in
  def MUL8_r_r : InstRL78_8bit<0xD6,
        (outs RL78XReg:$rd), (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
        "mulu $rd ; $rsrc2 trunk to i8",
        [(set i8:$rd, (mul i8:$rsrc, i8:$rsrc2))]>;
}

// We have defined the same thing 3 times which is not ideal
// however the other solution will be is the define the following 2
// as Pseudo and replace them with MUL8_r_r later ... there's no need for that.
let usesCustomInserter = 0 in
def MULU_zext_16_r_r : InstRL78_8bit<0xD6,
        (outs RL78AXRP:$rd), (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
        "mulu $rsrc2 ; $rd, $rsrc, $rsrc2",
        [(set i16:$rd, (mul (i16 (zext i8:$rsrc)), (i16 (zext i8:$rsrc2))))]>;

let usesCustomInserter = 0 in
def UMUL_LOHI_16_r_r : InstRL78_8bit<0xD6,
        (outs RL78XReg:$rd, RL78AReg:$rd2), (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
        "mulu $rsrc2 ; $rd, $rd2, $rsrc, $rsrc2",
        [(set i8:$rd, i8:$rd2, (umullohi i8:$rsrc, i8:$rsrc2))]>;

let Defs = [R1], Uses = [R0, R1], mayLoad = 0, mayStore = 0, isCodeGenOnly = 0 in {
let isCodeGenOnly = 1 in
def MULU_r : InstRL78_8bit<0xD6,
        (outs RL78XReg:$rd), (ins),
        "mulu $rd",
        []>;
}
}

//===----------------------------------------------------------------------===//
// MULHU_cg instruction
//===----------------------------------------------------------------------===//

def isS3Core : Predicate<"Subtarget->isRL78S3CoreType()">;
def isNotS3Core : Predicate<"!Subtarget->isRL78S3CoreType()">;
//OBS. Since we are discarding the high 16 part of the result (from BC)
// we need signal that value from BC is def.
let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1, Defs = [RP2] in
{
//we could have used mulh instead mulh just as easy; it makes no difference
 let usesCustomInserter = 0 in
 def MUL16_rp_rp : InstRL78_24bit<0xCEFB01,
        (outs RL78AXRP:$rd), (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
        "mulhu ;$rd, $rsrc2 trunk to i16",
        [(set i16:$rd, (mul i16:$rsrc, i16:$rsrc2))]>;
}

let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1 in {
let usesCustomInserter = 0 in
def MUL32_zext_r_r : InstRL78_24bit<0xCEFB01,
        (outs RL78AXRP:$rd, RL78BCRP:$rd2), (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
        "mulhu ;$rd, $rd2, $rsrc, $rsrc2",
        [(set i16:$rd, i16:$rd2, (umullohi i16:$rsrc, i16:$rsrc2))]>;
}

let Predicates = [isS3Core], usesCustomInserter = 1, mayLoad = 0, mayStore = 0 in {


}

let Predicates = [isNotS3Core], usesCustomInserter = 1 in {

 def MUL16_rp_rp_S1_S2 : Pseudo<
       (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2),
       ";mulu $rd, $rsrc, $rsrc2",
       [(set i16:$rd, (mul i16:$rsrc, i16:$rsrc2))]>;

  }

//===----------------------------------------------------------------------===//
// MULH_cg instruction
//===----------------------------------------------------------------------===//

let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1 in {
let usesCustomInserter = 0 in
def MUL32_sext_r_r : InstRL78_24bit<0xCEFB02,
        (outs RL78AXRP:$rd, RL78BCRP:$rd2), (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
        "mulh ;$rd, $rd2, $rsrc, $rsrc2",
        [(set i16:$rd, i16:$rd2, (smullohi i16:$rsrc, i16:$rsrc2))]>;
}

let Predicates = [isS3Core], usesCustomInserter = 1, mayLoad = 0, mayStore = 0 in {


}

//===----------------------------------------------------------------------===//
// DIVHU_cg instruction
//===----------------------------------------------------------------------===//

let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1 in {

// The NOP_cg is based on RENESAS TECHNICAL UPDATE TN-RL*-A025C/E.
let usesCustomInserter = 0 in
def UDIVREM16_r_r : InstRL78_32bit<0xCEFB0300,
        (outs RL78AXRP:$rd, RL78DERP:$rd2), (ins RL78AXRP:$rsrc, RL78DERP:$rsrc2),
        "divhu ;$rd, $rd2, $rsrc, $rsrc2\n\tnop",
        [(set i16:$rd, i16:$rd2, (udivrem i16:$rsrc, i16:$rsrc2))]>;
}

let Predicates = [isS3Core], usesCustomInserter = 1, mayLoad = 0, mayStore = 0 in {


}

//===----------------------------------------------------------------------===//
// DIVWU_cg instruction
//===----------------------------------------------------------------------===//

def SDTDIVWU : SDTypeProfile<4, 4,
  [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>, SDTCisSameAs<0, 3>, SDTCisSameAs<0, 4>,
   SDTCisSameAs<0, 5>, SDTCisSameAs<0, 6>, SDTCisSameAs<0, 7>, SDTCisInt<0>]>;

def divwu : SDNode<"RL78ISD::DIVWU", SDTDIVWU, []>;

let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1 in {

// The NOP_cg is based on RENESAS TECHNICAL UPDATE TN-RL*-A025C/E.
let usesCustomInserter = 0 in
def UDIVREM32_r_r : InstRL78_32bit<0xCEFB0B00,
        (outs RL78AXRP:$rd, RL78BCRP:$rd2, RL78DERP:$rd3, RL78HL:$rd4),
        (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2, RL78DERP:$rsrc3, RL78HL:$rsrc4),
        "divwu ;$rd, $rd2, $rd3, $rd4, $rsrc, $rsrc2, $rsrc3, $rsrc4\n\tnop",
        [(set i16:$rd, i16:$rd2, i16:$rd3, i16:$rd4,
         (divwu i16:$rsrc, i16:$rsrc2, i16:$rsrc3, i16:$rsrc4))]>;
}

let Predicates = [isS3Core], usesCustomInserter = 1, mayLoad = 0, mayStore = 0 in {


}

//===----------------------------------------------------------------------===//
// MACHU_cg/MACH_cg instructions
//===----------------------------------------------------------------------===//

def SDTMACHU : SDTypeProfile<2, 4,
  [SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>, SDTCisSameAs<0, 3>, SDTCisSameAs<0, 4>,
   SDTCisSameAs<0, 5>, SDTCisInt<0>]>;

def machu : SDNode<"RL78ISD::MACHU", SDTMACHU, []>;
def mach :  SDNode<"RL78ISD::MACH", SDTMACHU, []>;

let Predicates = [isS3Core], usesCustomInserter = 1, isCodeGenOnly = 1, Defs = [CCreg] in {

// X + Y * Z
let usesCustomInserter = 0 in
def MACHU_CG : InstRL78_24bit<0xCEFB05,
        (outs RL78RegMACRL:$rd1, RL78RegMACRH:$rd2), (ins RL78RegMACRL:$rsrcXL, RL78RegMACRH:$rsrcXH, RL78AXRP:$rsrcY, RL78BCRP:$rsrcZ),
        "machu ; macr, ax, bc",
        [(set i16:$rd1, i16:$rd2,
         (machu i16:$rsrcXL, i16:$rsrcXH, i16:$rsrcY, i16:$rsrcZ))]>;

let usesCustomInserter = 0 in
def MACH_CG : InstRL78_24bit<0xCEFB06,
        (outs RL78RegMACRL:$rd1, RL78RegMACRH:$rd2), (ins RL78RegMACRL:$rsrcXL, RL78RegMACRH:$rsrcXH, RL78AXRP:$rsrcY, RL78BCRP:$rsrcZ),
        "mach ; macr, ax, bc",
        [(set i16:$rd1, i16:$rd2,
         (mach i16:$rsrcXL, i16:$rsrcXH, i16:$rsrcY, i16:$rsrcZ))]>;

}

let Predicates = [isS3Core], Defs = [CCreg], mayLoad = 0, mayStore = 0 in {


}

let Predicates = [isS3Core], Defs = [CCreg], mayLoad = 0, mayStore = 0 in {


}

//===----------------------------------------------------------------------===//
// INC instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag] in {

let Constraints = "$rsrc = $rd" in {

//Instruction       Opcode
//INC r             80 (X..H -> 0..7)

} // Constraints = "$rsrc = $rd"

//Instruction       Opcode
//INC saddr         A4 saddr

//Instruction       Opcode
//INC !addr16       A0 adrl adrh

let mayLoad = 1, mayStore = 1, usesCustomInserter = 1 in {

//INC ES:!addr16 ;11 A0 adrl adrh

//INC ES:[HL+byte] ;11 61 59 adr

} // mayLoad = 1, mayStore = 1

let usesCustomInserter = 1 in {

//Instruction       Opcode
//INC [HL+byte]     61 59 adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def INC_memri : InstRL78_24bit<0x615900,
        (outs), (ins RegOffsetAddr:$addr),
        "inc $addr",
        []>;

} // usesCustomInserter = 1

} // Defs = [CCreg, Zflag]

def inc : SDNode<"RL78ISD::INC", SDTUnaryOp, [SDNPMemOperand]>;

//===----------------------------------------------------------------------===//
// DEC instruction
//===----------------------------------------------------------------------===//

let Defs = [CCreg, Zflag] in {

let Constraints = "$rsrc = $rd" in {

//Instruction       Opcode
//DEC r             90 (X..H -> 0..7)

} // Constraints = "$rsrc = $rd"

//Instruction       Opcode
//DEC saddr         B4 saddr

//Instruction        Opcode
//DEC !addr16       B0 adrl adrh

let mayLoad = 1, mayStore = 1, usesCustomInserter = 1 in {

//DEC ES:!addr16 ;11 B0 adrl adrh

//DEC ES:[HL+byte] ;11 61 69 adr

} // mayLoad = 1, mayStore = 1

let usesCustomInserter = 1 in {

//Instruction       Opcode
//DEC [HL+byte]     61 69 adr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def DEC_memri : InstRL78_24bit<0x616900,
        (outs), (ins RegOffsetAddr:$addr),
        "dec $addr",
        []>;

} // usesCustomInserter = 1

} // Defs = [CCreg, Zflag]


//===----------------------------------------------------------------------===//
// INCW instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd" in {

//Instruction       Opcode
//INCW AX           A1
//INCW BC           A3
//INCW DE           A5
//INCW HL           A7
}

//Instruction       Opcode
//INCW saddrp       A6 saddr

//Instruction       Opcode
//INCW addr16       A2 adrl adrh

let mayLoad = 1, mayStore = 1, usesCustomInserter = 1 in {

//INCW ES:!addr16 ;11 A2 adrl adrh

//INCW ES:[HL+byte] ;11 61 79 adr

} // mayLoad = 1, mayStore = 1

let usesCustomInserter = 1 in {

//Instruction       Opcode
//INCW [HL+byte]    61 79 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 1 in
  def INCW_memri : InstRL78_24bit<0x617900,
        (outs), (ins RegOffsetAddr:$addr),
        "incw $addr",
        []>;
}

//===----------------------------------------------------------------------===//
// DECW instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd" in {

//Instruction       Opcode
//DECW AX           B1
//DECW BC           B3
//DECW DE           B5
//DECW HL           B7
}

//Instruction       Opcode
//DECW saddrp       B6 saddr

//Instruction       Opcode
//DECW addr16       B2 adrl adrh

let mayLoad = 1, mayStore = 1, usesCustomInserter = 1 in {

//DECW ES:!addr16 ;11 B2 adrl adrh

//DECW ES:[HL+byte] ;11 61 89 adr

} // mayLoad = 1, mayStore = 1

let usesCustomInserter = 1 in {

//Instruction       Opcode
//DECW [HL+byte]    61 89 adr
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 1 in
  def DECW_memri : InstRL78_24bit<0x618900,
        (outs), (ins RegOffsetAddr:$addr),
        "decw $addr",
        []>;
}

//===----------------------------------------------------------------------===//
// SHR instruction
//===----------------------------------------------------------------------===//


let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {

//Instruction       Opcode
//SHR A, X          31 XA (X -> 1..7)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SHR_r_i  : InstRL78_16bit<0x310A,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, shift8imm:$imm),
        "shr $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SHR_r_r : Pseudo<
    (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
    ";shr $rd, $rsrc2",
    [(set i8:$rd, (srl i8:$rsrc, i8:$rsrc2))]>;

}

//===----------------------------------------------------------------------===//
// SHRW instruction
//===----------------------------------------------------------------------===//


let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {

//Instruction       Opcode
//SHRW AX, 1        31 1E
//SHRW AX, 2        31 2E
//SHRW AX, 3        31 3E
//SHRW AX, 4        31 4E
//SHRW AX, 5        31 5E
//SHRW AX, 6        31 6E
//SHRW AX, 7        31 7E
//SHRW AX, 8        31 8E
//SHRW AX, 9        31 9E
//SHRW AX, 10       31 AE
//SHRW AX, 11       31 BE
//SHRW AX, 12       31 CE
//SHRW AX, 13       31 DE
//SHRW AX, 14       31 EE
//SHRW AX, 15       31 FE
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SHRW_rp_i  : InstRL78_16bit<0x311E,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, shift16imm:$imm),
        "shrw $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SHRW_rp_rp : Pseudo<
    (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78Reg:$rsrc2),
    ";shrw $rd, $rsrc2",
    [(set i16:$rd, (srl i16:$rsrc, i8:$rsrc2))]>;
}

//===----------------------------------------------------------------------===//
// SHL instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {
//Instruction       Opcode
//SHL A, X          31 X9 (X -> 1..7)
//SHL B, X          31 X8 (X -> 1..7)
//SHL C, X          31 X7 (X -> 1..7)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SHL_r_imm  : InstRL78_16bit<0x3119,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, shift8imm:$imm),
        "shl $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SHL_r_r : Pseudo<
    (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
    ";shl $rd, $rsrc2",
    [(set i8:$rd, (shl i8:$rsrc, i8:$rsrc2))]>;

}

//===----------------------------------------------------------------------===//
// SHLW instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {

//Instruction       Opcode
//SHLW AX, X        31 XD (X -> 1..15)
//SHLW BC, X        31 XC (X -> 1..15)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SHLW_rp_imm  : InstRL78_16bit<0x311D,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, shift16imm:$imm),
        "shlw $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SHLW_rp_rp : Pseudo<
    (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78Reg:$rsrc2),
    ";shlw $rd, $rsrc2",
    [(set i16:$rd, (shl i16:$rsrc, i8:$rsrc2))]>;
}

//===----------------------------------------------------------------------===//
// SAR instruction
//===----------------------------------------------------------------------===//
let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {

//Instruction       Opcode
//SAR A, X          31 XB (X -> 1..7)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SAR_r_i  : InstRL78_16bit<0x310B,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, shift8imm:$imm),
        "sar $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SAR_r_r : Pseudo<
    (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
    ";sar $rd, $rsrc2",
    [(set i8:$rd, (sra i8:$rsrc, i8:$rsrc2))]>;

}

//===----------------------------------------------------------------------===//
// SARW instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {

//Instruction       Opcode
//SARW AX, 1        31 1F
//SARW AX, 2        31 2F
//SARW AX, 3        31 3F
//SARW AX, 4        31 4F
//SARW AX, 5        31 5F
//SARW AX, 6        31 6F
//SARW AX, 7        31 7F
//SARW AX, 8        31 8F
//SARW AX, 9        31 9F
//SARW AX, 10       31 AF
//SARW AX, 11       31 BF
//SARW AX, 12       31 CF
//SARW AX, 13       31 DF
//SARW AX, 14       31 EF
//SARW AX, 15       31 FF
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def SARW_rp_i  : InstRL78_16bit<0x311F,
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, shift16imm:$imm),
        "sarw $rd, $imm",
        []>;
}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [R3] in {

def SARW_rp_rp : Pseudo<
    (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78Reg:$rsrc2),
    ";sarw $rd, $rsrc2",
    [(set i16:$rd, (sra i16:$rsrc, i8:$rsrc2))]>;
}

//===----------------------------------------------------------------------===//
// ROTL/ROTR pseudos
//===----------------------------------------------------------------------===//

let usesCustomInserter = 1, Defs = [R3] in {
  def ROTL_r_imm : Pseudo<
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, i8imm:$imm),
        ";rotl $rd, $rsrc, $imm",
        [(set i8:$rd, (rotl i8:$rsrc, (i8 imm:$imm)))]>;

  def ROTR_r_imm : Pseudo<
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, i8imm:$imm),
        ";rotr $rd, $rsrc, $imm",
        [(set i8:$rd, (rotr i8:$rsrc, (i8 imm:$imm)))]>;

  def ROTL16_r_imm : Pseudo<
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i8imm:$imm),
        ";rotl $rd, $rsrc, $imm",
        [(set i16:$rd, (rotl i16:$rsrc, (i8 imm:$imm)))]>;

  def ROTR16_r_imm : Pseudo<
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i8imm:$imm),
        ";rotr $rd, $rsrc, $imm",
        [(set i16:$rd, (rotr i16:$rsrc, (i8 imm:$imm)))]>;

}

let Constraints = "$rsrc = $rd", usesCustomInserter = 1 in {

def ROTR_rp_rp : Pseudo<
    (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
    ";rotr $rd, $rsrc2",
    [(set i8:$rd, (rotr i8:$rsrc, i8:$rsrc2))]>;

def ROTL_rp_rp : Pseudo<
    (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2),
    ";rotl $rd, $rsrc2",
    [(set i8:$rd, (rotl i8:$rsrc, i8:$rsrc2))]>;

def ROTR16_rp_rp : Pseudo<
    (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78Reg:$rsrc2),
    ";rotr $rd, $rsrc2",
    [(set i16:$rd, (rotr i16:$rsrc, i8:$rsrc2))]>;

def ROTL16_rp_rp : Pseudo<
    (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78Reg:$rsrc2),
    ";rotl $rd, $rsrc2",
    [(set i16:$rd, (rotl i16:$rsrc, i8:$rsrc2))]>;

}

//===----------------------------------------------------------------------===//
// ROR instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1  in
{
//Instruction       Opcode
//ROR A, 1          61 DB
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def ROR_r_1 : InstRL78_16bit<0x61DB,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc),
        "ror $rd, 1",
        []>;
}

//===----------------------------------------------------------------------===//
// ROL instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], usesCustomInserter = 1 in {
//Instruction       Opcode
//ROL A, 1          61 EB
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def ROL_r_1  : InstRL78_16bit<0x61EB,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc),
        "rol $rd, 1",
        []>;
}

//===----------------------------------------------------------------------===//
// RORC instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], Uses = [CCreg] in {
//Instruction       Opcode
//RORC A, 1         61 FB
}

//===----------------------------------------------------------------------===//
// ROLC instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], Uses = [CCreg] in {
//Instruction       Opcode
//ROLC A, 1         61 DC
}

//===----------------------------------------------------------------------===//
// ROLWC instruction
//===----------------------------------------------------------------------===//

let Constraints = "$rsrc = $rd", Defs = [CCreg], Uses = [CCreg] in {

//Instruction       Opcode
//ROLWC AX, 1       61 EE
//ROLWC BC, 1       61 FE
}

//===----------------------------------------------------------------------===//
// MOV1 instruction
//===----------------------------------------------------------------------===//

def SDTMOV1TOCY : SDTypeProfile<0, 2, [SDTCisSameAs<0, 1>, SDTCisInt<0>]>;
def mov1tocy : SDNode<"RL78ISD::MOV1TOCY", SDTMOV1TOCY, [SDNPHasChain, SDNPOptInGlue]>;

def SDTLOAD1TOCY : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisPtrTy<1>]>;
def load1tocy : SDNode<"RL78ISD::LOAD1TOCY", SDTLOAD1TOCY, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;

let Defs = [CCreg] in {

//Instruction       Opcode
//MOV1 CY, saddr.X      71 X4 saddr (X -> 0..7)
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 0 in
def MOV1_cy_saddr : InstRL78_24bit<0x710400,
        (outs), (ins ABS8:$addr, bitimm:$imm),
        "mov1 cy, $addr$imm",
        []>;

let usesCustomInserter = 1 in {
//Instruction           Opcode
//MOV1 CY, A.X          71 XC (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def MOV1_cy_r : InstRL78_16bit<0x718C,
        (outs), (ins RL78Reg:$rsrc, bitimm:$imm),
        "mov1 cy, $rsrc$imm",
        []>;
}

let usesCustomInserter = 1 in {
//Instruction           Opcode
//MOV1 CY, [HL].X       71 X4 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def MOV1_cy_memr : InstRL78_16bit<0x7184,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "mov1 cy, $addr$imm",
        []>;
}
}

def : Pat<(mov1tocy (i8 (load SADDR:$addr)), (i8 imm:$imm)),
          (MOV1_cy_saddr SADDR:$addr, imm:$imm)>;

let Defs = [CCreg], Uses = [CCreg], hasSideEffects = 1 in {

//Instruction           Opcode
//MOV1 PSW.X, CY		71 X9 FA (X -> 0..7)


//Instruction           Opcode
//MOV1 CY, PSW.0		71 XC FA (X -> 0..7)
}

def SDTIntMov1FromCy : SDTypeProfile<1, 3, [
  SDTCisSameAs<0, 3>, SDTCisSameAs<0, 1>, SDTCisSameAs<0, 2>, SDTCisInt<0>
]>;

def mov1fromcy : SDNode<"RL78ISD::MOV1FROMCY", SDTIntMov1FromCy, []>;

def store1fromcy : SDNode<"RL78ISD::STORE1FROMCY", SDTLOAD1TOCY, [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;

let usesCustomInserter = 1, Constraints = "$rsrc = $rd", Uses = [CCreg] in {
//Instruction           Opcode
//MOV1 A.X, CY          71 X9 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 0, mayStore = 0 in
  def MOV1_r_cy : InstRL78_16bit<0x7189,
        (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, bitimm:$imm),
        "mov1 $rd$imm, cy",
        []>;
}

let usesCustomInserter = 1, Uses = [CCreg] in {
//Instruction           Opcode
//MOV1 [HL].X, CY       71 X1 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 1 in
  def MOV1_memr_cy : InstRL78_16bit<0x7181,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "mov1 $addr$imm, cy",
        []>;
}

let Uses = [CCreg] in {

//Instruction           Opcode
//MOV1 saddr.X, CY      71 X1 saddr (X -> 0..7)

let hasSideEffects = 1 in {

//Instruction         Opcode
//MOV1 sfr.0. CY  71 09 sfr   (X -> 0..7)

//Instruction         Opcode
//MOV1 sfr.0. CY  71 09 sfr   (X -> 0..7)
let mayLoad = 0, mayStore = 1, isCodeGenOnly = 1 in
  def MOV1_sfrReg_cy : InstRL78_24bit<0x710900,
        (outs), (ins RL78SfrReg:$addr, bitimm:$imm, RL78RegCY:$rcy),
        "mov1 $addr$imm, $rcy",
        []>;

//Instruction         Opcode
//MOV1 CY, sfr.x ;71 xC sfr   (X -> 0..7)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def MOV1_cy_sfr : InstRL78_24bit<0x710C00,
        (outs), (ins Sfr:$addr, bitimm:$imm),
        "mov1 cy, $addr$imm ",
        []>;

//Instruction         Opcode
//MOV1 CY, sfr.x ;71 xC sfr   (X -> 0..7)
let mayLoad = 1, mayStore = 0, isCodeGenOnly = 1 in
  def MOV1_cy_sfrReg : InstRL78_24bit<0x710C00,
        (outs), (ins RL78RegCY:$rcy, RL78SfrReg:$addr, bitimm:$imm),
        "mov1 $rcy, $addr$imm ",
        []>;

} // hasSideEffects = 1

//Instruction               Opcode
//MOV1 CY, ES:[HL].0    ;11 71 84

//MOV1 ES:[HL].0, CY    ;11 71 81


}

//===----------------------------------------------------------------------===//
// AND1 instruction
//===----------------------------------------------------------------------===//

def and1cy : SDNode<"RL78ISD::AND1CY", SDTLOAD1TOCY, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;

let Uses = [CCreg], Defs = [CCreg] in {

//Instruction           Opcode
//AND1 CY, saddr.X      71 X5 saddr (X -> 0..7)
let mayLoad = 0, mayStore = 0, isCodeGenOnly = 1 in
  def AND1_cy_r : InstRL78_24bit<0x710500,
        (outs), (ins RL78Reg:$rsrc, bitimm:$imm),
        "and1 cy, $rsrc$imm",
        []>;

//Instruction           Opcode
//AND1 CY, saddr.X      71 X5 saddr (X -> 0..7)

//AND1 CY, A.X          71 XD (X -> 0..7 -> 8..F)
let mayLoad = 0, mayStore = 0 in
  let isCodeGenOnly = 1 in
  def AND1_cy_A : InstRL78_16bit<0x718D,
        (outs), (ins RL78AReg:$rsrc, bitimm:$imm),
        "and1 cy, $rsrc$imm",
        []>;

let usesCustomInserter = 1 in {
//Instruction           Opcode
//AND1 CY, [HL].X       71 X5 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def AND1_cy_memr : InstRL78_16bit<0x7185,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "and1 cy, $addr$imm",
        []>;
}

let mayLoad = 1, mayStore = 0 in {

let hasSideEffects = 1 in {

//Instruction         Opcode
//AND1 CY, sfr.0         ;71 0D sfr (X -> 0..7)

//Instruction         Opcode
//AND1 CY, sfr.0         ;71 0D sfr (X -> 0..7)


//AND1 CY, PSW.0         ;71 0D FA  (X -> 0..7 -> 8..F)

} // hasSideEffects = 1

//Instruction               Opcode
//AND1 CY, ES:[HL].0       ;11 71 85

} // mayLoad = 1, mayStore = 0

} // Uses = [CCreg], Defs = [CCreg]

//===----------------------------------------------------------------------===//
// OR1 instruction
//===----------------------------------------------------------------------===//

def or1cy : SDNode<"RL78ISD::OR1CY", SDTLOAD1TOCY, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;

let Uses = [CCreg], Defs = [CCreg] in {

//Instruction           Opcode
//OR1  CY, saddr.X      71 X6 saddr (X -> 0..7)
let mayLoad = 0, mayStore = 0, isCodeGenOnly = 1 in
  def OR1_cy_r : InstRL78_24bit<0x710600,
        (outs), (ins RL78Reg:$rsrc, bitimm:$imm),
        "or1 cy, $rsrc$imm",
        []>;

//Instruction           Opcode
//OR1 CY, saddr.X      71 X6 saddr (X -> 0..7)

//OR1 CY, A.X           71 XE (X -> 0..7 -> 8..F)
let mayLoad = 0, mayStore = 0 in
  let isCodeGenOnly = 1 in
  def OR1_cy_A : InstRL78_16bit<0x718E,
        (outs), (ins RL78AReg:$rsrc, bitimm:$imm),
        "or1 cy, $rsrc$imm",
        []>;

let mayLoad = 1, mayStore = 0 in {

let usesCustomInserter = 1 in {
//Instruction           Opcode
//OR1 CY, [HL].X        71 X6 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def OR1_cy_memr : InstRL78_16bit<0x7186,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "or1 cy, $addr$imm",
        []>;
}

let hasSideEffects = 1 in {

//Instruction         Opcode
//OR1 CY, sfr.X    71 0E sfr (X -> 0..7)

//Instruction         Opcode
//OR1 CY, sfr.X    71 0E sfr (X -> 0..7)

//OR1 CY, PSW.0            ;71 0E FA  (X -> 0..7 -> 8..F)

} // hasSideEffects = 1

//Instruction               Opcode
//OR1 CY, ES:[HL].7 ;11 71 86

} // mayLoad = 1, mayStore = 0

} // Uses = [CCreg], Defs = [CCreg]

//===----------------------------------------------------------------------===//
// XOR1 instruction
//===----------------------------------------------------------------------===//

def xor1cy : SDNode<"RL78ISD::XOR1CY", SDTLOAD1TOCY, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;

let Uses = [CCreg], Defs = [CCreg] in {

//Instruction           Opcode
//XOR1 CY, A.X        71 XF (X -> 0..7 -> 8..F)
let mayLoad = 0, mayStore = 0 in
  let isCodeGenOnly = 1 in
  def XOR1_cy_A : InstRL78_16bit<0x718F,
        (outs), (ins RL78AReg:$rsrc, bitimm:$imm),
        "xor1 cy, $rsrc$imm",
        []>;

let mayLoad = 1, mayStore = 0 in {

//Instruction         Opcode
//XOR1 CY, saddr.X    71 X7 saddr (X -> 0..7)
  let isCodeGenOnly = 1 in
  def XOR1_cy_r : InstRL78_24bit<0x710700,
        (outs), (ins RL78Reg:$rsrc, bitimm:$imm),
        "xor1 cy, $rsrc$imm",
        []>;

//Instruction           Opcode
//XOR1 CY, saddr.X      71 X7 saddr (X -> 0..7)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def XOR1_cy_saddrx : InstRL78_24bit<0x710700,
        (outs), (ins ABS8:$addr, bitimm:$imm),
        "xor1 cy, $addr$imm",
        []>;

let usesCustomInserter = 1 in {
//Instruction           Opcode
//XOR1 CY, [HL].X       71 X7 (X -> 0..7 -> 8..F)
  let isCodeGenOnly = 1 in
  let mayLoad = 1, mayStore = 0 in
  def XOR1_cy_memr : InstRL78_16bit<0x7187,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "xor1 cy, $addr$imm",
        []>;
} // usesCustomInserter = 1

let hasSideEffects = 1 in {

//Instruction         Opcode
//XOR1 CY, sfr.X    71 0F sfr (X -> 0..7)

//Instruction         Opcode
//XOR1 CY, sfr.X    71 0F sfr (X -> 0..7)

//XOR1 CY, PSW.7 ;71 xF FA (X -> 0..7 -> 8..F)

} // hasSideEffects = 1

//Instruction               Opcode
//XOR1 CY, ES:[HL].7 ;11 71 87
let isCodeGenOnly = 1 in
def XOR1_esmemr : InstRL78_24bit<0x117187,
           (outs), (ins EsHlRegAddr:$addr, bitimm:$imm),
           "xor1 cy, $addr$imm",
           []>;

} // mayLoad = 1, mayStore = 0

} // Uses = [CCreg], Defs = [CCreg]

//===----------------------------------------------------------------------===//
// SET1 instruction
//===----------------------------------------------------------------------===//
// From the description it is clear this is only for SET1/CLR1 with dst being a memory operand.
// No need to replace AND/OR in case the dst is a register as the size and speed are the same.

def SDTSET1CLR1 : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisPtrTy<1>]>;

def set1 : SDNode<"RL78ISD::SET1", SDTSET1CLR1, [SDNPHasChain, SDNPMayLoad, SDNPMayStore, SDNPMemOperand]>;

let Constraints = "$rsrc = $rd", mayLoad = 0, mayStore = 0 in {
//Instruction           Opcode
//SET1 A.X              71 XA (X -> 0..7 -> 8..F)
}


//Instruction           Opcode
//SET1 saddr.X          71 X2 saddr (X -> 0..7)


//Instruction           Opcode
//SET1 !addr16.X        71 X0 adrl adrh (X -> 0..7)

let usesCustomInserter = 1 in {
//Instruction           Opcode
//SET1 [HL].X           71 X2 (X -> 0..7 -> 8..F)
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def SET1_memr : InstRL78_16bit<0x7182,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "set1 $addr$imm",
        []>;
}

let hasSideEffects = 1 in {

let Constraints = "$rsrc = $rd" in
{
//SET1 PSW.x                  ;71 xA FA
}

//SET1 sfr.0                  ;71 xA sfr


//SET1 sfr.0                  ;71 xA sfr

} // hasSideEffects = 1

//Instruction           Opcode
//SET1 CY        ;71 80
let Defs = [CCreg], mayLoad = 0, mayStore = 0 in
let isCodeGenOnly = 1 in
def SET1_cy : InstRL78_16bit<0x7180,
        (outs), (ins RL78RegCY:$rcy),
        "set1 $rcy",
        []>;

let usesCustomInserter = 1 in {
//Instruction               Opcode
//SET1 ES:!addr16.0            ;11 71 x0 adrl adrh

//SET1 ES:[HL].0               ;11 71 82

}

//===----------------------------------------------------------------------===//
// CLR1 instruction
//===----------------------------------------------------------------------===//

def clr1 : SDNode<"RL78ISD::CLR1", SDTSET1CLR1, [SDNPHasChain, SDNPMayLoad, SDNPMayStore, SDNPMemOperand]>;

let Constraints = "$rsrc = $rd", mayLoad = 0, mayStore = 0 in
{

//Instruction           Opcode
//CLR1 A.X              71 XB (X -> 0..7 -> 8..F)
}


//Instruction           Opcode
//CLR1 saddr.X          71 X3 saddr (X -> 0..7)
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def CLR1_saddr : InstRL78_24bit<0x710300,
        (outs), (ins ABS8:$addr, bitimm:$imm),
        "clr1 $addr$imm",
        []>;

//Instruction           Opcode
//CLR1 !addr16.X        71 X8 adrl adrh (X -> 0..7)

let usesCustomInserter = 1 in {
//Instruction           Opcode
//CLR1 [HL].X           71 X3 (X -> 0..7 -> 8..F)
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def CLR1_memr : InstRL78_16bit<0x7183,
        (outs), (ins HLAddr:$addr, bitimm:$imm),
        "clr1 $addr$imm",
        []>;
}

let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {

let Constraints = "$rsrc = $rd" in
{
//CLR1 PSW.X ;71 XB FA
}

//CLR1 sfr.x ;71 xB sfr
let isCodeGenOnly = 1 in
let mayLoad = 1, mayStore = 1 in
def CLR1_sfr : InstRL78_24bit<0x710B00,
        (outs), (ins Sfr:$addr, bitimm:$imm),
        "clr1 $addr$imm",
        []>;

//CLR1 sfr.x ;71 xB sfr

} // hasSideEffects = 1

//Instruction           Opcode
//CLR1 CY           71 88
let Defs = [CCreg], mayLoad = 0, mayStore = 0 in
let isCodeGenOnly = 1 in
def CLR1_cy : InstRL78_16bit<0x7188,
        (outs), (ins RL78RegCY:$rcy),
        "clr1 $rcy",
        []>;

let usesCustomInserter = 1 in {
//Instruction               Opcode
//CLR1 ES:!addr16.x ;11 71 x8 adrl adrh

//CLR1 ES:[HL].7 ;11 71 F3
}


//===----------------------------------------------------------------------===//
// NOT1 instruction
//===----------------------------------------------------------------------===//

def SDTNOT1CY : SDTypeProfile<0, 0, []>;
def not1cy : SDNode<"RL78ISD::NOT1CY", SDTNOT1CY, [SDNPHasChain, SDNPOptInGlue]>;

//Instruction           Opcode
//NOT1 CY               71 C0
let Defs = [CCreg], Uses = [CCreg] in {
}

//===----------------------------------------------------------------------===//
// CALL instruction
//===----------------------------------------------------------------------===//

def SDT_RL78CallSeqStart : SDCallSeqStart<[ SDTCisVT<0, i16>,
                                          SDTCisVT<1, i16> ]>;
def SDT_RL78CallSeqEnd   : SDCallSeqEnd<[ SDTCisVT<0, i16>,
                                        SDTCisVT<1, i16> ]>;

def callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_RL78CallSeqStart,
                           [SDNPHasChain, SDNPOutGlue]>;
def callseq_end   : SDNode<"ISD::CALLSEQ_END",   SDT_RL78CallSeqEnd,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

let Defs = [SPreg], Uses = [SPreg] in {
def ADJCALLSTACKDOWN : Pseudo<(outs), (ins i16imm:$amt1, i16imm:$amt2),
                               ";ADJCALLSTACKDOWN $amt1, $amt2",
                               [(callseq_start timm:$amt1, timm:$amt2)]>;
def ADJCALLSTACKUP : Pseudo<(outs), (ins i16imm:$amt1, i16imm:$amt2),
                            ";ADJCALLSTACKUP $amt1",
                            [(callseq_end timm:$amt1, timm:$amt2)]>;
}

let isCodeGenOnly = 1, mayLoad = 0, mayStore = 0, Defs = [SPreg], Uses = [SPreg] in {
def CALL_STACK_SETUP : InstRL78_8bit<0x0, (outs), (ins i16imm:$amt1),
                               ";CALL_STACK_SETUP $amt1",
                               []>;
def CALL_STACK_DESTROY : InstRL78_8bit<0x0, (outs), (ins i16imm:$amt1),
                            ";CALL_STACK_DESTROY $amt1",
                            []>;
}

def SDTRL78Call : SDTypeProfile<0, -1, [SDTCisVT<0, iPTR>]>;

def call : SDNode<"RL78ISD::CALL", SDTRL78Call,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                            SDNPVariadic]>;

let usesCustomInserter = 1, isCall = 1, isCodeGenOnly = 1, Defs = [SPreg], Uses = [SPreg] in {
  def CALL_cs_rp: InstRL78_16bit<0x61CA,
        (outs), (ins RL78RPRegs:$low, RL78RPRegs:$high, variable_ops),
        "call $low",
        [(call (i16 (RL78Hi16 i16:$high, i16:$low)))]>;
}

let isCall = 1, Defs = [SPreg, R0, R1, R2, R3, R4, R5, R6, R7, RP0, RP2, RP4, RP6], Uses = [SPreg] in
{
//Instruction       Opcode
//CALL AX           61 CA
//CALL BC           61 DA
//CALL DE           61 EA
//CALL HL           61 FA
let Uses = [CS] in {
  let isCodeGenOnly = 1 in
  def CALL_rp_cg : InstRL78_16bit<0x61CA,
        (outs), (ins RL78RPRegs:$rsrc, variable_ops),
        "call $rsrc",
        [(call i16:$rsrc)]>;
}
  let isCodeGenOnly = 1 in
  def CALL_addr16 : InstRL78_24bit<0xFD0000,
        (outs), (ins ABS16:$addr16, variable_ops),
        "call $addr16",
        [(call (i16 tglobaladdr:$addr16))]>;

 let isCodeGenOnly = 1 in

 def CALL_addr20 : InstRL78_32bit<0xFC000000,
        (outs), (ins ABS20:$addr20, variable_ops),
        "call !!$addr20",
        [(call (i16 (RL78Hi16 tglobaladdr:$addr20, (i16 (RL78Low16 tglobaladdr:$addr20)))))]>;

}

// Patterns to generate CALL_addr16/20 instructions for texternalsym.
def : Pat<(call (i16 (RL78Low16 texternalsym:$addr16))),
          (CALL_addr16 texternalsym:$addr16)>;

def : Pat<(call (i16 (RL78Hi16 texternalsym:$addr20, (i16 (RL78Low16 texternalsym:$addr20))))),
          (CALL_addr20 texternalsym:$addr20)>;

//===----------------------------------------------------------------------===//
// CALLT instruction
//===----------------------------------------------------------------------===//

def callt : SDNode<"RL78ISD::CALLT", SDTRL78Call,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                            SDNPVariadic]>;

// A call like CALL_addr16 (argument registers, register mask and stack size
// as variable operands). The vendor definition lacked variable_ops and isCall.
let isCall = 1, Defs = [SPreg], Uses = [SPreg] in
let isCodeGenOnly = 1 in
def CALLT_addr5 : InstRL78_16bit<0x6184,
        (outs), (ins ABS5:$addr5, variable_ops),
        "callt $addr5",
        [(callt (i16 tglobaladdr:$addr5))]>;

//===----------------------------------------------------------------------===//
// RET_cg instruction
//===----------------------------------------------------------------------===//

def SDTRL78Ret     : SDTypeProfile<0, 0, []>;
def ret       : SDNode<"RL78ISD::RET", SDTRL78Ret,
                           [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

let isReturn = 1, isTerminator = 1, isBarrier = 1, Uses = [SPreg] in
{
}

//===----------------------------------------------------------------------===//
// RETI_cg instruction
//===----------------------------------------------------------------------===//

def reti       : SDNode<"RL78ISD::RETI", SDTRL78Ret,
                           [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

let isReturn = 1, isTerminator = 1, isBarrier = 1, Uses = [SPreg] in
{
}

//===----------------------------------------------------------------------===//
// RETB_cg instruction
//===----------------------------------------------------------------------===//

def retb       : SDNode<"RL78ISD::RETB", SDTRL78Ret,
                           [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

let isReturn = 1, isTerminator = 1, isBarrier = 1, Uses = [SPreg] in
{
}

//===----------------------------------------------------------------------===//
// PUSH instruction
//===----------------------------------------------------------------------===//

let Defs = [SPreg], Uses = [SPreg], mayLoad = 0, mayStore = 1 in {

//Instruction       Opcode
//PUSH AX           C1
//PUSH BC           C3
//PUSH DE           C5
//PUSH HL           C7

  let Uses = [CCreg] in {
    let isCodeGenOnly = 1 in
    def PUSH_cc : InstRL78_16bit<0x61DD,
            (outs), (ins),
            "push PSW",
            []>;
  }
}

//===----------------------------------------------------------------------===//
// POP instruction
//===----------------------------------------------------------------------===//

let Defs = [SPreg], Uses = [SPreg], mayLoad = 1, mayStore = 0 in {

//Instruction       Opcode
//POP AX            C0
//POP BC            C2
//POP DE            C4
//POP HL            C6

  let Defs = [CCreg] in {
    let isCodeGenOnly = 1 in
    def POP_cc : InstRL78_16bit<0x61CD,
            (outs), (ins),
            "pop PSW",
            []>;
  }
}

//===----------------------------------------------------------------------===//
// BR_CC defines  and pseudo
//===----------------------------------------------------------------------===//

def SDTRL78brcc :
    SDTypeProfile<0, 2, [SDTCisVT<0, OtherVT>, SDTCisVT<1, i8>]>;

def RL78brcc : SDNode<"RL78ISD::BRCC", SDTRL78brcc, [SDNPHasChain, SDNPInGlue]>;


let isTerminator = 1, isBranch = 1, Uses = [CCreg] in {
  def BRCC  : Pseudo<
          (outs), (ins brtarget:$target, CCOp:$cond),
          ";b$cond $target",
          [(RL78brcc bb:$target, imm:$cond)]>;
}

//===----------------------------------------------------------------------===//
// SELECT_CC defines and pseudo
//===----------------------------------------------------------------------===//

def isOptForSize  : Predicate<"shouldOptForSize(MF)">;
def isOptForSpeed : Predicate<"!shouldOptForSize(MF)">;

def SDTRL78selectcc :
    SDTypeProfile<1, 3, [SDTCisSameAs<0, 1>, SDTCisInt<0>, SDTCisVT<3, i8>]>;
def SDTRL78selectccBTBF :
    SDTypeProfile<1, 5, [SDTCisSameAs<0, 1>, SDTCisInt<0>, SDTCisVT<3, i8>,  SDTCisVT<4, i8>,  SDTCisVT<5, i8>]>;

def RL78selectcc: SDNode<"RL78ISD::SELECTCC", SDTRL78selectcc, [SDNPInGlue]>;
def RL78selectccBTBF: SDNode<"RL78ISD::SELECTCCBTBF", SDTRL78selectccBTBF>;

def enabled : Predicate<"false">;

let usesCustomInserter = 1, isSelect = 1, mayStore = 0, Uses = [CCreg] in {

  let Predicates = [isOptForSize] in {
  def SELECTCC8_imm_r: Pseudo<
          (outs RL78Reg:$rd), (ins i8imm:$imm1, RL78Reg:$rsrc2, CCOp:$cond),
          ";select_cc $rd, $imm1, $rsrc2",
          [(set i8:$rd, (RL78selectcc (i8 imm:$imm1), i8:$rsrc2, imm:$cond))]>;

  }

  let mayLoad = 1 in {

    def SELECTCC8_esaddr_imm: Pseudo<
              (outs RL78Reg:$rd), (ins EsAddr16:$addr1, i8imm:$imm2, CCOp:$cond),
              ";select_cc $rd, $addr1, $imm2",
              [(set i8:$rd, (RL78selectcc (load ESADDRABS16:$addr1), (i8 imm:$imm2), imm:$cond))]>;
    def SELECTCBTBFC8_esaddr_imm: Pseudo<
              (outs RL78Reg:$rd), (ins EsAddr16:$addr1, i8imm:$imm2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
              ";select_cc_btbf $rd, $addr1, $imm2, $rcmp, $bit",
              [(set i8:$rd, (RL78selectccBTBF (load ESADDRABS16:$addr1), (i8 imm:$imm2), imm:$cond, i8:$rcmp, imm:$bit))]>;
    def SELECTCC8_esaddr_r: Pseudo<
              (outs RL78Reg:$rd), (ins EsAddr16:$addr1, RL78Reg:$rsrc2, CCOp:$cond),
              ";select_cc $rd, $addr1, $rsrc2",
              [(set i8:$rd, (RL78selectcc (load ESADDRABS16:$addr1), i8:$rsrc2, imm:$cond))]>;
  } // mayLoad = 1
  def SELECTCC8_r_r: Pseudo<
          (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2, CCOp:$cond),
          ";select_cc $rd, $rsrc, $rsrc2",
          [(set i8:$rd, (RL78selectcc i8:$rsrc, i8:$rsrc2, imm:$cond))]>;

  def SELECTCCBTBF8_r_r: Pseudo<
          (outs RL78Reg:$rd), (ins RL78Reg:$rsrc, RL78Reg:$rsrc2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
          ";select_cc_btbf $rd, $rsrc, $rsrc2, $rcmp, $bit",
          [(set i8:$rd, (RL78selectccBTBF i8:$rsrc, i8:$rsrc2, imm:$cond, i8:$rcmp, imm:$bit))]>;

  let Predicates = [isOptForSize] in {
  def SELECTCC16_imm_imm: Pseudo<
          (outs RL78RPRegs:$rd), (ins i16imm:$imm1, i16imm:$imm2, CCOp:$cond),
          ";select_cc $rd, $imm1, $imm2",
          [(set i16:$rd, (RL78selectcc (i16 imm:$imm1), (i16 imm:$imm2), imm:$cond))]>;
  }
  let Predicates = [isOptForSpeed] in {
    def SELECTCCBTBF16_imm_imm: Pseudo<
          (outs RL78RPRegs:$rd), (ins i16imm:$imm1, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
          ";select_cc_btbf $rd, $imm1, $imm2, $rcmp, $bit",
          [(set i16:$rd, (RL78selectccBTBF (i16 imm:$imm1), (i16 imm:$imm2), imm:$cond, i8:$rcmp, imm:$bit))]>;
  }
  let Predicates = [isOptForSize] in {
  def SELECTCC16_imm_rp: Pseudo<
          (outs RL78RPRegs:$rd), (ins i16imm:$imm1, RL78RPRegs:$rsrc2, CCOp:$cond),
          ";select_cc $rd, $imm1, $rsrc2",
          [(set i16:$rd, (RL78selectcc (i16 imm:$imm1), i16:$rsrc2, imm:$cond))]>;
  }
  def SELECTCCBTBF16_imm_rp: Pseudo<
        (outs RL78RPRegs:$rd), (ins i16imm:$imm1, RL78RPRegs:$rsrc2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
        ";select_cc_btbf $rd, $imm1, $rsrc2, $rcmp, $bit",
        [(set i16:$rd, (RL78selectccBTBF (i16 imm:$imm1), i16:$rsrc2, imm:$cond, i8:$rcmp, imm:$bit))]>;
  let mayLoad = 1 in {
      def SELECTCC16_esaddr_imm: Pseudo<
              (outs RL78RPRegs:$rd), (ins EsAddr16:$addr1, i16imm:$imm2, CCOp:$cond),
              ";select_cc $rd, $addr1, $imm2",
              [(set i16:$rd, (RL78selectcc (load ESADDRABS16:$addr1), (i16 imm:$imm2), imm:$cond))]>;
      def SELECTCCBTBF116_esaddr_imm: Pseudo<
              (outs RL78RPRegs:$rd), (ins EsAddr16:$addr1, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
              ";select_cc_btbf $rd, $addr1, $imm2, $rcmp, $bit",
              [(set i16:$rd, (RL78selectccBTBF (load ESADDRABS16:$addr1), (i16 imm:$imm2), imm:$cond, i8:$rcmp, imm:$bit))]>;
      def SELECTCC16_esaddr_rp: Pseudo<
              (outs RL78RPRegs:$rd), (ins EsAddr16:$addr1, RL78RPRegs:$rsrc2, CCOp:$cond),
              ";select_cc $rd, $addr1, $rsrc2",
              [(set i16:$rd, (RL78selectcc (load ESADDRABS16:$addr1), i16:$rsrc2, imm:$cond))]>;
    } // mayLoad = 1

  let Predicates = [isOptForSize] in {
  def SELECTCC16_rp_imm: Pseudo<
         (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i16imm:$imm2, CCOp:$cond),
         ";select_cc $rd, $rsrc, $imm2",
         [(set i16:$rd, (RL78selectcc i16:$rsrc, (i16 imm:$imm2), imm:$cond))]>;
  }
  def SELECTCCBTBF16_rp_imm: Pseudo<
         (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
         ";select_cc_btbf $rd, $rsrc, $imm2, $rcmp, $bit",
         [(set i16:$rd, (RL78selectccBTBF i16:$rsrc, (i16 imm:$imm2), imm:$cond, i8:$rcmp, imm:$bit))]>;

  def SELECTCC16_rp_rp: Pseudo<
          (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2, CCOp:$cond),
          ";select_cc $rd, $rsrc, $rsrc2",
          [(set i16:$rd, (RL78selectcc i16:$rsrc, i16:$rsrc2, imm:$cond))]>;

  def SELECTCCBTBF16_rp_rp: Pseudo<
          (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2, CCOp:$cond, RL78Reg:$rcmp, bitimm:$bit),
          ";select_cc_btbf $rd, $rsrc, $rsrc2, $rcmp, $bit",
          [(set i16:$rd, (RL78selectccBTBF i16:$rsrc, i16:$rsrc2, imm:$cond, i8:$rcmp, imm:$bit))]>;

}

//===----------------------------------------------------------------------===//
// LOAD_SELECTCC defines and pseudos
//===----------------------------------------------------------------------===//

def SDTRL78load_selectcc :
  SDTypeProfile<1, 3, [
    SDTCisInt<0>,            // the loaded value
    SDTCisVT<1, iPTR>,       // addr1
    SDTCisVT<2, iPTR>,       // addr2
    SDTCisVT<3, i8>          // cond
  ]>;

def RL78load_selectcc :
    SDNode<"RL78ISD::LOAD_SELECTCC", SDTRL78load_selectcc, [SDNPHasChain, SDNPInGlue]>;

let usesCustomInserter = 1, isSelect = 1, mayLoad = 1, mayStore = 0, Uses = [CCreg] in {

def LOAD_SELECTCC8_r_esaddr16_esaddr16 : Pseudo<
  (outs RL78Reg:$rd), (ins EsAddr16:$addr1, EsAddr16:$addr2, CCOp:$cond),
  ";load_selectcc $rd, $addr1, $addr2",
  [(set i8:$rd, (RL78load_selectcc ESADDRABS16:$addr1, ESADDRABS16:$addr2, imm:$cond))]>;

def LOAD_SELECTCC16_rp_esaddr16_esaddr16 : Pseudo<
  (outs RL78RPRegs:$rd), (ins EsAddr16:$addr1, EsAddr16:$addr2, CCOp:$cond),
  ";load_selectcc $rd, $addr1, $addr2",
  [(set i16:$rd, (RL78load_selectcc ESADDRABS16:$addr1, ESADDRABS16:$addr2, imm:$cond))]>;

def LOAD_SELECTCC8_r_esaddrr_esaddrr : Pseudo<
  (outs RL78Reg:$rd), (ins EsHlRegAddr:$addr1, EsHlRegAddr:$addr2, CCOp:$cond),
  ";load_selectcc $rd, $addr1, $addr2",
  [(set i8:$rd, (RL78load_selectcc ESADDRr:$addr1, ESADDRr:$addr2, imm:$cond))]>;

def LOAD_SELECTCC16_rp_esaddrr_esaddrr : Pseudo<
  (outs RL78RPRegs:$rd), (ins EsHlRegAddr:$addr1, EsHlRegAddr:$addr2, CCOp:$cond),
  ";load_selectcc $rd, $addr1, $addr2",
  [(set i16:$rd, (RL78load_selectcc ESADDRr:$addr1, ESADDRr:$addr2, imm:$cond))]>;

}

//===----------------------------------------------------------------------===//
// LOWCMP compound instruction
//===----------------------------------------------------------------------===//

def SDTRL78LowCmp : SDTypeProfile<0, 2, [SDTCisInt<0>, SDTCisVT<1, i16>]>;
def RL78lowcmp: SDNode<"RL78ISD::LOWCMP", SDTRL78LowCmp, [SDNPOptInGlue, SDNPOutGlue]>;
//===----------------------------------------------------------------------===//
// BR
//===----------------------------------------------------------------------===//

def tailcall : SDNode<"RL78ISD::TAIL_CALL", SDTRL78Call,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                            SDNPVariadic]>;

let isTerminator = 1, isBranch = 1, isBarrier = 1 in {
  let isIndirectBranch = 1, usesCustomInserter = 1, Uses = [CS] in {
    //BR AX 61 CB
    let isCodeGenOnly = 1 in
    let usesCustomInserter = 0 in
    def BR_AX_cg : InstRL78_16bit<0x61CB,
        (outs), (ins RL78AXRP:$rsrc),
        "br $rsrc",
         [(brind i16:$rsrc)]>;
  }

  def BR : Pseudo<
        (outs), (ins brtarget:$addr),
        "br $addr",
         [(br bb:$addr)]>;

let mayLoad = 0, mayStore = 0 in {

//BR $addr20    EF adr


//BR $!addr20 EE adrl adrh

} // mayLoad = 0, mayStore = 0

let isCall = 1, isReturn = 1 in {
//BR !addr16 ED adrl adrh
  let isCodeGenOnly = 1 in
  def BR_addr16 : InstRL78_24bit<0xED0000,
        (outs), (ins ABS16:$addr16, variable_ops),
        "br $addr16",
         [(tailcall (i16 tglobaladdr:$addr16))]>;

 let isCodeGenOnly = 1 in

 def BR_addr20 : InstRL78_32bit<0xEC000000,
        (outs), (ins ABS20:$addr20, variable_ops),
        "br !!$addr20",
        [(tailcall (i16 (RL78Hi16 tglobaladdr:$addr20, (i16 (RL78Low16 tglobaladdr:$addr20)))))]>;
}
}


//===----------------------------------------------------------------------===//
// Conditional branch instructions:
// BC/BNC/BZ/BNZ/BH/BNH
//===----------------------------------------------------------------------===//
//Instruction       Opcode
let isBranch = 1, isTerminator = 1, Uses = [CCreg], mayLoad = 0, mayStore = 0 in {
//BH $addr20        61 C3 adr
 let isCodeGenOnly = 1 in
 def B_cc : InstRL78_24bit<0x61C300,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;
//BNH $addr20       61 D3 adr
let isCodeGenOnly = 1 in
def B_BNH : InstRL78_24bit<0x61D300,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;

//BC $addr20        DC adr
 let isCodeGenOnly = 1 in
 def B_BC : InstRL78_16bit<0xDC00,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;

//BNC $addr20       DE adr
let isCodeGenOnly = 1 in
def B_BNC : InstRL78_16bit<0xDE00,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;

//BZ $addr20        DD adr
let isCodeGenOnly = 1 in
def B_BZ : InstRL78_16bit<0xDD00,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;

//BNZ $addr20       DF adr
let isCodeGenOnly = 1 in
def B_BNZ : InstRL78_16bit<0xDF00,
            (outs), (ins brtargetRel8:$target, CCOp:$cond),
            "b$cond $target",
            []>;
}

//===----------------------------------------------------------------------===//
// Conditional skip instructions:
// SKC/SKNC/SKZ/SKNZ/SKH/SKNH
//===----------------------------------------------------------------------===//

let mayLoad = 0, mayStore = 0 in {

let isBranch = 1, isTerminator = 1, Uses = [CCreg] in {
//Instruction       Opcode
//SKC               61 C8
//SKNC              61 D8
//SKZ               61 E8
//SKNZ              61 F8
//SKH               61 E3
//SKNH              61 F3
 let isCodeGenOnly = 1 in
 def SK_cc_nodst : InstRL78_16bit<0x61C8,
            (outs), (ins CCOp:$cond),
            "sk$cond",
            []>;
}

let isBranch = 1, isTerminator = 1, isCodeGenOnly = 1, Uses = [CCreg] in {
//Instruction       Opcode
//SKC               61 C8
//SKNC              61 D8
//SKZ               61 E8
//SKNZ              61 F8
//SKH               61 E3
//SKNH              61 F3
 def SK_cc : InstRL78_16bit<0x61C8,
            (outs), (ins brtarget:$target, CCOp:$cond),
            "sk$cond ;$target",
            []>;
}

} // mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Conditional branch by bit test pseudo
//===----------------------------------------------------------------------===//

def SDTRL78btbf :
    SDTypeProfile<0, 4, [SDTCisVT<2, i8>, SDTCisVT<3, i8>, SDTCisVT<0, OtherVT>, SDTCisVT<1, i8>]>;

def RL78btbf : SDNode<"RL78ISD::BTBF", SDTRL78btbf, [SDNPHasChain]>;

def SDTRL78btclr :
    SDTypeProfile<1, 4, [SDTCisVT<0, i8>, SDTCisVT<3, i8>, SDTCisVT<4, i8>, SDTCisVT<1, OtherVT>, SDTCisVT<2, i8>]>;

let isTerminator = 1, isBranch = 1, usesCustomInserter = 1 in {
  let usesCustomInserter = 0 in
  def BTBF : Pseudo<
          (outs), (ins brtarget:$target, CCOp:$cond, RL78AReg:$rsrc, bitimm:$bit),
          ";b$cond $rsrc$bit, $target",
          [(RL78btbf bb:$target, imm:$cond, i8:$rsrc, imm:$bit)]>;

  let usesCustomInserter = 0 in
  def BTBF_mem : Pseudo<
          (outs), (ins brtarget:$target, CCOp:$cond, HLAddr:$addr, bitimm:$bit),
          ";b$cond $addr$bit, $target",
          [(RL78btbf bb:$target, imm:$cond, (i8 (load ADDRr:$addr)), imm:$bit)]>;
}

let isTerminator = 1, isBranch = 1, hasSideEffects = 1 in {
def BTBF_sfr : Pseudo<
          (outs), (ins brtarget:$target, CCOp:$cond, Sfr:$addr, bitimm:$bit),
          ";b$cond $addr$bit, $target",
          [(RL78btbf bb:$target, imm:$cond, (i8 (load SFR:$addr)), imm:$bit)]>;
}

//===----------------------------------------------------------------------===//
// BT/BF
//===----------------------------------------------------------------------===//

let isBranch = 1, isTerminator = 1 in {

//Instruction               Opcode
//BT A.X, $addr20           31 X3 adr (X -> 0..7)
//BF A.X, $addr20           31 X5 adr (X -> 0..7)
let mayLoad = 0, mayStore = 0 in
  let isCodeGenOnly = 1 in
  let usesCustomInserter = 0 in
  def BTBF_A : InstRL78_24bit<0x310300,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, RL78AReg:$rsrc, bitimm:$bit),
           "b$cond $rsrc$bit, $target",
           []>;

let mayLoad = 1, mayStore = 0 in {

//Instruction               Opcode
//BT saddr.X, $addr20       31 X2 saddr adr (X -> 0..7)
//BF saddr.X, $addr20       31 X4 saddr adr (X -> 0..7)
  let isCodeGenOnly = 1 in
  def BTBF_saddr : InstRL78_32bit<0x31020000,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, ABS8:$src, bitimm:$bit),
           "b$cond $src$bit, $target",
           [(RL78btbf bb:$target, imm:$cond, (i8 (load SADDR:$src)), imm:$bit)]>;

let usesCustomInserter = 1 in {
//Instruction               Opcode
//BT [HL].X, $addr20        31 X3 adr (X -> 0..7 -> 8..F)
//BF [HL].X, $addr20        31 X5 adr (X -> 0..7 -> 8..F)
let isCodeGenOnly = 1 in
let usesCustomInserter = 0 in
def BTBF_memr : InstRL78_24bit<0x318300,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, HLAddr:$addr, bitimm:$bit),
           "b$cond $addr$bit, $target",
           []>;
}

let hasSideEffects = 1 in {

//BF sfr.0, $addr20 ;31 84 sfr adr
//BT sfr.0, $addr20 ;31 82 sfr adr
 let isCodeGenOnly = 1 in
 def BTBF_sfri_addr : InstRL78_32bit<0x31820000,
        (outs), (ins brtargetRel8:$target,CCOp:$cond, Sfr:$addr, bitimm:$imm),
        "b$cond $addr$imm, $target",
        []>;

//BF sfr.0, $addr20 ;31 84 sfr adr
//BT sfr.0, $addr20 ;31 82 sfr adr
 let isCodeGenOnly = 1 in
 def BTBF_sfrRegi_addr : InstRL78_32bit<0x3182FF00,
        (outs), (ins brtargetRel8:$target,CCOp:$cond, RL78SfrReg:$addr, bitimm:$imm),
        "b$cond $addr$imm, $target",
        []>;

//BF PSW.0, $addr20 ;31 84 FA adr
//BT PSW.0, $addr20 ;31 82 FA adr
 let isCodeGenOnly = 1 in
 def BTBF_PSWi_addr : InstRL78_32bit<0x3182FA00,
        (outs), (ins brtargetRel8:$target,CCOp:$cond, RL78RegPSW:$rsrc, bitimm:$imm),
        "b$cond $rsrc$imm, $target",
        []>;

} // hasSideEffects = 1

//Instruction               Opcode
//BF ES:[HL].0, $addr20 ;11 31 85 adr
//BT ES:[HL].0, $addr20 ;11 31 83 adr
let isCodeGenOnly = 1 in
def BTBF_esmemr : InstRL78_32bit<0x11318300,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, EsHlRegAddr:$addr, bitimm:$bit),
           "b$cond $addr$bit, $target",
           []>;

} // mayLoad = 1, mayStore = 0

} // isBranch = 1, isTerminator = 1

//===----------------------------------------------------------------------===//
// BTCLR
//===----------------------------------------------------------------------===//

let isBranch = 1, isTerminator = 1, hasSideEffects = 1 in {

let Constraints = "$rsrc = $rd", mayLoad = 0, mayStore = 0 in {

//Instruction               Opcode
//BTCLR A.X, $addr20        31 X1 adr (X -> 0..7)
  let isCodeGenOnly = 1 in
  let usesCustomInserter = 0 in
  def BTCLR_A : InstRL78_24bit<0x310100,
           (outs RL78AReg:$rd), (ins brtargetRel8:$target, CCOp:$cond, RL78AReg:$rsrc, bitimm:$bit),
           "btclr $rd$bit, $target",
           []>;
}

let mayLoad = 1, mayStore = 1 in {

//BTCLR saddr.X, $addr20    31 X0 saddr adr (X -> 0..7)
  let isCodeGenOnly = 1 in
  def BTCLR_saddr : InstRL78_32bit<0x31000000,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, ABS8:$src, bitimm:$bit),
           "btclr $src$bit, $target",
           []>;

let usesCustomInserter = 1 in {
//Instruction               Opcode
//BTCLR [HL].X, $addr20     31 X1 adr (X -> 0..7 -> 8..F)
let isCodeGenOnly = 1 in
let usesCustomInserter = 0 in
def BTCLR_memr : InstRL78_24bit<0x318100,
           (outs), (ins brtargetRel8:$target, CCOp:$cond, HLAddr:$addr, bitimm:$bit),
           "btclr $addr$bit, $target",
           []>;
}

//BTCLR sfr.0, $addr20 ;31 80 sfr adr
 let isCodeGenOnly = 1 in
 def BTCLR_sfri_addr : InstRL78_32bit<0x31800000,
        (outs), (ins brtargetRel8:$target, Sfr:$addr, bitimm:$imm),
        "btclr $addr$imm, $target",
        []>;


//BTCLR sfr.0, $addr20 ;31 80 sfr adr
 let isCodeGenOnly = 1 in
 def BTCLR_sfrRegi_addr : InstRL78_32bit<0x3180FF00,
        (outs), (ins brtargetRel8:$target, RL78SfrReg:$addr, bitimm:$imm),
        "btclr $addr$imm, $target",
        []>;

//BTCLR PSW.0, $addr20 ;31 80 FA adr


//Instruction               Opcode
//BTCLR ES:[HL].X, $addr20  11 31 X1 adr (X -> 0..7 -> 8..F)

} // mayLoad = 1, mayStore = 1

} // isBranch = 1, isTerminator = 1, hasSideEffects = 1

//===----------------------------------------------------------------------===//
// SEL instruction
//===----------------------------------------------------------------------===//

//type requirements of the SelectionDAG node: NumResults = 0, NumOperands = 1
//and Constraints = imm
def SDTSELRB : SDTypeProfile<0, 1, [SDTCisInt<0>]>;

def sel_rb : SDNode<"RL78ISD::SEL_RB", SDTSELRB, [SDNPHasChain, SDNPSideEffect]>;

def isNotS1Core : Predicate<"!Subtarget->isRL78S1CoreType()">;

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

let Predicates = [isNotS1Core] in {
//Instruction       Opcode
//SEL RB0           61 CF
//SEL RB1           61 DF
//SEL RB2           61 EF
//SEL RB3           61 FF
let isCodeGenOnly = 1 in
def SEL : InstRL78_16bit<0x61CF,
        (outs), (ins SELRBx:$rsrc),
        "sel $rsrc",
         [(sel_rb i8:$rsrc)]>;
}

//===----------------------------------------------------------------------===//
// NOP_cg instruction
//===----------------------------------------------------------------------===//



//===----------------------------------------------------------------------===//
// EI_cg instruction
//===----------------------------------------------------------------------===//



//===----------------------------------------------------------------------===//
// DI_cg instruction
//===----------------------------------------------------------------------===//



//===----------------------------------------------------------------------===//
// HALT_cg instruction
//===----------------------------------------------------------------------===//



//===----------------------------------------------------------------------===//
// STOP_cg instruction
//===----------------------------------------------------------------------===//



//===----------------------------------------------------------------------===//
// BRK_cg instruction
//===----------------------------------------------------------------------===//



} // hasSideEffects = 1, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// ATOMIC support
//===----------------------------------------------------------------------===//


//===----------------------------------------------------------------------===//
// HI16 matchers
//===----------------------------------------------------------------------===//
let isCodeGenOnly = 1 in {
def HI16_rp_addr : InstRL78_24bit<0x300000,
        (outs RL78RPRegs:$rd), (ins i16imm:$addr, RL78RPRegs:$low),
        "movw $rd, $addr",
        [(set i16:$rd, (RL78Hi16 tglobaladdr:$addr, i16:$low))]>;

def HI16_rp_rp : Pseudo<
        (outs RL78RPRegs:$rd), (ins RL78RPRegs:$rsrc, RL78RPRegs:$low),
         ";movw $rd, $rsrc",
        [(set i16:$rd, (RL78Hi16 i16:$rsrc, i16:$low))]>;
}


//===----------------------------------------------------------------------===//
// __delay_cycles pseudo instruction
//===----------------------------------------------------------------------===//
def RL78delay_cycles_1_4 :
    SDNode<"RL78ISD::DELAY_CYCLES_1_4",
           SDTypeProfile<0, 1, [SDTCisInt<0>]>, [SDNPSideEffect, SDNPHasChain]>;
def RL78delay_cycles_5 :
    SDNode<"RL78ISD::DELAY_CYCLES_5",
           SDTypeProfile<0, 0, []>, [SDNPSideEffect, SDNPHasChain]>;
def RL78delay_cycles_6_1279 :
    SDNode<"RL78ISD::DELAY_CYCLES_6_1279",
           SDTypeProfile<0, 1, [SDTCisInt<0>]>, [SDNPSideEffect, SDNPHasChain]>;

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {
  def DELAY_CYCLES_1_4 :
      Pseudo<(outs), (ins i16imm:$cycles), ";__delay_cycles_1_4 $cycles",
             [(RL78delay_cycles_1_4(i16 imm:$cycles))]>;
}
let Defs = [CCreg], hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {
  def DELAY_CYCLES_5 :
      Pseudo<(outs), (ins),
             ";__delay_cycles_5", [(RL78delay_cycles_5)]>;
}
let Defs = [R1, CCreg], hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {
  def DELAY_CYCLES_6_1279 :
      Pseudo<(outs), (ins i16imm:$cycles), ";__delay_cycles_6_1279 $cycles",
             [(RL78delay_cycles_6_1279(i16 imm:$cycles))]>;
}
include "RL78InstrISA.td"
