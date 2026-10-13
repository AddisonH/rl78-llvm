;RUN: llc -verify-machineinstrs -mtriple=rl78 -minsert-nop-with-label=nop.ll,3,LABEL2 < %s | FileCheck %s

source_filename = "nop.ll"

define dso_local void @test_nop() #0 !dbg !7 {
  ;CHECK:LABEL2@0000:
	;CHECK-NEXT:nop
  ret void, !dbg !10
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "LLVM for Renesas RL78 (internal) clang version 17.0.1 (https://gitlab.global.renesas.com/compiler_dev/llvm-project 1611ecf0e7ed0dda1b7d68cc570736639c6b70fb)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "nop.ll", directory: "[]", checksumkind: CSK_MD5, checksum: "f7fbeaf2398ffacfe5a93e75df5f0e39")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!7 = distinct !DISubprogram(name: "test_nop", scope: !1, file: !1, line: 1, type: !8, scopeLine: 2, spFlags: DISPFlagDefinition, unit: !0)
!8 = !DISubroutineType(types: !9)
!9 = !{null}
!10 = !DILocation(line: 3, column: 2, scope: !7)
