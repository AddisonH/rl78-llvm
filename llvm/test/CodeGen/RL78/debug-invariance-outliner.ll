; -g must not change code. The machine outliner must map instructions the same
; way with debug instructions: blocks are skipped by their non-debug size, and
; a debug instruction between two illegal ones does not add a second illegal
; number (which reordered the outlined functions).

; RUN: rm -rf %t && mkdir -p %t/g %t/n
; RUN: llc -disable-block-placement=true -filetype=obj %s -o %t/g/x.o
; RUN: opt -strip-debug %s | llc -disable-block-placement=true -filetype=obj -o %t/n/x.o
; RUN: cd %t/g && llvm-objdump -d --no-show-raw-insn x.o > %t/g.txt
; RUN: cd %t/n && llvm-objdump -d --no-show-raw-insn x.o > %t/n.txt
; RUN: diff %t/g.txt %t/n.txt

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Function Attrs: optsize
define fastcc void @ee_vsprintf(ptr %0, ptr %1, i1 %2, i16 %3, i8 %4) #0 !dbg !4 {
  %6 = alloca ptr, align 2
  br label %7

7:                                                ; preds = %9, %5
  %8 = phi i16 [ %11, %9 ], [ 0, %5 ]
    #dbg_value(i16 %8, !7, !DIExpression(), !9)
  store ptr %1, ptr null, align 2
  switch i8 %4, label %14 [
    i8 35, label %13
    i8 43, label %9
    i8 32, label %12
  ]

9:                                                ; preds = %12, %7
  %10 = phi i16 [ 0, %7 ], [ 1, %12 ]
  %11 = or i16 %8, %10
  br label %7

12:                                               ; preds = %7
  br label %9

13:                                               ; preds = %7
  ret void

14:                                               ; preds = %7
  %15 = load ptr, ptr %0, align 2
  %16 = getelementptr i8, ptr %15, i16 1
  store ptr %16, ptr %6, align 2
  %17 = load i8, ptr %16, align 1
  %18 = or i8 %17, 0
  br i1 %2, label %19, label %20

19:                                               ; preds = %14
  ret void

20:                                               ; preds = %14
  %21 = icmp eq i8 %17, 0
  br i1 %21, label %22, label %23

22:                                               ; preds = %20
  ret void

23:                                               ; preds = %20
  %24 = load i8, ptr null, align 1
  switch i8 %24, label %29 [
    i8 108, label %25
    i8 76, label %25
  ]

25:                                               ; preds = %23, %23
  %26 = load ptr, ptr %0, align 2
  %27 = getelementptr i8, ptr %26, i16 1
  store ptr %27, ptr %6, align 2
  %28 = load i8, ptr %27, align 1
  br label %29

29:                                               ; preds = %25, %23
  %30 = phi i8 [ %24, %23 ], [ %28, %25 ]
  %cond1 = icmp eq i8 %30, 0
  br i1 %cond1, label %31, label %32

31:                                               ; preds = %29
  ret void

32:                                               ; preds = %29
  %33 = or i16 %8, %3
  %34 = load ptr, ptr %1, align 2
  %35 = icmp eq ptr %34, null
  %36 = select i1 %35, i32 0, i32 0
  %37 = call fastcc i16 null(ptr null)
  %38 = tail call fastcc ptr null(ptr null, i32 0, i16 0, i16 0, i16 0, i16 %33)
  ret void
}

attributes #0 = { optsize }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !2, globals: !2, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!2 = !{}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "ee_vsprintf", scope: !5, file: !5, line: 461, type: !6, scopeLine: 462, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !2, keyInstructions: true)
!5 = !DIFile(filename: "ee_printf.c", directory: "/", checksumkind: CSK_MD5, checksum: "f020ef7778fdbfcb50421c94c2c9a22b")
!6 = !DISubroutineType(cc: DW_CC_nocall, types: !2)
!7 = !DILocalVariable(name: "flags", scope: !4, file: !5, line: 469, type: !8)
!8 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!9 = !DILocation(line: 0, scope: !4)
