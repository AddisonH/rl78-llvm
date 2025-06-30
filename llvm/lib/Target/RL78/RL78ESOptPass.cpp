//===------------------ RL78ESOptPass.cpp -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// Pass to eliminate unnecessary re-initializations of the ES register.
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/ADT/SparseSet.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/Support/Debug.h"

#include <queue>

using namespace llvm;

namespace {
class RL78ESOptPass : public MachineFunctionPass {
public:
  RL78ESOptPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 ES register optimization";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
};

char RL78ESOptPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78ESOptPass() { return new RL78ESOptPass(); }

bool RL78ESOptPass::runOnMachineFunction(MachineFunction &MF) {

  // Eliminate unnecessary re-initializations introduced by LowerESSrc.
  // mov a, c
  // mov es, a
  // movw ax, #12
  // movw es:[hl+4], ax
  // ....
  // mov a, c <- not needed
  // mov es, a <- not needed
  // movw ax, #13
  // movw es:[hl+6], ax

  bool Changed = true;

  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;

    for (MachineBasicBlock::iterator Next = std::next(MBB.begin()),
                                     E = MBB.end();
         Next != E;) {

      // Find the first initialization of ES and it's possible copy.
      MachineInstr &FirstCopy = *std::prev(Next);
      if ((Next->getOpcode() != RL78::MOV_es_A || !FirstCopy.isCopy() ||
           FirstCopy.getOperand(0).getReg() != RL78::R1) &&
          Next->getOpcode() != RL78::MOV_es_imm) {
        Next++;
        continue;
      }
      MachineInstr &Last = *Next;

      Next++;
      while (Next != E) {
        // Calls represent a barrier, stop trying to eliminate extra copies.
        if (Next->isCall()) {
          Next++;
          break;
        }
        // If we initialize with a different opcode we should stop and try to
        // replace for the new value.
        if ((Next->getOpcode() == RL78::MOV_es_A ||
             Next->getOpcode() == RL78::MOV_es_imm) &&
            Next->getOpcode() != Last.getOpcode())
          break;

        if (Next->getOpcode() == Last.getOpcode()) {
          if (Next->getOpcode() == RL78::MOV_es_A &&
              FirstCopy.getOperand(1).getReg() ==
                  std::prev(Next)->getOperand(1).getReg() &&
              std::prev(Next)->getOperand(0).getReg() == RL78::R1) {
            // Eliminate the second initialization and associated copy if the
            // source was the same register.
            MachineInstr &Mov = *Next;
            MachineInstr &Copy = *std::prev(Next);
            Next++;
            Copy.eraseFromParent();
            Mov.eraseFromParent();
            Changed = true;
          } else if (Next->getOperand(1).isIdenticalTo(Last.getOperand(1)) &&
                     (Next->getOpcode() == RL78::MOV_es_imm ||
                      Next->getOpcode() == RL78::MOV_es_A &&
                          (!std::prev(Next)->isCopy() ||
                           std::prev(Next)->getOperand(0).getReg() !=
                               RL78::R1))) {
            // Eliminate the second initialization with an imm or with R1 but
            // with missing/already eliminated copy.
            MachineInstr &Mov = *Next;
            Next++;
            Mov.eraseFromParent();
            Changed = true;
          } else {
            break;
          }
        } else {
          Next++;
        }
      }
    }
  }

  return Changed;
}
