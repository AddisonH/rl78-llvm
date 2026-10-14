//===-- RL78InstPrinter.cpp - Convert RL78 MCInst to assembly syntax -----==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This class prints an RL78 MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#include "RL78InstPrinter.h"
#include "RL78TargetMachine.h"
#include "llvm/MC/MCAsmInfo.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

#define GET_INSTRUCTION_NAME
#define PRINT_ALIAS_INSTR
#include "RL78GenAsmWriter.inc"

void RL78InstPrinter::printRegName(raw_ostream &OS, MCRegister Reg) {
  OS << StringRef(getRegisterName(Reg)).lower();
}

void RL78InstPrinter::printInst(const MCInst *MI, uint64_t Address,
                                StringRef Annot, const MCSubtargetInfo &STI,
                                raw_ostream &O) {
  if (!printAliasInstr(MI, Address, STI, O))
    printInstruction(MI, Address, STI, O);
  printAnnotation(O, Annot);
}

void RL78InstPrinter::printOperand(const MCInst *MI, int opNum,
                                   const MCSubtargetInfo &STI, raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);

  if (MO.isReg()) {
    printRegName(O, MO.getReg());
    return;
  }

  if (MO.isImm()) {
    O << "#" << (int)MO.getImm();
    return;
  }

  if (MO.isExpr()) {
    O << "#";
    MAI.printExpr(O, *MO.getExpr());
    return;
  }
}

// [rp]
void RL78InstPrinter::printMemReg(const MCInst *MI, int opNum,
                                  const MCSubtargetInfo &STI, raw_ostream &O) {
  O << "[";
  printRegName(O, MI->getOperand(opNum).getReg());
  O << "]";
}

// [rp+byte]
void RL78InstPrinter::printMemRegDisp(const MCInst *MI, int opNum,
                                      const MCSubtargetInfo &STI,
                                      raw_ostream &O) {
  O << "[";
  printRegName(O, MI->getOperand(opNum).getReg());
  O << "+";
  const MCOperand &Disp = MI->getOperand(opNum + 1);
  if (Disp.isImm())
    O << Disp.getImm();
  else
    MAI.printExpr(O, *Disp.getExpr());
  O << "]";
}

// [HL+B], [HL+C]
void RL78InstPrinter::printMemRegReg(const MCInst *MI, int opNum,
                                     const MCSubtargetInfo &STI,
                                     raw_ostream &O) {
  O << "[";
  printRegName(O, MI->getOperand(opNum).getReg());
  O << "+";
  printRegName(O, MI->getOperand(opNum + 1).getReg());
  O << "]";
}

void RL78InstPrinter::printESMemReg(const MCInst *MI, int opNum,
                                    const MCSubtargetInfo &STI,
                                    raw_ostream &O) {
  O << "es:";
  printMemReg(MI, opNum + 1, STI, O);
}

void RL78InstPrinter::printESMemRegDisp(const MCInst *MI, int opNum,
                                        const MCSubtargetInfo &STI,
                                        raw_ostream &O) {
  O << "es:";
  printMemRegDisp(MI, opNum + 1, STI, O);
}

void RL78InstPrinter::printESMemRegReg(const MCInst *MI, int opNum,
                                       const MCSubtargetInfo &STI,
                                       raw_ostream &O) {
  O << "es:";
  printMemRegReg(MI, opNum + 1, STI, O);
}

// $addr20, $!addr20: a displacement from the end of the instruction. Shown
// as the target address when the instruction's address is known.
void RL78InstPrinter::printBranchTarget(const MCInst *MI, uint64_t Address,
                                        int opNum, raw_ostream &O,
                                        bool Rel16) {
  O << (Rel16 ? "$!" : "$");
  const MCOperand &MO = MI->getOperand(opNum);
  if (!MO.isImm()) {
    MAI.printExpr(O, *MO.getExpr());
    return;
  }
  int64_t Disp = Rel16 ? int16_t(MO.getImm()) : int8_t(MO.getImm());
  if (PrintBranchImmAsAddress) {
    uint64_t Size = MII.get(MI->getOpcode()).getSize();
    O << formatHex((Address + Size + Disp) & 0xFFFFF);
  } else {
    O << formatHex(Disp);
  }
}

void RL78InstPrinter::printBranchTarget8(const MCInst *MI, uint64_t Address,
                                         int opNum, const MCSubtargetInfo &STI,
                                         raw_ostream &O) {
  printBranchTarget(MI, Address, opNum, O, /*Rel16=*/false);
}

void RL78InstPrinter::printBranchTarget16(const MCInst *MI, uint64_t Address,
                                          int opNum, const MCSubtargetInfo &STI,
                                          raw_ostream &O) {
  printBranchTarget(MI, Address, opNum, O, /*Rel16=*/true);
}

// !addr16 of a branch or call: a code address in 00000H-0FFFFH.
void RL78InstPrinter::printCode16Operand(const MCInst *MI, int opNum,
                                         const MCSubtargetInfo &STI,
                                         raw_ostream &O) {
  O << "!";
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << format_hex(MO.getImm(), 0);
  else
    MAI.printExpr(O, *MO.getExpr());
}

// BT (Z) and BF (NZ).
void RL78InstPrinter::printBitCondOperand(const MCInst *MI, int opNum,
                                          const MCSubtargetInfo &STI,
                                          raw_ostream &O) {
  O << (MI->getOperand(opNum).getImm() == RL78CC::RL78CC_Z ? "t" : "f");
}

// word[B], word[C], word[BC]
void RL78InstPrinter::printMemWord(const MCInst *MI, int opNum,
                                   const MCSubtargetInfo &STI, raw_ostream &O) {
  const MCOperand &Base = MI->getOperand(opNum + 1);
  if (Base.isImm())
    O << Base.getImm();
  else
    MAI.printExpr(O, *Base.getExpr());
  O << "[";
  printRegName(O, MI->getOperand(opNum).getReg());
  O << "]";
}

void RL78InstPrinter::printESMemWord(const MCInst *MI, int opNum,
                                     const MCSubtargetInfo &STI,
                                     raw_ostream &O) {
  O << "es:";
  printMemWord(MI, opNum + 1, STI, O);
}

void RL78InstPrinter::printSELRBxOperand(const MCInst *MI, int opNum,
                                         const MCSubtargetInfo &STI,
                                         raw_ostream &O) {
  static const char *RB[] = {"rb0", "rb1", "rb2", "rb3"};
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << RB[MO.getImm()];
  else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printBitOperand(const MCInst *MI, int opNum,
                                      const MCSubtargetInfo &STI,
                                      raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm()) {
    RL78ReportError((int)MO.getImm() >= 0 && (int)MO.getImm() < 8,
                    "Instruction using operand outside of range.");
    O << "." << (int)MO.getImm();
  } else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printShiftOperand(const MCInst *MI, int opNum,
                                        const MCSubtargetInfo &STI,
                                        raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << (int)MO.getImm();
  else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printABS8Operand(const MCInst *MI, int opNum,
                                       const MCSubtargetInfo &STI,
                                       raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << (((MO.getImm() & 0xFF) < 0x20) ? "0xfff" : "0xffe")
      << format_hex_no_prefix(MO.getImm() & 0xFF, 2);
  else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printSfrOperand(const MCInst *MI, int opNum,
                                      const MCSubtargetInfo &STI,
                                      raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm()) {
    // The sfrs that are registers print as their names.
    static const char *const Names[8] = {"spl", "sph", "psw", nullptr,
                                         "cs",  "es",  "pmc", "mem"};
    unsigned Low = MO.getImm() & 0xFF;
    if (Low >= 0xF8 && Names[Low - 0xF8])
      O << Names[Low - 0xF8];
    else
      O << "0xfff" << format_hex_no_prefix(Low, 2);
  } else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

// sfrp: always the address (SP, the pair at FFFF8H, has its own forms).
void RL78InstPrinter::printSfrpOperand(const MCInst *MI, int opNum,
                                       const MCSubtargetInfo &STI,
                                       raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << "0xfff" << format_hex_no_prefix(0xFF & MO.getImm(), 2);
  else
    MAI.printExpr(O, *MO.getExpr());
}

void RL78InstPrinter::printABS16Operand(const MCInst *MI, int opNum,
                                        const MCSubtargetInfo &STI,
                                        raw_ostream &O) {
  O << "!";
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm()) {

    switch (MI->getOpcode()) {
    default:
      O << "0xf" << format_hex_no_prefix(0xFFFF & MO.getImm(), 4);
      break;
    case RL78::CALL_addr16:
    case RL78::BR_addr16:
      O << format_hex(MO.getImm(), 0);
      break;
    }
  } else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());

  assert((MO.isImm() || MO.isExpr()) &&
         "Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printABS5Operand(const MCInst *MI, int opNum,
                                       const MCSubtargetInfo &STI,
                                       raw_ostream &O) {
  O << "[";
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << format_hex(MO.getImm(), 6);
  else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");

  O << "]";
}

void RL78InstPrinter::printABS20Operand(const MCInst *MI, int opNum,
                                        const MCSubtargetInfo &STI,
                                        raw_ostream &O) {
  const MCOperand &MO = MI->getOperand(opNum);
  if (MO.isImm())
    O << format_hex(MO.getImm(), 0);
  else if (MO.isExpr())
    MAI.printExpr(O, *MO.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printEsAddr16Operand(const MCInst *MI, int opNum,
                                           const MCSubtargetInfo &STI,
                                           raw_ostream &O) {
  assert((MI->getOperand(opNum).isReg() &&
          MI->getOperand(opNum).getReg() == RL78::ES) &&
         "Expected ES register");
  printOperand(MI, opNum, STI, O);
  O << ":";
  O << "!";
  const MCOperand &MO1 = MI->getOperand(opNum + 1);
  if (MO1.isImm())
    O << format_hex(0xFFFF & MO1.getImm(), 0);
  else if (MO1.isExpr())
    MAI.printExpr(O, *MO1.getExpr());
  else
    llvm_unreachable("Operand type is not Immediate or Expression!");
}

void RL78InstPrinter::printCCOperand(const MCInst *MI, int opNum,
                                     const MCSubtargetInfo &STI,
                                     raw_ostream &O) {
  // CC operand is always immediate/const.
  int CC = static_cast<int>(MI->getOperand(opNum).getImm());
  switch (MI->getOpcode()) {
  default:
    break;
    switch (CC) {
    default:
      llvm_unreachable("Invalid condition code!");
    case RL78CC::RL78CC_Z:
      O << "t";
      return;
    case RL78CC::RL78CC_NZ:
      O << "f";
      return;
    }
  }
  O << RL78CondCodeToString((RL78CC::CondCodes)CC);
}
