//===--- RL78.cpp - RL78 Helpers for Tools --------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "../Clang.h"
#include "clang/Basic/CharInfo.h"
#include "clang/Driver/Driver.h"
#include "clang/Driver/DriverDiagnostic.h"
#include "clang/Options/Options.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/raw_ostream.h"
#include "clang/Driver/CommonArgs.h"

using namespace clang::driver;
using namespace clang::driver::tools;
using namespace clang;
using namespace llvm::opt;

void rl78::getRL78TargetFeatures(const Driver &D, const llvm::Triple &Triple,
                            const llvm::opt::ArgList &Args,
                            std::vector<llvm::StringRef> &Features) {

  StringRef cpu = getRL78Cpu(Args, Triple);
  const Arg *disableMDA = Args.getLastArg(options::OPT_mdisable_mda);
  const Arg *mCode = Args.getLastArg(options::OPT_mnear_code, options::OPT_mfar_code);
  const Arg *mirrorSource = Args.getLastArg(options::OPT_mirror_source_EQ);

  bool isS1 = cpu.equals_insensitive("s1");
  bool isS2 = cpu.equals_insensitive("s2");
  
  bool mdaDisabled = disableMDA;
  bool hasExplicitMirrorFlag =
      Args.getLastArg(options::OPT_mirror_source_0) ||
      Args.getLastArg(options::OPT_mirror_source_1) ||
      Args.getLastArg(options::OPT_mirror_source_common);

  if (!cpu.equals_insensitive("s1") &&
      !cpu.equals_insensitive("s2") && !cpu.equals_insensitive("s3")){
    D.Diag(diag::err_target_unknown_cpu) << cpu;
    return;
  }

  if (!isS2 && mdaDisabled) {
    D.Diag(diag::err_drv_cannot_mix_options) << cpu << "-mdisable-mda";
    return;
  }

  // Add any that the user explicitly requested on the command line,
  // which may override the defaults. Positive command-line options are encoded
  // as positive features starting with a "+" sign. Negative command-line
  // options are encoded as negative features starting with a "-" sign.
  handleTargetFeaturesGroup(D, Triple, Args, Features, options::OPT_m_rl78_Features_Group);

  if (mCode) {
    // Add -far-code as the last feature if the last option is -mnear-code.
    if (mCode->getOption().getID() == options::OPT_mnear_code) {
      Features.push_back("-far-code");
    }
    // Do not add new features if the last option is -mfar-code.
    // Remove all +near-code features regardless of whether the last option
    // is -mfar-code or -mnear-code.
    Features.erase(std::remove(Features.begin(), Features.end(), "+near-code"),
                   Features.end());
  }

  if (isS1 && (Args.getLastArg(options::OPT_mirror_source_1) ||
               (mirrorSource && mirrorSource->containsValue("1")))) {
    D.Diag(diag::err_drv_argument_not_allowed_with) << "-mirror-source=1"
                                                    << "-mcpu=S1";
    return;
  }

  if (!hasExplicitMirrorFlag) {
    // Handle feature corresponding to "-mirror-source=" option.
    if (mirrorSource) {
      if (mirrorSource->containsValue("0"))
        Features.push_back("+mirror-source-0");
      else if (mirrorSource->containsValue("1"))
        Features.push_back("+mirror-source-1");
      else if (mirrorSource->containsValue("common"))
        Features.push_back("+mirror-source-common");
      else
        D.Diag(diag::err_drv_invalid_argument_to_option)
            << mirrorSource->getValue()
            << mirrorSource->getOption().getName();
    } else
      Features.push_back("+mirror-source-0");
  }

  // -mrelax is default, unless -mno-relax is specified.
  if (Args.hasFlag(options::OPT_mrelax, options::OPT_mno_relax, true)) {
    Features.push_back("+relax");
    // -gsplit-dwarf -mrelax requires DW_AT_high_pc/DW_AT_ranges/... indexing
    // into .debug_addr, which is currently not implemented.
    Arg *A;
    if (getDebugFissionKind(D, Args, A) != DwarfFissionKind::None)
      D.Diag(clang::diag::err_drv_unsupported_opt_for_target)
          << A->getAsString(Args) << "rl78 with -mrelax";
  } else {
    Features.push_back("-relax");
  }
}

StringRef rl78::getRL78Cpu(const llvm::opt::ArgList &Args,
                              const llvm::Triple &Triple) {
    assert(Triple.isRL78() && "Unexpected triple");

    if (const Arg *A = Args.getLastArg(options::OPT_mcpu_EQ))
        return A->getValue();
    // Default cpu is S3.
    return "s3";
}

bool rl78::getRL78OptSize(const llvm::opt::ArgList &Args,
                          const llvm::Triple &Triple) {
    assert(Triple.isRL78() && "Unexpected triple");
    if (const Arg *optimizeOpt = Args.getLastArg(options::OPT_O)) {
        StringRef Opt = optimizeOpt->getValue();
        return Opt == "s" || Opt == "z";
    }
    // Default is not optimize for size.
    return false;
}

StringRef rl78::getRL78CodeModel(const llvm::opt::ArgList &Args,
                                 const llvm::Triple &Triple) {
    assert(Triple.isRL78() && "Unexpected triple");

    const Arg *mCode =
        Args.getLastArg(options::OPT_mnear_code, options::OPT_mfar_code);
    if (mCode && mCode->getOption().getID() == options::OPT_mfar_code)
        return "mfar-code";
    // Default is near-code.
    return "mnear-code";
}

StringRef rl78::getRL78DoubleSize(const llvm::opt::ArgList &Args,
                                  const llvm::Triple &Triple) {
    assert(Triple.isRL78() && "Unexpected triple");

    if (const Arg *BitDoubles = Args.getLastArg(options::OPT_m64bit_doubles))
        return "m64bit-doubles";
    // Default is 32 bit.
    return "m32bit-doubles";
}

StringRef rl78::getRL78DisableMDA(const llvm::opt::ArgList &Args,
                              const llvm::Triple &Triple) {
    assert(Triple.isRL78() && "Unexpected triple");

    if (const Arg *BitDoubles = Args.getLastArg(options::OPT_mdisable_mda))
        return "mdisable-mda";
    // Default is enabled, but we don't have a flag for it.
    return "";
}

void rl78::addRL78PassTuneArgs(const llvm::opt::ArgList &Args,
                               llvm::opt::ArgStringList &CmdArgs) {
  Arg *OptArg = Args.getLastArg(options::OPT_O_Group);
  char OptLevel =
      (OptArg && OptArg->getNumValues()) ? OptArg->getValue()[0] : '\0';

  if (OptLevel != 's' && OptLevel != 'z')
    return;

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-enable-load-pre=false");

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-disable-machine-cse=true");

  // SimplifyCFG: a branch is two bytes and there is no conditional move, so
  // computing a value on both paths to save a branch grows the code.
  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-keep-loops=false");

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-bonus-inst-threshold=0");

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-phi-node-folding-threshold=0");

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-disable-lsr=true");

  CmdArgs.push_back("-mllvm");
  CmdArgs.push_back("-disable-phi-elim-edge-splitting=true");

  // What the MachineOutliner leaves between two outlined calls often repeats
  // as well. Outlining again costs a call and a return each time, so only
  // where size is all that counts.
  if (OptLevel == 'z') {
    CmdArgs.push_back("-mllvm");
    CmdArgs.push_back("-machine-outliner-reruns=2");
  }
}
