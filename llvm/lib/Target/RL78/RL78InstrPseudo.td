//===-- RL78InstrPseudo.td - RL78 code generation pseudos --*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Instructions that only code generation uses. Each stands for one or more of
// the hardware instructions of RL78InstrISA.td and is replaced by them in a
// custom inserter, in frame index elimination, after register allocation
// (RL78InstrInfo::expandPostRAPseudo), at branch relaxation
// (RL78ExpandPseudoInsts) or when it is printed (RL78LowerToHardware). The
// size is that of the hardware instructions where it is known in advance.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Stack slots
//===----------------------------------------------------------------------===//

// MOV/MOVW with [SP+byte] exist for A and AX only. Spill code needs any
// register: RL78InsertExchangeInstructions exchanges it with A or AX around
// the access.
let mayLoad = 1 in {
def LOAD8_r_stack_slot
    : RL78Pseudo<2, (outs RL78Reg:$rd), (ins STACKSlot:$addr)>;
def LOAD16_rp_stack_slot
    : RL78Pseudo<2, (outs RL78SpillRP:$rd), (ins STACKSlot:$addr)>;
}
let mayStore = 1 in {
def STORE8_stack_slot_r
    : RL78Pseudo<2, (outs), (ins STACKSlot:$addr, RL78Reg:$rsrc)>;
def STORE16_stack_slot_rp
    : RL78Pseudo<2, (outs), (ins STACKSlot:$addr, RL78SpillRP:$rsrc)>;
}

// An argument passed on the stack is loaded into any register too. Its slot
// is never written, so the allocator can load it again where it is used
// (rematerialization) instead of keeping a copy in a slot of its own. These
// become LOAD8_r_stack_slot and LOAD16_rp_stack_slot when the frame index is
// eliminated.
let mayLoad = 1, isReMaterializable = 1, AddedComplexity = 10 in {
def LOAD8_r_arg_slot
    : RL78Pseudo<2, (outs RL78Reg:$rd), (ins STACKSlot:$addr),
                 [(set i8:$rd, (load ADDRArgSP:$addr))]>;
def LOAD16_rp_arg_slot
    : RL78Pseudo<2, (outs RL78RPRegs:$rd), (ins STACKSlot:$addr),
                 [(set i16:$rd, (load ADDRArgSP:$addr))]>;
}

// The address of a stack slot: MOVW AX, SP and ADDW AX, #word.
let Defs = [CCreg] in
def MOVW_rp_stack_slot
    : RL78Pseudo<0, (outs RL78AXRP:$rd), (ins STACKSlot:$addr)>;

//===----------------------------------------------------------------------===//
// PSW
//===----------------------------------------------------------------------===//

let hasSideEffects = 1, OneInst = 1, Uses = [CCreg] in {
// MOV A, PSW
def MOV_A_PSW_cg
    : RL78Pseudo<2, (outs RL78Reg:$dest), (ins),
                 [(set i8:$dest, (int_rl78_getpsw))]>;
// MOV PSW, A
let Defs = [CCreg] in
def MOV_PSW_A_cg
    : RL78Pseudo<2, (outs), (ins RL78Reg:$rsrc),
                 [(int_rl78_setpsw i8:$rsrc)]>;
}

//===----------------------------------------------------------------------===//
// Byte swaps
//===----------------------------------------------------------------------===//

// XCH A, X
let Constraints = "$rsrc = $rd", OneInst = 1 in
def BSWAP_rp
    : RL78Pseudo<1, (outs RL78AXRP:$rd), (ins RL78AXRP:$rsrc),
                 [(set i16:$rd, (bswap i16:$rsrc))]>;

// XCH A, X; XCHW AX, rp; XCH A, X
let Constraints = "$rsrc = $rd, $rsrc2 = $rd2" in
def BSWAP32_rp
    : RL78Pseudo<3, (outs RL78AXRP:$rd, RL78BCDEHL:$rd2),
                 (ins RL78AXRP:$rsrc, RL78BCDEHL:$rsrc2),
                 [(set i16:$rd, i16:$rd2, (xchw i16:$rsrc, i16:$rsrc2))]>;

//===----------------------------------------------------------------------===//
// Multiply, divide, multiply-accumulate
//===----------------------------------------------------------------------===//

// MULU X with the results code generation asks for. Only the low byte of
// the product is used by the first, but A is written all the same.
let OneInst = 1 in {
let Defs = [R1] in
def MUL8_r_r
    : RL78Pseudo<1, (outs RL78XReg:$rd), (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
                 [(set i8:$rd, (mul i8:$rsrc, i8:$rsrc2))]>;
def MULU_zext_16_r_r
    : RL78Pseudo<1, (outs RL78AXRP:$rd), (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
                 [(set i16:$rd, (mul (i16 (zext i8:$rsrc)),
                                     (i16 (zext i8:$rsrc2))))]>;
def UMUL_LOHI_16_r_r
    : RL78Pseudo<1, (outs RL78XReg:$rd, RL78AReg:$rd2),
                 (ins RL78AReg:$rsrc, RL78XReg:$rsrc2),
                 [(set i8:$rd, i8:$rd2, (umullohi i8:$rsrc, i8:$rsrc2))]>;
}

let Predicates = [isS3Core] in {
let OneInst = 1 in {
// MULHU; the high word of the product (BC) is not used but written.
let Defs = [RP2] in
def MUL16_rp_rp
    : RL78Pseudo<3, (outs RL78AXRP:$rd), (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
                 [(set i16:$rd, (mul i16:$rsrc, i16:$rsrc2))]>;
// MULHU
def MUL32_zext_r_r
    : RL78Pseudo<3, (outs RL78AXRP:$rd, RL78BCRP:$rd2),
                 (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
                 [(set i16:$rd, i16:$rd2, (umullohi i16:$rsrc, i16:$rsrc2))]>;
// MULH
def MUL32_sext_r_r
    : RL78Pseudo<3, (outs RL78AXRP:$rd, RL78BCRP:$rd2),
                 (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
                 [(set i16:$rd, i16:$rd2, (smullohi i16:$rsrc, i16:$rsrc2))]>;
}

// DIVHU and DIVWU, each followed by a NOP (Renesas technical update
// TN-RL*-A025: no interrupt may be accepted between the two).
def UDIVREM16_r_r
    : RL78Pseudo<4, (outs RL78AXRP:$rd, RL78DERP:$rd2),
                 (ins RL78AXRP:$rsrc, RL78DERP:$rsrc2),
                 [(set i16:$rd, i16:$rd2, (udivrem i16:$rsrc, i16:$rsrc2))]>;
def UDIVREM32_r_r
    : RL78Pseudo<4, (outs RL78AXRP:$rd, RL78BCRP:$rd2, RL78DERP:$rd3,
                          RL78HL:$rd4),
                 (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2, RL78DERP:$rsrc3,
                      RL78HL:$rsrc4),
                 [(set i16:$rd, i16:$rd2, i16:$rd3, i16:$rd4,
                       (divwu i16:$rsrc, i16:$rsrc2, i16:$rsrc3,
                              i16:$rsrc4))]>;

// MACHU and MACH: MACR += AX * BC.
let Defs = [CCreg], OneInst = 1 in {
def MACHU_CG
    : RL78Pseudo<3, (outs RL78RegMACRL:$rd1, RL78RegMACRH:$rd2),
                 (ins RL78RegMACRL:$rsrcXL, RL78RegMACRH:$rsrcXH,
                      RL78AXRP:$rsrcY, RL78BCRP:$rsrcZ),
                 [(set i16:$rd1, i16:$rd2,
                       (machu i16:$rsrcXL, i16:$rsrcXH, i16:$rsrcY,
                              i16:$rsrcZ))]>;
def MACH_CG
    : RL78Pseudo<3, (outs RL78RegMACRL:$rd1, RL78RegMACRH:$rd2),
                 (ins RL78RegMACRL:$rsrcXL, RL78RegMACRH:$rsrcXH,
                      RL78AXRP:$rsrcY, RL78BCRP:$rsrcZ),
                 [(set i16:$rd1, i16:$rd2,
                       (mach i16:$rsrcXL, i16:$rsrcXH, i16:$rsrcY,
                             i16:$rsrcZ))]>;
}
} // Predicates = [isS3Core]

// The 16-bit multiply without MULHU: with the multiplier/divider unit, or
// three MULU that also use BC and DE (the custom inserter adds those
// definitions). Expanded after register allocation.
let Predicates = [isNotS3Core], usesCustomInserter = 1,
    Constraints = "$rsrc = $rd" in
def MUL16_rp_rp_S1_S2
    : RL78Pseudo<0, (outs RL78AXRP:$rd), (ins RL78AXRP:$rsrc, RL78BCRP:$rsrc2),
                 [(set i16:$rd, (mul i16:$rsrc, i16:$rsrc2))]>;

//===----------------------------------------------------------------------===//
// Shifts and rotates
//===----------------------------------------------------------------------===//

// Shifts and rotates by a count in a register: the value in A or AX and the
// count in B, which the unrolled form (-O3, expanded after register
// allocation) uses up; a loop on any registers otherwise (custom inserter).
let Constraints = "$rsrc = $rd", usesCustomInserter = 1,
    Defs = [R3, CCreg] in {
def SHL_r_r : RL78Pseudo<0, (outs RL78AReg:$rd),
                         (ins RL78AReg:$rsrc, RL78BReg8:$rsrc2),
                         [(set i8:$rd, (shl i8:$rsrc, i8:$rsrc2))]>;
def SHR_r_r : RL78Pseudo<0, (outs RL78AReg:$rd),
                         (ins RL78AReg:$rsrc, RL78BReg8:$rsrc2),
                         [(set i8:$rd, (srl i8:$rsrc, i8:$rsrc2))]>;
def SAR_r_r : RL78Pseudo<0, (outs RL78AReg:$rd),
                         (ins RL78AReg:$rsrc, RL78BReg8:$rsrc2),
                         [(set i8:$rd, (sra i8:$rsrc, i8:$rsrc2))]>;
def ROTL_rp_rp : RL78Pseudo<0, (outs RL78AReg:$rd),
                            (ins RL78AReg:$rsrc, RL78BReg8:$rsrc2),
                            [(set i8:$rd, (rotl i8:$rsrc, i8:$rsrc2))]>;
def ROTR_rp_rp : RL78Pseudo<0, (outs RL78AReg:$rd),
                            (ins RL78AReg:$rsrc, RL78BReg8:$rsrc2),
                            [(set i8:$rd, (rotr i8:$rsrc, i8:$rsrc2))]>;
def SHLW_rp_rp : RL78Pseudo<0, (outs RL78AXRP:$rd),
                            (ins RL78AXRP:$rsrc, RL78BReg8:$rsrc2),
                            [(set i16:$rd, (shl i16:$rsrc, i8:$rsrc2))]>;
def SHRW_rp_rp : RL78Pseudo<0, (outs RL78AXRP:$rd),
                            (ins RL78AXRP:$rsrc, RL78BReg8:$rsrc2),
                            [(set i16:$rd, (srl i16:$rsrc, i8:$rsrc2))]>;
def SARW_rp_rp : RL78Pseudo<0, (outs RL78AXRP:$rd),
                            (ins RL78AXRP:$rsrc, RL78BReg8:$rsrc2),
                            [(set i16:$rd, (sra i16:$rsrc, i8:$rsrc2))]>;
def ROTL16_rp_rp : RL78Pseudo<0, (outs RL78AXRP:$rd),
                              (ins RL78AXRP:$rsrc, RL78BReg8:$rsrc2),
                              [(set i16:$rd, (rotl i16:$rsrc, i8:$rsrc2))]>;
def ROTR16_rp_rp : RL78Pseudo<0, (outs RL78AXRP:$rd),
                              (ins RL78AXRP:$rsrc, RL78BReg8:$rsrc2),
                              [(set i16:$rd, (rotr i16:$rsrc, i8:$rsrc2))]>;
}

// Rotates by a constant, on A or AX and expanded after register allocation.
// Some counts also use X or BC: the custom inserter adds that definition.
let Constraints = "$rsrc = $rd", usesCustomInserter = 1, Defs = [CCreg] in {
def ROTL_r_imm : RL78Pseudo<0, (outs RL78AReg:$rd),
                            (ins RL78AReg:$rsrc, i8imm:$imm),
                            [(set i8:$rd, (rotl i8:$rsrc, (i8 imm:$imm)))]>;
def ROTR_r_imm : RL78Pseudo<0, (outs RL78AReg:$rd),
                            (ins RL78AReg:$rsrc, i8imm:$imm),
                            [(set i8:$rd, (rotr i8:$rsrc, (i8 imm:$imm)))]>;
def ROTL16_r_imm : RL78Pseudo<0, (outs RL78AXRP:$rd),
                              (ins RL78AXRP:$rsrc, i8imm:$imm),
                              [(set i16:$rd, (rotl i16:$rsrc, (i8 imm:$imm)))]>;
def ROTR16_r_imm : RL78Pseudo<0, (outs RL78AXRP:$rd),
                              (ins RL78AXRP:$rsrc, i8imm:$imm),
                              [(set i16:$rd, (rotr i16:$rsrc, (i8 imm:$imm)))]>;
}

//===----------------------------------------------------------------------===//
// Calls and tail calls
//===----------------------------------------------------------------------===//

let Defs = [SPreg], Uses = [SPreg] in {
def ADJCALLSTACKDOWN
    : RL78Pseudo<0, (outs), (ins i16imm:$amt1, i16imm:$amt2),
                 [(callseq_start timm:$amt1, timm:$amt2)]>;
def ADJCALLSTACKUP
    : RL78Pseudo<0, (outs), (ins i16imm:$amt1, i16imm:$amt2),
                 [(callseq_end timm:$amt1, timm:$amt2)]>;
// What frame lowering makes of the two above when the adjustment is kept.
def CALL_STACK_SETUP : RL78Pseudo<1, (outs), (ins i16imm:$amt1)>;
def CALL_STACK_DESTROY : RL78Pseudo<1, (outs), (ins i16imm:$amt1)>;
}

// The hardware calls and jumps with what code generation needs to know: the
// registers a call clobbers, the argument registers and the register mask
// (variable operands), and which jump is a tail call.
let isCall = 1 in {
// A far indirect call: the custom inserter loads CS from $high and makes it
// CALL_rp_cg.
let usesCustomInserter = 1, Defs = [SPreg], Uses = [SPreg] in
def CALL_cs_rp
    : RL78Pseudo<2, (outs), (ins RL78RPRegs:$low, RL78RPRegs:$high,
                                 variable_ops),
                 [(call (i16 (RL78Hi16 i16:$high, i16:$low)))]>;

let OneInst = 1 in {
let Defs = [SPreg, R0, R1, R2, R3, R4, R5, R6, R7, RP0, RP2, RP4, RP6] in {
// CALL rp
let Uses = [CS] in
def CALL_rp_cg
    : RL78Pseudo<2, (outs), (ins RL78RPRegs:$rsrc, variable_ops),
                 [(call i16:$rsrc)]>;
let Uses = [SPreg] in {
// CALL !addr16
def CALL_addr16
    : RL78Pseudo<3, (outs), (ins ABS16:$addr16, variable_ops),
                 [(call (i16 tglobaladdr:$addr16))]>;
// CALL !!addr20
def CALL_addr20
    : RL78Pseudo<4, (outs), (ins ABS20:$addr20, variable_ops),
                 [(call (i16 (RL78Hi16 tglobaladdr:$addr20,
                                  (i16 (RL78Low16 tglobaladdr:$addr20)))))]>;
}
}
// CALLT [addr5]
let Defs = [SPreg], Uses = [SPreg] in
def CALLT_addr5
    : RL78Pseudo<2, (outs), (ins ABS5:$addr5, variable_ops),
                 [(callt (i16 tglobaladdr:$addr5))]>;

// BR !addr16 and BR !!addr20 as tail calls.
let isReturn = 1, isTerminator = 1, isBranch = 1, isBarrier = 1 in {
def BR_addr16
    : RL78Pseudo<3, (outs), (ins ABS16:$addr16, variable_ops),
                 [(tailcall (i16 tglobaladdr:$addr16))]>;
def BR_addr20
    : RL78Pseudo<4, (outs), (ins ABS20:$addr20, variable_ops),
                 [(tailcall (i16 (RL78Hi16 tglobaladdr:$addr20,
                                      (i16 (RL78Low16 tglobaladdr:$addr20)))))]>;
}
} // OneInst = 1
} // isCall = 1

def : Pat<(call (i16 (RL78Low16 texternalsym:$addr16))),
          (CALL_addr16 texternalsym:$addr16)>;
def : Pat<(call (i16 (RL78Hi16 texternalsym:$addr20,
                           (i16 (RL78Low16 texternalsym:$addr20))))),
          (CALL_addr20 texternalsym:$addr20)>;

//===----------------------------------------------------------------------===//
// Branches
//===----------------------------------------------------------------------===//

// Branches whose form (relative 8 or 16 bits, a skip over one instruction,
// the inverted condition around a longer jump) is chosen once the distance
// is known, by RL78ExpandPseudoInsts.
let isTerminator = 1, isBranch = 1 in {
let isBarrier = 1 in {
def BR : RL78Pseudo<0, (outs), (ins brtarget:$addr), [(br bb:$addr)]>;
// BR AX
let isIndirectBranch = 1, Uses = [CS], OneInst = 1 in
def BR_AX_cg
    : RL78Pseudo<2, (outs), (ins RL78AXRP:$rsrc), [(brind i16:$rsrc)]>;
}

let Uses = [CCreg] in
def BRCC : RL78Pseudo<0, (outs), (ins brtarget:$target, CCOp:$cond),
                      [(RL78brcc bb:$target, imm:$cond)]>;

// A skip as the last instruction of a block, which RL78ExpandPseudoInsts
// makes of a BRCC: a branch over the one instruction of the next block, or
// over the BR that follows it.
let Uses = [CCreg], OneInst = 1 in {
def SKcc_cg : RL78Pseudo<2, (outs), (ins condSkCZ:$cc)>;
def SKHcc_cg : RL78Pseudo<2, (outs), (ins condH:$cc)>;
}

// BT and BF on a bit of A, [HL], an sfr or a saddr byte.
def BTBF
    : RL78Pseudo<0, (outs), (ins brtarget:$target, CCOp:$cond, RL78AReg:$rsrc,
                                 bitimm:$bit),
                 [(RL78btbf bb:$target, imm:$cond, i8:$rsrc, imm:$bit)]>;
let mayLoad = 1 in {
def BTBF_mem
    : RL78Pseudo<0, (outs), (ins brtarget:$target, CCOp:$cond, HLAddr:$addr,
                                 bitimm:$bit),
                 [(RL78btbf bb:$target, imm:$cond, (i8 (load ADDRr:$addr)),
                            imm:$bit)]>;
let hasSideEffects = 1 in
def BTBF_sfr
    : RL78Pseudo<0, (outs), (ins brtarget:$target, CCOp:$cond, Sfr:$addr,
                                 bitimm:$bit),
                 [(RL78btbf bb:$target, imm:$cond, (i8 (load SFR:$addr)),
                            imm:$bit)]>;
def BTBF_saddr
    : RL78Pseudo<0, (outs), (ins brtarget:$target, CCOp:$cond, ABS8:$src,
                                 bitimm:$bit),
                 [(RL78btbf bb:$target, imm:$cond, (i8 (load SADDR:$src)),
                            imm:$bit)]>;
}
} // isTerminator = 1, isBranch = 1

// BC/BNC/BZ/BNZ over the next instructions of a bundle, a distance in bytes
// (the steps of a shift by a variable count): control stays in the bundle,
// so this is not a terminator.
let Uses = [CCreg], hasSideEffects = 1, OneInst = 1 in
def Bcc_over : RL78Pseudo<2, (outs), (ins i8imm:$dist, condCZ:$cc)>;

//===----------------------------------------------------------------------===//
// Selects
//===----------------------------------------------------------------------===//

// A select on the flags (SELECTCC*) or on a bit of a register
// (SELECTCCBTBF*): the custom inserter builds the branch and the blocks.
let usesCustomInserter = 1, isSelect = 1, Uses = [CCreg] in {
let Predicates = [isOptForSize] in
def SELECTCC8_imm_r
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins i8imm:$imm1, RL78Reg:$rsrc2, CCOp:$cond),
                 [(set i8:$rd, (RL78selectcc (i8 imm:$imm1), i8:$rsrc2,
                                             imm:$cond))]>;
def SELECTCC8_r_r
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins RL78Reg:$rsrc, RL78Reg:$rsrc2, CCOp:$cond),
                 [(set i8:$rd, (RL78selectcc i8:$rsrc, i8:$rsrc2,
                                             imm:$cond))]>;
def SELECTCCBTBF8_r_r
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins RL78Reg:$rsrc, RL78Reg:$rsrc2, CCOp:$cond, RL78Reg:$rcmp,
                      bitimm:$bit),
                 [(set i8:$rd, (RL78selectccBTBF i8:$rsrc, i8:$rsrc2, imm:$cond,
                                                 i8:$rcmp, imm:$bit))]>;

let Predicates = [isOptForSize] in {
def SELECTCC16_imm_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins i16imm:$imm1, i16imm:$imm2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc (i16 imm:$imm1), (i16 imm:$imm2),
                                              imm:$cond))]>;
def SELECTCC16_imm_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins i16imm:$imm1, RL78RPRegs:$rsrc2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc (i16 imm:$imm1), i16:$rsrc2,
                                              imm:$cond))]>;
def SELECTCC16_rp_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins RL78RPRegs:$rsrc, i16imm:$imm2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc i16:$rsrc, (i16 imm:$imm2),
                                              imm:$cond))]>;
}
def SELECTCC16_rp_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc i16:$rsrc, i16:$rsrc2,
                                              imm:$cond))]>;

let Predicates = [isOptForSpeed] in
def SELECTCCBTBF16_imm_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins i16imm:$imm1, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp,
                      bitimm:$bit),
                 [(set i16:$rd, (RL78selectccBTBF (i16 imm:$imm1),
                                                  (i16 imm:$imm2), imm:$cond,
                                                  i8:$rcmp, imm:$bit))]>;
def SELECTCCBTBF16_imm_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins i16imm:$imm1, RL78RPRegs:$rsrc2, CCOp:$cond,
                      RL78Reg:$rcmp, bitimm:$bit),
                 [(set i16:$rd, (RL78selectccBTBF (i16 imm:$imm1), i16:$rsrc2,
                                                  imm:$cond, i8:$rcmp,
                                                  imm:$bit))]>;
def SELECTCCBTBF16_rp_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins RL78RPRegs:$rsrc, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp,
                      bitimm:$bit),
                 [(set i16:$rd, (RL78selectccBTBF i16:$rsrc, (i16 imm:$imm2),
                                                  imm:$cond, i8:$rcmp,
                                                  imm:$bit))]>;
def SELECTCCBTBF16_rp_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins RL78RPRegs:$rsrc, RL78RPRegs:$rsrc2, CCOp:$cond,
                      RL78Reg:$rcmp, bitimm:$bit),
                 [(set i16:$rd, (RL78selectccBTBF i16:$rsrc, i16:$rsrc2,
                                                  imm:$cond, i8:$rcmp,
                                                  imm:$bit))]>;

// With the first value loaded from ES:!addr16 when it is chosen.
let mayLoad = 1 in {
def SELECTCC8_esaddr_imm
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins EsAddr16:$addr1, i8imm:$imm2, CCOp:$cond),
                 [(set i8:$rd, (RL78selectcc (load ESADDRABS16:$addr1),
                                             (i8 imm:$imm2), imm:$cond))]>;
def SELECTCBTBFC8_esaddr_imm
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins EsAddr16:$addr1, i8imm:$imm2, CCOp:$cond, RL78Reg:$rcmp,
                      bitimm:$bit),
                 [(set i8:$rd, (RL78selectccBTBF (load ESADDRABS16:$addr1),
                                                 (i8 imm:$imm2), imm:$cond,
                                                 i8:$rcmp, imm:$bit))]>;
def SELECTCC8_esaddr_r
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins EsAddr16:$addr1, RL78Reg:$rsrc2, CCOp:$cond),
                 [(set i8:$rd, (RL78selectcc (load ESADDRABS16:$addr1),
                                             i8:$rsrc2, imm:$cond))]>;
def SELECTCC16_esaddr_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins EsAddr16:$addr1, i16imm:$imm2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc (load ESADDRABS16:$addr1),
                                              (i16 imm:$imm2), imm:$cond))]>;
def SELECTCCBTBF116_esaddr_imm
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins EsAddr16:$addr1, i16imm:$imm2, CCOp:$cond, RL78Reg:$rcmp,
                      bitimm:$bit),
                 [(set i16:$rd, (RL78selectccBTBF (load ESADDRABS16:$addr1),
                                                  (i16 imm:$imm2), imm:$cond,
                                                  i8:$rcmp, imm:$bit))]>;
def SELECTCC16_esaddr_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins EsAddr16:$addr1, RL78RPRegs:$rsrc2, CCOp:$cond),
                 [(set i16:$rd, (RL78selectcc (load ESADDRABS16:$addr1),
                                              i16:$rsrc2, imm:$cond))]>;

// A load from one of two far addresses.
def LOAD_SELECTCC8_r_esaddr16_esaddr16
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins EsAddr16:$addr1, EsAddr16:$addr2, CCOp:$cond),
                 [(set i8:$rd, (RL78load_selectcc ESADDRABS16:$addr1,
                                                  ESADDRABS16:$addr2,
                                                  imm:$cond))]>;
def LOAD_SELECTCC16_rp_esaddr16_esaddr16
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins EsAddr16:$addr1, EsAddr16:$addr2, CCOp:$cond),
                 [(set i16:$rd, (RL78load_selectcc ESADDRABS16:$addr1,
                                                   ESADDRABS16:$addr2,
                                                   imm:$cond))]>;
def LOAD_SELECTCC8_r_esaddrr_esaddrr
    : RL78Pseudo<0, (outs RL78Reg:$rd),
                 (ins EsHlRegAddr:$addr1, EsHlRegAddr:$addr2, CCOp:$cond),
                 [(set i8:$rd, (RL78load_selectcc ESADDRr:$addr1,
                                                  ESADDRr:$addr2,
                                                  imm:$cond))]>;
def LOAD_SELECTCC16_rp_esaddrr_esaddrr
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins EsHlRegAddr:$addr1, EsHlRegAddr:$addr2, CCOp:$cond),
                 [(set i16:$rd, (RL78load_selectcc ESADDRr:$addr1,
                                                   ESADDRr:$addr2,
                                                   imm:$cond))]>;
} // mayLoad = 1
} // usesCustomInserter = 1, isSelect = 1, Uses = [CCreg]

//===----------------------------------------------------------------------===//
// Far addresses
//===----------------------------------------------------------------------===//

// The segment of a far address, as a 16-bit value: MOVW rp, #word for a
// global, a copy otherwise.
let OneInst = 1 in
def HI16_rp_addr
    : RL78Pseudo<3, (outs RL78RPRegs:$rd), (ins i16imm:$addr, RL78RPRegs:$low),
                 [(set i16:$rd, (RL78Hi16 tglobaladdr:$addr, i16:$low))]>;
def HI16_rp_rp
    : RL78Pseudo<0, (outs RL78RPRegs:$rd),
                 (ins RL78RPRegs:$rsrc, RL78RPRegs:$low),
                 [(set i16:$rd, (RL78Hi16 i16:$rsrc, i16:$low))]>;

//===----------------------------------------------------------------------===//
// __delay_cycles
//===----------------------------------------------------------------------===//

let hasSideEffects = 1 in {
def DELAY_CYCLES_1_4
    : RL78Pseudo<0, (outs), (ins i16imm:$cycles),
                 [(RL78delay_cycles_1_4 (i16 imm:$cycles))]>;
let Defs = [CCreg] in
def DELAY_CYCLES_5 : RL78Pseudo<0, (outs), (ins), [(RL78delay_cycles_5)]>;
let Defs = [R1, CCreg] in
def DELAY_CYCLES_6_1279
    : RL78Pseudo<0, (outs), (ins i16imm:$cycles),
                 [(RL78delay_cycles_6_1279 (i16 imm:$cycles))]>;
}
