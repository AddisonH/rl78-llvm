//===-- RL78Subtarget.cpp - RL78 Subtarget Information ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the RL78 specific subclass of TargetSubtargetInfo.
//
//===----------------------------------------------------------------------===//

#include "RL78Subtarget.h"
#include "llvm/CodeGen/SelectionDAGISel.h"

using namespace llvm;

#define DEBUG_TYPE "RL78-subtarget"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "RL78GenSubtargetInfo.inc"

void RL78Subtarget::anchor() {}

// The ILP list scheduler gives the fastest code, the hybrid one (register
// pressure first, latency only where pressure is low) the smallest: Embench
// -Os 0.5% smaller, -O3 1.2% slower.
static ScheduleDAGSDNodes *createRL78DAGScheduler(SelectionDAGISel *IS,
                                                  CodeGenOptLevel OptLevel) {
  if (IS->MF->getFunction().hasOptSize())
    return createHybridListDAGScheduler(IS, OptLevel);
  return createILPListDAGScheduler(IS, OptLevel);
}

RegisterScheduler::FunctionPassCtor
RL78Subtarget::getDAGScheduler(CodeGenOptLevel OptLevel) const {
  if (OptLevel == CodeGenOptLevel::None)
    return nullptr;
  return createRL78DAGScheduler;
}

RL78Subtarget &
RL78Subtarget::initializeSubtargetDependencies(const Triple &TT, StringRef CPU,
                                                StringRef TuneCPU, StringRef FS,
                                                StringRef ABIName) {
  HasRegBanks = false;
  HasMulDiv = false;
  has64BitDoubles = false;
  mirrorSource = (unsigned char)RL78MirrorSource::Zero;
  hasFarCodeModel = false;
  romModel = (unsigned char)RL78RomModel::Near;
  disableMDA = false;
  linkerRelax = false;

  // Determine default and user specified characteristics.
  if (CPU.empty())
    CPU = "RL78_S3";

  if (TuneCPU.empty())
    TuneCPU = CPU;

  // Parse features string.
  ParseSubtargetFeatures(CPU, TuneCPU, FS);

  return *this;
}

RL78Subtarget::RL78Subtarget(const Triple &TT, StringRef CPU, StringRef TuneCPU,
                StringRef FS, StringRef ABIName,
                const TargetMachine &TM)
    : RL78GenSubtargetInfo(TT, CPU, TuneCPU, FS), TargetTriple(TT),
      InstrInfo(initializeSubtargetDependencies(TT, CPU, TuneCPU, FS, ABIName)), TLInfo(TM, *this),
      FrameLowering(*this) {}
