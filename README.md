# LLVM for RL78 (experimental fork)

This is a fork of [LLVM](https://github.com/llvm/llvm-project) with a backend
for the Renesas RL78 family of 8/16-bit microcontrollers: `llc`, `clang`,
`lld`, the assembler and the disassembler.

It starts from the source releases of Renesas' own *LLVM for Renesas RL78*
(based on LLVM 17.0.1, published at <https://llvm-gcc-renesas.com>), moves
them to LLVM 23.1.3, and then reworks the backend with one goal: an RL78
backend in the shape upstream LLVM would accept.

**This is not a Renesas product and not part of upstream LLVM.** It is a
personal, experimental project. Nothing here has been sent upstream. If you
need a supported RL78 compiler, use the Renesas release.

## Status

The compiler builds, and what it generates runs correctly on everything it is
tested with (below). It is not yet as good as the Renesas release at code
size: the instruction descriptions were rebuilt from the manual first, and
the tuning that used to hide their shortcomings is only now being redone on
top of the new model.

| Check | Result |
| --- | --- |
| RL78 lit tests (`llvm/test/CodeGen/RL78`, `MC/RL78`, `MC/Disassembler/RL78`) | all pass |
| Every encoding of the Software Manual, assembled and disassembled | 1,224 of 1,224 |
| GCC C torture, execution, near data (`-O0`, `-O2`, `-Os`) | 4,050 of 4,542 runs pass |
| GCC C torture, execution, far data (`-O0`, `-O2`) | 2,636 of 3,028 runs pass |
| CoreMark, `-O3` and `-Os` | correct CRCs |
| Embench, `-Os` | 17 programs run and verify their results |

The torture runs that do not pass are the same ones as before the backend was
reworked. Many need a 32-bit `int`, more memory than the simulated device
has, or something RL78 does not have; they have not all been looked at.

Programs are run on an instruction-level RL78 simulator written for this
project.

What is different from the Renesas 17.0.1 releases:

- **LLVM 23.1.3** instead of 17.0.1.
- **The instruction set is described once, in TableGen**
  (`RL78InstrISA.td`): every form of the RL78 Software Manual with its exact
  operand register classes and its encoding. The encoder, the disassembler
  and the assembler's matcher are generated from it; the hand-written ones
  are gone.
- **Code generation uses those definitions.** Instructions no longer claim
  to take any register and get repaired after register allocation: the
  accumulator (`A`/`AX`) and the other fixed registers are ordinary register
  classes that the allocator sees.
- **Core differences are subtarget features** (`reg-banks`, `muldiv`) instead
  of comparisons of the CPU name.
- **Debug information does not change the generated code** (`-g` and no `-g`
  give the same instructions).
- **Bugs fixed** that are also in the Renesas releases, among them wrong code
  for a 2-byte `memcmp`, for a 16-bit rotate left by 2 or 3, for a bit test
  feeding a select with far data, and for interrupt handlers and copies that
  use the multiply-accumulate register.
- **Upstream behaviour where the Renesas fork differed for compatibility with
  the CC-RL compiler**, for example incompatible pointer types are an error,
  as in upstream Clang.

## Branches

| Branch | What it is |
| --- | --- |
| `rl78-23-classes` | Current work: LLVM 23.1.3 with the rebuilt instruction model. Start here. |
| `rl78-23` | LLVM 23.1.3 port before the instruction model was rebuilt. Smaller code today, older design. |
| `rl78-17` | The Renesas 17.0.1 line plus early fixes. Frozen. |
| `vendor/renesas-17` | `llvmorg-17.0.1` plus one commit per Renesas source release, unmodified apart from line endings and packaging debris. Tags `renesas/17.0.1.YYYYMM`. |
| `main` | Upstream LLVM `main`, untouched. |

## Building

The usual LLVM build, with RL78 added to the targets:

```sh
cmake -S llvm -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86;RL78"
ninja -C build clang lld llc llvm-mc llvm-objdump FileCheck
```

Then:

```sh
build/bin/clang --target=rl78-unknown-elf -Os -S hello.c -o hello.s
build/bin/llvm-mc -triple=rl78 -show-encoding file.s
build/bin/llvm-objdump -d file.o
```

`-mcpu=s1`, `s2` or `s3` selects the core (default `s3`); `-mfar-code` and
`-mfar-data` select the memory models.

Linking a complete program also needs a C library and startup code built for
RL78 (newlib and libgloss in the Renesas toolchain). This repository does not
build them yet.

## Tests

```sh
build/bin/llvm-lit llvm/test/CodeGen/RL78 llvm/test/MC/RL78 \
                   llvm/test/MC/Disassembler/RL78
```

The tests live where upstream keeps them, next to those of the other targets:

- `llvm/test/CodeGen/RL78` for code generation,
- `llvm/test/MC/RL78` and `llvm/test/MC/Disassembler/RL78` for the assembler
  and disassembler, including a generated test for every encoding of the
  manual,
- `clang/test` and `lld/test/ELF` for the driver, the front end and the
  linker (files with `rl78` in the name).

Most code generation tests have their expectations written by
`llvm/utils/update_llc_test_checks.py`; after a change to code generation,
run it on the tests that fail and read the differences.

## Where things are

Everything specific to RL78 is in `llvm/lib/Target/RL78`:

| File | Contents |
| --- | --- |
| `RL78InstrISA.td` | The hardware instructions, as in the Software Manual, and the patterns that select them |
| `RL78InstrPseudo.td` | Instructions that only code generation uses (calls, selects, shifts by a register, ...) |
| `RL78InstrInfo.td` | SelectionDAG nodes, operands and predicates shared by the two |
| `RL78RegisterInfo.td` | Registers and the register classes the instruction set needs |
| `RL78ISelLowering.cpp`, `RL78ISelDAGToDAG.cpp` | Lowering and instruction selection |
| `RL78InstrInfo.cpp` | Copies, spills and the expansion of pseudos after register allocation |
| `MCTargetDesc`, `AsmParser`, `Disassembler` | Object files, fixups, the assembler and the disassembler |

Clang's part is in `clang/lib/Basic/Targets/RL78.*` and the driver; the
linker's in `lld/ELF/Arch/RL78.cpp`.

## License

The same as LLVM: Apache License 2.0 with LLVM Exceptions (see
`LICENSE.TXT`). The files of the Renesas source releases carry the same
license header.

For LLVM itself, see <https://llvm.org> and the
[upstream repository](https://github.com/llvm/llvm-project).
