; RUN: opt < %s -passes=tailcallelim -verify-dom-info -S | FileCheck %s

define i32 @test1_factorial(i32 %x) {
entry:
	%tmp.1 = icmp sgt i32 %x, 0
	br i1 %tmp.1, label %then, label %else
then:
	%tmp.6 = add i32 %x, -1
	%recurse = call i32 @test1_factorial( i32 %tmp.6 )
	%accumulate = mul i32 %recurse, %x
	ret i32 %accumulate
else:
	ret i32 1
}

; CHECK-LABEL: define i32 @test1_factorial(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i32 [ 1, %entry ], [ %accumulate, %then ]
; CHECK: then:
; CHECK-NOT: %recurse
; CHECK: %accumulate = mul i32 %accumulator.tr, %x.tr
; CHECK: else:
; CHECK: %accumulator.ret.tr = mul i32 %accumulator.tr, 1
; CHECK: ret i32 %accumulator.ret.tr

; This is a more aggressive form of accumulator recursion insertion, which 
; requires noticing that X doesn't change as we perform the tailcall.

define i32 @test2_mul(i32 %x, i32 %y) {
entry:
	%tmp.1 = icmp eq i32 %y, 0
	br i1 %tmp.1, label %return, label %endif
endif:
	%tmp.8 = add i32 %y, -1
	%recurse = call i32 @test2_mul( i32 %x, i32 %tmp.8 )
	%accumulate = add i32 %recurse, %x
	ret i32 %accumulate
return:
	ret i32 %x
}

; CHECK-LABEL: define i32 @test2_mul(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i32 [ 0, %entry ], [ %accumulate, %endif ]
; CHECK: endif:
; CHECK-NOT: %recurse
; CHECK: %accumulate = add i32 %accumulator.tr, %x
; CHECK: return:
; CHECK: %accumulator.ret.tr = add i32 %accumulator.tr, %x
; CHECK: ret i32 %accumulator.ret.tr

define i64 @test3_fib(i64 %n) nounwind readnone {
; CHECK-LABEL: define i64 @test3_fib(
; CHECK-SAME: i64 [[N:%.*]]) #[[ATTR0:[0-9]+]] {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[TAILRECURSE:%.*]]
; CHECK:       tailrecurse:
; CHECK-NEXT:    [[ACCUMULATOR_TR:%.*]] = phi i64 [ 0, [[ENTRY:%.*]] ], [ [[ACCUMULATE:%.*]], [[BB1:%.*]] ]
; CHECK-NEXT:    [[N_TR:%.*]] = phi i64 [ [[N]], [[ENTRY]] ], [ [[TMP1:%.*]], [[BB1]] ]
; CHECK-NEXT:    switch i64 [[N_TR]], label [[BB1]] [
; CHECK-NEXT:      i64 0, label [[BB2:%.*]]
; CHECK-NEXT:      i64 1, label [[BB2]]
; CHECK-NEXT:    ]
; CHECK:       bb1:
; CHECK-NEXT:    [[TMP0:%.*]] = add i64 [[N_TR]], -1
; CHECK-NEXT:    [[RECURSE1:%.*]] = tail call i64 @test3_fib(i64 [[TMP0]]) #[[ATTR2:[0-9]+]]
; CHECK-NEXT:    [[TMP1]] = add i64 [[N_TR]], -2
; CHECK-NEXT:    [[ACCUMULATE]] = add nsw i64 [[ACCUMULATOR_TR]], [[RECURSE1]]
; CHECK-NEXT:    br label [[TAILRECURSE]]
; CHECK:       bb2:
; CHECK-NEXT:    [[ACCUMULATOR_RET_TR:%.*]] = add nsw i64 [[ACCUMULATOR_TR]], [[N_TR]]
; CHECK-NEXT:    ret i64 [[ACCUMULATOR_RET_TR]]
;
entry:
  switch i64 %n, label %bb1 [
    i64 0, label %bb2
    i64 1, label %bb2
  ]

bb1:
  %0 = add i64 %n, -1
  %recurse1 = tail call i64 @test3_fib(i64 %0) nounwind
  %1 = add i64 %n, -2
  %recurse2 = tail call i64 @test3_fib(i64 %1) nounwind
  %accumulate = add nsw i64 %recurse2, %recurse1
  ret i64 %accumulate

bb2:
  ret i64 %n
}

; CHECK-LABEL: define i64 @test3_fib(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i64 [ 0, %entry ], [ %accumulate, %bb1 ]
; CHECK: bb1:
; CHECK-NOT: %recurse2
; CHECK: %accumulate = add nsw i64 %accumulator.tr, %recurse1
; CHECK: bb2:
; CHECK: %accumulator.ret.tr = add nsw i64 %accumulator.tr, %n.tr
; CHECK: ret i64 %accumulator.ret.tr

define i32 @test4_base_case_call() local_unnamed_addr {
entry:
  %base = call i32 @test4_helper()
  switch i32 %base, label %sw.default [
    i32 1, label %cleanup
    i32 5, label %cleanup
    i32 7, label %cleanup
  ]

sw.default:
  %recurse = call i32 @test4_base_case_call()
  %accumulate = add nsw i32 %recurse, 1
  br label %cleanup

cleanup:
  %retval.0 = phi i32 [ %accumulate, %sw.default ], [ %base, %entry ], [ %base, %entry ], [ %base, %entry ]
  ret i32 %retval.0
}

declare i32 @test4_helper()

; CHECK-LABEL: define i32 @test4_base_case_call(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i32 [ 0, %entry ], [ %accumulate, %sw.default ]
; CHECK: sw.default:
; CHECK-NOT: %recurse
; CHECK: %accumulate = add nsw i32 %accumulator.tr, 1
; CHECK: cleanup:
; CHECK: %accumulator.ret.tr = add nsw i32 %accumulator.tr, %base
; CHECK: ret i32 %accumulator.ret.tr

define i32 @test5_base_case_load(ptr nocapture %A, i32 %n) local_unnamed_addr {
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:
  %base = load i32, ptr %A, align 4
  ret i32 %base

if.end:
  %idxprom = zext i32 %n to i64
  %arrayidx1 = getelementptr inbounds i32, ptr %A, i64 %idxprom
  %load = load i32, ptr %arrayidx1, align 4
  %sub = add i32 %n, -1
  %recurse = tail call i32 @test5_base_case_load(ptr %A, i32 %sub)
  %accumulate = add i32 %recurse, %load
  ret i32 %accumulate
}

; CHECK-LABEL: define i32 @test5_base_case_load(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i32 [ 0, %entry ], [ %accumulate, %if.end ]
; CHECK: if.then:
; CHECK: %accumulator.ret.tr = add i32 %accumulator.tr, %base
; CHECK: ret i32 %accumulator.ret.tr
; CHECK: if.end:
; CHECK-NOT: %recurse
; CHECK: %accumulate = add i32 %accumulator.tr, %load

define i32 @test6_multiple_returns(i32 %x, i32 %y) local_unnamed_addr {
entry:
  switch i32 %x, label %default [
    i32 0, label %case0
    i32 99, label %case99
  ]

case0:
  %helper = call i32 @test6_helper()
  ret i32 %helper

case99:
  %sub1 = add i32 %x, -1
  %recurse1 = call i32 @test6_multiple_returns(i32 %sub1, i32 %y)
  ret i32 18

default:
  %sub2 = add i32 %x, -1
  %recurse2 = call i32 @test6_multiple_returns(i32 %sub2, i32 %y)
  %accumulate = add i32 %recurse2, %y
  ret i32 %accumulate
}

declare i32 @test6_helper()

; CHECK-LABEL: define i32 @test6_multiple_returns(
; CHECK: tailrecurse:
; CHECK: %accumulator.tr = phi i32 [ %accumulator.tr, %case99 ], [ 0, %entry ], [ %accumulate, %default ]
; CHECK: %ret.tr = phi i32 [ poison, %entry ], [ %current.ret.tr, %case99 ], [ %ret.tr, %default ]
; CHECK: %ret.known.tr = phi i1 [ false, %entry ], [ true, %case99 ], [ %ret.known.tr, %default ]
; CHECK: case0:
; CHECK: %accumulator.ret.tr2 = add i32 %accumulator.tr, %helper
; CHECK: %current.ret.tr1 = select i1 %ret.known.tr, i32 %ret.tr, i32 %accumulator.ret.tr2
; CHECK: case99:
; CHECK-NOT: %recurse
; CHECK: %accumulator.ret.tr = add i32 %accumulator.tr, 18
; CHECK: %current.ret.tr = select i1 %ret.known.tr, i32 %ret.tr, i32 %accumulator.ret.tr
; CHECK: default:
; CHECK-NOT: %recurse
; CHECK: %accumulate = add i32 %accumulator.tr, %y

; It is only safe to transform one accumulator per function, make sure we don't
; try to remove more.

define i32 @test7_multiple_accumulators(i32 %a) local_unnamed_addr {
entry:
  %tobool = icmp eq i32 %a, 0
  br i1 %tobool, label %return, label %if.end

if.end:
  %and = and i32 %a, 1
  %tobool1 = icmp eq i32 %and, 0
  %sub = add nsw i32 %a, -1
  br i1 %tobool1, label %if.end3, label %if.then2

if.then2:
  %recurse1 = tail call i32 @test7_multiple_accumulators(i32 %sub)
  %accumulate1 = add nsw i32 %recurse1, 1
  br label %return

if.end3:
  %recurse2 = tail call i32 @test7_multiple_accumulators(i32 %sub)
  %accumulate2 = mul nsw i32 %recurse2, 2
  br label %return

return:
  %retval.0 = phi i32 [ %accumulate1, %if.then2 ], [ %accumulate2, %if.end3 ], [ 0, %entry ]
  ret i32 %retval.0
}

%struct.ListNode = type { i32, ptr }

; We cannot TRE commutative, non-associative intrinsics
define i32 @test_non_associative_sadd_sat(ptr %a) local_unnamed_addr {
; CHECK-LABEL: define i32 @test_non_associative_sadd_sat(
; CHECK-SAME: ptr [[A:%.*]]) local_unnamed_addr {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TOBOOL_NOT:%.*]] = icmp eq ptr [[A]], null
; CHECK-NEXT:    br i1 [[TOBOOL_NOT]], label [[COMMON_RET6:%.*]], label [[IF_END:%.*]]
; CHECK:       common.ret6:
; CHECK-NEXT:    ret i32 -1
; CHECK:       if.end:
; CHECK-NEXT:    [[TMP0:%.*]] = load i32, ptr [[A]], align 4
; CHECK-NEXT:    [[NEXT:%.*]] = getelementptr inbounds [[STRUCT_LISTNODE:%.*]], ptr [[A]], i64 0, i32 1
; CHECK-NEXT:    [[TMP1:%.*]] = load ptr, ptr [[NEXT]], align 8
; CHECK-NEXT:    [[CALL:%.*]] = tail call i32 @test_non_associative_sadd_sat(ptr [[TMP1]])
; CHECK-NEXT:    [[DOTSROA_SPECULATED:%.*]] = tail call i32 @llvm.sadd.sat.i32(i32 [[TMP0]], i32 [[CALL]])
; CHECK-NEXT:    ret i32 [[DOTSROA_SPECULATED]]
;
entry:
  %tobool.not = icmp eq ptr %a, null
  br i1 %tobool.not, label %common.ret6, label %if.end

common.ret6:                                      ; preds = %entry, %if.end
  %common.ret6.op = phi i32 [ %.sroa.speculated, %if.end ], [ -1, %entry ]
  ret i32 %common.ret6.op

if.end:                                           ; preds = %entry
  %0 = load i32, ptr %a
  %next = getelementptr inbounds %struct.ListNode, ptr %a, i64 0, i32 1
  %1 = load ptr, ptr %next
  %call = tail call i32 @test_non_associative_sadd_sat(ptr %1)
  %.sroa.speculated = tail call i32 @llvm.sadd.sat.i32(i32 %0, i32 %call)
  br label %common.ret6
}

declare i32 @llvm.sadd.sat.i32(i32, i32)
