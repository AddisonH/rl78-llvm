; Test for replacing the BT a.bit + AND a, #mask with a BTCLR.
; RUN: llc -mtriple=rl78 < %s | FileCheck %s

@g_cmd_flag.0 = global i8 0

define void @R_WDT_Restart()  {
entry:
  store volatile i8 -84, ptr inttoptr (i16 -85 to ptr)
  ret void
}

define void @test()  {
entry:
  %bf.load = load i8, ptr @g_cmd_flag.0
  %bf.shl.mask = and i8 %bf.load, 2
  %cmp = icmp eq i8 %bf.shl.mask, 0
  br i1 %cmp, label %if.then, label %if.end

if.then:
  tail call void @R_WDT_Restart() #2
  br label %if.end

if.end:
  %bf.clear = and i8 %bf.load, -3
  store i8 %bf.clear, ptr @g_cmd_flag.0, align 2
  tail call void @R_WDT_Restart() #2
  ret void
}

; CHECK: btclr a.1, $
; CHECK-NOT: bt a.1
; CHECK-NOT: and a, #-3
