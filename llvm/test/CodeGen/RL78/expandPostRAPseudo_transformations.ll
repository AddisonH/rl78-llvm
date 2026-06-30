;RUN: llc -mtriple=rl78 -mcpu=S2 -print-before=postrapseudos  < %s 2>&1 -O3 | FileCheck %s --check-prefix=CHECK_A
;RUN: llc -mtriple=rl78 -mcpu=S2 < %s -O3 | FileCheck %s --check-prefix=CHECK_B
;RUN: llc -mtriple=rl78 -mcpu=S2 < %s| FileCheck %s --check-prefix=CHECK_C

define i16 @SHLW_test(i16 %a, i16 %b) {
    ;CHECK_A: SHLW_test
    ;CHECK_A: {{.*}} = SHLW_rp_rp{{.*}}

    ;CHECK_C-LABEL: .LBB0_1
    ;CHECK_C: shlw ax, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB0_1

    %shift = shl i16 %a, %b
    ret i16 %shift
}

define i8 @SHL_test(i8 %a, i8 %b){
    ;CHECK_A: SHL_test
    ;CHECK_A: {{.*}} = SHL_r_r{{.*}}

    ;CHECK_C-LABEL: .LBB1_1
    ;CHECK_C: shl a, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB1_1

    %shift = shl i8 %a, %b
    ret i8 %shift
}

define i16 @SHRW_test(i16 %a, i16 %b){
    ;CHECK_A: SHRW_test
    ;CHECK_A: {{.*}} = SHRW_rp_rp{{.*}}

    ;CHECK_C-LABEL: .LBB2_1
    ;CHECK_C: shrw ax, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB2_1

    %shift = lshr i16 %a, %b
    ret i16 %shift
}

define i8 @SHR_test(i8 %a, i8 %b){
    ;CHECK_A: SHR_test
    ;CHECK_A: {{.*}} = SHR_r_r{{.*}}

    ;CHECK_C-LABEL: .LBB3_1
    ;CHECK_C: shr a, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB3_1

    %shift = lshr i8 %a, %b
    ret i8 %shift
}

define i16 @SARW_test(i16 %a, i16 %b){
    ;CHECK_A: SARW_test
    ;CHECK_A: {{.*}} = SARW_rp_rp{{.*}}

    ;CHECK_C-LABEL: .LBB4_1
    ;CHECK_C: sarw ax, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB4_1

    %shift = ashr i16 %a, %b
    ret i16 %shift
}

define i8 @SAR_test(i8 %a, i8 %b){
    ;CHECK_A: SAR_test
    ;CHECK_A: {{.*}} = SAR_r_r{{.*}}

    ;CHECK_C-LABEL: .LBB5_1
    ;CHECK_C: sar a, 1
    ;CHECK_C-NEXT: dec c
    ;CHECK_C-NEXT: bnz $.LBB5_1

    %shift = ashr i8 %a, %b
    ret i8 %shift
}

define i16 @ROTL16_test(i16 %x, i16 %n){
    ;CHECK_A: ROTL16_test
    ;CHECK_A: {{.*}} = ROTL16_rp_rp{{.*}}

    ;CHECK_B-LABEL: _ROTL16_test
    ;CHECK_B:mov1 cy, a.7
    ;CHECK_B-NEXT:rolwc ax, 1
    ;CHECK_B-NEXT:mov1 cy, a.7
    ;CHECK_B-NEXT:rolwc ax, 1

    %n.mask = and i16 %n, 15
    %shl = shl i16 %x, %n.mask
    %inv = sub i16 16, %n.mask
    %shr = lshr i16 %x, %inv
    %rot = or i16 %shl, %shr
    ret i16 %rot
}

define i16 @ROTR16_test(i16 %x, i16 %n){
    ;CHECK_A: ROTR16_test
    ;CHECK_A: {{.*}} = ROTR16_rp_rp{{.*}}

    ;CHECK_B-LABEL:_ROTR16_test
    ;CHECK_B:shrw ax, 1
    ;CHECK_B-NEXT:mov1 a.7, cy
    ;CHECK_B-NEXT:shrw ax, 1
    ;CHECK_B-NEXT:mov1 a.7, cy

    %n.mask = and i16 %n, 15
    %shl = lshr i16 %x, %n.mask
    %inv = sub i16 16, %n.mask
    %shr = shl i16 %x, %inv
    %rot = or i16 %shl, %shr
    ret i16 %rot
}

define i8 @ROTL_test(i8 %x, i8 %n){
    ;CHECK_A: ROTL_test
    ;CHECK_A: {{.*}} = ROTL_rp_rp{{.*}}

    ;CHECK_B-LABEL:_ROTL_test
    ;CHECK_B:rol a, 1

    %n.mask = and i8 %n, 7
    %shl = shl i8 %x, %n.mask
    %inv = sub i8 8, %n.mask
    %shr = lshr i8 %x, %inv
    %rot = or i8 %shl, %shr
    ret i8 %rot
}

define i8 @ROTR_test(i8 %x, i8 %n){
    ;CHECK_A: ROTR_test
    ;CHECK_A: {{.*}} = ROTR_rp_rp{{.*}}

    ;CHECK_B-LABEL:_ROTR_test
    ;CHECK_B:ror a, 1

    %n.mask = and i8 %n, 7
    %shl = lshr i8 %x, %n.mask
    %inv = sub i8 8, %n.mask
    %shr = shl i8 %x, %inv
    %rot = or i8 %shl, %shr
    ret i8 %rot
}

define i32 @ADDE_Test(i32 %a, i32 %b){
    ;CHECK_A: ADDE_Test
    ;CHECK_A: {{.*}} = ADDE_rp_rp{{.*}}

    ;CHECK_B-LABEL:_ADDE_Test
    ;CHECK_B:sknc
    ;CHECK_B-NEXT:incw {{.*}}
    ;CHECK_B-NEXT:addw {{.*}}

    %sum = add i32 %a, %b
    ret i32 %sum
}

define i32 @SUBE_test(i32 %a, i32 %b){
    ;CHECK_A: SUBE_test
    ;CHECK_A: {{.*}} = SUBE_rp_rp{{.*}}

    ;CHECK_B-LABEL:_SUBE_test
    ;CHECK_B:sknc
    ;CHECK_B-NEXT:decw {{.*}}
    ;CHECK_B-NEXT:subw {{.*}}

    %dif = sub i32 %a, %b
    ret i32 %dif
}

define i16 @MUL_test(i16 %a, i16 %b){
    ;CHECK_A: MUL_test
    ;CHECK_A: {{.*}} = MUL16_rp_rp{{.*}}

    ;CHECK_B-LABEL:_MUL_test
    ;CHECK_B:mulhu

    %ceva = mul i16 %b, %a
    ret i16 %ceva
}
