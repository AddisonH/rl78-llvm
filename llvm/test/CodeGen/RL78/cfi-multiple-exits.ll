; RUN: llc -mtriple=rl78 < %s | FileCheck %s
; RUN: llc -mtriple=rl78 -filetype=obj < %s | llvm-dwarfdump --debug-frame - \
; RUN:   | FileCheck %s --check-prefix=FRAME

; The CFA is tracked with .cfi_adjust_cfa_offset as SP changes, so the offset
; left by an epilogue must be corrected at the start of the next exit block
; (the frame is still allocated there). Generated from:
;   void a(int *); void b(int *, int); int g(int);
;   void f(int *p, int *q) { q[1] = 1; if (g(*p)) a(q + 3); else b(q + 3, 0); }

; CHECK-LABEL: _f:
; CHECK:      push ax
; CHECK-NEXT: .cfi_adjust_cfa_offset 2
; CHECK:      bz $.LBB0_2
; CHECK:      pop hl
; CHECK-NEXT: .cfi_adjust_cfa_offset -2
; CHECK:      br !_a
; CHECK:      .LBB0_2:
; CHECK-NEXT: .cfi_adjust_cfa_offset 2
; CHECK-NOT:  .cfi_
; CHECK:      pop hl
; CHECK-NEXT: .cfi_adjust_cfa_offset -2
; CHECK:      br !_b

; Both "pop hl" leave the CFA at SP+4 (the return address only); between them
; it is back at SP+6.
; FRAME:      0x0: CFA=SPreg+4
; FRAME-NEXT: 0x1: CFA=SPreg+6
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+8
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+6
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+4
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+6
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+4

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Function Attrs: minsize noinline nounwind optsize
define dso_local void @f(ptr nocapture noundef readonly %0, ptr noundef %1) local_unnamed_addr #0 !dbg !8 {
  call void @llvm.dbg.value(metadata ptr %0, metadata !14, metadata !DIExpression()), !dbg !16
  call void @llvm.dbg.value(metadata ptr %1, metadata !15, metadata !DIExpression()), !dbg !16
  %3 = getelementptr inbounds i16, ptr %1, i16 1, !dbg !17
  store i16 1, ptr %3, align 2, !dbg !18, !tbaa !19
  %4 = load i16, ptr %0, align 2, !dbg !23, !tbaa !19
  %5 = tail call i16 @g(i16 noundef %4) #3, !dbg !25
  %6 = icmp eq i16 %5, 0, !dbg !25
  br i1 %6, label %9, label %7, !dbg !26

7:                                                ; preds = %2
  %8 = getelementptr inbounds i16, ptr %1, i16 3, !dbg !27
  tail call void @a(ptr noundef nonnull %8) #3, !dbg !28
  br label %11, !dbg !28

9:                                                ; preds = %2
  %10 = getelementptr inbounds i16, ptr %1, i16 3, !dbg !29
  tail call void @b(ptr noundef nonnull %10, i16 noundef 0) #3, !dbg !30
  br label %11

11:                                               ; preds = %9, %7
  ret void, !dbg !31
}

; Function Attrs: minsize optsize
declare !dbg !32 dso_local i16 @g(i16 noundef) local_unnamed_addr #1

; Function Attrs: minsize optsize
declare !dbg !35 dso_local void @a(ptr noundef) local_unnamed_addr #1

; Function Attrs: minsize optsize
declare !dbg !38 dso_local void @b(ptr noundef, i16 noundef) local_unnamed_addr #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare void @llvm.dbg.value(metadata, metadata, metadata) #2

attributes #0 = { minsize noinline nounwind optsize "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #1 = { minsize optsize "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { minsize nounwind optsize }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6}
!llvm.ident = !{!7}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "cfi.c", directory: "/tmp")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 2}
!5 = !{i32 1, !"target-abi", !"nc_nd_d32"}
!6 = !{i32 7, !"debug-info-assignment-tracking", i1 true}
!7 = !{!"LLVM for Renesas RL78 17.0.1.202606 (541cc9327) clang version 17.0.1"}
!8 = distinct !DISubprogram(name: "f", scope: !1, file: !1, line: 4, type: !9, scopeLine: 4, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !13)
!9 = !DISubroutineType(types: !10)
!10 = !{null, !11, !11}
!11 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !12, size: 16)
!12 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!13 = !{!14, !15}
!14 = !DILocalVariable(name: "p", arg: 1, scope: !8, file: !1, line: 4, type: !11)
!15 = !DILocalVariable(name: "q", arg: 2, scope: !8, file: !1, line: 4, type: !11)
!16 = !DILocation(line: 0, scope: !8)
!17 = !DILocation(line: 5, column: 3, scope: !8)
!18 = !DILocation(line: 5, column: 8, scope: !8)
!19 = !{!20, !20, i64 0}
!20 = !{!"int", !21, i64 0}
!21 = !{!"omnipotent char", !22, i64 0}
!22 = !{!"Simple C/C++ TBAA"}
!23 = !DILocation(line: 6, column: 9, scope: !24)
!24 = distinct !DILexicalBlock(scope: !8, file: !1, line: 6, column: 7)
!25 = !DILocation(line: 6, column: 7, scope: !24)
!26 = !DILocation(line: 6, column: 7, scope: !8)
!27 = !DILocation(line: 7, column: 9, scope: !24)
!28 = !DILocation(line: 7, column: 5, scope: !24)
!29 = !DILocation(line: 9, column: 9, scope: !24)
!30 = !DILocation(line: 9, column: 5, scope: !24)
!31 = !DILocation(line: 10, column: 1, scope: !8)
!32 = !DISubprogram(name: "g", scope: !1, file: !1, line: 3, type: !33, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!33 = !DISubroutineType(types: !34)
!34 = !{!12, !12}
!35 = !DISubprogram(name: "a", scope: !1, file: !1, line: 1, type: !36, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!36 = !DISubroutineType(types: !37)
!37 = !{null, !11}
!38 = !DISubprogram(name: "b", scope: !1, file: !1, line: 2, type: !39, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!39 = !DISubroutineType(types: !40)
!40 = !{null, !11, !12}
