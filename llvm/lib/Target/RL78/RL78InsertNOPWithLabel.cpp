//===-- RL78InsertNOPWithLabel.cpp - Insert NOP_cg with label for RL78 ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass inserts a label and nop instruction at specified locations
// based on the -mllvm -minsert-nop-with-label=file,line,label option.
// - nops are used by the emulator to set event points
// - the labels are used to find the addresses where we inserted the nops
//
//===----------------------------------------------------------------------===//

#include "RL78TargetMachine.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/DebugLoc.h"
#include "llvm/MC/MCContext.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include <iomanip>
#include <set>
#include <map>
#include <sstream>
using namespace llvm;

namespace {
class RL78InsertNOPWithLabelPass : public MachineFunctionPass {
public:
  RL78InsertNOPWithLabelPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RL78 Insert local label and nop instruction";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  void parseInsertInfo(StringRef InsertInfo);

private:
  std::string sourceFile;
  unsigned lineNumber = 0;
  std::string labelName;
  static char ID;
  unsigned labelIndex = 0;
};

char RL78InsertNOPWithLabelPass::ID = 0;
} // end anonymous namespace

FunctionPass *llvm::createRL78InsertNOPWithLabelPass() {
  return new RL78InsertNOPWithLabelPass();
}

llvm::cl::list<std::string> InsertNOPWithLabel("minsert-nop-with-label",
                       cl::desc("Insert local label and nop (file,line,label)"),
                       cl::Hidden);

/// Parse the file,line,label argument from the command-line option.
void RL78InsertNOPWithLabelPass::parseInsertInfo(StringRef InsertInfo) {
  SmallVector<StringRef, 3> ParseArgs;
  InsertInfo.split(ParseArgs, ',');

  if (ParseArgs.size() != 3 || ParseArgs[0].empty() || ParseArgs[2].empty()) {
    RL78ReportError(
        false, "Missing argument for the \"-minsert-nop-with-label\" option");
    return;
  }

  sourceFile = std::string(ParseArgs[0]);
  labelName = std::string(ParseArgs[2]);

  // line number accepts decimal or hexadecimal,
  // the range is from 1 to 4294967295.
  StringRef lineArg = ParseArgs[1];
  bool isLineValid = true;
  if (lineArg.starts_with("0x") || lineArg.starts_with("0X")) {
    if (lineArg.drop_front(2).getAsInteger(16, lineNumber) || lineNumber < 1)
      isLineValid = false;
  } else {
    if (lineArg.getAsInteger(10, lineNumber) || lineNumber < 1)
      isLineValid = false;
  }
  RL78ReportError(
      isLineValid,
      "Invalid argument for the \"-minsert-nop-with-label\" option");
}

bool RL78InsertNOPWithLabelPass::runOnMachineFunction(MachineFunction &MF) {
  const TargetInstrInfo *TII = MF.getSubtarget<RL78Subtarget>().getInstrInfo();
  MCContext &Context = MF.getContext();
  bool changed = false;

  // Map to track labels to insert for each file and line number.
  std::multimap<std::pair<std::string, unsigned>, std::string> 
                                                            FileLineToLabelsMap;

  // Preprocess all specified command-line options.
  for (const auto &InsertInfo : InsertNOPWithLabel) {
    parseInsertInfo(InsertInfo);
    FileLineToLabelsMap.insert({{sourceFile, lineNumber}, labelName});
  }

  // Set to track already inserted label-line pairs for each file.
  std::set<std::pair<std::pair<std::string, unsigned>, std::string>> 
                                                                  InsertedLabel;

  // Proceed to insert the local label name and nop instruction.
  auto insertLabelAndNOP = [&](MachineBasicBlock &MBB, MachineInstr &MI,
                  const DebugLoc &DL, const std::string &file, unsigned line,
                  const std::string &label) {
    // Skip insertion if this line-label pair has been inserted for the file.
    if (InsertedLabel.count({{file, line}, label}))
      return;

    // The name of local label looks like labelName@0000.
    std::ostringstream labelStream;
    labelStream << label << "@" << std::setw(4) << std::setfill('0')
                << labelIndex++;
    std::string localLabel = labelStream.str();

    MCSymbol *LabelSymbol = Context.getOrCreateSymbol(localLabel);
    BuildMI(MBB, MI, DL, TII->get(RL78::ANNOTATION_LABEL)).addSym(LabelSymbol);
    BuildMI(MBB, MI, DL, TII->get(RL78::NOP));

    // Add to the set to prevent duplicate insertions for this line-label pair.
    InsertedLabel.insert({{file, line}, label});
  };

  const auto *Subprogram = MF.getFunction().getSubprogram();
  if (!Subprogram)
    return false;

  SmallString<128> DebugFilename;
  DebugFilename = Subprogram->getFilename();
  sys::path::remove_dots(DebugFilename, /*remove_dot_dot=*/true);

  // Iterate over MachineBasicBlocks and MachineInstructions.
  for (MachineBasicBlock &MBB : MF) {
    if (MBB.empty())
      continue;
    if (MBB.isEntryBlock() && Subprogram) {
      // Iterate through each line-label pair.
      for (const auto &[FileLine, label] : FileLineToLabelsMap) {
        const auto &[file, line] = FileLine;
        if (sys::path::filename(DebugFilename) == sys::path::filename(file) &&
            Subprogram->getLine() == line) {
          insertLabelAndNOP(MBB, *MBB.begin(), DebugLoc(), file, line, label);
          changed = true;
        }
      }
    }
    for (MachineBasicBlock::iterator Next = MBB.begin(), E = MBB.end();
         Next != E;) {
      MachineInstr &MI = *Next;
      DebugLoc DL = MI.getDebugLoc();
      ++Next;
      // Skip instructions without DebugLoc.
      if (!DL)
        continue;

      // Handle the original debug location. Use getInlinedAt() for inline code,
      // otherwise use get() for the base location.
      const DILocation *OriginalLoc =
          DL.getInlinedAt() ? DL.getInlinedAt() : DL.get();
      if (!OriginalLoc)
        continue;

      for (const auto &[FileLine, label] : FileLineToLabelsMap) {
        const auto &[file, line] = FileLine;

        // Check if the line and file match the current instruction.
        if (OriginalLoc->getLine() == line &&
            sys::path::filename(DebugFilename) == sys::path::filename(file)) {
          insertLabelAndNOP(MBB, MI, DL, file, line, label);
          changed = true;
        }
      }
    }
  }

  return changed;
}