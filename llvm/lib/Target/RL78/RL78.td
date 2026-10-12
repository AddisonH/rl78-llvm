//===-- RL78.td - Describe the RL78 Target Machine -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Target-independent interfaces which we are implementing
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"


//===----------------------------------------------------------------------===//
// RL78 Subtarget features.
//===----------------------------------------------------------------------===//

def Feature64bitDoubles : SubtargetFeature<"64bit-doubles", "has64BitDoubles", "true",
                                      "Use 64-bit Doubles">;

def FeatureMirrorSourceOne : SubtargetFeature<"mirror-source-1", "mirrorSource", "1",
                                      "MAA is set to 1">;
def FeatureMirrorSourceZero : SubtargetFeature<"mirror-source-0", "mirrorSource", "0",
                                      "MAA is set to 0">;
def FeatureMirrorSourceCommon : SubtargetFeature<"mirror-source-common", "mirrorSource", "2",
                                      "Mirror source is set to common">;

def FeatureFarCode : SubtargetFeature<"far-code", "hasFarCodeModel", "true",
                                      "Default function pointers are far.">;

def FeatureNearRom : SubtargetFeature<"near-rom", "romModel", "0",
                                      "Default constant data pointers are near.">;

def FeatureCommonRom : SubtargetFeature<"common-rom", "romModel", "2",
                                      "Common constant mode.">;

// What the cores differ in. S1 has one register bank and no SEL RBn; only S3
// has the multiply, divide and multiply-accumulate instructions.
def FeatureRegBanks
    : SubtargetFeature<"reg-banks", "HasRegBanks", "true",
                       "Four register banks (SEL RBn)">;
def FeatureMulDiv
    : SubtargetFeature<"muldiv", "HasMulDiv", "true",
                       "MULHU, MULH, DIVHU, DIVWU, MACHU and MACH">;

def FeatureDisableMDA : SubtargetFeature<"disable-mda", "disableMDA", "true",
                                      "Disable usage of Mul/Div/Mac accelerator (S2 only).">;

def FeatureRelax : SubtargetFeature<"relax", "linkerRelax", "true",
                                    "Enable linker relaxation.">;

//===----------------------------------------------------------------------===//
// Register File, Calling Conv, Instruction Descriptions
//===----------------------------------------------------------------------===//

include "RL78Schedule.td"
include "RL78InstrInfo.td"

// Generic pseudos with pointer operands (LOAD_STACK_GUARD, ...) use 16-bit
// register pairs.
defm : RemapAllTargetPseudoPointerOperands<RL78RPRegs>;

def RL78InstrInfo : InstrInfo {
  // this will be the default behavior in the future, so better to be prepared
  let guessInstructionProperties = 0;
}

def RL78AsmParser : AsmParser {
  bit ShouldEmitMatchRegisterName = 0;
}

//===----------------------------------------------------------------------===//
// RL78 processors supported.
//===----------------------------------------------------------------------===//

class Proc<string Name, list<SubtargetFeature> Features>
 : Processor<Name, NoItineraries, Features>;

def : ProcessorModel<"RL78_S1", NoSchedModel, []>;
def : ProcessorModel<"RL78_S2", NoSchedModel, [FeatureRegBanks]>;
def : ProcessorModel<"RL78_S3", NoSchedModel,
                     [FeatureRegBanks, FeatureMulDiv]>;

//===----------------------------------------------------------------------===//
// Declare the target which we are implementing
//===----------------------------------------------------------------------===//

def RL78AsmWriter : AsmWriter {
  string AsmWriterClassName  = "InstPrinter";
  int PassSubtarget = 1;
  int Variant = 0;
}

def RL78 : Target {
  // Pull in Instruction Info:
  let InstructionSet = RL78InstrInfo;
  let AssemblyParsers  = [RL78AsmParser];
  let AssemblyWriters = [RL78AsmWriter];
}
