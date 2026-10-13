; RUN: llc -verify-machineinstrs -mattr=+relax -filetype=obj < %s -o %t.relax.o
; RUN: llvm-dwarfdump -v --debug-rnglists %t.relax.o | FileCheck %s --check-prefix=RELAX
; RUN: llvm-dwarfdump --debug-info %t.relax.o | FileCheck %s --check-prefix=INFO
; RUN: llc -verify-machineinstrs -mattr=-relax -filetype=obj < %s -o %t.o
; RUN: llvm-dwarfdump -v --debug-rnglists %t.o | FileCheck %s --check-prefix=NORELAX
; RUN: llvm-dwarfdump --debug-info %t.o | FileCheck %s --check-prefix=INFO

; DWARF 5 range lists use offsets and lengths (ULEB128 label differences),
; which RL78 cannot relocate. In a section with linker relaxation (f calls
; g: relaxable), the range is a pair of address-pool indices instead; cold()
; has no relaxable instruction and keeps start/length. DW_AT_high_pc is a
; 4-byte difference, relocated (and evaluated by llvm-dwarfdump).
; Generated from:
;   int g(int); int h;
;   __attribute__((section(".text.cold"))) void cold(void) { h = 0; }
;   int f(int x) { int y = g(x); if (y) cold(); return g(y) + 1; }

; RELAX:   [DW_RLE_startx_length]: 0x00000000, 0x00000005
; RELAX:   [DW_RLE_startx_endx  ]: 0x00000001, 0x{{[0-9a-f]+}}
; NORELAX: [DW_RLE_startx_length]: 0x00000000, 0x00000005
; NORELAX: [DW_RLE_startx_length]: 0x00000001, 0x{{[0-9a-f]+}}

; INFO:      DW_TAG_subprogram
; INFO-NEXT:   DW_AT_low_pc (0x00000000)
; INFO-NEXT:   DW_AT_high_pc (0x00000005)
; INFO:      DW_TAG_subprogram
; INFO-NEXT:   DW_AT_low_pc (0x00000000)
; INFO-NEXT:   DW_AT_high_pc (0x00000019)

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

@h = dso_local local_unnamed_addr global i16 0, align 2, !dbg !0

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(write, argmem: none, inaccessiblemem: none, target_mem: none)
define dso_local void @cold() local_unnamed_addr #0 section ".text.cold" !dbg !17 {
  store i16 0, ptr @h, align 2, !dbg !20, !tbaa !21
  ret void, !dbg !22
}

; Function Attrs: noinline nounwind
define dso_local range(i16 -32767, -32768) i16 @f(i16 noundef %0) local_unnamed_addr #1 !dbg !23 {
    #dbg_value(i16 %0, !27, !DIExpression(), !29)
  %2 = tail call i16 @g(i16 noundef %0) #3, !dbg !30
    #dbg_value(i16 %2, !28, !DIExpression(), !29)
  %3 = icmp eq i16 %2, 0, !dbg !31
  br i1 %3, label %5, label %4, !dbg !33

4:                                                ; preds = %1
  tail call void @cold(), !dbg !34
  br label %5, !dbg !34

5:                                                ; preds = %4, %1
  %6 = tail call i16 @g(i16 noundef %2) #3, !dbg !35
  %7 = add nsw i16 %6, 1, !dbg !36
  ret i16 %7, !dbg !37
}

declare !dbg !38 dso_local i16 @g(i16 noundef) local_unnamed_addr #2

attributes #0 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(write, argmem: none, inaccessiblemem: none, target_mem: none) "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0" }
attributes #1 = { noinline nounwind "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0" }
attributes #2 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0" }
attributes #3 = { nounwind }

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!6, !7, !8, !9, !10}
!llvm.ident = !{!11}
!llvm.errno.tbaa = !{!12}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "h", scope: !2, file: !3, line: 2, type: !5, isLocal: false, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C11, file: !3, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, globals: !4, splitDebugInlining: false, nameTableKind: None)
!3 = !DIFile(filename: "d.c", directory: "/tmp")
!4 = !{!0}
!5 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!6 = !{i32 7, !"Dwarf Version", i32 5}
!7 = !{i32 2, !"Debug Info Version", i32 3}
!8 = !{i32 1, !"wchar_size", i32 2}
!9 = !{i32 1, !"target-abi", !"nc_nd_d32"}
!10 = !{i32 7, !"debug-info-assignment-tracking", i1 true}
!11 = !{!"clang version 23.1.3"}
!12 = !{!13, !14, i64 0}
!13 = !{!"__libc_errno", !14, i64 0}
!14 = !{!"int", !15, i64 0}
!15 = !{!"omnipotent char", !16, i64 0}
!16 = !{!"Simple C/C++ TBAA"}
!17 = distinct !DISubprogram(name: "cold", scope: !3, file: !3, line: 3, type: !18, scopeLine: 3, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !2, keyInstructions: true)
!18 = !DISubroutineType(types: !19)
!19 = !{null}
!20 = !DILocation(line: 3, column: 60, scope: !17, atomGroup: 1, atomRank: 1)
!21 = !{!14, !14, i64 0}
!22 = !DILocation(line: 3, column: 65, scope: !17, atomGroup: 2, atomRank: 1)
!23 = distinct !DISubprogram(name: "f", scope: !3, file: !3, line: 4, type: !24, scopeLine: 4, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !2, retainedNodes: !26, keyInstructions: true)
!24 = !DISubroutineType(types: !25)
!25 = !{!5, !5}
!26 = !{!27, !28}
!27 = !DILocalVariable(name: "x", arg: 1, scope: !23, file: !3, line: 4, type: !5)
!28 = !DILocalVariable(name: "y", scope: !23, file: !3, line: 5, type: !5)
!29 = !DILocation(line: 0, scope: !23)
!30 = !DILocation(line: 5, column: 11, scope: !23, atomGroup: 1, atomRank: 2)
!31 = !DILocation(line: 6, column: 7, scope: !32, atomGroup: 2, atomRank: 2)
!32 = distinct !DILexicalBlock(scope: !23, file: !3, line: 6, column: 7)
!33 = !DILocation(line: 6, column: 7, scope: !32, atomGroup: 2, atomRank: 1)
!34 = !DILocation(line: 7, column: 5, scope: !32)
!35 = !DILocation(line: 8, column: 10, scope: !23)
!36 = !DILocation(line: 8, column: 15, scope: !23, atomGroup: 4, atomRank: 2)
!37 = !DILocation(line: 8, column: 3, scope: !23, atomGroup: 4, atomRank: 1)
!38 = !DISubprogram(name: "g", scope: !3, file: !3, line: 1, type: !24, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
