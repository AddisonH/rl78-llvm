//===- RL78.cpp -----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "RelocScan.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/TimeProfiler.h"
#include <stack>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace lld;
using namespace lld::elf;

RL78PltSection::RL78PltSection(Ctx &ctx) : PltSection(ctx) {
  name = ".lowtext";
  addralign = 2;
}

// Removes the entries of functions that ended up in the lower 64 KiB of ROM:
// they are reachable with a near address and need no trampoline.
bool RL78PltSection::updateAllocSize(Ctx &ctx) {
  llvm::DenseSet<std::pair<uint64_t, StringRef>> seen;
  size_t numSyms = 0;
  for (const Symbol *sym : entries) {
    // Ignore any possible duplicates.
    if (!seen.insert({sym->getVA(ctx), sym->getName()}).second)
      continue;
    if (!(sym->getVA(ctx) >> 16)) {
      ctx.symAux[sym->auxIdx].pltIdx = -1;
      continue;
    }
    ctx.symAux[sym->auxIdx].pltIdx = numSyms;
    entries[numSyms++] = sym;
  }
  if (numSyms == entries.size())
    return false;
  entries.resize(numSyms);
  return true;
}

RL78CalltSection::RL78CalltSection(Ctx &ctx)
    : SyntheticSection(ctx, ".callt0", SHT_PROGBITS, SHF_ALLOC, 2) {}

const MapVector<RL78CalltSection::Target, unsigned> &
RL78CalltSection::getEntries() const {
  if (selected)
    return entries;
  selected = true;

  // The table has 32 entries; the input files' own entries come first.
  size_t used = 0;
  for (InputSectionBase *sec : ctx.inputSections)
    if (sec != this && sec->isLive() && sec->name == ".callt0")
      used += sec->getSize();
  size_t numFree = used < 64 ? (64 - used) / 2 : 0;

  // An entry pays for itself from the third call on.
  SmallVector<std::pair<Target, unsigned>, 0> candidates;
  for (const auto &[target, count] : calls) {
    auto *d = dyn_cast<Defined>(target.first);
    if (count < 3 || !d || !d->section || !(d->section->flags & SHF_EXECINSTR))
      continue;
    candidates.push_back({target, count});
  }
  llvm::stable_sort(candidates, [](const auto &a, const auto &b) {
    return a.second > b.second;
  });
  if (candidates.size() > numFree)
    candidates.resize(numFree);
  for (const auto &c : candidates)
    entries.insert({c.first, entries.size()});
  return entries;
}

uint64_t RL78CalltSection::getEntryVA(const Symbol &sym, int64_t addend) const {
  auto it = getEntries().find({&sym, addend});
  if (it == entries.end() || !getParent())
    return 0;
  uint64_t va = getVA() + it->second * 2;
  return va >= 0x80 && va <= 0xBE && va % 2 == 0 ? va : 0;
}

void RL78CalltSection::writeTo(uint8_t *buf) {
  for (const auto &[target, index] : getEntries())
    write16le(buf + index * 2, target.first->getVA(ctx, target.second));
}

namespace {
class RL78 final : public TargetInfo {
public:
  RL78(Ctx &);
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  template <class ELFT, class RelTy>
  void scanSectionImpl(InputSectionBase &sec, Relocs<RelTy> rels,
                       unsigned shard);
  void scanSection(InputSectionBase &sec, unsigned shard) override {
    elf::scanSection1<RL78, ELF32LE>(*this, sec, shard);
  }
  void writePlt(uint8_t *buf, const Symbol &sym,
                uint64_t pltEntryAddr) const override;
  void relocate(uint8_t *loc, const Relocation &rel,
                uint64_t val) const override;
  void relocateAlloc(InputSection &sec, uint8_t *buf) const override;
  bool relaxOnce(int pass) const override;
  void finalizeRelax(int passes) const override;

private:
  bool needsPltEntry(const Symbol &sym, RelType type) const;
  uint64_t checkAndPop(uint8_t *loc, const Relocation &rel, char bitSize = 0,
                       bool isSigned = false, uint64_t adj = 0) const;
  void push(uint64_t value) const;
};
} // namespace

// The CC-RL operator relocations (R_RL78_SYM, R_RL78_OP*, R_RL78_ABS*)
// evaluate an expression on a stack. A sequence never spans input sections, but
// sections are relocated in parallel, so each thread has its own stack.
static thread_local std::stack<uint64_t> relocationStack;

RL78::RL78(Ctx &ctx) : TargetInfo(ctx) { pltEntrySize = 4; }

static uint32_t getEFlags(InputFile *file) {
  return cast<ObjFile<ELF32LE>>(file)->getObj().getHeader().e_flags;
}

static bool mergeFlags(Ctx &ctx, uint32_t &mergedFlags, uint32_t newFlags,
                       unsigned flag, const char *msg, InputFile *f) {
  if ((mergedFlags & flag) == 0) { // The merged flag is common.
    mergedFlags |= (newFlags & flag);
    return true;
  }
  if ((newFlags & flag) == 0) // The new flag is common.
    return true;
  if ((mergedFlags & flag) != (newFlags & flag)) { // Both set, different.
    Err(ctx) << msg << f;
    return false;
  }
  return true;
}

uint32_t RL78::calcEFlags() const {
  assert(!ctx.objectFiles.empty());
  uint32_t mergedFlags = getEFlags(ctx.objectFiles[0]);
  bool mergeSucceeded = true;
  // Verify that all input files have compatible flags.
  for (InputFile *f : ArrayRef(ctx.objectFiles).slice(1)) {
    uint32_t newFlags = getEFlags(f);
    if (mergedFlags == newFlags)
      continue;

    mergedFlags |= (newFlags & EF_RL78_FU_EXIST);
    mergedFlags |= (newFlags & EF_RL78_EI_EXIST);

    mergeSucceeded &= mergeFlags(ctx, mergedFlags, newFlags, EF_RL78_MAA_1,
                                 "incompatible MAA flags: ", f);

    if ((mergedFlags & EF_RL78_CPU_16BIT) == 0) {
      if ((newFlags & EF_RL78_CPU_16BIT) == 0) {
        Err(ctx) << "CPU flag can't be set to common for both input files: "
                 << f;
        mergeSucceeded = false;
      } else {
        mergedFlags |= (newFlags & EF_RL78_CPU_16BIT);
      }
    } else if ((newFlags & EF_RL78_CPU_16BIT) != 0 &&
               (mergedFlags & EF_RL78_CPU_16BIT) !=
                   (newFlags & EF_RL78_CPU_16BIT)) {
      Err(ctx) << "incompatible CPU flags: " << f;
      mergeSucceeded = false;
    }

    // TODO change to size 8 if force option is specified
    mergeSucceeded &= mergeFlags(ctx, mergedFlags, newFlags, EF_RL78_DOUBLE_8,
                                 "incompatible double type size flags: ", f);

    // TODO change to far if force option is specified
    mergeSucceeded &= mergeFlags(ctx, mergedFlags, newFlags, EF_RL78_TEXT_FAR,
                                 "incompatible text area flags: ", f);

    // TODO change to far if force option is specified
    mergeSucceeded &= mergeFlags(ctx, mergedFlags, newFlags, EF_RL78_DATA_FAR,
                                 "incompatible data area flags: ", f);

    if ((mergedFlags & EF_RL78_RODATA_FAR) == 0) {
      mergedFlags |= (newFlags & EF_RL78_RODATA_FAR);
    } else if ((newFlags & EF_RL78_RODATA_FAR) != 0 &&
               (mergedFlags & EF_RL78_RODATA_FAR) !=
                   (newFlags & EF_RL78_RODATA_FAR)) {
      Warn(ctx) << "incompatible rodata area flags, changed to far:  " << f;
      mergedFlags |= (newFlags & EF_RL78_RODATA_FAR);
    }
  }
  return mergeSucceeded ? mergedFlags : 0;
}

static RelExpr getRelExpr(Ctx &ctx, RelType type) {
  switch (type) {
  case R_RL78_DIR8S_PCREL:
  case R_RL78_DIR16S_PCREL:
  case R_RL78_ABS8S_PCREL:
  case R_RL78_ABS16S_PCREL:
    return R_PC;
  case R_RL78_RELAX:
    return ctx.arg.relax ? R_RELAX_HINT : R_NONE;
  default:
    return R_ABS;
  }
}

RelExpr RL78::getRelExpr(RelType type, const Symbol &s,
                         const uint8_t *loc) const {
  return ::getRelExpr(ctx, type);
}

// Near (16-bit) references to code need a PLT entry (a trampoline in the low
// 64 KiB) when the function ends up above 64 KiB. Every candidate gets an
// entry here; RL78PltSection::updateAllocSize drops the unneeded ones once
// addresses are known.
bool RL78::needsPltEntry(const Symbol &sym, RelType type) const {
  if (!(sym.hasNoType() || sym.isFunc() || sym.isSection()))
    return false;
  OutputSection *osec = sym.getOutputSection();
  if (!osec || !(osec->flags & SHF_EXECINSTR) || sym.isInPlt(ctx))
    return false;
  if (type == R_RL78_DIR16U)
    return true;
  // With far code, LOWW() of a function is one half of its far address;
  // only the plain 16-bit reference is a near pointer to it.
  if (ctx.arg.rl78FarCode)
    return false;
  // FIXME: Is there a better way to handle test in ticket_2677?
  return type == R_RL78_OPlowW &&
         (!sym.isDefined() ||
          cast<Defined>(sym).section->name.starts_with(".text"));
}

template <class ELFT, class RelTy>
void RL78::scanSectionImpl(InputSectionBase &sec, Relocs<RelTy> rels,
                           unsigned shard) {
  RelocScan rs(ctx, &sec, shard);
  sec.relocations.reserve(rels.size());
  for (auto it = rels.begin(); it != rels.end(); ++it) {
    RelType type = it->getType(false);
    // R_RL78_NONE, and R_RL78_RELAX with --no-relax.
    if (::getRelExpr(ctx, type) == R_NONE)
      continue;
    // Relocation scanning is serial for RL78 (see scanRelocations), so the PLT
    // can be modified here.
    Symbol &sym = sec.getFile<ELFT>()->getSymbol(it->getSymbol(false));
    if (needsPltEntry(sym, type)) {
      sym.allocateAux(ctx);
      ctx.in.plt->addEntry(sym);
    }
    int64_t addend = rs.getAddend<ELFT>(*it, type);
    // A relaxable call !!addr20 or call !addr16 is a candidate for CALLT.
    if (ctx.in.rl78Callt && (sec.flags & SHF_EXECINSTR) && it->r_offset &&
        std::next(it) != rels.end() &&
        std::next(it)->getType(false) == R_RL78_RELAX) {
      uint8_t opc = sec.content()[it->r_offset - 1];
      if ((type == R_RL78_DIR20U && opc == 0xFC) ||
          (type == R_RL78_DIR16U && opc == 0xFD))
        ctx.in.rl78Callt->addCall(sym, addend);
    }
    rs.scan<ELFT, RelTy>(it, type, addend);
  }
}

void RL78::writePlt(uint8_t *buf, const Symbol &sym,
                    uint64_t pltEntryAddr) const {
  // br !!addr20
  write32le(buf, 0x000000EC | ((sym.getVA(ctx) & 0xFFFFF) << 8));
}

static void write3le(void *p, uint8_t v) {
  write<uint8_t, llvm::endianness::little>(
      p, (read<uint8_t, llvm::endianness::little>(p) & 0x8f) | ((v & 0x7) << 4));
}

static void write8le(void *p, uint8_t v) {
  write<uint8_t, llvm::endianness::little>(p, v);
}

static void write24le(void *p, uint64_t v) {
  write32le(p, (read32le(p) & 0xff00'0000) | (v & ~0xff00'0000));
}

// True if the call at r can be a CALLT: its target has a table entry and is
// in the low 64 KiB, which is all a table entry can hold.
static bool relaxToCallt(Ctx &ctx, const Relocation &r, uint64_t tgtVA) {
  return ctx.in.rl78Callt && isUInt<16>(tgtVA) &&
         ctx.in.rl78Callt->getEntryVA(*r.sym, r.addend);
}

// The relocation's target address, ignoring any PLT entry.
static uint64_t getTargetVA(Ctx &ctx, const InputSection &sec,
                            const Relocation &r, uint64_t loc) {
  return sec.getRelocTargetVA(
      ctx, Relocation{R_ABS, r.type, r.offset, r.addend, r.sym}, loc);
}

// \p prevRemove is what the previous pass removed at this relocation.
static void relaxDIR20U(Ctx &ctx, const InputSection &sec, size_t i,
                        uint64_t loc, Relocation &r, uint32_t prevRemove,
                        uint32_t &remove) {
  // Handle only br/call !!addr20.
  const auto opc = sec.content().data()[r.offset - 1];
  if (opc != 0xEC && opc != 0xFC)
    return;

  // Note that 'loc' is the VA of the relocation (= brVA + 1).
  const auto brVA = loc - 1;
  const auto tgtVA = getTargetVA(ctx, sec, r, loc);

  // If the branch target is in the same input section after the branch,
  // relaxing the branch will affect its address; if we don't consider this we
  // fail to relax some branches that are just "at the boundary" e.g. at +127
  // bytes (max. 8-bit signed value). The target's address is the one the
  // previous pass left, so what that pass removed here is in it already.
  const auto adjTgtVA = isa<Defined>(r.sym) &&
                        cast<Defined>(r.sym)->section == &sec && tgtVA > brVA;
  auto tgtMoves = [&](int64_t n) {
    return adjTgtVA ? n - int64_t(prevRemove) : 0;
  };

  // Relative distance between the instructions.
  const auto deltaVA = int64_t(tgtVA - brVA);

  // For branches, try first to relax to br $addr20. PC will be brVA+2 when
  // relaxing to 2 bytes, and an adjusted tgtVA will be at -2.
  const auto disp8 = (deltaVA - 2) - tgtMoves(2);
  if (opc == 0xEC && isInt<8>(disp8)) {
    sec.relaxAux->relocTypes[i] = R_RL78_DIR8S_PCREL;
    sec.relaxAux->writes.push_back(0xEF); // BR $addr20.
    remove = 2;
    return;
  }

  // Then, try callt [addr5].
  if (opc == 0xFC && relaxToCallt(ctx, r, tgtVA)) {
    sec.relaxAux->relocTypes[i] = R_RL78_DIR_CALLT;
    remove = 2;
    return;
  }

  // Then, try br/call !addr16.
  if (isUInt<16>(tgtVA)) {
    sec.relaxAux->relocTypes[i] = R_RL78_DIR16U;
    sec.relaxAux->writes.push_back(opc + 1); // I.e. 0xED and 0xFD, resp.
    remove = 1;
    return;
  }

  // Lastly, try br/call $!addr20. PC will be brVA+3 when relaxing to 3 bytes,
  // and an adjusted tgtVA will be at -1.
  const auto disp16 = (deltaVA - 3) - tgtMoves(1);
  if (isInt<16>(disp16)) {
    sec.relaxAux->relocTypes[i] = R_RL78_DIR16S_PCREL;
    sec.relaxAux->writes.push_back(opc + 2); // I.e. 0xEE and 0xFE, resp.
    remove = 1;
  }
}

template <bool PCRel>
static void relaxDIR16(Ctx &ctx, const InputSection &sec, size_t i,
                       uint64_t loc, Relocation &r, uint32_t prevRemove,
                       uint32_t &remove) {
  // Handle only the branches:
  //   br !addr16   (PCRel = false)
  //   br $!addr20  (PCRel = true)
  // and call !addr16, which can become callt [addr5]; call $!addr20 cannot be
  // relaxed further.
  const auto opc = sec.content().data()[r.offset - 1];
  if (!PCRel && opc == 0xFD) {
    if (relaxToCallt(ctx, r, getTargetVA(ctx, sec, r, loc))) {
      sec.relaxAux->relocTypes[i] = R_RL78_DIR_CALLT;
      remove = 1;
    }
    return;
  }
  if (opc != (PCRel ? 0xEE : 0xED))
    return;

  // Note that 'loc' is the VA of the relocation (= brVA + 1).
  const auto brVA = loc - 1;
  const auto tgtVA = getTargetVA(ctx, sec, r, loc);

  // See relaxDIR20U.
  const auto adjTgtVA = isa<Defined>(r.sym) &&
                        cast<Defined>(r.sym)->section == &sec && tgtVA > brVA;

  // Relative distance between the instructions.
  const auto deltaVA = int64_t(tgtVA - brVA);

  // PC will be brVA+2 when relaxing to 2 bytes, and an adjusted tgtVA will be
  // at -1.
  const auto disp8 = (deltaVA - 2) - (adjTgtVA ? 1 - int64_t(prevRemove) : 0);
  if (isInt<8>(disp8)) {
    sec.relaxAux->relocTypes[i] = R_RL78_DIR8S_PCREL;
    sec.relaxAux->writes.push_back(0xEF); // BR $addr20.
    remove = 1;
  }
}

static bool relax(Ctx &ctx, InputSection &sec) {
  if (sec.relocs().empty())
    return false;

  const uint64_t secAddr = sec.getVA();
  auto &aux = *sec.relaxAux;
  bool changed = false;

  ArrayRef<SymbolAnchor> sa = aux.anchors;
  uint64_t delta = 0;
  uint32_t prevDelta = 0;

  auto updateAnchor = [&](const SymbolAnchor &a) {
    if (a.end)
      a.d->size = a.offset - delta - a.d->value;
    else
      a.d->value = a.offset - delta;
  };

  std::fill_n(aux.relocTypes.get(), sec.relocs().size(), R_RL78_NONE);
  aux.writes.clear();

  for (auto [i, r] : llvm::enumerate(sec.relocs())) {
    const uint64_t loc = secAddr + r.offset - delta;
    uint32_t &cur = aux.relocDeltas[i], remove = 0;
    const uint32_t prevRemove = cur - prevDelta;
    prevDelta = cur;
    const bool relaxable = i + 1 != sec.relocs().size() &&
                           sec.relocs()[i + 1].type == R_RL78_RELAX;

    if (relaxable) {
      switch (r.type) {
      case R_RL78_DIR20U:
        relaxDIR20U(ctx, sec, i, loc, r, prevRemove, remove);
        break;
      case R_RL78_DIR16U:
        relaxDIR16<false>(ctx, sec, i, loc, r, prevRemove, remove);
        break;
      case R_RL78_DIR16S_PCREL:
        relaxDIR16<true>(ctx, sec, i, loc, r, prevRemove, remove);
        break;
      default:
        break;
      }
    }

    // For all anchors whose offsets are <= r.offset, they are preceded by
    // the previous relocation whose `relocDeltas` value equals `delta`.
    // Decrease their st_value and update their st_size.
    for (; sa.size() && sa[0].offset <= r.offset; sa = sa.slice(1))
      updateAnchor(sa[0]);

    delta += remove;
    if (delta != cur) {
      cur = delta;
      changed = true;
    }
  }

  for (const auto &a : sa)
    updateAnchor(a);

  sec.bytesDropped = delta;
  return changed;
}

bool RL78::relaxOnce(int pass) const {
  if (!ctx.arg.relax)
    return false;

  llvm::TimeTraceScope timeScope("RL78 relaxOnce");
  if (pass == 0)
    initSymbolAnchors(ctx);

  SmallVector<InputSection *, 0> storage;
  bool changed = false;
  for (OutputSection *osec : ctx.outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;
    for (InputSection *sec : getInputSections(*osec, storage))
      if (sec->relaxAux)
        changed |= relax(ctx, *sec);
  }
  return changed;
}

void RL78::finalizeRelax(int passes) const {
  if (!ctx.arg.relax)
    return;

  llvm::TimeTraceScope timeScope("Finalize RL78 relaxation");
  Log(ctx) << "relaxation passes: " << passes;
  SmallVector<InputSection *, 0> storage;

  for (OutputSection *osec : ctx.outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;

    for (InputSection *sec : getInputSections(*osec, storage)) {
      if (!sec->relaxAux)
        continue;
      RelaxAux &aux = *sec->relaxAux;
      if (!aux.relocDeltas)
        continue;

      MutableArrayRef<Relocation> rels = sec->relocs();
      ArrayRef<uint8_t> old = sec->content();
      size_t newSize = old.size() - aux.relocDeltas[rels.size() - 1];
      size_t writesIdx = 0;
      uint8_t *p = ctx.bAlloc.Allocate<uint8_t>(newSize);
      uint64_t offset = 0;
      int64_t delta = 0;
      sec->content_ = p;
      sec->size = newSize;
      sec->bytesDropped = 0;

      for (size_t i = 0, e = rels.size(); i != e; ++i) {
        uint32_t remove = aux.relocDeltas[i] - delta;
        delta = aux.relocDeltas[i];
        if (remove == 0 && aux.relocTypes[i] == R_RL78_NONE)
          continue;

        // Copy from last location to the current relocated location.
        const Relocation &r = rels[i];
        uint64_t size = r.offset - offset;
        memcpy(p, old.data() + offset, size);
        p += size;

        int64_t skip = 0;
        if (RelType newType = aux.relocTypes[i]) {
          switch (newType) {
          case R_RL78_DIR16U:
          case R_RL78_DIR16S_PCREL:
            write24le(p - 1, aux.writes[writesIdx++]);
            skip = 2;
            break;
          case R_RL78_DIR8S_PCREL:
            write16le(p - 1, aux.writes[writesIdx++]);
            skip = 1;
            break;
          case R_RL78_DIR_CALLT:
            // callt [addr5]; relocateAlloc fills in the table entry.
            write16le(p - 1, 0x8461);
            skip = 1;
            break;
          default:
            llvm_unreachable("unsupported type");
          }
        }

        p += skip;
        offset = r.offset + skip + remove;
      }

      memcpy(p, old.data() + offset, old.size() - offset);

      // Adjust the relocation offsets.
      delta = 0;
      for (size_t i = 0, e = rels.size(); i != e;) {
        uint64_t cur = rels[i].offset;
        do {
          rels[i].offset -= delta;
          if (aux.relocTypes[i] != R_RL78_NONE) {
            rels[i].type = aux.relocTypes[i];
            rels[i].expr = ::getRelExpr(ctx, rels[i].type);
          }
        } while (++i != e && rels[i].offset == cur);
        delta = aux.relocDeltas[i - 1];
      }
    }
  }
}

static uint64_t checkAndConvertMirrorAddr(Ctx &ctx, uint8_t *loc,
                                          const Relocation &rel, uint64_t val,
                                          bool allowOutOfRange = false) {
  // clang-format off
  /*
  RL78-S1 core
    MAA = 0: Mirror data in addresses 00000H to 05EFFH to addresses F8000H to FDEFFH.
    MAA = 1: Setting prohibited.
  RL78-S2 core
    MAA = 0: Mirror data in addresses 00000H to 0FFFFH to addresses F0000H to FFFFFH.
    MAA = 1: Mirror data in addresses 10000H to 1FFFFH to addresses F0000H to FFFFFH.
  RL78-S3 core
    MAA = 0: Mirror data in addresses 00000H to 0FFFFH to addresses F0000H to FFFFFH.
    MAA = 1: Mirror data in addresses 10000H to 1FFFFH to addresses F0000H to FFFFFH.
  */
  // clang-format on

  uint32_t maaFlag = ctx.arg.eflags & EF_RL78_MAA_1;
  MemoryRegion *mirrorRegion = ctx.script->memoryRegions.lookup("MIRROR");
  if (!mirrorRegion) {
    Err(ctx) << getErrorLoc(ctx, loc) << "memory region 'MIRROR' not declared";
    return 0;
  }

  // Get FLASH MEMORY start/end address.
  uint32_t start = mirrorRegion->getOrigin() & 0xFFFF;
  uint32_t end = start + mirrorRegion->getLength();

  if (!maaFlag) {
    // We need to know if the maaFlag was correct beforehand.
    Err(ctx) << getErrorLoc(ctx, loc) << "relocation " << rel.type
             << " is invalid when MAA mode flag in ELF is set to common!";
    return 0;
  }

  if (maaFlag == EF_RL78_MAA_1) {
    start += 0x10000;
    end += 0x10000;
  }

  if (!(mirrorRegion->getOrigin() & 0xF0000) ||
      mirrorRegion->getOrigin() < end) {
    Err(ctx) << getErrorLoc(ctx, loc)
             << "memory region 'MIRROR' is not in a correct location";
    return 0;
  }

  // Get addend needed to put the the address in MIRROR.
  uint32_t correction = mirrorRegion->getOrigin() - start;

  if (val >= start && val <= end)
    return val + correction;
  // Return it unchanged, used for R_RL78_OPmir.
  if (allowOutOfRange)
    return val;
  Err(ctx) << getErrorLoc(ctx, loc) << "relocation " << rel.type
           << " out of MIRROR range: " << Twine::utohexstr(val)
           << " is not in [" << Twine::utohexstr(start) << ", "
           << Twine::utohexstr(end) << "]";
  return 0;
}

static uint8_t checkAndConvertSAddr(Ctx &ctx, uint8_t *loc,
                                    const Relocation &rel, uint64_t val) {
  uint32_t max1 = 0xff1f;
  uint32_t min1 = 0xfe20;
  uint32_t max2 = 0xfff1f;
  uint32_t min2 = 0xffe20;
  if ((val >= min1 && val <= max1) || (val >= min2 && val <= max2))
    return val;
  Err(ctx) << getErrorLoc(ctx, loc) << "relocation " << rel.type
           << " out of SADDR(P) range: " << val << " is not in ["
           << Twine::utohexstr(min1) << ", " << Twine::utohexstr(max1)
           << "] or [" << Twine::utohexstr(min2) << ", "
           << Twine::utohexstr(max2) << "]";
  return 0;
}

static uint16_t checkAndConvertRAM(Ctx &ctx, uint8_t *loc,
                                   const Relocation &rel, uint64_t val) {
  MemoryRegion *ramRegion = ctx.script->memoryRegions.lookup("RAM");
  if (!ramRegion) {
    Err(ctx) << getErrorLoc(ctx, loc) << "memory region 'RAM' not declared";
    return 0;
  }
  uint32_t start = ramRegion->getOrigin();
  uint32_t end = start + ramRegion->getLength();

  if (val >= start && val <= end)
    return val;
  Err(ctx) << getErrorLoc(ctx, loc) << "relocation " << rel.type
           << " out of RAM range: " << Twine::utohexstr(val) << " is not in ["
           << Twine::utohexstr(start) << ", " << Twine::utohexstr(end) << "]";
  return 0;
}

uint64_t RL78::checkAndPop(uint8_t *loc, const Relocation &rel, char bitSize,
                           bool isSigned, uint64_t adj) const {
  if (relocationStack.empty()) {
    Err(ctx) << getErrorLoc(ctx, loc) << "relocation " << rel.type
             << " is invalid: linker relocation stack is empty, nothing to "
                "pop!";
    return 0;
  }
  uint64_t t = relocationStack.top() - adj;
  if (bitSize > 0) {
    if (isSigned)
      checkInt(ctx, loc, t, bitSize, rel);
    else
      checkUInt(ctx, loc, t, bitSize, rel);
  }
  relocationStack.pop();
  return t;
}

void RL78::push(uint64_t value) const { relocationStack.push(value); }

void RL78::relocate(uint8_t *loc, const Relocation &rel, uint64_t val) const {
  // TODO Not sure if zero refers to boot cluster 0?
  // also if these addresses are target specific?
  uint32_t zeroCALLTST = 0x00080;
  uint32_t CALLTST = 0x01080;

  switch (rel.type) {
  case R_RL78_DIR3U:
    checkUInt(ctx, loc, val, 3, rel);
    write3le(loc, val);
    break;
  case R_RL78_DIR8U:
    checkUInt(ctx, loc, val, 8, rel);
    write8le(loc, val);
    break;
  case R_RL78_DIR16U:
    // checkUInt(ctx, loc, val, 16, rel); - temporary revert
    write16le(loc, val);
    break;
  case R_RL78_DIR20U:
    checkUInt(ctx, loc, val, 20, rel);
    write24le(loc, val);
    break;
  case R_RL78_DIR20U_16:
    checkUInt(ctx, loc, val, 20, rel);
    write16le(loc, val);
    break;
  case R_RL78_DIR20UW_16:
    checkUInt(ctx, loc, val, 20, rel);
    write16le(loc, val & 0xfffe);
    break;
  case R_RL78_DIR32U:
    checkUInt(ctx, loc, val, 32, rel);
    write32le(loc, val);
    break;
  case R_RL78_DIR8U_MIR:
    write8le(loc, checkAndConvertMirrorAddr(ctx, loc, rel, val));
    break;
  case R_RL78_DIR16U_MIR:
    write16le(loc, checkAndConvertMirrorAddr(ctx, loc, rel, val));
    break;
  case R_RL78_DIR16UW_MIR:
    write16le(loc, checkAndConvertMirrorAddr(ctx, loc, rel, val) & 0xfffe);
    break;
  case R_RL78_DIR8U_SAD:
    write8le(loc, checkAndConvertSAddr(ctx, loc, rel, val) & 0xff);
    break;
  case R_RL78_DIR8UW_SAD:
    write8le(loc, checkAndConvertSAddr(ctx, loc, rel, val) & 0xfe);
    break;
  case R_RL78_DIR16U_RAM:
    write16le(loc, checkAndConvertRAM(ctx, loc, rel, val) & 0xffff);
    break;
  case R_RL78_DIR16UW_RAM:
    write16le(loc, checkAndConvertRAM(ctx, loc, rel, val) & 0xfffe);
    break;
  case R_RL78_DIR8S_PCREL:
    checkInt(ctx, loc, val - 1, 8, rel);
    write8le(loc, val - 1);
    break;
  case R_RL78_DIR16S_PCREL:
    checkIntUInt(ctx, loc, val - 2, 16, rel);
    write16le(loc, val - 2);
    break;
  case R_RL78_DIR_CALLT:
    write8le(loc, ((((val - zeroCALLTST) & 0x30) >> 4) +
                   (((val - CALLTST) & 0x0e) << 3)) |
                      0x84);
    break;
  case R_RL78_ABS3U:
    write3le(loc, checkAndPop(loc, rel, 3));
    break;
  case R_RL78_ABS8U:
    write8le(loc, checkAndPop(loc, rel, 8));
    break;
  case R_RL78_ABS8UW:
    write8le(loc, checkAndPop(loc, rel, 8) & 0xfe);
    break;
  case R_RL78_ABS16U:
    write16le(loc, checkAndPop(loc, rel, 16));
    break;
  case R_RL78_ABS16UW:
    write16le(loc, checkAndPop(loc, rel, 16) & 0xfffe);
    break;
  case R_RL78_ABS20U:
    write24le(loc, checkAndPop(loc, rel, 20));
    break;
  case R_RL78_ABS20U_16:
    write16le(loc, checkAndPop(loc, rel, 20));
    break;
  case R_RL78_ABS20UW_16:
    write16le(loc, checkAndPop(loc, rel, 20) & 0xfffe);
    break;
  case R_RL78_ABS32U:
    write32le(loc, checkAndPop(loc, rel, 32));
    break;
  case R_RL78_ABS8S_PCREL:
    write8le(loc, (checkAndPop(loc, rel, 8, true, val) - 1) & 0xff);
    break;
  case R_RL78_ABS16S_PCREL:
    write16le(loc, (checkAndPop(loc, rel, 16, true, val) - 2) & 0xffff);
    break;
  case R_RL78_ABS_CALLT: {
    uint64_t savedVal = checkAndPop(loc, rel);
    write8le(loc, ((((savedVal - zeroCALLTST) & 0x30) >> 4) +
                   (((savedVal - CALLTST) & 0x0e) << 3)) |
                      0x84);
    break;
  }
  case R_RL78_REF:
    break;
  case R_RL78_SYM:
    push(val);
    break;
  case R_RL78_SYM_MIR:
    push(checkAndConvertMirrorAddr(ctx, loc, rel, val));
    break;
  case R_RL78_OPadd: {
    uint64_t a = checkAndPop(loc, rel);
    uint64_t b = checkAndPop(loc, rel);
    push(a + b);
    break;
  }
  case R_RL78_OPsub: {
    uint64_t a = checkAndPop(loc, rel);
    uint64_t b = checkAndPop(loc, rel);
    push(b - a);
    break;
  }
  case R_RL78_OPsctsize:
  case R_RL78_OPscttop:
    push(val);
    break;
  case R_RL78_OPlowH:
    push((val & 0xFF00) >> 8);
    break;
  case R_RL78_OPlowL:
    push(val & 0xff);
    break;
  case R_RL78_OPhighW:
    push((val & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPlowW:
    // TODO currently we incorrectly use this for constant references too, it
    // should be R_RL78_OPlowW_MIR one possible solution to this might be at
    // ISelLowering::makeaddress, where we would insert a different node to
    // signal that it should be a constant access from the rom/mirror area
    push(val & 0xFFFF);
    break;
  case R_RL78_OPhighW_MIR:
    push((checkAndConvertMirrorAddr(ctx, loc, rel, val) & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPlowW_MIR:
    push(checkAndConvertMirrorAddr(ctx, loc, rel, val) & 0xFFFF);
    break;
  case R_RL78_OPlowW_SMIR: {
    // For absolute symbols the value of the addend is passed from
    // relocateAlloc(), so it will be 0 here to not add it twice. Otherwise we
    // get the addend here instead of taking it from relocateAlloc().
    uint64_t addend = 0;
    if (rel.sym && rel.sym->isDefined())
      addend = rel.addend;
    // Only after we converted the address to mirror we will add the addend.
    push((checkAndConvertMirrorAddr(ctx, loc, rel, val) + addend) & 0xFFFF);
    break;
  }
  case R_RL78_OPmir: {
    uint64_t t = checkAndPop(loc, rel);
    push(checkAndConvertMirrorAddr(ctx, loc, rel, t, true));
    break;
  }
  case R_RL78_OPABSlowH:
    push((checkAndPop(loc, rel) & 0xFF00) >> 8);
    break;
  case R_RL78_OPABSlowL:
    push(checkAndPop(loc, rel) & 0xFF);
    break;
  case R_RL78_OPABShighW:
    push((checkAndPop(loc, rel) & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPABSlowW:
    push(checkAndPop(loc, rel) & 0xFFFF);
    break;
  case R_RL78_RELAX:
    break;
  default:
    Err(ctx) << getErrorLoc(ctx, loc) << "unrecognized relocation "
             << rel.type;
  }
}

void RL78::relocateAlloc(InputSection &sec, uint8_t *buf) const {
  uint64_t secAddr = sec.getOutputSection()->addr + sec.outSecOff;
  for (const Relocation &rel : sec.relocs()) {
    uint8_t *loc = buf + rel.offset;
    Relocation r = rel;
    // For R_RL78_OPlowW_SMIR against a defined symbol the addend is applied
    // by relocate() after the address is converted to the mirror.
    if (rel.type == R_RL78_OPlowW_SMIR && rel.sym && rel.sym->isDefined())
      r.addend = 0;
    const uint64_t val = SignExtend64(
        sec.getRelocTargetVA(ctx, r, secAddr + rel.offset), 32);

    // Near references to a function with a PLT entry go through the entry.
    // R_RL78_DIR16U is used by 16-bit calls/branches. Function addresses in
    // data use R_RL78_OPlowW (as CC-RL does); R_RL78_OPhighW is included
    // because -mfar-data also uses the high part, and unlike -mfar-code it
    // has no option that turns the PLT off.
    // TODO: rename rl78FarCode to rl78DisablePlt and make it consider both
    //       -mfar-data and -mfar-code.
    if (rel.sym->isInPlt(ctx) &&
        (rel.type == R_RL78_DIR16U ||
         (!ctx.arg.rl78FarCode &&
          !(sec.getOutputSection()->flags & SHF_EXECINSTR) &&
          (rel.type == R_RL78_OPlowW || rel.type == R_RL78_OPhighW)))) {
      relocate(loc, rel, rel.sym->getPltVA(ctx));
      continue;
    }

    // A call relaxed to CALLT names the function, not its table entry.
    if (rel.type == R_RL78_DIR_CALLT && ctx.in.rl78Callt)
      if (uint64_t entryVA = ctx.in.rl78Callt->getEntryVA(*rel.sym, r.addend)) {
        relocate(loc, rel, entryVA);
        continue;
      }

    switch (rel.type) {
    case R_RL78_ABS8S_PCREL:
    case R_RL78_ABS16S_PCREL:
      relocate(loc, rel, secAddr + rel.offset);
      break;
    case R_RL78_OPsctsize: {
      auto *d = dyn_cast<Defined>(rel.sym);
      if (!d)
        Err(ctx) << getErrorLoc(ctx, loc) << " symbol " << rel.sym
                 << " is not defined!";
      else if (auto *isec = dyn_cast_or_null<InputSection>(d->section))
        relocate(loc, rel, isec->getOutputSection()->size);
      else
        Err(ctx) << getErrorLoc(ctx, loc) << " symbol " << rel.sym
                 << " is not a section symbol!";
      break;
    }
    default:
      relocate(loc, rel, val);
    }
  }
}

void elf::setRL78TargetInfo(Ctx &ctx) { ctx.target.reset(new RL78(ctx)); }
