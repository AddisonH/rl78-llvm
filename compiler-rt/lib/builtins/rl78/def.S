//===-- def.S - Define common values --------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifdef __RL78_S3__
    #define _RL78_S3 1
    #define _XMAC 0
    #define _XMULDIV 0
    #define _XMUL 0
    #define MACRH 0xFFFF2
    #define MACRL 0xFFFF0
#else
    #define _RL78_S3 0
    #ifdef  __MDA_ENABLED__
        #define _XMAC 1
        #define _XMULDIV 1
        #define _XMUL 1
        #define MDAL 0xFFFF0
        #define MDAH 0xFFFF2
        #define MDBL 0xFFFF6
        #define MDBH 0xFFFF4
        #define MDCL 0xF00E0
        #define MDCH 0xF00E2
        #define MDUC 0xF00E8
    #else
        #define _XMAC 0
        #ifdef  XMULDIV
            #define _XMULDIV 1
            #define _XMUL 1
        #else
            #define _XMULDIV 0
            #ifdef  XMUL
                #define _XMUL 1
            #else
                #define _XMUL 0
            #endif
        #endif
    #endif
#endif

#ifdef DBL4
    #define _DBL4 1
#else
    #define _DBL4 0
#endif