//===--- TextEncoding.cpp -------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "clang/Lex/TextEncoding.h"
#include "clang/Basic/DiagnosticDriver.h"
#include "llvm/Support/TextEncoding.h"

using namespace clang;

llvm::TextEncodingConverter *
TextEncoding::getConverter(ConversionAction Action) const {
  switch (Action) {
  case CA_ToLiteralEncoding:
    return ToLiteralEncodingConverter.get();
  case CA_FromInputEncoding:
    return FromInputEncodingConverter.get();
  default:
    return nullptr;
  }
}

std::error_code
TextEncoding::setConvertersFromOptions(TextEncoding &TE,
                                       const clang::LangOptions &Opts) {
  using namespace llvm;

  const char *UTF8 = "UTF-8";
  TE.LiteralEncoding =
      Opts.LiteralEncoding.empty() ? UTF8 : Opts.LiteralEncoding.c_str();

  // Create converter between internal and literal encoding specified
  // in fexec-charset option.
  if (TE.LiteralEncoding == UTF8)
    return std::error_code();
  ErrorOr<TextEncodingConverter> ErrorOrConverter =
      llvm::TextEncodingConverter::create(UTF8, TE.LiteralEncoding);
  if (ErrorOrConverter)
    TE.ToLiteralEncodingConverter =
        std::make_unique<TextEncodingConverter>(std::move(*ErrorOrConverter));
  else
    return ErrorOrConverter.getError();
  return std::error_code();
}

std::error_code
TextEncoding::setInputConverterFromOptions(TextEncoding &TE,
                                           const clang::LangOptions &Opts) {
  using namespace llvm;

  const char *UTF8 = "UTF-8";
  TE.InputEncoding =
      Opts.InputCharset.empty() ? UTF8 : Opts.InputCharset.c_str();
  if (TE.InputEncoding == UTF8)
    return std::error_code();
  ErrorOr<TextEncodingConverter> ErrorOrConverter =
      llvm::TextEncodingConverter::create(TE.InputEncoding, UTF8);
  if (!ErrorOrConverter)
    return ErrorOrConverter.getError();
  TE.FromInputEncodingConverter =
      std::make_unique<TextEncodingConverter>(std::move(*ErrorOrConverter));
  return std::error_code();
}
