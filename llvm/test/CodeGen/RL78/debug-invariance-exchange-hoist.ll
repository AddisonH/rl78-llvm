; -g must not change code. RL78InsertExchangeInstructions moves stack loads and
; AX copies within a window of instructions, which must not count debug
; instructions.

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define i16 @calc_func(ptr %0, i1 %cond, i16 %1) !dbg !4 {
  br i1 %cond, label %3, label %4

3:                                                ; preds = %2
  br label %4

4:                                                ; preds = %3, %2
  %5 = phi i16 [ %1, %2 ], [ 0, %3 ]
    #dbg_value(i16 %5, !7, !DIExpression(), !11)
  %6 = tail call i16 null(i16 0, i16 0)
  %7 = and i16 %5, 1
  %8 = or i16 %1, %7
  store i16 %8, ptr %0, align 2
  ret i16 0
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "core_list_join.c", directory: "/", checksumkind: CSK_MD5, checksum: "8d082dc4a9676c02731a8cf209339072")
!2 = !{}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "calc_func", scope: !5, file: !5, line: 70, type: !6, scopeLine: 71, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !2, keyInstructions: true)
!5 = !DIFile(filename: "core_list_join.c", directory: "/", checksumkind: CSK_MD5, checksum: "8d082dc4a9676c02731a8cf209339072")
!6 = !DISubroutineType(types: !2)
!7 = !DILocalVariable(name: "retval", scope: !4, file: !5, line: 73, type: !8)
!8 = !DIDerivedType(tag: DW_TAG_typedef, name: "ee_s16", file: !9, line: 94, baseType: !10)
!9 = !DIFile(filename: "core_portme.h", directory: "/", checksumkind: CSK_MD5, checksum: "2d2d6a4257ad0be98541f4ee2edeb712")
!10 = !DIBasicType(name: "short", size: 16, encoding: DW_ATE_signed)
!11 = !DILocation(line: 0, scope: !4)
