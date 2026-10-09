//===------------------ RL78AdjustMemRefsPass.cpp -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// Pass to improve register allocation in case of indirect addressing.
//
// During lowering we only use HL, this is what most instructions
// can accept. However a few instructions accept DE too.
// This pass attempts to improve the generated code by switching HL to DE if
// the usage range of two separate addresses overlaps, making it beneficial to
// use HL for one and DE for the other.
//
// It also handles the case when the offset  does not fit into a byte by
// changing the load/store instructions to use word[BC].
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "RL78Subtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SparseSet.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

#include <queue>

using namespace llvm;

// Pinning every address to HL/DE/BC by a straight-line interval scan (below)
// ignores loops: a pointer carried around a loop in DE was copied to HL before
// each access (push de / pop hl), CoreMark's list walks most of all. The
// generic load/store forms are the word[BC] encodings and are specialized to
// [DE+byte]/[HL+byte] after allocation, so any of BC, DE, HL works as long as
// the offset fits a byte: constrain the class and let the allocator choose.
// Only for loaded pointers, though: left free, other bases (p + 4 and the
// like) sometimes got DE/BC and the allocator spilled worse around them
// (Embench huffbench +18%, also with the scan's choice as a hint), while the
// pin cost little there.
static cl::opt<bool> PinAddressRegs(
    "rl78-pin-address-regs", cl::Hidden, cl::init(false),
    cl::desc("Pin load/store address registers to HL/DE before allocation "
             "instead of constraining them to BC/DE/HL"));
static cl::opt<bool> OnlyLoadedPointers(
    "rl78-unpin-loaded-pointers-only", cl::Hidden, cl::init(true),
    cl::desc("Leave only loaded pointers (p = p->next) to the allocator"));

namespace {
class RL78AdjustMemRefsPass : public MachineFunctionPass {
public:
  RL78AdjustMemRefsPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 Adjust Indirect Memory Refs";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;
};

char RL78AdjustMemRefsPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78AdjustMemRefsPass() {
  return new RL78AdjustMemRefsPass();
}

// Return the operand index of the address register.
// Returns -1 if the passed instruction is not a store or load
// that supports both HL and DE based addressing.
static int getAddrOpPositions(const MachineInstr &MI) {
  switch (MI.getOpcode()) {
  case RL78::LOAD16_rp_rpi:
  case RL78::LOAD8_r_ri:
    return 1;
  case RL78::STORE8_ri_imm:
  case RL78::STORE16_rpi_rp:
  case RL78::STORE8_ri_r:
    return 0;
  default:
    return -1;
  }
}

// A pointer that is itself loaded (p = p->next), directly or through COPYs and
// PHIs. Selected loads write $rp0 and are followed by `%v = COPY $rp0`.
static bool isLoadedPointer(Register R, const MachineRegisterInfo &MRI,
                            SmallPtrSetImpl<const MachineInstr *> &Seen,
                            unsigned Depth = 0) {
  const MachineInstr *Def = R.isVirtual() ? MRI.getUniqueVRegDef(R) : nullptr;
  if (!Def || Depth > 6 || !Seen.insert(Def).second)
    return false;
  if (Def->isPHI()) {
    for (unsigned I = 1; I < Def->getNumOperands(); I += 2)
      if (isLoadedPointer(Def->getOperand(I).getReg(), MRI, Seen, Depth + 1))
        return true;
    return false;
  }
  if (!Def->isCopy())
    return false;
  Register Src = Def->getOperand(1).getReg();
  if (Src.isVirtual())
    return isLoadedPointer(Src, MRI, Seen, Depth + 1);
  MachineBasicBlock::const_iterator Begin = Def->getParent()->begin();
  MachineBasicBlock::const_iterator It = Def->getIterator();
  if (It == Begin)
    return false;
  It = skipDebugInstructionsBackward(std::prev(It), Begin);
  if (It->isDebugInstr())
    return false;
  const MachineInstr &Prev = *It;
  return Prev.mayLoad() && Prev.getNumOperands() &&
         Prev.getOperand(0).isReg() && Prev.getOperand(0).getReg() == Src;
}

bool RL78AdjustMemRefsPass::runOnMachineFunction(MachineFunction &MF) {

  SmallSet<unsigned, 10> addressRegs;
  SmallSet<unsigned, 10> needsBC;
  std::map<unsigned, std::pair<unsigned, unsigned>> regRange;
  unsigned index = 0;
  int addrPos = -1;

  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      // Debug instructions must not lengthen the intervals: -g would change
      // the HL/DE assignment.
      if (MI.isDebugInstr()) {
        Next++;
        continue;
      }
      for (unsigned i = 0; i < MI.getNumOperands(); i++) {
        if (i == 0 && MI.getOperand(i).isReg() && MI.getOperand(i).isDef())
          continue;
        if (MI.getOperand(i).isReg() &&
            Register::isVirtualRegister(MI.getOperand(i).getReg())) {
          // Save use intervals for virtual registers.
          unsigned RegOp = MI.getOperand(i).getReg();
          if (regRange.find(RegOp) == regRange.end()) {
            regRange[RegOp] = {index, index};
          } else {
            regRange[RegOp] = std::pair(regRange[RegOp].first, index);
          }
        }
      }

      addrPos = getAddrOpPositions(MI);
      if (addrPos != -1) {
        // Gather load/store address regs.
        const MachineOperand &Imm = MI.getOperand(addrPos + 1);
        // If address requires word[BC] force the vreg assignment to BC.
        if ((Imm.isImm() && Imm.getImm() > 255) || Imm.isGlobal() ||
            Imm.isSymbol())
          needsBC.insert(MI.getOperand(addrPos).getReg());

        addressRegs.insert(MI.getOperand(addrPos).getReg());
      }
      Next++;
      index++;
    }
  }

  // Filter vregs that are not used as addresses.
  SmallVector<std::tuple<unsigned, unsigned, unsigned>> addrRegRange;
  for (auto const &r : regRange)
    if (addressRegs.contains(r.first))
      addrRegRange.push_back(
          std::tuple(r.first, r.second.first, r.second.second));

  // Sort vreg intervals based on starting point in order to iterate over them
  // and determine overlapping regions, where we can use DE for the second
  // address.
  std::sort(addrRegRange.begin(), addrRegRange.end(),
            [](const std::tuple<unsigned, unsigned, unsigned> &a,
               const std::tuple<unsigned, unsigned, unsigned> &b) {
              return (get<1>(a) < get<1>(b));
            });

  unsigned rp6Usage = 0;
  unsigned rp4Usage = 0;

  // Priority queue whose top points to the earliest interval ending.
  std::priority_queue<std::pair<unsigned, unsigned>, std::vector<std::pair<unsigned, unsigned>>,
                      std::greater<std::pair<unsigned, unsigned>>>
      rangeHeap;

  // Assign HL or DE to virtual registers based on interval overlap.
  DenseMap<unsigned, unsigned> vRegsMap;
  for (auto &range : addrRegRange) {
    unsigned VirtualReg = get<0>(range);
    unsigned start = get<1>(range);
    unsigned end = get<2>(range);
    unsigned PhysReg;

    // Remove all intervals that finish before the current interval.
    while (!rangeHeap.empty() && rangeHeap.top().first < start) {
      unsigned freedReg = rangeHeap.top().second;
      if (freedReg == RL78::RP6)
        rp6Usage--;
      else
        rp4Usage--;
      rangeHeap.pop();
    }

    // Force PhysReg to BC if it is required by the offset size.
    // Otherwise allocate to unused PhysReg or fall back to HL
    // if DE is not free.
    if (needsBC.contains(VirtualReg)) {
      PhysReg = RL78::RP2;
    } else if (rp6Usage == 0) {
      PhysReg = RL78::RP6;
    } else if (rp4Usage == 0) {
      PhysReg = RL78::RP4;
    } else {
      PhysReg = RL78::RP6;
    }

    // Save the Phys-Virtual mapping.
    if (PhysReg == RL78::RP6)
      rp6Usage++;
    else
      rp4Usage++;
    rangeHeap.push({end, PhysReg});
    vRegsMap[VirtualReg] = PhysReg;
  }

  if (!PinAddressRegs) {
    // Offsets over a byte, and symbols, need word[BC]: those still go to BC.
    MachineRegisterInfo &MRI = MF.getRegInfo();
    const TargetInstrInfo *TII =
        MF.getSubtarget<RL78Subtarget>().getInstrInfo();
    bool Changed = false;
    for (MachineBasicBlock &MBB : MF)
      for (MachineInstr &MI : MBB) {
        int Pos = getAddrOpPositions(MI);
        if (Pos == -1)
          continue;
        Register R = MI.getOperand(Pos).getReg();
        if (!R.isVirtual())
          continue;
        SmallPtrSet<const MachineInstr *, 8> Seen;
        if (needsBC.contains(R) ||
            (OnlyLoadedPointers && !isLoadedPointer(R, MRI, Seen))) {
          // Pinned as before: to BC for word[BC], else the scan's HL/DE.
          Register Phys = needsBC.contains(R) ? Register(RL78::RP2)
                                              : Register(vRegsMap[R]);
          BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::COPY), Phys)
              .addReg(R);
          MI.getOperand(Pos).ChangeToRegister(Phys, false);
        } else {
          Register NewR = R;
          if (!MRI.constrainRegClass(R, &RL78::RL78BCDEHLRegClass)) {
            NewR = MRI.createVirtualRegister(&RL78::RL78BCDEHLRegClass);
            BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::COPY), NewR)
                .addReg(R);
            MI.getOperand(Pos).setReg(NewR);
          }
        }
        Changed = true;
      }
    return Changed;
  }

  const TargetInstrInfo *TII = MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;

      addrPos = getAddrOpPositions(MI);
      if (addrPos != -1) {
        unsigned PhysReg = vRegsMap[MI.getOperand(addrPos).getReg()];
        BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RL78::COPY), PhysReg)
            .addReg(MI.getOperand(addrPos).getReg());
        MI.getOperand(addrPos).ChangeToRegister(PhysReg, false);
        Changed = true;
      }
      Next++;
    }
  }

  return Changed;
}
