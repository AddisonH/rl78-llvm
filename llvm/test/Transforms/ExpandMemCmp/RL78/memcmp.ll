; RUN: opt -S -passes=expand-memcmp -mtriple=rl78 < %s | FileCheck %s

; memcmp returns a 16-bit int on RL78. The expansion must use that type, and
; a 2-byte memcmp must not be a plain subtraction of the two (byte-swapped)
; i16 loads: the difference overflows into the sign bit, e.g.
; memcmp("\xFF\x00", "\x00\x00", 2) would be negative.

target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

declare i16 @memcmp(ptr, ptr, i16)

define i16 @cmp1(ptr %a, ptr %b) {
; CHECK-LABEL: @cmp1(
; CHECK: [[A:%.*]] = load i8, ptr %a
; CHECK: [[B:%.*]] = load i8, ptr %b
; CHECK: [[AZ:%.*]] = zext i8 [[A]] to i16
; CHECK: [[BZ:%.*]] = zext i8 [[B]] to i16
; CHECK: [[D:%.*]] = sub i16 [[AZ]], [[BZ]]
; CHECK: ret i16 [[D]]
  %r = call i16 @memcmp(ptr %a, ptr %b, i16 1)
  ret i16 %r
}

define i16 @cmp2(ptr %a, ptr %b) {
; CHECK-LABEL: @cmp2(
; CHECK: [[A:%.*]] = load i16, ptr %a
; CHECK: [[B:%.*]] = load i16, ptr %b
; CHECK: [[AS:%.*]] = call i16 @llvm.bswap.i16(i16 [[A]])
; CHECK: [[BS:%.*]] = call i16 @llvm.bswap.i16(i16 [[B]])
; CHECK-NOT: sub
; CHECK: [[R:%.*]] = call i16 @llvm.ucmp.i16.i16(i16 [[AS]], i16 [[BS]])
; CHECK: ret i16 [[R]]
  %r = call i16 @memcmp(ptr %a, ptr %b, i16 2)
  ret i16 %r
}

define i1 @eq4(ptr %a, ptr %b) {
; CHECK-LABEL: @eq4(
; CHECK-NOT: call i16 @memcmp
; CHECK: ret i1
  %r = call i16 @memcmp(ptr %a, ptr %b, i16 4)
  %c = icmp eq i16 %r, 0
  ret i1 %c
}
