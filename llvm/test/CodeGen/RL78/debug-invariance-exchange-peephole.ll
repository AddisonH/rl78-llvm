; -g must not change code. RL78InsertExchangeInstructions' adjacent-instruction
; peepholes (here CMPW AX, #0 + XOR1 CY, A.7 + BH -> ADDW AX, AX) must skip
; debug instructions.

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -verify-machineinstrs -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define fastcc ptr @number(ptr %0, i16 %1) !dbg !4 {
  br label %3

3:                                                ; preds = %2
    #dbg_value(ptr %0, !7, !DIExpression(), !10)
  %4 = icmp sgt i16 %1, 0
  br i1 %4, label %5, label %6

5:                                                ; preds = %3
  store i8 0, ptr null, align 1
  ret ptr null

6:                                                ; preds = %3
  ret ptr null
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !2, globals: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!2 = !{}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "number", scope: !5, file: !5, line: 53, type: !6, scopeLine: 54, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !2, keyInstructions: true)
!5 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!6 = !DISubroutineType(types: !2)
!7 = !DILocalVariable(name: "str", arg: 1, scope: !4, file: !5, line: 53, type: !8)
!8 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !9, size: 16)
!9 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_signed_char)
!10 = !DILocation(line: 0, scope: !4)
