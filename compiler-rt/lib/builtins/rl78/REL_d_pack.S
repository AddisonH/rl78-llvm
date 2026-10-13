//===-- REL_d_pack.S - Implement _REL_d_pack ------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements _REL_d_pack for the compiler_rt library: the rounding
// and packing of a double, see REL_d_pack.h.
//
//===----------------------------------------------------------------------===//

  #include "REL_d_pack.h"

  .file   "REL_d_pack.S"
  .extern __REL_d_inf

  .text

  .globl __REL_d_pack
  .type  __REL_d_pack,@function
__REL_d_pack:
  D_PACK 0, 1
.Lfunc_end1:
  .size __REL_d_pack, .Lfunc_end1-__REL_d_pack
