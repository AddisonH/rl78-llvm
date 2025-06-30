//===-- RL78InsertNOPWithLabel.h - Insert NOP with label for RL78 ---------===//

//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RL78_RL78INSERTNOPWITHLABEL_H
#define LLVM_LIB_TARGET_RL78_RL78INSERTNOPWITHLABEL_H

#include "llvm/Support/CommandLine.h"
#include <string>
#include <vector>

extern llvm::cl::list<std::string> InsertNOPWithLabel;

#endif
