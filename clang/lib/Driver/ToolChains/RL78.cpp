//===--- RL78.cpp - RL78 ToolChain Implementations ------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RL78.h"

#include "Gnu.h"
#include "Arch/RL78.h"
#include "clang/Driver/CommonArgs.h"
#include "clang/Driver/Compilation.h"
#include "clang/Driver/MultilibBuilder.h"
#include "clang/Options/Options.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/VirtualFileSystem.h"
#include "llvm/Support/raw_ostream.h"

using namespace clang::driver;
using namespace clang::driver::toolchains;
using namespace clang::driver::tools;
using namespace clang;
using namespace llvm::opt;

struct RL78Multilib {
  StringRef cpu;
  StringRef opt;
  StringRef code;
  bool fullDoubles = false;
  bool disableMDA = false;
};

static std::string buildMultilibPath(RL78Multilib flags) { 
    // Naming rule is {cpu}_{opt}_{short code model}_{short data model}_{short double size}_{short mda usage for S2}
    std::string folderName = (flags.cpu + "_" + flags.opt +
                 "_" + (flags.code.equals_insensitive("mfar-code") ? "fc" : "nc") +
                 "_nd" +
                 "_" + (flags.fullDoubles ? "d64" : "d32")).str();
    if(flags.cpu.equals_insensitive("s2")) {
        folderName = folderName + (flags.disableMDA ? "_nomda" : "_mda");
    }
    return folderName; 
}

static void addMultilibFlags(MultilibBuilder& lib, RL78Multilib flags) {
    lib.flag(Twine("-mcpu=" + flags.cpu).str())
        .flag(Twine("-" + flags.opt).str())
        .flag(Twine("-" + flags.code).str());
    if(flags.fullDoubles)
        lib.flag("-m64bit-doubles");
    if(flags.disableMDA)
        lib.flag("-mdisable-mda");
}

static bool findRL78Multilibs(const Driver &D, const llvm::Triple &TargetTriple,
                              const ArgList &Args, DetectedMultilibs &Result) {

    constexpr RL78Multilib RL78MultilibSet[] = {
        // S1 core.
        {"s1", "O2", "mnear-code"},
        {"s1", "O2", "mfar-code"},
        {"s1", "Oz", "mnear-code"},
        {"s1", "Oz", "mfar-code"},
        {"s1", "O2", "mnear-code", /* fullDoubles */ true},
        {"s1", "O2", "mfar-code", /* fullDoubles */ true},
        {"s1", "Oz", "mnear-code", /* fullDoubles */ true},
        {"s1", "Oz", "mfar-code", /* fullDoubles */ true},

        // S2 core.
        {"s2", "O2", "mnear-code"},
        {"s2", "O2", "mfar-code"},
        {"s2", "Oz", "mnear-code"},
        {"s2", "Oz", "mfar-code"},
        {"s2", "O2", "mnear-code", /* fullDoubles */ true},
        {"s2", "O2", "mfar-code", /* fullDoubles */ true},
        {"s2", "Oz", "mnear-code", /* fullDoubles */ true},
        {"s2", "Oz", "mfar-code", /* fullDoubles */ true},

        {"s2", "O2", "mnear-code", /* fullDoubles */ false, /* disableMDA */ true},
        {"s2", "O2", "mfar-code", /* fullDoubles */ false, /* disableMDA */ true},
        {"s2", "Oz", "mnear-code", /* fullDoubles */ false, /* disableMDA */ true},
        {"s2", "Oz", "mfar-code", /* fullDoubles */ false, /* disableMDA */ true},
        {"s2", "O2", "mnear-code", /* fullDoubles */ true,  /* disableMDA */ true},
        {"s2", "O2", "mfar-code", /* fullDoubles */ true,  /* disableMDA */ true},
        {"s2", "Oz", "mnear-code", /* fullDoubles */ true,  /* disableMDA */ true},
        {"s2", "Oz", "mfar-code", /* fullDoubles */ true,  /* disableMDA */ true},

        // S3 core.
        {"s3", "O2", "mnear-code"},
        {"s3", "O2", "mfar-code"},
        {"s3", "Oz", "mnear-code"},
        {"s3", "Oz", "mfar-code"},
        {"s3", "O2", "mnear-code", /* fullDoubles */ true},
        {"s3", "O2", "mfar-code", /* fullDoubles */ true},
        {"s3", "Oz", "mnear-code", /* fullDoubles */ true},
        {"s3", "Oz", "mfar-code", /* fullDoubles */ true},
    };

    std::vector<MultilibBuilder> libs;
    for (const RL78Multilib &element : RL78MultilibSet) {
        MultilibBuilder lib = MultilibBuilder(buildMultilibPath(element));
        addMultilibFlags(lib, element);
        libs.emplace_back(lib);
    }

    Multilib::flags_list Flags;
    StringRef Cpu = rl78::getRL78Cpu(Args, TargetTriple);
    bool IsOptFotSize = rl78::getRL78OptSize(Args, TargetTriple);
    StringRef CodeModel = rl78::getRL78CodeModel(Args, TargetTriple);
    StringRef DoubleSize = rl78::getRL78DoubleSize(Args, TargetTriple);
    StringRef disableMDA = rl78::getRL78DisableMDA(Args, TargetTriple);

   for (const RL78Multilib &element : RL78MultilibSet) {
        addMultilibFlag(Cpu.equals_insensitive(element.cpu),
                        Twine("-mcpu=", element.cpu).str().c_str(), Flags);
    }
    addMultilibFlag(IsOptFotSize, "-Oz", Flags);
    addMultilibFlag(!IsOptFotSize, "-O2", Flags);
    addMultilibFlag(CodeModel.equals_insensitive("mfar-code"), "-mfar-code",
                    Flags);
    addMultilibFlag(!CodeModel.equals_insensitive("mfar-code"), "-mnear-code",
                    Flags);
    addMultilibFlag(DoubleSize.equals_insensitive("m64bit-doubles"),
                    "-m64bit-doubles", Flags);
    addMultilibFlag(disableMDA.equals_insensitive("mdisable-mda"),
                    "-mdisable-mda", Flags);

    Result.Multilibs =
        MultilibSetBuilder().Either(ArrayRef<MultilibBuilder>(libs)).makeMultilibSet();
    return Result.Multilibs.select(D, Flags, Result.SelectedMultilibs);
}

// RL78 Toolchain
RL78ToolChain::RL78ToolChain(const Driver &D, const llvm::Triple &Triple,
                             const ArgList &Args)
    : BareMetal(D, Triple, Args) {
   DetectedMultilibs Result;
   if (findRL78Multilibs(D, Triple, Args, Result)) {
    SelectedMultilibs = Result.SelectedMultilibs;
    Multilibs = Result.Multilibs;
   }
}

std::string RL78ToolChain::computeSysRoot() const {
   // For some reason, after normalizing the target triple, it gets set back
   // to the original value, specified by the user.
   // This means that if the user specifies -target rl78, the sysroot will point
   // to ./lib/clang-runtimes/rl78 and not to
   // ./lib/clang-runtimes/rl78-unknown-elf. We would like to avoid that, so we
   // force it here to be rl78-unknown-elf.
   if (!getDriver().SysRoot.empty())
    return getDriver().SysRoot;

   SmallString<128> SysRootDir;
   llvm::sys::path::append(SysRootDir, getDriver().Dir, "../lib/clang-runtimes",
                           "rl78-unknown-elf");

   if (SelectedMultilibs.size())
     SysRootDir += SelectedMultilibs[SelectedMultilibs.size() - 1].osSuffix();
   return std::string(SysRootDir);
}

void RL78ToolChain::AddClangSystemIncludeArgs(const ArgList &DriverArgs,
                                              ArgStringList &CC1Args) const {
 if (DriverArgs.hasArg(options::OPT_nostdinc))
    return;

  if (!DriverArgs.hasArg(options::OPT_nobuiltininc)) {
    SmallString<128> Dir(getDriver().ResourceDir);
    llvm::sys::path::append(Dir, "include");
    addSystemInclude(DriverArgs, CC1Args, Dir.str());
  }

  if (!DriverArgs.hasArg(options::OPT_nostdlibinc)) {
    SmallString<128> Dir(computeSysRoot());
    if (!Dir.empty()) {
      llvm::sys::path::append(Dir, "include");
      addSystemInclude(DriverArgs, CC1Args, Dir.str());
    }
  }
}

void RL78ToolChain::AddClangCXXStdlibIncludeArgs(const ArgList &DriverArgs,
                                             ArgStringList &CC1Args) const {
  if (DriverArgs.hasArg(options::OPT_nostdinc) ||
      DriverArgs.hasArg(options::OPT_nostdlibinc) ||
      DriverArgs.hasArg(options::OPT_nostdincxx))
    return;

  std::string SysRoot(computeSysRoot());
  if (SysRoot.empty())
    return;

  SmallString<128> Dir(SysRoot);
  llvm::sys::path::append(Dir, "include", "c++", "v1");
  addSystemInclude(DriverArgs, CC1Args, Dir.str());

}

void RL78ToolChain::AddCXXStdlibLibArgs(const ArgList &Args,
                                    ArgStringList &CmdArgs) const {
    CmdArgs.push_back("-lc++");
    CmdArgs.push_back("-lc++abi");
}

void RL78ToolChain::AddLinkRuntimeLib(const ArgList &Args,
                                      ArgStringList &CmdArgs) const {
  CmdArgs.push_back(
      Args.MakeArgString("-lclang_rt.builtins"));
}

auto RL78ToolChain::buildLinker() const -> Tool * {
  return new rl78::Linker(*this);
}

static std::string GetStartObjectPath(const toolchains::RL78ToolChain &TC, std::string ObjName) {
  std::string SysRoot(TC.computeSysRoot());
  if (SysRoot.empty())
    return ObjName;

  SmallString<128> Dir(SysRoot);
  llvm::sys::path::append(Dir, "lib", ObjName);
  return Dir.c_str();
}

static bool userProvidedPasses(const llvm::opt::ArgList &Args) {
  for (StringRef WL : Args.getAllArgValues(options::OPT_Wl_COMMA)) {
    SmallVector<StringRef, 8> Pieces;
    WL.split(Pieces, ',');
    for (StringRef P : Pieces)
      if (P.starts_with("lto-newpm-passes="))
        return true;
  }

  return false;
}

static llvm::StringRef getOptimizationLevel(const llvm::opt::ArgList &Args) {
  if (llvm::opt::Arg *A = Args.getLastArg(options::OPT_O_Group)) {
    if (A->getOption().matches(options::OPT_O)) {
      llvm::StringRef V = A->getValue();
      return V;
    }
  }
  return {};
}

void rl78::Linker::ConstructJob(Compilation &C, const JobAction &JA,
                                const InputInfo &Output,
                                const InputInfoList &Inputs,
                                const ArgList &Args,
                                const char *LinkingOutput) const {

  const ToolChain &ToolChain = getToolChain();
  std::string Linker = ToolChain.GetProgramPath(getShortName());
  ArgStringList CmdArgs;

  auto &TC = static_cast<const toolchains::RL78ToolChain &>(getToolChain());

  // Extract all the -m options
  std::vector<llvm::StringRef> Features;
  handleTargetFeaturesGroup(TC.getDriver(), TC.getTriple(), Args, Features,
                            options::OPT_m_rl78_Features_Group);

  bool hasExplicitMirrorFlag =
    Args.getLastArg(options::OPT_mirror_source_0) ||
    Args.getLastArg(options::OPT_mirror_source_1) ||
    Args.getLastArg(options::OPT_mirror_source_common);
  const Arg *mirrorSource = Args.getLastArg(options::OPT_mirror_source_EQ);
  if (!hasExplicitMirrorFlag) {
    // Handle feature corresponding to "-mirror-source=" option.
    if (mirrorSource) {
      if (mirrorSource->containsValue("0"))
        Features.push_back("+mirror-source-0");
      else if (mirrorSource->containsValue("1"))
        Features.push_back("+mirror-source-1");
      else if (mirrorSource->containsValue("common"))
        Features.push_back("+mirror-source-common");
    } else
      Features.push_back("+mirror-source-0");
  }

  // Add features to mattr
  std::string MAttrString = "-plugin-opt=-mattr=";
  for (auto OneFeature : Features) {
    MAttrString.append(Args.MakeArgString(OneFeature));
    if (OneFeature != Features.back())
      MAttrString.append(",");
  }
  if (!Features.empty())
    CmdArgs.push_back(Args.MakeArgString(MAttrString));

  if (Args.hasFlag(options::OPT_mrelax, options::OPT_mno_relax, true)) {
    CmdArgs.push_back("--relax");
    // When optimizing for size, call the most called functions through the
    // CALLT table: one byte less per call, two clocks more.
    StringRef OptLevel = getOptimizationLevel(Args);
    if (OptLevel == "s" || OptLevel == "z")
      CmdArgs.push_back("--relax-callt");
  } else {
    CmdArgs.push_back("--no-relax");
  }

  AddLinkerInputs(TC, Inputs, Args, CmdArgs, JA);

  CmdArgs.push_back("-Bstatic");

  // Adding all paths specified with -L
  Args.AddAllArgs(CmdArgs, options::OPT_L);

  SmallString<128> Dir(TC.computeSysRoot());
  llvm::sys::path::append(Dir, "lib");
  CmdArgs.push_back(Args.MakeArgString("-L" + Dir));

  if (auto LTO = ToolChain.getLTOMode(Args); LTO != LTOK_None) {
    assert(!Inputs.empty() && "Must have at least one input.");
    // Provide a default LTO pipeline tuned for code size (improves -Os/-Oz
    // builds).
    if (!userProvidedPasses(Args)) {
      // LLVM 23 has no Os/Oz pipelines: O2, with the functions' optsize /
      // minsize attributes (set at compile time) doing the size tuning.
      if (StringRef O = getOptimizationLevel(Args); O == "s" || O == "z")
        CmdArgs.push_back(
            Args.MakeArgString("--lto-newpm-passes=lto<O2>,globalopt,mergefunc"));
    }
    rl78::addRL78PassTuneArgs(Args, CmdArgs);
    addLTOOptions(ToolChain, Args, CmdArgs, Output, Inputs, LTO == LTOK_Thin);
  }

  const bool Sim = Args.hasArg(options::OPT_fsim);

  // libc++ on picolibc is built with a section per function and object so
  // that a program takes only what it uses; without this a C++ program that
  // prints a line is several hundred kilobytes and its constants do not fit
  // in the mirror area. C links are left as they are.
  // -Wl,--no-gc-sections, later on the command line, turns it off.
  if (TC.getDriver().CCCIsCXX() &&
      !Args.hasArg(options::OPT_r, options::OPT_nostdlib,
                   options::OPT_nostartfiles))
    CmdArgs.insert(CmdArgs.begin(), "--gc-sections");

  // picolibc's linker script unless -T gives one. A relocatable link (-r)
  // gets none: the script's PROVIDEs would give addresses to symbols that
  // the final link is to define.
  if (Args.hasArg(options::OPT_r)) {
    Args.AddAllArgs(CmdArgs, options::OPT_T);
  } else if (!Args.hasArg(options::OPT_T)) {
    // The C++ variant also places the exception tables.
    const char *linkerscript =
        TC.getDriver().CCCIsCXX() ? "picolibcpp.ld" : "picolibc.ld";
    CmdArgs.push_back(
        Args.MakeArgString("-T" + GetStartObjectPath(TC, linkerscript)));
  } else {
    Args.AddAllArgs(CmdArgs, options::OPT_T);
  }

  // crt0.o does not return from main; on a simulator the program ends with
  // exit().
  if (!Args.hasArg(options::OPT_nostdlib, options::OPT_nostartfiles))
    CmdArgs.push_back(Args.MakeArgString(
        GetStartObjectPath(TC, Sim ? "crt0-semihost.o" : "crt0.o")));

  // Libraries in dependency order: libc++ and libc++abi, the console and
  // exit stubs (the simulator's, or stubs that an application's own
  // definitions replace), libc (with the maths library), compiler-rt.
  if (!Args.hasArg(options::OPT_nostdlib, options::OPT_nodefaultlibs)) {
    if (TC.ShouldLinkCXXStdlib(Args))
      TC.AddCXXStdlibLibArgs(Args, CmdArgs);
    CmdArgs.push_back(Sim ? "-lsemihost" : "-ldummyhost");
    CmdArgs.push_back("-lc");
    TC.AddLinkRuntimeLib(Args, CmdArgs);
  }

  CmdArgs.push_back("-o");
  CmdArgs.push_back(Output.getFilename());

  if (Args.hasFlag(options::OPT_mfar_code, options::OPT_mnear_code, false))
    CmdArgs.push_back("-mfar-code");

  C.addCommand(std::make_unique<Command>(
      JA, *this, ResponseFileSupport::AtFileUTF8(), Args.MakeArgString(TC.GetLinkerPath()), CmdArgs, Inputs));
}
// RL78 tools end.