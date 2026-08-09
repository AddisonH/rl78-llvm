//===-- RL78.h - Top-level interface for RL78 representation --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the entry points for global functions defined in the LLVM
// RL78 back-end.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78_H
#define LLVM_LIB_TARGET_RL78_RL78_H

#include "MCTargetDesc/RL78MCTargetDesc.h"
#include "llvm/Support/Process.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/MC/MCContext.h"
#include "llvm/Support/SourceMgr.h"
#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#elif defined(_MSC_VER)
#include <fcntl.h>
#include <io.h>
#endif

namespace llvm {
class FunctionPass;
class RL78TargetMachine;
class formatted_raw_ostream;
class AsmPrinter;
class MCInst;
class MachineInstr;
class PassRegistry;

FunctionPass *createRL78ISelDag(RL78TargetMachine &TM, CodeGenOpt::Level OptLevel);

FunctionPass *createRL78InsertExchangeInstructionsPass();
FunctionPass *createRL78ExpandPseudoInstsPass();
FunctionPass *createRL78SelectBTCLRPass();
FunctionPass *createRL78CMPWithZeroElimPass();
FunctionPass *createRL78AdjustMemRefsPass();
FunctionPass *createRL78InstructionSpecializationPass();
FunctionPass *createRL78ConstPropAndOpSwap();
FunctionPass *createRL78InsertNOPWithLabelPass();
FunctionPass *createRL78ESOptPass();
FunctionPass *createRL78InsertInstsForDelayCyclesPass();
FunctionPass *createRL78NarrowDemandedOpsPass();

void initializeRL78DAGToDAGISelPass(PassRegistry &);
void initializeRL78NarrowDemandedOpsPass(PassRegistry &);

void LowerRL78MachineInstrToMCInst(const MachineInstr *MI, MCInst &OutMI,
                                   AsmPrinter &AP);
} // end namespace llvm

namespace llvm {
// Enums corresponding to RL78 condition codes.
namespace RL78CC {
enum CondCodes {
  RL78CC_C,
  RL78CC_NC,
  RL78CC_Z,
  RL78CC_NZ,
  RL78CC_H,
  RL78CC_NH
};
}

namespace RL78AS {
enum AddressSpaces { Default = 0, Near = 1, FarData = 2, FarCode = 3 };
}

inline static const char *RL78CondCodeToString(RL78CC::CondCodes CC) {
  switch (CC) {
  case RL78CC::RL78CC_C:
    return "c";
  case RL78CC::RL78CC_NC:
    return "nc";
  case RL78CC::RL78CC_Z:
    return "z";
  case RL78CC::RL78CC_NZ:
    return "nz";
  case RL78CC::RL78CC_H:
    return "h";
  case RL78CC::RL78CC_NH:
    return "nh";
  }
  llvm_unreachable("Invalid condition code!");
}

static inline void RL78ReportError(bool condition, StringRef Reason,
                            MCContext *Ctx = nullptr, SMLoc Loc = SMLoc()) {

  if (!condition) {
    if (Ctx && Loc.isValid()) {
      Ctx->getSourceManager()->PrintMessage(errs(), Loc, SourceMgr::DK_Error,
                                            Reason);
    } else {
      SMDiagnostic Diag("", SourceMgr::DK_Error, Reason);
      SourceMgr SM;
      SM.PrintMessage(errs(), Diag, /*ShowColors=*/true);
    }
    exit(1);
  }
}
} // end namespace llvm
#endif
