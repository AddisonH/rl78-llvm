; -g must not change code. RL78AdjustMemRefsPass picks HL or DE for pointers
; from their live intervals, which must not be lengthened by debug
; instructions.

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define i16 @core_state_transition(ptr %0, ptr %1) {
    #dbg_value(ptr %1, !4, !DIExpression(), !12)
  %3 = load i8, ptr %0, align 1
  %4 = tail call fastcc i8 null(i8 %3)
  store i32 0, ptr %1, align 2
  ret i16 0
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, enums: !2, retainedTypes: !2, globals: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "core_state.c", directory: "/", checksumkind: CSK_MD5, checksum: "edcfc7a0b146a50028014f06e6826aa3")
!2 = !{}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !DILocalVariable(name: "transition_count", arg: 2, scope: !5, file: !6, line: 217, type: !8)
!5 = distinct !DISubprogram(name: "core_state_transition", scope: !6, file: !6, line: 217, type: !7, scopeLine: 218, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !2, keyInstructions: true)
!6 = !DIFile(filename: "core_state.c", directory: "/", checksumkind: CSK_MD5, checksum: "edcfc7a0b146a50028014f06e6826aa3")
!7 = !DISubroutineType(types: !2)
!8 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !9, size: 16)
!9 = !DIDerivedType(tag: DW_TAG_typedef, name: "ee_u32", file: !10, line: 107, baseType: !11)
!10 = !DIFile(filename: "core_portme.h", directory: "/", checksumkind: CSK_MD5, checksum: "2d2d6a4257ad0be98541f4ee2edeb712")
!11 = !DIBasicType(name: "unsigned long", size: 32, encoding: DW_ATE_unsigned)
!12 = !DILocation(line: 0, scope: !5)
