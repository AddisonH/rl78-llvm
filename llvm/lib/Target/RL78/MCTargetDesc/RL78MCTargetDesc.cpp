//===-- RL78MCTargetDesc.cpp - RL78 Target Descriptions -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides RL78 specific target descriptions.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78InstPrinter.h"
#include "RL78MCAsmInfo.h"
#include "RL78TargetStreamer.h"
#include "TargetInfo/RL78TargetInfo.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCInstrAnalysis.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"

#include "llvm/Support/Compiler.h"

using namespace llvm;

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "RL78GenInstrInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "RL78GenSubtargetInfo.inc"

#define GET_REGINFO_MC_DESC
#include "RL78GenRegisterInfo.inc"

class RL78MCInstrAnalysis : public MCInstrAnalysis {
public:
  RL78MCInstrAnalysis(const MCInstrInfo *Info) : MCInstrAnalysis(Info) {}

  bool evaluateBranch(const MCInst &Inst, uint64_t Addr, uint64_t Size,
                      uint64_t &Target) const override {
    unsigned Opcode = Inst.getOpcode();
    switch (Opcode) {
    case RL78::BTCLR_saddr:
    case RL78::BTCLR_memr:
    case RL78::BTCLR_sfri_addr:
    case RL78::BTCLR_PSWi_addr:
    case RL78::BTCLR_esmemr:
    case RL78::B_cc:
    case RL78::BR_rel8:
    case RL78::BR_rel16:
    case RL78::BTBF_A:
    case RL78::BTBF_saddr:
    case RL78::BTBF_memr:
    case RL78::BTBF_sfri_addr:
    case RL78::BTBF_PSWi_addr:
    case RL78::BTBF_esmemr:
    case RL78::BR_addr16:
    case RL78::BR_addr20:
    case RL78::CALL_addr16rel:
    case RL78::CALL_addr16:
    case RL78::CALL_addr20:
      Target = Inst.getOperand(0).getImm();
      break;
    case RL78::BTCLR_A:
      Target = Inst.getOperand(1).getImm();
      break;
    default:
      return false;
    }
    return true;
  }

  static int64_t getsaddrRange(int64_t Imm) {
    if ((Imm & 0xFF) < 0x20)
      return (Imm & 0xFF) + 0xFFF00;
    else
      return (Imm & 0xFF) + 0xFFE00;
  }

  std::optional<uint64_t>
  evaluateMemoryOperandAddress(const MCInst &Inst, const MCSubtargetInfo *STI,
                               uint64_t Addr, uint64_t Size) const override {
    unsigned Opcode = Inst.getOpcode();
    switch (Opcode) {
    case RL78::CMP0_abs16_cg:
    case RL78::CLRB_abs16_cg:
    case RL78::DECW_abs16_cg:
    case RL78::INCW_abs16_cg:
    case RL78::DEC_abs16_cg:
    case RL78::INC_abs16_cg:
      return (Inst.getOperand(0).getImm() & 0xFFFF) + 0xF0000;
    case RL78::SUBW_rp_saddr:
    case RL78::ADDW_rp_saddr:
    case RL78::XOR_r_saddr:
    case RL78::OR_r_saddr:
    case RL78::AND_r_saddr:
    case RL78::SUBC_r_saddr:
    case RL78::SUB_r_saddr:
    case RL78::ADDC_r_saddrabs:
    case RL78::ADD_r_saddr:
    case RL78::XCH_A_saddrabs:
      return getsaddrRange(Inst.getOperand(2).getImm());
    case RL78::MOVW_saddrp_imm:
    case RL78::CLR1_saddr:
    case RL78::SET1_saddr:
    case RL78::XOR1_cy_saddrx:
    case RL78::AND1_cy_saddrx:
    case RL78::OR1_cy_saddrx:
    case RL78::MOV1_saddr_cy:
    case RL78::MOV1_cy_saddr:
    case RL78::STORE8_saddr_A:
    case RL78::CMP_saddr_imm:
    case RL78::XOR_saddr_imm:
    case RL78::OR_saddr_imm:
    case RL78::AND_saddr_imm:
    case RL78::SUBC_saddr_imm:
    case RL78::SUB_saddr_imm:
    case RL78::ADDC_saddrabs_imm:
    case RL78::ADD_saddr_imm:
    case RL78::STORE8_saddr_imm:
    case RL78::DECW_saddr:
    case RL78::INCW_saddr:
    case RL78::DEC_saddr_cg:
    case RL78::INC_saddr_cg:
    case RL78::CMP0_saddr_cg:
    case RL78::STORE16_saddrp_rp:
    case RL78::CLRB_saddr_cg:
    case RL78::ONEB_saddr_cg:
      return getsaddrRange(Inst.getOperand(0).getImm());
    case RL78::CMPW_rp_saddr:
    case RL78::CMP_r_saddr:
    case RL78::MOV_es_saddr:
    case RL78::LOAD8_rlo_saddr:
    case RL78::LOAD16_rp_saddrp:
      return getsaddrRange(Inst.getOperand(1).getImm());
    case RL78::LOAD8_r_abs16:
    case RL78::CMP_r_abs16:
      return (Inst.getOperand(1).getImm() & 0xFFFF) + 0xF0000;
    case RL78::ADDC_r_abs16:
    case RL78::ADD_r_abs16:
    case RL78::XCH_A_abs16_cg:
    case RL78::XOR_r_abs16:
    case RL78::OR_r_abs16:
    case RL78::AND_r_abs16:
    case RL78::SUBC_r_abs16:
    case RL78::SUBW_rp_abs16:
    case RL78::ADDW_rp_abs16:
    case RL78::SUB_r_abs16:
      return (Inst.getOperand(2).getImm() & 0xFFFF) + 0xF0000;
    case RL78::CMP_abs16_imm:
    case RL78::STORE8_abs16_imm:
    case RL78::ONEB_abs16_cg:
    case RL78::STORE16_abs16_rp:
    case RL78::STORE8_abs16_r:
      return (Inst.getOperand(0).getImm() & 0xFFFF) + 0xF0000;
    case RL78::LOAD16_rp_rpi:
    case RL78::LOAD8_r_ri:
    case RL78::LOAD16_rp_memBorCi:
      if (Inst.getOperand(1).getReg() == RL78::RP2 ||
          Inst.getOperand(1).getReg() == RL78::R2 ||
          Inst.getOperand(1).getReg() == RL78::R3)
        return (Inst.getOperand(2).getImm() & 0xFFFF) + 0xF0000;
      else
        return std::nullopt;
    case RL78::STORE8_ri_r:
    case RL78::STORE16_rpi_rp:
    case RL78::STORE16_memBorCi_rp:
      if (Inst.getOperand(0).getReg() == RL78::RP2 ||
          Inst.getOperand(0).getReg() == RL78::R2 ||
          Inst.getOperand(0).getReg() == RL78::R3)
        return (Inst.getOperand(1).getImm() & 0xFFFF) + 0xF0000;
      else
        return std::nullopt;
    case RL78::CMPW_rp_abs16:
    case RL78::STORE8_ri_imm:
    case RL78::LOAD16_rp_abs16:
      return (Inst.getOperand(1).getImm() & 0xFFFF) + 0xF0000;
    default:
      return std::nullopt;
    }
  }

};

static MCAsmInfo *createRL78MCAsmInfo(const MCRegisterInfo &MRI,
                                      const Triple &TT,
                                      const MCTargetOptions &Options) {
  MCAsmInfo *MAI = new RL78ELFMCAsmInfo(TT, Options);
  unsigned Reg = MRI.getDwarfRegNum(RL78::SPreg, false);
  MCCFIInstruction Inst = MCCFIInstruction::cfiDefCfa(nullptr, Reg, 4);
  MAI->addInitialFrameState(Inst);
  Reg = MRI.getDwarfRegNum(RL78::PCreg, false);
  Inst = MCCFIInstruction::createOffset(nullptr, Reg, -4);
  MAI->addInitialFrameState(Inst);
  return MAI;
}

static MCInstrInfo *createRL78MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitRL78MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createRL78MCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  // OBS. Return address is saved on the stack (CFA-4) however:
  // 1. we set RA = PCreg just like GCC so we don't need to make changes in GDB.
  // 2. we emit a DW_CFA_offset: r37 at cfa-4 in the CIE (see above).
  InitRL78MCRegisterInfo(X, RL78::PCreg);
  return X;
}

static MCSubtargetInfo *createRL78MCSubtargetInfo(const Triple &TT,
                                                  StringRef CPU, StringRef FS) {
  if (CPU.empty())
    CPU = "RL78_S3";
  return createRL78MCSubtargetInfoImpl(TT, CPU, /*TuneCPU=*/CPU, FS);
}

static MCTargetStreamer *
createObjectTargetStreamer(MCStreamer &S, const MCSubtargetInfo &STI) {
  return new RL78TargetELFStreamer(S, STI);
}

MCStreamer *createELFStreamer(const Triple &T, MCContext &Ctx,
                              std::unique_ptr<MCAsmBackend> &&TAB,
                              std::unique_ptr<MCObjectWriter> &&OW,
                              std::unique_ptr<MCCodeEmitter> &&Emitter) {
  return new RL78ELFStreamer(Ctx, std::move(TAB), std::move(OW),
                             std::move(Emitter));
}

static MCTargetStreamer *createTargetAsmStreamer(MCStreamer &S,
                                                 formatted_raw_ostream &OS,
                                                 MCInstPrinter *InstPrint) {
  return new RL78TargetAsmStreamer(S, OS);
}

static MCInstPrinter *createRL78MCInstPrinter(const Triple &T,
                                              unsigned SyntaxVariant,
                                              const MCAsmInfo &MAI,
                                              const MCInstrInfo &MII,
                                              const MCRegisterInfo &MRI) {
  return new RL78InstPrinter(MAI, MII, MRI);
}
static MCInstrAnalysis *createRL78MCInstrAnalysis(const MCInstrInfo *Info) {
  return new RL78MCInstrAnalysis(Info);
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRL78TargetMC() {
  // Register the MC asm info.
  RegisterMCAsmInfoFn X(getTheRL78Target(), createRL78MCAsmInfo);

  for (Target *T : {&getTheRL78Target()}) {
    // Register the MC instruction info.
    TargetRegistry::RegisterMCInstrInfo(*T, createRL78MCInstrInfo);

    // Register the MC register info.
    TargetRegistry::RegisterMCRegInfo(*T, createRL78MCRegisterInfo);

    // Register the MC subtarget info.
    TargetRegistry::RegisterMCSubtargetInfo(*T, createRL78MCSubtargetInfo);

    // Register the MC Code Emitter.
    TargetRegistry::RegisterMCCodeEmitter(*T, createRL78MCCodeEmitter);

    // Register the asm backend.
    TargetRegistry::RegisterMCAsmBackend(*T, createRL78AsmBackend);

    // Register the object target streamer.
    TargetRegistry::RegisterObjectTargetStreamer(*T,
                                                 createObjectTargetStreamer);

    // Register the object target streamer.
    TargetRegistry::RegisterELFStreamer(*T, createELFStreamer);

    // Register the InstrAnalysis.
    TargetRegistry::RegisterMCInstrAnalysis(*T, createRL78MCInstrAnalysis);

    // Register the asm streamer.
    TargetRegistry::RegisterAsmTargetStreamer(*T, createTargetAsmStreamer);

    // Register the MCInstPrinter.
    TargetRegistry::RegisterMCInstPrinter(*T, createRL78MCInstPrinter);
  }
}
