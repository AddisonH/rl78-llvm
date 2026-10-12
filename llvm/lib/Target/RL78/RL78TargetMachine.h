//===-- RL78TargetMachine.h - Define TargetMachine for RL78 ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the RL78 specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78TARGETMACHINE_H
#define LLVM_LIB_TARGET_RL78_RL78TARGETMACHINE_H

#include "RL78Subtarget.h"
#include "llvm/CodeGen/CodeGenTargetMachineImpl.h"

namespace llvm {

class RL78TargetMachine : public CodeGenTargetMachineImpl {
  std::unique_ptr<TargetLoweringObjectFile> TLOF;
  //RL78Subtarget Subtarget;
  mutable StringMap<std::unique_ptr<RL78Subtarget>> SubtargetMap;

public:
  RL78TargetMachine(const Target &T, const Triple &TT, StringRef CPU,
                    StringRef FS, const TargetOptions &Options,
                    std::optional<Reloc::Model> RM, std::optional<CodeModel::Model> CM,
                    CodeGenOptLevel OL, bool JIT);
  ~RL78TargetMachine() override;

  // DO NOT IMPLEMENT: There is no such thing as a valid default subtarget,
  // subtargets are per-function entities based on the target-specific
  // attributes of each function.
  const RL78Subtarget *getSubtargetImpl() const = delete;
  const RL78Subtarget *getSubtargetImpl(const Function &) const override;

  void registerPassBuilderCallbacks(PassBuilder &) override;

  // Pass Pipeline Configuration
  TargetPassConfig *createPassConfig(PassManagerBase &PM) override;
  TargetTransformInfo getTargetTransformInfo(const Function &F) const override;
  MachineFunctionInfo *
  createMachineFunctionInfo(BumpPtrAllocator &Allocator, const Function &F,
                            const TargetSubtargetInfo *STI) const override;
  TargetLoweringObjectFile *getObjFileLowering() const override {
    return TLOF.get();
  }

  bool isMachineVerifierClean() const override { return false; }

  bool useIPRA() const override { return true; }

  ScheduleDAGInstrs *
  createMachineScheduler(MachineSchedContext *C) const override;

  bool isNoopAddrSpaceCast(unsigned SrcAS, unsigned DestAS) const override {
    return SrcAS == DestAS ||
           (RL78AS::Near == SrcAS && RL78AS::Default == DestAS) ||
           (RL78AS::FarCode == SrcAS && RL78AS::FarData == DestAS) ||
           (RL78AS::FarData == SrcAS && RL78AS::FarCode == DestAS);
  }

};

} // end namespace llvm

#endif
