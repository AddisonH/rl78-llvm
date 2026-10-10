//===-- RL78ExpandPseudoInsts.cpp - Define TargetMachine for RL78 --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

#include "RL78TargetMachine.h"

using namespace llvm;


namespace {
class RL78ExpandPseudoInsts : public MachineFunctionPass {
public:
  RL78ExpandPseudoInsts() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override { return "RL78 expand pseudo instructions"; }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
  //
  std::map<const MachineBasicBlock *, unsigned> bbSizeMap;
  std::map<const MachineBasicBlock *, uint64_t> bbOffsetMap;
  //
  bool processBranch(MachineInstr &MI, MachineBasicBlock &MBB,
                     const TargetInstrInfo *TII);
  void buildBBOffsetMap(MachineFunction &MF, const TargetInstrInfo *TII);
};

char RL78ExpandPseudoInsts::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78ExpandPseudoInstsPass() {
  return new RL78ExpandPseudoInsts();
}

static unsigned calcBasicBlockSize(MachineBasicBlock &MBB, const TargetInstrInfo *TII) {
  return std::accumulate(
      MBB.begin(), MBB.end(), 0, [TII](unsigned Sum, const MachineInstr &MI) {
        return Sum + TII->getInstSizeInBytes(MI);
      });
}

// Check if MBB has only 1 instruction.
static bool isSingleInstructionBB(MachineBasicBlock &MBB) {
  unsigned blockSize = 0;
  for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end(); Next != E;
       Next++) {
    MachineInstr &MI = *Next;
    if (MI.isDebugInstr())
      continue;
    switch (MI.getOpcode()) {
    case RL78::ADJCALLSTACKDOWN:
    case RL78::ADJCALLSTACKUP:
    case RL78::CALL_STACK_SETUP:
    case RL78::CALL_STACK_DESTROY:
      // Not real instructions.
      break;
    case RL78::BSWAP32_rp:
      // 2 x XCH + 1 x XCHW.
      blockSize += 3;
      break;
    case RL78::UDIVREM16_r_r:
    case RL78::UDIVREM32_r_r:
      // DIV + NOP_cg.
      blockSize += 2;
      break;
    default:
      blockSize += 1;
      break;
    }
    if (blockSize > 1)
      return false;
  }
  //
  return (blockSize == 1);
}

void RL78ExpandPseudoInsts::buildBBOffsetMap(MachineFunction &MF,
                                            const TargetInstrInfo *TII) {
  bbOffsetMap.clear();
  uint64_t Off = 0;
  for (MachineBasicBlock &MBB : MF) {
    bbOffsetMap[&MBB] = Off;
    auto It = bbSizeMap.find(&MBB);
    unsigned Size =
        (It != bbSizeMap.end()) ? It->second : calcBasicBlockSize(MBB, TII);
    Off += Size;
  }
}

bool RL78ExpandPseudoInsts::processBranch(MachineInstr &MI,
                                         MachineBasicBlock &MBB,
                                         const TargetInstrInfo *TII) {
  // Return if not BRCC/BR/BTBF.
  if ((MI.getOpcode() != RL78::BRCC) && (MI.getOpcode() != RL78::BR) &&
      (MI.getOpcode() != RL78::BTBF) && (MI.getOpcode() != RL78::BTBF_mem) &&
      (MI.getOpcode() != RL78::BTBF_sfr))
    return false;
  // MI.dump();
  MachineFunction::iterator MBBI = MBB.getIterator();
  MachineBasicBlock &targetMBB = *MI.getOperand(0).getMBB();
  MachineFunction::iterator NextMBBI = std::next(MBBI);
  // if this is the last instruction in MBB and the next (fall-through) block
  // has only 1 instruction.
  if ((MI.getOpcode() == RL78::BRCC) && (MI == MBB.getLastNonDebugInstr()) &&
      isSingleInstructionBB(*NextMBBI) &&
      !NextMBBI->SkipPHIsLabelsAndDebug(NextMBBI->begin())->isPseudo() &&
      (std::next(NextMBBI) == targetMBB.getIterator())) {
    // Insert a conditional skip instruction.
    BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::SK_cc))
        .add(MI.getOperand(0))
        .add(MI.getOperand(1));
  } else {
    // First check if the jump is in range [-128 + size(instruction), +127]
    // bytes size(instruction) = { BC, BNC, BZ, BNZ = 2 bytes, BH, BNH = 3
    // bytes, BT, BF = 3/4}.
    unsigned jumpSize = 0;
    unsigned range = 0;
    unsigned sourceOff = bbOffsetMap[&MBB];
    unsigned targetOff = bbOffsetMap[&targetMBB];
    unsigned sourceBBSize = bbSizeMap[&MBB];
    // size(instruction) = { BC, BNC, BZ, BNZ = 2 bytes, BH, BNH = 3 bytes,
    // BR = 2, BT, BF = 3/4}.
    unsigned instrSize = 4;
    // Find jump distance, if the target BB is the same as the source BB
    // then the jump distance will be size of the source BB.
    if (&MBB == &targetMBB) {
      jumpSize = sourceBBSize;
      range = 127 - instrSize;
    } else {                       // Find jump direction.
      if (targetOff > sourceOff) { // Forward jump.
        jumpSize = targetOff - (sourceOff + sourceBBSize);
        range = 127;
      } else { // Backward jump.
        // range = -128 + size(instruction)
        jumpSize = (sourceOff + sourceBBSize) - targetOff;
        range = 128 - instrSize;
      }
    }
    //
    if (jumpSize < range) {
      // Insert a rel8 branch.
      switch (MI.getOpcode()) {
      default:
        llvm_unreachable("Invalid branch instruction!");
      case RL78::BTBF:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTBF_A))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        break;
      case RL78::BTBF_mem:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTBF_memr))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        break;
      case RL78::BTBF_sfr:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BTBF_sfri_addr))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1))
            .add(MI.getOperand(2))
            .add(MI.getOperand(3));
        break;
      case RL78::BRCC:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::B_cc))
            .add(MI.getOperand(0))
            .add(MI.getOperand(1));
        break;
      case RL78::BR:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BR_rel8))
            .add(MI.getOperand(0));
        break;
      }
    } else {
      // Use SKIP with opposite branch condition + unconditional rel16 branch.
      SmallVector<MachineOperand, 4> Cond;
      // If conditional branch (BR has only 1 operand).
      if (MI.getNumOperands() > 1) {
        Cond.push_back(MachineOperand::CreateImm(MI.getOperand(1).getImm()));
        TII->reverseBranchCondition(Cond);
      }
      //
      switch (MI.getOpcode()) {
      default:
        llvm_unreachable("Invalid branch instruction!");
      case RL78::BTBF_mem:
      case RL78::BTBF_sfr:
      case RL78::BTBF: {
        if (MI.getOpcode() == RL78::BTBF_sfr)
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::MOV1_CY_sfr_b))
              .add(MI.getOperand(2))
              .add(MI.getOperand(3));
        else if (MI.getOpcode() == RL78::BTBF_mem)
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::MOV1_CY_mHL_b))
              .add(MI.getOperand(2))
              .add(MI.getOperand(3));
        else
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::MOV1_CY_A_b))
              .add(MI.getOperand(2))
              .add(MI.getOperand(3));

        RL78CC::CondCodes CC =
            static_cast<RL78CC::CondCodes>(MI.getOperand(1).getImm());
        RL78CC::CondCodes ReversedInCy = CC == RL78CC::CondCodes::RL78CC_Z
                                             ? RL78CC::CondCodes::RL78CC_NC
                                             : RL78CC::CondCodes::RL78CC_C;

        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::SK_cc))
            .add(MI.getOperand(0))
            .addImm(ReversedInCy);

        if (isInt<16>(jumpSize))
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BR_rel16))
              .add(MI.getOperand(0));
        else
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BR_addr20))
              .add(MI.getOperand(0));
        break;
      }
      case RL78::BRCC:
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::SK_cc))
            .add(MI.getOperand(0))
            .addImm(Cond[0].getImm());
        LLVM_FALLTHROUGH;
      case RL78::BR:
        if (isInt<16>(jumpSize))
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BR_rel16))
              .add(MI.getOperand(0));
        else
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::BR_addr20))
              .add(MI.getOperand(0));
        break;
      }
    }
  }
  // Remove the pseudo instruction.
  MI.eraseFromParent();
  return true;
}

bool RL78ExpandPseudoInsts::runOnMachineFunction(MachineFunction &MF) {
  bool Changed = false;
  bool LocalChanged = false;
  const TargetInstrInfo *TII = MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  do {
    // Calc the size of each basic block.
    bbSizeMap.clear();
    for (MachineBasicBlock &MBB : MF)
      bbSizeMap[&MBB] = calcBasicBlockSize(MBB, TII);
    buildBBOffsetMap(MF, TII);
    // MF.dump();
    LocalChanged = false;
    for (MachineBasicBlock &MBB : MF) {
      if (MBB.empty())
        continue;
      //
      MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
      if (I == MBB.end())
        continue;
      //
      if (processBranch(*I, MBB, TII)) {
        LocalChanged = true;
        bbSizeMap[&MBB] = calcBasicBlockSize(MBB, TII);
        buildBBOffsetMap(MF, TII);
      }
      // The iterator may be invalidated.
      I = MBB.getLastNonDebugInstr();
      // Was this the only branch instruction?
      if (I == MBB.begin() || !(I->isBranch()))
        continue;
      if (processBranch(*(--I), MBB, TII)) {
        LocalChanged = true;
        bbSizeMap[&MBB] = calcBasicBlockSize(MBB, TII);
        buildBBOffsetMap(MF, TII);
      }
    }
    Changed |= LocalChanged;

  } while (LocalChanged);
  // MF.dump();
  bbSizeMap.clear();
  bbOffsetMap.clear();
  return Changed;
}
