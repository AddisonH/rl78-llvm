; RUN: llc -verify-machineinstrs -filetype=obj < %s | llvm-objdump -dr - | FileCheck %s

; A comparison with a function address plus a constant folds into one
; immediate operand, "movw bc, #_f+64"; its fixup used to assume a plain
; symbol (assertion in RL78MCExpr::ConvertExpressionToFixups).

; CHECK:      movw {{[a-z]+}}, #0
; CHECK-NEXT: R_RL78_DIR16U _f+0x40

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"
target triple = "rl78-unknown-unknown-elf"

define dso_local range(i16 0, 2) i16 @f() #0 {
  %1 = tail call i16 @g() #2
  %2 = icmp ule i16 %1, ptrtoint (ptr @f to i16)
  %3 = icmp ugt i16 %1, add (i16 ptrtoint (ptr @f to i16), i16 64)
  %4 = or i1 %2, %3
  %5 = zext i1 %4 to i16
  ret i16 %5
}

declare dso_local i16 @g() local_unnamed_addr #1

attributes #0 = { noinline nounwind "no-jump-tables"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #1 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="RL78_S3" "target-features"="+mirror-source-0,+relax" }
attributes #2 = { nounwind }

