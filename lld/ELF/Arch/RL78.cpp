//===- RL78.cpp
//------------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "SyntheticSections.h"
#include "OutputSections.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/TimeProfiler.h"
#include "llvm/Support/Format.h"
#include <stack>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace lld;
using namespace lld::elf;

RL78PltSection::RL78PltSection() {
  name = ".lowtext";
  addralign = 2;
}

void RL78PltSection::initAllocSize() {
  config->rl78InhibitAssert = true;
  script->assignAddresses();
}

// Used by RL78 to remove entries which don't require a PLT entry,
// i.e. are in the lower 64KB of ROM; this saves space.
bool RL78PltSection::updateAllocSize() {
  llvm::DenseSet<std::pair<uint64_t, StringRef>> Seen;
  size_t NumSyms = 0;
  for (auto sym : entries) {
    // Ignore any possible duplicates.
    if (!Seen.insert({sym->getVA(), sym->getName()}).second)
      continue;
    if (!(sym->getVA() >> 16)) {
      symAux[sym->auxIdx].pltIdx = -1;
      continue;
    }
    symAux[sym->auxIdx].pltIdx = NumSyms;
    entries[NumSyms++] = sym;
  }
  if (NumSyms == entries.size())
    return false;
  entries.resize(NumSyms);
  return true;
}

void RL78PltSection::finiAllocSize() {
  config->rl78InhibitAssert = false;
  script->assignAddresses();
}

namespace {
class RL78 final : public TargetInfo {
public:
  RL78();
  void relocate(uint8_t *loc, const Relocation &rel,
                uint64_t val) const override;
  void relocateAlloc(InputSectionBase &sec, uint8_t *buf) const override;
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType Type, const Symbol &S,
                     const uint8_t *loc) const override;
  void writePlt(uint8_t *buf, const Symbol &sym,
                uint64_t pltEntryAddr) const override;
  bool relaxOnce(int pass) const override;
private:
  std::stack<uint64_t> relocationStack;
  uint64_t checkAndPop(uint8_t *loc, const Relocation &rel, char bitSize = 0,
                       bool isSigned = false, uint64_t adj = 0) const;
  void push(uint8_t *loc, uint64_t Value) const;
  uint16_t checkAndConvertRAM(uint8_t *loc, const Relocation &rel,
                              uint64_t val) const;
};
} // namespace

RL78::RL78() { pltEntrySize = 4; }

namespace {
struct SymbolAnchor {
  uint64_t offset;
  Defined *d;
  bool end; // This is set for the anchor of st_value+st_size.
};
} // namespace

struct elf::RL78RelaxAux {
  // This records symbol start and end offsets which will be adjusted according
  // to the nearest relocDeltas element.
  SmallVector<SymbolAnchor, 0> anchors;
  // For relocations[i], the actual offset is r_offset - (i ? relocDeltas[i-1] :
  // 0).
  std::unique_ptr<uint32_t[]> relocDeltas;
  // For relocations[i], the actual type is relocTypes[i].
  std::unique_ptr<RelType[]> relocTypes;
  SmallVector<uint32_t, 0> writes;
};

static void initSymbolAnchors() {
  SmallVector<InputSection *, 0> storage;
  for (OutputSection *osec : outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;
    for (InputSection *sec : getInputSections(*osec, storage)) {
      sec->rl78RelaxAux = make<RL78RelaxAux>();
      if (sec->relocs().size()) {
        sec->rl78RelaxAux->relocDeltas =
            std::make_unique<uint32_t[]>(sec->relocs().size());
        sec->rl78RelaxAux->relocTypes =
            std::make_unique<RelType[]>(sec->relocs().size());
      }
    }
  }
  // Store anchors (st_value and st_value+st_size) for symbols relative to text
  // sections.
  //
  // For a defined symbol foo, we may have `d->file != file` with --wrap=foo.
  // We should process foo, as the defining object file's symbol table may not
  // contain foo after redirectSymbols changed the foo entry to __wrap_foo. To
  // avoid adding a Defined that is undefined in one object file, use
  // `!d->scriptDefined` to exclude symbols that are definitely not wrapped.
  //
  // `relaxAux->anchors` may contain duplicate symbols, but that is fine.
  for (InputFile *file : ctx.objectFiles)
    for (Symbol *sym : file->getSymbols()) {
      auto *d = dyn_cast<Defined>(sym);
      if (!d || (d->file != file && !d->scriptDefined) || d->isSection())
        continue;
      if (auto *sec = dyn_cast_or_null<InputSection>(d->section))
        if (sec->flags & SHF_EXECINSTR && sec->rl78RelaxAux) {
          // If sec is discarded, relaxAux will be nullptr.
          sec->rl78RelaxAux->anchors.push_back({d->value, d, false});
          if (d->size)
            sec->rl78RelaxAux->anchors.push_back({d->value + d->size, d, true});
        }
    }
  // Sort anchors by offset so that we can find the closest relocation
  // efficiently. For a zero size symbol, ensure that its start anchor precedes
  // its end anchor. For two symbols with anchors at the same offset, their
  // order does not matter.
  for (OutputSection *osec : outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;
    for (InputSection *sec : getInputSections(*osec, storage)) {
      llvm::sort(sec->rl78RelaxAux->anchors, [](auto &a, auto &b) {
        return std::make_pair(a.offset, a.end) <
               std::make_pair(b.offset, b.end);
      });
    }
  }
}

static uint32_t getEFlags(InputFile *file) {
  return cast<ObjFile<ELF32LE>>(file)->getObj().getHeader().e_flags;
}

static bool mergeFlags(uint32_t &mergedFlags, uint32_t newFlags, unsigned flag,
                       const Twine &msg, InputFile *f) {
  if ((mergedFlags & flag) == 0) { // if the merged flag is set to common
    mergedFlags |= (newFlags & flag);
    return true;
  } else if ((newFlags & flag) == 0) { // if the new flag is set to common
    return true;
  } else if ((mergedFlags & flag) !=
             (newFlags & flag)) { // if both are non-common and non-matching
    error(msg + toString(f));
    return false;
  } else {

    return true;
  }
}

uint32_t RL78::calcEFlags() const {
  assert(!ctx.objectFiles.empty());
  uint32_t mergedFlags = getEFlags(ctx.objectFiles[0]);
  bool mergeSucceeded = true;
  // Verify that all input files have compatible flags
  for (InputFile *f : ArrayRef(ctx.objectFiles).slice(1)) {
    uint32_t newFlags = getEFlags(f);
    if (mergedFlags == newFlags)
      continue;

    mergedFlags |= (newFlags & ELF::EF_RL78_FU_EXIST);
    mergedFlags |= (newFlags & ELF::EF_RL78_EI_EXIST);

    mergeSucceeded &= mergeFlags(mergedFlags, newFlags, ELF::EF_RL78_MAA_1,
                                 "incompatible MAA flags: ", f);

    if ((mergedFlags & ELF::EF_RL78_CPU_16BIT) == 0) {
      if ((newFlags & ELF::EF_RL78_CPU_16BIT) == 0) {
        error("CPU flag can't be set to common for both input files: " +
              toString(f));
        mergeSucceeded = false;
      } else {
        mergedFlags |= (newFlags & ELF::EF_RL78_CPU_16BIT);
      }
    } else if ((newFlags & ELF::EF_RL78_CPU_16BIT) != 0 &&
               (mergedFlags & ELF::EF_RL78_CPU_16BIT) !=
                   (newFlags & ELF::EF_RL78_CPU_16BIT)) {
      error("incompatible CPU flags: " + toString(f));
      mergeSucceeded = false;
    }

    // TODO change to size 8 if force option is specified
    mergeSucceeded &= mergeFlags(mergedFlags, newFlags, ELF::EF_RL78_DOUBLE_8,
                                 "incompatible double type size flags: ", f);

    // TODO change to far if force option is specified
    mergeSucceeded &= mergeFlags(mergedFlags, newFlags, ELF::EF_RL78_TEXT_FAR,
                                 "incompatible text area flags: ", f);

    // TODO change to far if force option is specified
    mergeSucceeded &= mergeFlags(mergedFlags, newFlags, ELF::EF_RL78_DATA_FAR,
                                 "incompatible data area flags: ", f);

    if ((mergedFlags & ELF::EF_RL78_RODATA_FAR) == 0) {
      mergedFlags |= (newFlags & ELF::EF_RL78_RODATA_FAR);
    } else if ((newFlags & ELF::EF_RL78_RODATA_FAR) != 0 &&
               (mergedFlags & ELF::EF_RL78_RODATA_FAR) !=
                   (newFlags & ELF::EF_RL78_RODATA_FAR)) {
      warn("incompatible rodata area flags, changed to far:  " + toString(f));
      mergedFlags |= (newFlags & ELF::EF_RL78_RODATA_FAR);
    }
  }
  return mergeSucceeded ? mergedFlags : 0;
}

static RelExpr getRelExpr(RelType Type) {
  switch (Type) {
  case R_RL78_DIR8S_PCREL:
  case R_RL78_DIR16S_PCREL:
  case R_RL78_ABS8S_PCREL:
  case R_RL78_ABS16S_PCREL:
    return R_PC;
  case R_RL78_RELAX:
    return config->relax ? R_RELAX_HINT : R_NONE;
  default:
    return R_ABS;
  }
}

RelExpr RL78::getRelExpr(RelType Type, const Symbol &S,
                         const uint8_t *loc) const {
  return ::getRelExpr(Type);
}

void RL78::writePlt(uint8_t *buf, const Symbol &sym,
                    uint64_t pltEntryAddr) const {
  write32le(buf, 0x000000EC | ((sym.getVA() & 0xFFFFF) << 8));
}

inline void write3le(void *P, uint8_t V) {
  write<uint8_t, llvm::support::little>(
      P, (read<uint8_t, llvm::support::little>(P) & 0x8f) | ((V & 0x7) << 4));
}

inline void write8le(void *P, uint8_t V) {
  write<uint8_t, llvm::support::little>(P, V);
}

inline void write24le(void *P, uint64_t V) {
  write32le(P, (read32le(P) & 0xff00'0000) | (V & ~0xff00'0000));
}

static void relaxDIR20U(const InputSection &sec, size_t i, uint64_t loc,
                        Relocation &r, uint32_t &remove) {
  // Handle only br/call !!addr20.
  const auto opc = sec.content().data()[r.offset - 1];
  if (opc != 0xEC && opc != 0xFC)
    return;

  const auto brVA = loc - 1; // Note that 'loc' is the VA of the relocation (= brVA + 1).
  const auto tgtVA = sec.getRelocTargetVA(sec.file, r.type, r.addend, loc, *r.sym, R_ABS);

  // If the branch target is in the same input section after the branch, relaxing the branch
  // will affect its address; if we don't consider this we fail to relax some branches that
  // are just "at the boundary" e.g. at +127 bytes (max. 8-bit signed value).
  const auto adjTgtVA = isa<Defined>(r.sym) &&
                        cast<Defined>(r.sym)->section == &sec && tgtVA > brVA;

  // Relative distance between the instructions.
  const auto deltaVA = int64_t(tgtVA - brVA);

  // For branches, try first to relax to br $addr20.
  const auto disp8 = (deltaVA - 2)           // PC will be brVA+2 when relaxing to 2-byte
                       - (adjTgtVA ? 2 : 0); // and adjusted tgtVA will be at -2.
  if (opc == 0xEC && isInt<8>(disp8)) {
    sec.rl78RelaxAux->relocTypes[i] = R_RL78_DIR8S_PCREL;
    sec.rl78RelaxAux->writes.push_back(0xEF); // BR $addr20.
    remove = 2;
    return;
  }

  // Then, try br/call !addr16.
  if (isUInt<16>(tgtVA)) {
    sec.rl78RelaxAux->relocTypes[i] = R_RL78_DIR16U;
    sec.rl78RelaxAux->writes.push_back(opc + 1); // I.e. 0xED and 0xFD, resp.
    remove = 1;
    return;
  }

  // Lastly, try br/call $!addr20.
  const auto disp16 = (deltaVA - 3)          // PC will be brVA+3 when relaxing to 3-byte
                       - (adjTgtVA ? 1 : 0); // and adjusted tgtVA will be at -1.
  if (isInt<16>(disp16)) {
    sec.rl78RelaxAux->relocTypes[i] = R_RL78_DIR16S_PCREL;
    sec.rl78RelaxAux->writes.push_back(opc + 2); // I.e. 0xEE and 0xFE, respectively.
    remove = 1;
  }
}

template <bool PCRel>
static void relaxDIR16(const InputSection &sec, size_t i, uint64_t loc,
                       Relocation &r, uint32_t &remove) {
  // Handle only the branches:
  //   br !addr16   (PCRel = false)
  //   br $!addr20  (PCRel = true)
  // as the calls (call !addr16, resp. call $!addr20) cannot be relaxed further.
  const auto opc = sec.content().data()[r.offset - 1];
  if (opc != (PCRel ? 0xEE : 0xED))
    return;

  const auto brVA = loc - 1; // Note that 'loc' is the VA of the relocation (= brVA + 1).
  const auto tgtVA = sec.getRelocTargetVA(sec.file, r.type, r.addend, loc, *r.sym, R_ABS);

  // If the branch target is in the same input section after the branch,
  // relaxing the branch will affect its address; if we don't consider this we
  // fail to relax some branches that are just "at the boundary" e.g. at +127
  // bytes (max. 8-bit signed value).
  const auto adjTgtVA = isa<Defined>(r.sym) &&
                        cast<Defined>(r.sym)->section == &sec && tgtVA > brVA;

  // Relative distance between the instructions.
  const auto deltaVA = int64_t(tgtVA - brVA);

  // Displacement if relaxation would be applied.
  const auto disp8 = (deltaVA - 2)           // PC will be brVA+2 when relaxing to 2-byte
                       - (adjTgtVA ? 1 : 0); // and adjusted tgtVA will be at -1.
  if (isInt<8>(disp8)) {
    sec.rl78RelaxAux->relocTypes[i] = R_RL78_DIR8S_PCREL;
    sec.rl78RelaxAux->writes.push_back(0xEF); // BR $addr20.
    remove = 1;
  }
}

static bool relax(InputSection &sec) {
  if (sec.relocs().empty())
    return false;

  const uint64_t secAddr = sec.getVA();
  auto &aux = *sec.rl78RelaxAux;
  bool changed = false;

  ArrayRef<SymbolAnchor> sa = aux.anchors;
  uint64_t delta = 0;

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

    switch (r.type) {
    case R_RL78_DIR20U:
      if (i + 1 != sec.relocs().size() &&
          sec.relocs()[i + 1].type == R_RL78_RELAX)
        relaxDIR20U(sec, i, loc, r, remove);
      break;
    case R_RL78_DIR16U:
      if (i + 1 != sec.relocs().size() &&
          sec.relocs()[i + 1].type == R_RL78_RELAX)
        relaxDIR16<0>(sec, i, loc, r, remove);
      break;
    case R_RL78_DIR16S_PCREL:
      if (i + 1 != sec.relocs().size() &&
          sec.relocs()[i + 1].type == R_RL78_RELAX)
        relaxDIR16<1>(sec, i, loc, r, remove);
      break;
    default:
      break;
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
  if (!config->relax)
    return false;

  llvm::TimeTraceScope timeScope("RL78 relaxOnce");
  if (config->relocatable)
    return false;

  if (pass == 0)
    initSymbolAnchors();

  SmallVector<InputSection *, 0> storage;
  bool changed = false;
  for (OutputSection *osec : outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;
    for (InputSection *sec : getInputSections(*osec, storage))
      changed |= relax(*sec);
  }
  return changed;
}

void elf::rl78FinalizeRelax(int passes) {
  if (!config->relax)
    return;

  llvm::TimeTraceScope timeScope("Finalize RL78 relaxation");
  log("relaxation passes: " + Twine(passes));
  SmallVector<InputSection *, 0> storage;

  for (OutputSection *osec : outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;

    for (InputSection *sec : getInputSections(*osec, storage)) {
      RL78RelaxAux &aux = *sec->rl78RelaxAux;
      if (!aux.relocDeltas)
        continue;

      MutableArrayRef<Relocation> rels = sec->relocs();
      ArrayRef<uint8_t> old = sec->content();
      size_t newSize = old.size() - aux.relocDeltas[rels.size() - 1];
      size_t writesIdx = 0;
      uint8_t *p = context().bAlloc.Allocate<uint8_t>(newSize);
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
          case R_RL78_DIR16S_PCREL: {
            uint32_t val = aux.writes[writesIdx++];
            write24le(p - 1, val);
            skip = 2;
            break;
          }
          case R_RL78_DIR8S_PCREL: {
            write16le(p - 1, aux.writes[writesIdx++]);
            skip = 1;
            break;
          }
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
            rels[i].expr = getRelExpr(rels[i].type);
          }
        }
        while (++i != e && rels[i].offset == cur);
        delta = aux.relocDeltas[i - 1];
      }
    }
  }
}

static uint64_t checkAndConvertMirrorAddr(uint8_t *loc, const Relocation &rel,
                                          uint64_t val,
                                          bool AllowOutOfRange = false) {
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

  ErrorPlace errPlace = getErrorPlace(loc);
  uint32_t maaFlag = config->eflags & ELF::EF_RL78_MAA_1;

  LinkerScript *linkerScript = script.get();
  MapVector<llvm::StringRef, MemoryRegion*> memoryRegions = linkerScript->memoryRegions;
  MemoryRegion *mirrorRegion = memoryRegions.lookup("MIRROR");

  if (!mirrorRegion) {
    error(errPlace.loc + "memory region 'MIRROR' not declared");
    return 0;
  }

  // Get FLASH MEMORY start/end address.
  uint32_t start = mirrorRegion->getOrigin() & 0xFFFF;
  uint32_t end = start + mirrorRegion->getLength();

  if (!maaFlag) {
    // We need to know if the maaFlag was correct beforehand.
    error(errPlace.loc + "relocation " + lld::toString(rel.type) +
          " is invalid when MAA mode flag in ELF is set to common!");
    return 0;
  }

  if (maaFlag == EF_RL78_MAA_1) {
    start += 0x10000;
    end += 0x10000;
  }

  if (!(mirrorRegion->getOrigin() & 0xF0000) ||
      mirrorRegion->getOrigin() < end) {
    error(errPlace.loc + "memory region 'MIRROR' is not in a correct location");
    return 0;
  }

  // Get addend needed to put the the address in MIRROR.
  uint32_t correction = mirrorRegion->getOrigin() - start;

  if (val >= start && val <= end) {
    return val + correction;
  } else if (AllowOutOfRange) {
    // Return it unchanged, used for R_RL78_OPmir.
    return val;
  } else {
    errorOrWarn(errPlace.loc + "relocation " + lld::toString(rel.type) +
                " out of MIRROR range: " + Twine::utohexstr(val).str() +
                " is not in [" + Twine::utohexstr(start).str() + ", " +
                Twine::utohexstr(end).str() + "]");
    return 0;
  }
}

static uint8_t checkAndConvertSAddr(uint8_t *loc, const Relocation &rel,
                                    uint64_t val) {
  ErrorPlace errPlace = getErrorPlace(loc);
  uint32_t max1 = 0xff1f;
  uint32_t min1 = 0xfe20;
  uint32_t max2 = 0xfff1f;
  uint32_t min2 = 0xffe20;
  if ((val >= min1 && val <= max1) || (val >= min2 && val <= max2)) {
    return val;
  } else {
    error(errPlace.loc + "relocation " + lld::toString(rel.type) +
          " out of SADDR(P) range: " + Twine(val).str() + " is not in [" +
          Twine::utohexstr(min1).str() + ", " + Twine::utohexstr(max1).str() +
          "] or [" + Twine::utohexstr(min2).str() + ", " +
          Twine::utohexstr(max2).str() + "]");
    return 0;
  }
}

uint16_t RL78::checkAndConvertRAM(uint8_t *loc, const Relocation &rel,
                                  uint64_t val) const {
  ErrorPlace errPlace = getErrorPlace(loc);
  LinkerScript *linkerScript = script.get();
  MapVector<StringRef, MemoryRegion*> memoryRegions = linkerScript->memoryRegions;
  MemoryRegion *ramRegion = memoryRegions.lookup("RAM");
  if (!ramRegion)
  {
    error(errPlace.loc + "memory region 'RAM' not declared");
    return 0;
  }
  uint32_t start = ramRegion->getOrigin();
  uint32_t end = start + ramRegion->getLength();

  if (val >= start && val <= end) {
    return val;
  } else {
    error(errPlace.loc + "relocation " + lld::toString(rel.type) +
          " out of RAM range: " + Twine::utohexstr(val).str() + " is not in [" +
          Twine::utohexstr(start).str() + ", " + Twine::utohexstr(end).str() +
          "]");
    return 0;
  }
}

uint64_t RL78::checkAndPop(uint8_t *loc, const Relocation &rel, char bitSize,
                           bool isSigned, uint64_t adj) const {
  if (relocationStack.empty()) {
    error(getErrorPlace(loc).loc + "relocation " + lld::toString(rel.type) +
          " is invalid: linker relocation stack is empty, nothing to pop!");
    return 0;
  } else {
    uint64_t t = relocationStack.top() - adj;

    if (bitSize > 0) {
      if (isSigned) {
        checkInt(loc, t, bitSize, rel);
      } else {
        checkUInt(loc, t, bitSize, rel);
      }
    }

    const_cast<RL78 *>(this)->relocationStack.pop();
    return t;
  }
}

void RL78::push(uint8_t *loc, uint64_t Value) const {
  const_cast<RL78 *>(this)->relocationStack.push(Value);
}

void RL78::relocate(uint8_t *loc, const Relocation &rel, uint64_t val) const {
  // TODO Not sure if zero refers to boot cluster 0?
  // also if these addresses are target specific?
  uint32_t zeroCALLTST = 0x00080;
  uint32_t CALLTST = 0x01080;

  switch (rel.type) {
  case R_RL78_DIR3U:
    checkUInt(loc, val, 3, rel);
    write3le(loc, val);
    break;
  case R_RL78_DIR8U:
    checkUInt(loc, val, 8, rel);
    write8le(loc, val);
    break;
  case R_RL78_DIR16U:
    // checkUInt(loc, val, 16, Type); - temporary revert
    write16le(loc, val);
    break;
  case R_RL78_DIR20U:
    checkUInt(loc, val, 20, rel);
    write24le(loc, val);
    break;
  case R_RL78_DIR20U_16:
    checkUInt(loc, val, 20, rel);
    write16le(loc, val);
    break;
  case R_RL78_DIR20UW_16:
    checkUInt(loc, val, 20, rel);
    write16le(loc, val & 0xfffe);
    break;
  case R_RL78_DIR32U:
    checkUInt(loc, val, 32, rel);
    write32le(loc, val);
    break;
  case R_RL78_DIR8U_MIR:
    write8le(loc, checkAndConvertMirrorAddr(loc, rel, val));
    break;
  case R_RL78_DIR16U_MIR:
    write16le(loc, checkAndConvertMirrorAddr(loc, rel, val));
    break;
  case R_RL78_DIR16UW_MIR:
    write16le(loc, checkAndConvertMirrorAddr(loc, rel, val) & 0xfffe);
    break;
  case R_RL78_DIR8U_SAD:
    write8le(loc, checkAndConvertSAddr(loc, rel, val) & 0xff);
    break;
  case R_RL78_DIR8UW_SAD:
    write8le(loc, checkAndConvertSAddr(loc, rel, val) & 0xfe);
    break;
  case R_RL78_DIR16U_RAM:
    write16le(loc, checkAndConvertRAM(loc, rel, val) & 0xffff);
    break;
  case R_RL78_DIR16UW_RAM:
    write16le(loc, checkAndConvertRAM(loc, rel, val) & 0xfffe);
    break;
  case R_RL78_DIR8S_PCREL:
    checkIntUInt(loc, val - 1, 8, rel);
    write8le(loc, val - 1);
    break;
  case R_RL78_DIR16S_PCREL:
    checkIntUInt(loc, val - 2, 16, rel);
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
  } break;
  case R_RL78_REF:
    break;
  case R_RL78_SYM:
    push(loc, val);
    break;
  case R_RL78_SYM_MIR:
    push(loc, checkAndConvertMirrorAddr(loc, rel, val));
    break;
  case R_RL78_OPadd: {
    uint64_t a = checkAndPop(loc, rel);
    uint64_t b = checkAndPop(loc, rel);
    push(loc, a + b);
  } break;
  case R_RL78_OPsub: {
    uint64_t a = checkAndPop(loc, rel);
    uint64_t b = checkAndPop(loc, rel);
    push(loc, b - a);
  } break;
  case R_RL78_OPsctsize:
  case R_RL78_OPscttop:
    push(loc, val);
    break;
  case R_RL78_OPlowH:
    push(loc, (val & 0xFF00) >> 8);
    break;
  case R_RL78_OPlowL:
    push(loc, val & 0xff);
    break;
  case R_RL78_OPhighW:
    push(loc, (val & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPlowW:
    // TODO currently we incorrectly use this for constant references too, it
    // should be R_RL78_OPlowW_MIR one possible solution to this might be at
    // ISelLowering::makeaddress, where we would insert a different node to
    // signal that it should be a constant access from the rom/mirror area
    push(loc, val & 0xFFFF);
    break;
  case R_RL78_OPhighW_MIR:
    push(loc, (checkAndConvertMirrorAddr(loc, rel, val) & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPlowW_MIR:
    push(loc, checkAndConvertMirrorAddr(loc, rel, val) & 0xFFFF);
    break;
  case R_RL78_OPlowW_SMIR: {
    // For absolute symbols the value of the addend is passed from
    // rellocateAlloc(), so it will be 0 here to not add it twice. Otherwise we
    // get the addend here instead of taking it from rellocateAlloc().
    uint64_t addend = 0;
    if (rel.sym && rel.sym->isDefined())
      addend = rel.addend;
    // Only after we converted the address to mirror we will add the addend.
    push(loc, (checkAndConvertMirrorAddr(loc, rel, val) + addend) & 0xFFFF);
    break;
  }
  case R_RL78_OPmir: {
    uint64_t T = checkAndPop(loc, rel);
    push(loc, checkAndConvertMirrorAddr(loc, rel, T, true));
  } break;
  case R_RL78_OPABSlowH:
    push(loc, (checkAndPop(loc, rel) & 0xFF00) >> 8);
    break;
  case R_RL78_OPABSlowL:
    push(loc, checkAndPop(loc, rel) & 0xFF);
    break;
  case R_RL78_OPABShighW:
    push(loc, (checkAndPop(loc, rel) & 0xFFFF0000) >> 16);
    break;
  case R_RL78_OPABSlowW:
    push(loc, checkAndPop(loc, rel) & 0xFFFF);
    break;
  case R_RL78_RELAX:
    break;
  default:
    error(getErrorLocation(loc) + "unrecognized relocation " + Twine(rel.type));
  }
}

void RL78::relocateAlloc(InputSectionBase &sec, uint8_t *buf) const {
  const unsigned bits = config->is64 ? 64 : 32;
  uint64_t secAddr = sec.getOutputSection()->addr;
  uint64_t addend;
  if (auto *s = dyn_cast<InputSection>(&sec))
    secAddr += s->outSecOff;
  for (const Relocation &rel : sec.relocs()) {
    uint8_t *loc = buf + rel.offset;
    addend = rel.addend;
    // For R_RL78_OPlowW_SMIR without an absolute symbol the value will be 0,
    // because conversion takes only the address to mirror, not the address with
    // the addend.
    if (rel.type == R_RL78_OPlowW_SMIR && rel.sym && rel.sym->isDefined())
      addend = 0;
    const uint64_t val = SignExtend64(
        sec.getRelocTargetVA(sec.file, rel.type, addend, secAddr + rel.offset,
                             *rel.sym, rel.expr),
        bits);
    if (rel.sym->isInPlt() && (rel.type == R_RL78_DIR16U ||
        // The original check here was: sym in plt (a function) and reloc type
        // is DIR16U, normally used by the 16-bit calls / branches.
        // DIR16U was previously used also for function symbols appearing
        // in data sections, but with the changes in the RL78AsmPrinter to use
        // same types of relocations as CC-RL, we now generate R_RL78_OPlowW
        // there... so, extended the check accordingly
        // NOTE: R_RL78_OPhighW was included to prevent situations where the
        // function symbol is in plt (the inclusion criterion in
        // RelocationScanner::processAux() uses R_RL78_OPlowW), but the high part
        // is used as well, and this seems to happen for -mfar-data, which does
        // not have a setting similar to config->rl78FarCode that inhibits the
        // plt altogether.
        // TODO: rename config->rl78FarCode to config->rl78DisablePlt and
        //       make it consider both -mfar-data and -mfar-code.
        (!(sec.getOutputSection()->flags & SHF_EXECINSTR) &&
         (rel.type == R_RL78_OPlowW || rel.type == R_RL78_OPhighW)))) {
      target->relocate(loc, rel, rel.sym->getPltVA());
    } else {
      switch (rel.type) {
      case R_RL78_ABS8S_PCREL:
      case R_RL78_ABS16S_PCREL:
        target->relocate(loc, rel, secAddr + rel.offset);
        break;
      case R_RL78_OPsctsize: {
        auto symbol = lld::toString(*rel.sym);
        if (Defined *d = dyn_cast<Defined>(rel.sym)) {
          if (InputSection *isec = cast_or_null<InputSection>(d->section)) {
            target->relocate(loc, rel, isec->getOutputSection()->size);
          } else {
            errorOrWarn(getErrorLocation(loc) + " symbol " + symbol +
                        " is not a section symbol!");
          }
        } else {
          errorOrWarn(getErrorLocation(loc) + " symbol " + symbol +
                      " is not defined!");
        }
      } break;
      default:
        target->relocate(loc, rel, val);
      }
    }
  }
}

/*TargetInfo *TargetInfo::getRL78TargetInfo() {
  static RL78 Target;
  return &Target;
}*/

TargetInfo *elf::getRL78TargetInfo() {
  static RL78 target;
  return &target;
}
