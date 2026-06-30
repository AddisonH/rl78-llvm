; NOTE: convert to set1/clr1 intrinsics at the IR level (bitfield type doesn't matter if single-bit).

; RUN: opt -mtriple=rl78 -passes=rl78-gen-set1-clr1-intrin -S %s | FileCheck %s


target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

define dso_local void @set1_0(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -2
  %bf.set = or i8 %bf.clear, 1
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_0(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -2
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_1(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -3
  %bf.set = or i8 %bf.clear, 2
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_1(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -3
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_2(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -5
  %bf.set = or i8 %bf.clear, 4
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_2(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -5
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_3(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, 8
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_3(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -9
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_4(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -17
  %bf.set = or i8 %bf.clear, 16
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_4(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -17
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_5(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -33
  %bf.set = or i8 %bf.clear, 32
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_5(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -33
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @set1_6(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -65
  %bf.set = or i8 %bf.clear, 64
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

define dso_local void @clr1_6(ptr noundef %b) {
  %b.addr = alloca ptr, align 2
  store ptr %b, ptr %b.addr, align 2
  %1 = load ptr, ptr %b.addr, align 2
  %bf.load = load volatile i8, ptr %1, align 2
  %bf.clear = and i8 %bf.load, -65
  %bf.set = or i8 %bf.clear, 0
  store volatile i8 %bf.set, ptr %1, align 2
  ret void
}

; CHECK-DAG: @set1_0
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_0
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_1
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_1
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_2
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_2
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_3
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_3
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_4
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_4
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_5
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_5
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_6
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_6
; CHECK:     @llvm.rl78.clr1
; CHECK:     }
