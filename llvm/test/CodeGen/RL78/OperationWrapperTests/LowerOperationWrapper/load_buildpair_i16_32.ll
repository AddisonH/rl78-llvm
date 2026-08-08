; RUN: llc -mtriple=rl78 -mattr=+far-data %s -o - | FileCheck %s

; CHECK: _test_load:
; CHECK: 	mov es, #HIGHW(_global_ptr)
; CHECK: 	movw ax, es:!LOWW(_global_ptr)
; CHECK: 	movw hl, ax
; CHECK: 	movw ax, es:!LOWW(_global_ptr+2)
; CHECK: 	mov a, x
; CHECK: 	mov es, a
; CHECK: 	movw ax, es:[hl+8]
; CHECK: 	movw ax, es:[hl+10]

@global_ptr = external dso_local global ptr, align 2

define dso_local i32 @test_load() #0 {
  %1 = load ptr, ptr @global_ptr, align 2
  %2 = getelementptr inbounds i32, ptr %1, i32 2
  %3 = load i32, ptr %2, align 2
  ret i32 %3
}
