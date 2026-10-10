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
; FRAME:      0x{{[0-9a-f]+}}: CFA=SPreg+4
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+6
; FRAME-NEXT: 0x{{[0-9a-f]+}}: CFA=SPreg+4
; FRAME-NOT:  CFA=

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Function Attrs: minsize noinline nounwind optsize
define dso_local void @f(ptr nofree noundef readonly captures(none) %0, ptr noundef initializes((2, 4)) %1) local_unnamed_addr #0 !dbg !13 {
    #dbg_value(ptr %0, !19, !DIExpression(), !21)
    #dbg_value(ptr %1, !20, !DIExpression(), !21)
  %3 = getelementptr inbounds nuw i8, ptr %1, i16 2, !dbg !22
  store i16 1, ptr %3, align 2, !dbg !23, !tbaa !24
  %4 = load i16, ptr %0, align 2, !dbg !25, !tbaa !24
  %5 = tail call i16 @g(i16 noundef %4) #2, !dbg !27
  %6 = icmp eq i16 %5, 0, !dbg !28
  br i1 %6, label %9, label %7, !dbg !29

7:                                                ; preds = %2
  %8 = getelementptr inbounds nuw i8, ptr %1, i16 6, !dbg !30
  tail call void @a(ptr noundef nonnull %8) #2, !dbg !31
  br label %11, !dbg !31

9:                                                ; preds = %2
  %10 = getelementptr inbounds nuw i8, ptr %1, i16 6, !dbg !32
  tail call void @b(ptr noundef nonnull %10, i16 noundef 0) #2, !dbg !33
  br label %11

11:                                               ; preds = %9, %7
  ret void, !dbg !34
}

; Function Attrs: minsize optsize
declare !dbg !35 dso_local i16 @g(i16 noundef) local_unnamed_addr #1

; Function Attrs: minsize optsize
declare !dbg !38 dso_local void @a(ptr noundef) local_unnamed_addr #1

; Function Attrs: minsize optsize
declare !dbg !41 dso_local void @b(ptr noundef, i16 noundef) local_unnamed_addr #1

attributes #0 = { minsize noinline nounwind optsize "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #1 = { minsize optsize "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #2 = { minsize nounwind optsize }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6}
!llvm.ident = !{!7}
!llvm.errno.tbaa = !{!8}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "cfi.c", directory: "/tmp")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 2}
!5 = !{i32 1, !"target-abi", !"nc_nd_d32"}
!6 = !{i32 7, !"debug-info-assignment-tracking", i1 true}
!7 = !{!"clang version 23.1.3 (/home/addison/workspace/rl-rs/rl78-llvm-23/clang 7007040911c29bad8f25232d9a682610d00b5eef)"}
!8 = !{!9, !10, i64 0}
!9 = !{!"__libc_errno", !10, i64 0}
!10 = !{!"int", !11, i64 0}
!11 = !{!"omnipotent char", !12, i64 0}
!12 = !{!"Simple C/C++ TBAA"}
!13 = distinct !DISubprogram(name: "f", scope: !1, file: !1, line: 4, type: !14, scopeLine: 4, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !18, keyInstructions: true)
!14 = !DISubroutineType(types: !15)
!15 = !{null, !16, !16}
!16 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !17, size: 16)
!17 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!18 = !{!19, !20}
!19 = !DILocalVariable(name: "p", arg: 1, scope: !13, file: !1, line: 4, type: !16)
!20 = !DILocalVariable(name: "q", arg: 2, scope: !13, file: !1, line: 4, type: !16)
!21 = !DILocation(line: 0, scope: !13)
!22 = !DILocation(line: 5, column: 3, scope: !13)
!23 = !DILocation(line: 5, column: 8, scope: !13, atomGroup: 1, atomRank: 1)
!24 = !{!10, !10, i64 0}
!25 = !DILocation(line: 6, column: 9, scope: !26)
!26 = distinct !DILexicalBlock(scope: !13, file: !1, line: 6, column: 7)
!27 = !DILocation(line: 6, column: 7, scope: !26)
!28 = !DILocation(line: 6, column: 7, scope: !26, atomGroup: 2, atomRank: 2)
!29 = !DILocation(line: 6, column: 7, scope: !26, atomGroup: 2, atomRank: 1)
!30 = !DILocation(line: 7, column: 9, scope: !26)
!31 = !DILocation(line: 7, column: 5, scope: !26)
!32 = !DILocation(line: 9, column: 9, scope: !26)
!33 = !DILocation(line: 9, column: 5, scope: !26)
!34 = !DILocation(line: 10, column: 1, scope: !13, atomGroup: 3, atomRank: 1)
!35 = !DISubprogram(name: "g", scope: !1, file: !1, line: 3, type: !36, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!36 = !DISubroutineType(types: !37)
!37 = !{!17, !17}
!38 = !DISubprogram(name: "a", scope: !1, file: !1, line: 1, type: !39, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!39 = !DISubroutineType(types: !40)
!40 = !{null, !16}
!41 = !DISubprogram(name: "b", scope: !1, file: !1, line: 2, type: !42, flags: DIFlagPrototyped, spFlags: DISPFlagOptimized)
!42 = !DISubroutineType(types: !43)
!43 = !{null, !16, !17}
