; -g must not change code. The register coalescer (with -join-splitedges, which
; RL78 enables at -Os/-Oz) must recognise a split edge block that also holds a
; debug instruction.

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -verify-machineinstrs -join-splitedges -disable-lsr=true -disable-machine-licm=true -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -join-splitedges -disable-lsr=true -disable-machine-licm=true -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define fastcc i16 @benchmark_body(i1 %0) {
  br i1 %0, label %2, label %8

2:                                                ; preds = %2, %1
  %3 = phi i16 [ 1, %2 ], [ 0, %1 ]
  %4 = load volatile i32, ptr null, align 2
  %5 = icmp eq i16 %3, 0
  br i1 %5, label %6, label %2

6:                                                ; preds = %2
  %7 = trunc i32 %4 to i16
    #dbg_value(i16 %7, !3, !DIExpression(), !9)
  br label %8

8:                                                ; preds = %6, %1
  %9 = phi i16 [ 0, %1 ], [ %7, %6 ]
  ret i16 %9
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "primecount.c", directory: "/", checksumkind: CSK_MD5, checksum: "945746ebddd442852d0ddc1fbe6a97ab")
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = !DILocalVariable(name: "r", scope: !4, file: !5, line: 152, type: !8)
!4 = distinct !DISubprogram(name: "benchmark_body", scope: !5, file: !5, line: 150, type: !6, scopeLine: 151, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !7, keyInstructions: true)
!5 = !DIFile(filename: "primecount.c", directory: "/", checksumkind: CSK_MD5, checksum: "945746ebddd442852d0ddc1fbe6a97ab")
!6 = !DISubroutineType(types: !7)
!7 = !{}
!8 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!9 = !DILocation(line: 0, scope: !4)
