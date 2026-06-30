; NOTE: convert to set1/clr1 intrinsics at the IR level only for bitfields in the near area.

; RUN: opt -mtriple=rl78 -passes=rl78-gen-set1-clr1-intrin -S %s | FileCheck %s


target datalayout = "e-m:o-p0:16:16:16-p1:16:16:16-p2:32:16:16:16-p3:32:16:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:8-n16:16-S16"

%struct.Bits = type { i8 }

@sb = dso_local global %struct.Bits zeroinitializer, align 1 #0

define dso_local void @set1_s() {
  %1 = load volatile i8, ptr @sb, align 1
  %2 = and i8 %1, -9
  %3 = or i8 %2, 8
  store volatile i8 %3, ptr @sb, align 1
  ret void
}

define dso_local void @clr1_s() {
  %1 = load volatile i8, ptr @sb, align 1
  %2 = and i8 %1, -9
  %3 = or i8 %2, 0
  store volatile i8 %3, ptr @sb, align 1
  ret void
}

define dso_local void @set1_d(ptr noundef %0) {
  %2 = alloca ptr, align 2
  store ptr %0, ptr %2, align 2
  %3 = load ptr, ptr %2, align 2
  %4 = load volatile i8, ptr %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 8
  store volatile i8 %6, ptr %3, align 1
  ret void
}

define dso_local void @clr1_d(ptr noundef %0) {
  %2 = alloca ptr, align 2
  store ptr %0, ptr %2, align 2
  %3 = load ptr, ptr %2, align 2
  %4 = load volatile i8, ptr %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 0
  store volatile i8 %6, ptr %3, align 1
  ret void
}

define dso_local void @set1_n(ptr addrspace(1) noundef %0)  {
  %2 = alloca ptr addrspace(1), align 2
  store ptr addrspace(1) %0, ptr %2, align 2
  %3 = load ptr addrspace(1), ptr %2, align 2
  %4 = load volatile i8, ptr addrspace(1) %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 8
  store volatile i8 %6, ptr addrspace(1) %3, align 1
  ret void
}

define dso_local void @clr1_n(ptr addrspace(1) noundef %0) {
  %2 = alloca ptr addrspace(1), align 2
  store ptr addrspace(1) %0, ptr %2, align 2
  %3 = load ptr addrspace(1), ptr %2, align 2
  %4 = load volatile i8, ptr addrspace(1) %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 0
  store volatile i8 %6, ptr addrspace(1) %3, align 1
  ret void
}

define dso_local void @set1_f(ptr addrspace(2) noundef %0) {
  %2 = alloca ptr addrspace(2), align 2
  store ptr addrspace(2) %0, ptr %2, align 2
  %3 = load ptr addrspace(2), ptr %2, align 2
  %4 = load volatile i8, ptr addrspace(2) %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 8
  store volatile i8 %6, ptr addrspace(2) %3, align 1
  ret void
}

define dso_local void @clr1_f(ptr addrspace(2) noundef %0) {
  %2 = alloca ptr addrspace(2), align 2
  store ptr addrspace(2) %0, ptr %2, align 2
  %3 = load ptr addrspace(2), ptr %2, align 2
  %4 = load volatile i8, ptr addrspace(2) %3, align 1
  %5 = and i8 %4, -9
  %6 = or i8 %5, 0
  store volatile i8 %6, ptr addrspace(2) %3, align 1
  ret void
}

; CHECK-DAG: @set1_s
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_s
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_d
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_d
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_n
; CHECK:     @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_n
; CHECK:     @llvm.rl78.clr1
; CHECK:     }

; CHECK-DAG: @set1_f
; CHECK-NOT: @llvm.rl78.set1
; CHECK:     }

; CHECK-DAG: @clr1_f
; CHECK-NOT: @llvm.rl78.clr1
; CHECK:     }
