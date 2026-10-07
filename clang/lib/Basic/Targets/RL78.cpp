//===--- RL78.cpp - Implement RL78 target feature support ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements RL78 TargetInfo objects.
//
//===----------------------------------------------------------------------===//

#include "RL78.h"
#include "clang/Basic/TargetBuiltins.h"
#include "llvm/ADT/StringSwitch.h"

using namespace clang;
using namespace clang::targets;

static constexpr int NumBuiltins =
    clang::RL78::LastTSBuiltin - Builtin::FirstTSBuiltin;

static constexpr llvm::StringTable BuiltinStrings =
    CLANG_BUILTIN_STR_TABLE_START
#define BUILTIN CLANG_BUILTIN_STR_TABLE
#include "clang/Basic/BuiltinsRL78.def"
    ;

static constexpr auto BuiltinInfos = Builtin::MakeInfos<NumBuiltins>({
#define BUILTIN CLANG_BUILTIN_ENTRY
#include "clang/Basic/BuiltinsRL78.def"
});

llvm::SmallVector<Builtin::InfosShard>
RL78TargetInfo::getTargetBuiltins() const {
  return {{&BuiltinStrings, BuiltinInfos}};
}

const char *const RL78TargetInfo::GCCRegNames[] = {
    "ax", "bc", "de", "hl", "x", "a",  "c", "b", "e",
    "d",  "l",  "h",  "sp",  "ap", "psw", "es", "cs"};

// Positional: one entry per LangAS before FirstTargetAddressSpace.
static_assert((unsigned)LangAS::__near == 27 &&
                  (unsigned)LangAS::FirstTargetAddressSpace == 30,
              "LangAS changed: update RL78AddrSpaceMap");
const LangASMap RL78TargetInfo::RL78AddrSpaceMap = {
    0, // Default
    0, // opencl_global
    0, // opencl_local
    0, // opencl_constant
    0, // opencl_private
    0, // opencl_generic
    0, // opencl_global_device
    0, // opencl_global_host
    0, // cuda_device
    0, // cuda_constant
    0, // cuda_shared
    0, // sycl_global
    0, // sycl_global_device
    0, // sycl_global_host
    0, // sycl_local
    0, // sycl_private
    0, // ptr32_sptr
    0, // ptr32_uptr
    0, // ptr64
    0, // hlsl_groupshared
    0, // hlsl_constant
    0, // hlsl_private
    0, // hlsl_device
    0, // hlsl_input
    0, // hlsl_output
    0, // hlsl_push_constant
    0, // wasm_funcref
    1, // __near
    2, // __far_data
    3, // __far_code
};

ArrayRef<const char *> RL78TargetInfo::getGCCRegNames() const {
  return llvm::ArrayRef(GCCRegNames);
}

const TargetInfo::GCCRegAlias RL78TargetInfo::GCCRegAliases[] = {
    {{"rp0"}, "ax"}, {{"rp2"}, "bc"}, {{"rp4"}, "de"}, {{"rp4"}, "hl"},
    {{"r1"}, "a"},   {{"r0"}, "x"},   {{"r3"}, "b"},   {{"r2"}, "c"},
    {{"r5"}, "d"},   {{"r4"}, "e"},   {{"r7"}, "h"},   {{"r6"}, "l"}};

ArrayRef<TargetInfo::GCCRegAlias> RL78TargetInfo::getGCCRegAliases() const {
  return llvm::ArrayRef(GCCRegAliases);
}

RL78TargetInfo::RL78TargetInfo(const llvm::Triple &Triple,
                               const TargetOptions &Opts)
    : TargetInfo(Triple) {

  has64BitDoubles = false;
  farCodeModel = false;
  farDataModel = false;
  isMDADisabled = false;
  for (auto &I : Opts.FeaturesAsWritten) {
    if (I == "+64bit-doubles")
      has64BitDoubles = true;
    if (I == "+disable-mda")
      isMDADisabled = true;
    if (I == "+far-code")
      farCodeModel = true;
    if (I == "+near-code")
      farCodeModel = false;
    if (I == "+far-data")
      farDataModel = true;
    if (I == "+near-data")
      farDataModel = false;
  }

  std::string ABI{farCodeModel ? "fc" : "nc"};
  ABI += (farDataModel ? "_fd" : "_nd");
  ABI += (has64BitDoubles ? "_d64" : "_d32");
  if (Opts.CPU == "RL78_S2")
    ABI += ((isMDADisabled ? "_nomda" : "_mda"));
  setABI(ABI);

  TLSSupported = false;
  IntWidth = 16;
  IntAlign = 16;
  LongWidth = 32;
  LongLongWidth = 64;
  LongAlign = LongLongAlign = 16;
  if (!has64BitDoubles) {
    DoubleWidth = 32;
    DoubleFormat = &llvm::APFloat::IEEEsingle();
    LongDoubleWidth = 32;
    LongDoubleFormat = &llvm::APFloat::IEEEsingle();
  } else {
    DoubleWidth = 64;
    DoubleFormat = &llvm::APFloat::IEEEdouble();
    LongDoubleWidth = 64;
    LongDoubleFormat = &llvm::APFloat::IEEEdouble();
  }
  Char32Type = UnsignedLong;
  WCharType = UnsignedInt;
  WIntType = UnsignedInt;
  FloatAlign = 16;
  DoubleAlign = 16;
  LongDoubleAlign = 16;
  PointerWidth = farDataModel ? 32 : 16;
  PointerAlign = 16;
  SuitableAlign = 16;
  DefaultAlignForAttributeAligned = 16;
  SizeType = UnsignedInt;
  IntMaxType = SignedLongLong;
  IntPtrType = farDataModel ? SignedLong : SignedInt;
  PtrDiffType = SignedInt;
  SigAtomicType = SignedLong;

  std::string DL;
  llvm::raw_string_ostream SS(DL);

  // NOTE: keep in sync with def from llvm/lib/Target/RL78/RL78TargetMachine.cpp
  SS << "e"               // little endian
        "-m:o";           // Mach-O mangling: Private symbols get L prefix.
                          // Other symbols get a _ prefix.
  if (farDataModel) {
    SS << "-p0:32:16:16"  // default: 32 bit width, 16 bit aligned
          "-A1";          // near allocas
  } else {
    SS << "-p0:16:16:16"; // default: 16 bit width, 16 bit aligned
  }

  SS << "-p1:16:16:16" // Near pointers: 16 bit width, 16 bit aligned.
        "-p2:32:16:16:16" // Far data pointers: 32 bit width, 16 bit aligned.
        "-p3:32:16:16:16" // Far code pointers: 32 bit width, 16 bit aligned.
        "-i32:16-i64:16-f32:16-f64:16-a:8" // integers of bit size 32 and 64, float and double types are 16 bit aligned. aggregate type objects are 8 bit aligned
        "-n8:8"                            // 8 bit native integer width
        "-n16:16"                          // 16 bit native integer width
        "-S16";                            // 16 bit natural stack alignment

  if (farCodeModel)
    SS << "-P3";                           // Use far pointers for functions.

  SS.flush();

  resetDataLayout(DL);
  UserLabelPrefix = "_"; // Consistent with the Mach-O mangling above.

  AddrSpaceMap = &RL78AddrSpaceMap;
}

void RL78TargetInfo::adjust(DiagnosticsEngine &Diags, LangOptions &Opts,
                            const TargetInfo *Aux) {
  TargetInfo::adjust(Diags, Opts, Aux);
  // Turn off POSIXThreads and ThreadModel so that we don't predefine _REENTRANT
  // or __STDCPP_THREADS__ if we will eventually end up stripping atomics
  // because they are unsupported.
  Opts.POSIXThreads = false;
  Opts.setThreadModel(LangOptions::ThreadModelKind::Single);
  Opts.ThreadsafeStatics = false;
}