;RUN: llc -mtriple=rl78 <%s -print-after=prolog-epilog 2>&1| FileCheck %s
;RUN: llc -mtriple=rl78 -rl78-frame-order-density=false <%s -print-after=prolog-epilog 2>&1 \
;RUN:   | FileCheck %s --check-prefix=USES

; Objects with the most uses per byte go closest to SP; by plain use count the
; 2048-byte array would come first and push the scalars beyond [SP+255].

define void @test_order(){
;CHECK: Frame Objects:
;CHECK-NEXT:   fi#0: size=1, align=1, at location [SP]
;CHECK-NEXT:   fi#1: size=8, align=2, at location [SP+2]
;CHECK-NEXT:   fi#2: size=2048, align=2, at location [SP+10]
;USES: Frame Objects:
;USES-NEXT:   fi#0: size=1, align=1, at location [SP+2048]
;USES-NEXT:   fi#1: size=8, align=2, at location [SP+2050]
;USES-NEXT:   fi#2: size=2048, align=2, at location [SP]
  entry:
  %b = alloca i8
  %c = alloca i64
  %a = alloca [1024 x i16]
  ;c - used 1 time(1 store {STORE8_ri_imm})
  ;b - used 2 times(2 stores {STORE16_rpi_rp})
  ;a - used 4 times(4 stores {STORE16_stack_slot_rp})

  store i8 52, i8* %c
  store i32 32, i8* %b
  store i64 1000, i1024* %a

  ret void
}
