; RUN: not llc -mtriple=rl78 < %s -o /dev/null 2>&1 | FileCheck %s
; RUN: not llc -mtriple=rl78 -O0 < %s -o /dev/null 2>&1 | FileCheck %s

; The frame has a fixed size: an alloca of a size known only at run time
; (from a frontend other than Clang, which rejects it) is an error.

; CHECK: error: {{.*}}Unsupported dynamic stack allocation

declare void @use(ptr)

define void @f(i16 %n) {
  %p = alloca i8, i16 %n
  call void @use(ptr %p)
  ret void
}
