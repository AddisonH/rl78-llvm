//===--- RL78.h - Declare RL78 target feature support ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares RL78 TargetInfo objects.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_BASIC_TARGETS_RL78_H
#define LLVM_CLANG_LIB_BASIC_TARGETS_RL78_H
#include "clang/Basic/MacroBuilder.h"
#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/TargetOptions.h"
#include "llvm/Support/Compiler.h"

namespace clang {
namespace targets {
class RL78TargetInfo : public TargetInfo {

  static const TargetInfo::GCCRegAlias GCCRegAliases[];
  static const char *const GCCRegNames[];
  // TODO: optimize this we are comparing the string twice
  std::string CPUName;
  bool has64BitDoubles;
  bool farCodeModel;
  bool commonRom;
  bool isMDADisabled;
  std::string ABI;

public:
  RL78TargetInfo(const llvm::Triple &Triple, const TargetOptions &Opts);

  void getTargetDefines(const LangOptions &Opts,
                        MacroBuilder &Builder) const override {
    
	Builder.defineMacro("__ELF__");

    // Define RL78 specific macros.
    Builder.defineMacro("__RL78__");

    // There is no _BitInt; like GCC, do not advertise a maximum width
    // (libc++ keys its _BitInt overloads on this macro).
    Builder.undefineMacro("__BITINT_MAXWIDTH__");

    if (Opts.CPlusPlus)
      Builder.defineMacro("_GNU_SOURCE");

    // OBS. We have kept the CCRL naming here which is the correct one (matches
    // the hardware) GCC defines __RL78_G10__, __RL78_G13, __RL78_G14__ which is
    // wrong.
    if (CPUName.compare("RL78_S1") == 0) {
      Builder.defineMacro("__RL78_S1__");
    } else if (CPUName.compare("RL78_S2") == 0) {
      Builder.defineMacro("__RL78_S2__");
      if (isMDADisabled) {
        Builder.defineMacro("__MDA_DISABLED__");
      } else {
        Builder.defineMacro("__MDA_ENABLED__");
      }
    } else if (CPUName.compare("RL78_S3") == 0) {
      Builder.defineMacro("__RL78_S3__");
    }

    if (has64BitDoubles)
      Builder.defineMacro("__RL78_64BIT_DOUBLES__");
    else
      Builder.defineMacro("__RL78_32BIT_DOUBLES__");

    if (commonRom)
      Builder.defineMacro("__COMMON_ROM__");

    if (farCodeModel)
      Builder.defineMacro("__RL78_MEDIUM__");
    else
      Builder.defineMacro("__RL78_SMALL__");

    // Data is near unless a pointer or an object says otherwise. A far
    // pointer holds a 20-bit address in 32 bits.
    Builder.defineMacro("__far", "__attribute__((__address_space__(" +
                                     Twine(FarDataAS) + ")))");
    Builder.defineMacro("__near", "");
  }

  /// Target address spaces: data is near (16-bit pointers into FxxxxH)
  /// by default; far data and far code pointers are 32 bits wide.
  enum : unsigned { FarDataAS = 2, FarCodeAS = 3 };

  static bool isFarAddressSpace(LangAS AS) {
    return isTargetAddressSpace(AS) && (toTargetAddressSpace(AS) == FarDataAS ||
                                        toTargetAddressSpace(AS) == FarCodeAS);
  }

  uint64_t getPointerWidthV(LangAS AddrSpace) const override {
    return isFarAddressSpace(AddrSpace) ? 32 : 16;
  }

  uint64_t getPointerAlignV(LangAS AddrSpace) const override { return 16; }

  unsigned getProgramAddressSpace() const override {
    return farCodeModel ? FarCodeAS : 0;
  }

  bool setCPU(StringRef Name) override {
    if ((Name.compare("RL78_S1") == 0) || (Name.compare("RL78_S2") == 0) ||
        (Name.compare("RL78_S3") == 0)) {
      CPUName = Name;
      return true;
    }
    return false;
  }

  bool setABI(const std::string &Name) override {
    SmallVector<StringRef, 4> parts;
    StringRef(Name).split(parts, '_');
    const auto validABI =
        llvm::is_contained({"nc", "fc"}, parts[0]) &&
        llvm::is_contained({"nd", "fd"}, parts[1]) &&
        llvm::is_contained({"d32", "d64"}, parts[2]) &&
        (parts.size() == 3 ||
         (parts.size() == 4 && llvm::is_contained({"mda", "nomda"}, parts[3])));
    assert(validABI);
    if (validABI)
      ABI = Name;
    return validABI;
  }

  StringRef getABI() const override { return ABI; }

  bool validateAsmConstraint(const char *&Name,
                             TargetInfo::ConstraintInfo &Info) const override {
    if ((Name[0] == 'a' && Name[1] == 'x') ||
        (Name[0] == 'b' && Name[1] == 'c') ||
        (Name[0] == 'd' && Name[1] == 'e') ||
        (Name[0] == 'h' && Name[1] == 'l')) {
      Info.setAllowsRegister();
      ++Name;
      return true;
    }

    switch (*Name) {
    case 'a':
    case 'x':
    case 'b':
    case 'c':
    case 'd':
    case 'e':
    case 'h':
    case 'l':
      Info.setAllowsRegister();
    }
    return true;
  }

  ArrayRef<const char *> getGCCRegNames() const override;

  ArrayRef<TargetInfo::GCCRegAlias> getGCCRegAliases() const override;

  llvm::SmallVector<Builtin::InfosShard> getTargetBuiltins() const override;

  bool allowsLargerPreferedTypeAlignment() const override { return false; }

  /// A near pointer converts to a far one; the far spaces convert into each
  /// other (one 20-bit address).
  bool isAddressSpaceSupersetOf(LangAS A, LangAS B) const override {
    return A == B || (isFarAddressSpace(A) &&
                      (B == LangAS::Default || isFarAddressSpace(B)));
  }

  BuiltinVaListKind getBuiltinVaListKind() const override {
    return TargetInfo::VoidPtrBuiltinVaList;
  }

  // Returns a string of target-specific clobbers, in LLVM format.
  std::string_view getClobbers() const override { return ""; }

  void adjust(DiagnosticsEngine &Diags, LangOptions &Opts,
              const TargetInfo *Aux) override;
};

} // namespace targets
} // namespace clang

#endif // LLVM_CLANG_LIB_BASIC_TARGETS_RL78_H
