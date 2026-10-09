; -g must not change code. RL78ExpandPseudoInsts turns a branch over a single
; instruction into a skip; a debug instruction in the skipped block must not
; prevent it.

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define fastcc void @ee_vsprintf() !dbg !4 {
  %1 = icmp eq i8 0, 1
  br i1 %1, label %2, label %3

2:                                                ; preds = %0
    #dbg_value(ptr null, !7, !DIExpression(), !12)
  ret void

3:                                                ; preds = %0
  %4 = tail call fastcc i16 null(ptr null, i16 0)
  ret void
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !2, globals: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!2 = !{}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "ee_vsprintf", scope: !5, file: !5, line: 461, type: !6, scopeLine: 462, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !2, keyInstructions: true)
!5 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!6 = !DISubroutineType(cc: DW_CC_nocall, types: !2)
!7 = !DILocalVariable(name: "args", arg: 3, scope: !4, file: !5, line: 461, type: !8)
!8 = !DIDerivedType(tag: DW_TAG_typedef, name: "va_list", file: !9, line: 12, baseType: !10)
!9 = !DIFile(filename: "__stdarg_va_list.h", directory: "/", checksumkind: CSK_MD5, checksum: "7bd78a282b99fcfe41a9e3c566d14f7d")
!10 = !DIDerivedType(tag: DW_TAG_typedef, name: "__builtin_va_list", file: !5, baseType: !11)
!11 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: null, size: 16)
!12 = !DILocation(line: 0, scope: !4)
