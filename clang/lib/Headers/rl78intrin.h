/*===---- rl78intrin.h - RL78 intrinsics by their Renesas names ------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

/* The names under which the Renesas CC-RL compiler provides the RL78
   intrinsic functions, for sources written for it. */

#ifndef __RL78INTRIN_H
#define __RL78INTRIN_H

#ifndef __RL78__
#error "This header is only meant to be used on RL78"
#endif

#define __DI() __builtin_rl78_di()
#define __EI() __builtin_rl78_ei()
#define __halt() __builtin_rl78_halt()
#define __stop() __builtin_rl78_stop()
#define __brk() __builtin_rl78_brk()
#define __nop() __builtin_rl78_nop()

#define __get_psw() __builtin_rl78_getpsw()
#define __set_psw(x) __builtin_rl78_setpsw(x)

#define __set1(p, b) __builtin_rl78_set1((p), (b))
#define __clr1(p, b) __builtin_rl78_clr1((p), (b))
#define __not1(p, b) __builtin_rl78_not1((p), (b))

#define __rolb(x, y) __builtin_rl78_rolb((x), (y))
#define __rorb(x, y) __builtin_rl78_rorb((x), (y))
#define __rolw(x, y) __builtin_rl78_rolw((x), (y))
#define __rorw(x, y) __builtin_rl78_rorw((x), (y))

#define __mulu(x, y) __builtin_rl78_mulu((x), (y))
#define __mului(x, y) __builtin_rl78_mului((x), (y))
#define __mulsi(x, y) __builtin_rl78_mulsi((x), (y))
#define __mulul(x, y) __builtin_rl78_mulul((x), (y))
#define __mulsl(x, y) __builtin_rl78_mulsl((x), (y))
#define __divui(x, y) __builtin_rl78_divui((x), (y))
#define __divul(x, y) __builtin_rl78_divul((x), (y))
#define __remui(x, y) __builtin_rl78_remui((x), (y))
#define __remul(x, y) __builtin_rl78_remul((x), (y))
#define __macui(x, y, z) __builtin_rl78_macui((x), (y), (z))
#define __macsi(x, y, z) __builtin_rl78_macsi((x), (y), (z))

#define __delay_cycles(n) __builtin_rl78_delay_cycles(n)

#endif /* __RL78INTRIN_H */
