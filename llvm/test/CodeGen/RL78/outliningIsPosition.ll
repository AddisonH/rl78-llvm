; RUN: llc -mtriple=rl78 < %s | FileCheck %s

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

; Instructions Debug/Position is illegal to outline, no _OUTLINED_FUNCTION_0 should be present in assembly file. 
; CHECK-LABEL: _test_position
; CHECK-NOT: !_OUTLINED_FUNCTION_0
; CHECK: .cfi_startproc

define dso_local i16 @test_position(i16 %a, i16 %b) !dbg !5 {
entry:
  %add = add i16 %a, %b, !dbg !8
  ret i16 %add, !dbg !9
}

define dso_local i16 @test_position2(i16 %a, i16 %b) !dbg !6 {
entry:
  %add = add i16 %a, %b, !dbg !8
  ret i16 %add, !dbg !9
}

!llvm.dbg.cu = !{!0}

!0 = distinct !DICompileUnit(
  language: DW_LANG_C,
  file: !1,
  isOptimized: true,
  emissionKind: FullDebug
)

!1 = !DIFile(filename: "test.c", directory: ".")

!5 = distinct !DISubprogram(
  name: "test_position",
  scope: !1,
  file: !1,
  line: 1,
  spFlags: DISPFlagDefinition | DISPFlagOptimized,
  unit: !0
)

!6 = distinct !DISubprogram(
  name: "test_position2",
  scope: !1,
  file: !1,
  line: 5,
  spFlags: DISPFlagDefinition | DISPFlagOptimized,
  unit: !0
)

!8 = !DILocation(line: 2, scope: !5)
!9 = !DILocation(line: 3, scope: !5)
