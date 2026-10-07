; RUN: not llc -mtriple rl78 -o %t.s -filetype=asm %s 2>&1 | FileCheck %s
; RUN: not llc -mtriple rl78 -o %t.o -filetype=obj %s 2>&1 | FileCheck %s --check-prefix=OBJ

; With assembly output, `. - foo` is not an absolute expression. Since LLVM 21
; the integrated assembler can fold it when writing an object (upstream's
; assembler-expressions-inlineasm.ll now expects the object to assemble), so
; only the assembly-output error is checked here.
; OBJ-NOT: expected absolute expression


; CHECK: <inline asm>:1:17: error: expected absolute expression

define i32 @main() local_unnamed_addr {
  tail call void asm sideeffect "foo: nop : .if . - foo==1;  nop;.endif", "~{dirflag},~{fpsr},~{flags}"()
  ret i32 0
}
