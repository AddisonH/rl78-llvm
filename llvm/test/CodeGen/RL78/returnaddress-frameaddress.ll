; RUN: llc -mtriple=rl78 -verify-machineinstrs < %s | FileCheck %s

; CALL leaves the return address at the incoming SP (PC[7:0], PC[15:8],
; PC[19:16]); the frame address is that slot. RL78 has no frame pointer
; chain, so depths above 0 give 0.

; CHECK-LABEL: _ra0:
; CHECK:      movw ax, [sp+0]
; CHECK-NEXT: ret
define ptr @ra0() {
  %r = call ptr @llvm.returnaddress.p0(i32 0)
  ret ptr %r
}

; With a frame, the slot is above it.
; CHECK-LABEL: _ra0_frame:
; CHECK:      subw sp, #10
; CHECK:      movw ax, [sp+10]
define ptr @ra0_frame(i16 %i) {
  %buf = alloca [10 x i8], align 1
  %p = getelementptr i8, ptr %buf, i16 %i
  store volatile i8 1, ptr %p
  %r = call ptr @llvm.returnaddress.p0(i32 0)
  ret ptr %r
}

; Far code: 20 bits, the third byte masked to PC[19:16].
; CHECK-LABEL: _ra0_far:
; CHECK:      movw ax, [sp+0]
; CHECK:      mov a, [sp+2]
; CHECK:      and a, #15
define ptr addrspace(3) @ra0_far() {
  %r = call ptr addrspace(3) @llvm.returnaddress.p3(i32 0)
  ret ptr addrspace(3) %r
}

; CHECK-LABEL: _ra1:
; CHECK:      clrw ax
; CHECK-NEXT: ret
define ptr @ra1() {
  %r = call ptr @llvm.returnaddress.p0(i32 1)
  ret ptr %r
}

; CHECK-LABEL: _fa0:
; CHECK:      movw ax, sp
; CHECK-NEXT: ret
define ptr @fa0() {
  %r = call ptr @llvm.frameaddress.p0(i32 0)
  ret ptr %r
}

; The depth-1 result is a constant only after legalization; the select on it
; is folded after instruction selection and must still produce a register
; value (it used to be a bare target constant: "Node emitted out of order").
; CHECK-LABEL: _ra1_select:
; CHECK:      clrw ax
; CHECK-NEXT: ret
define i16 @ra1_select() minsize optsize {
  %r = call ptr @llvm.returnaddress.p0(i32 1)
  %z = icmp eq ptr %r, null
  %s = select i1 %z, i16 0, i16 3
  ret i16 %s
}

declare ptr @llvm.returnaddress.p0(i32)
declare ptr addrspace(3) @llvm.returnaddress.p3(i32)
declare ptr @llvm.frameaddress.p0(i32)
