; NOTE: convert to set1/clr1 intrinsics at the IR level only for constant RHS values.

; RUN: opt -mtriple=rl78 -passes=rl78-gen-set1-clr1-intrin -S %s | FileCheck %s


target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

define dso_local void @no_set1(ptr noundef %b, i8 noundef %v) {
  %b.addr = alloca ptr, align 2
  %v.addr = alloca i8, align 1
  store ptr %b, ptr %b.addr, align 2
  store i8 %v, ptr %v.addr, align 1
  %1 = load i8, ptr %v.addr, align 1
  %2 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %2, align 1
  %bf.value = and i8 %1, 1
  %bf.shl = shl i8 %bf.value, 3
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, %bf.shl
  store volatile i8 %bf.set, ptr %2, align 1
  ret void
}

define dso_local void @set1(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 1
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, 8
  store volatile i8 %bf.set, ptr %1, align 1
  ret void
}

define dso_local void @no_clr1(ptr noundef %b, i8 noundef %v) {
  %b.addr = alloca ptr, align 2
  %v.addr = alloca i8, align 1
  store ptr %b, ptr %b.addr, align 2
  store i8 %v, ptr %v.addr, align 1
  %1 = load i8, ptr %v.addr, align 1
  %2 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %2, align 1
  %bf.value = and i8 %1, 1
  %bf.shl = shl i8 %bf.value, 3
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, %bf.shl
  store volatile i8 %bf.set, ptr %2, align 1
  ret void
}

define dso_local void @clr1(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 1
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 1
  ret void
}

; CHECK-DAG: @no_set1
; CHECK-NOT: @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @set1
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @no_clr1
; CHECK-NOT: @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @clr1
; CHECK:     @llvm.rl78.clr1
; CHECK:     }
