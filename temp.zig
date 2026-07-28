
=== Interleaved Source & Assembly: src/main.zig (Lines 140-151) ===

 [1;36m 140 | fn insertBalancedStd( [0m
         └─>  (No instructions / optimized away)

 [1;36m 141 |     allocator: std.mem.Allocator, [0m
         └─>  (No instructions / optimized away)

 [1;36m 142 |     keys: []const f32, [0m
         └─>  (No instructions / optimized away)

 [1;36m 143 |     tree: bts_std.BinaryTreeStd(f32).Tree, [0m
         └─>  (No instructions / optimized away)

 [1;36m 144 | ) !bts_std.BinaryTreeStd(f32).Tree { [0m
         └─>  sub	sp, sp, #352
         └─>  stp	x28, x27, [sp, #320]
         └─>  stp	x29, x30, [sp, #336]
         └─>  add	x29, sp, #336
         └─>  str	x8, [sp, #88]
         └─>  str	x0, [sp, #96]
         └─>  str	x1, [sp, #104]
         └─>  str	x4, [sp, #112]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  stur	x8, [x29, #-160]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  stur	x8, [x29, #-24]
         └─>  mov	x8, x2
         └─>  str	x8, [sp, #120]
         └─>  str	x3, [sp, #128]
         └─>  str	x4, [sp, #136]
         └─>  str	x2, [sp, #144]
         └─>  str	x3, [sp, #152]

 [1;36m 145 |     if (keys.len == 0) return tree; [0m
         └─>  ldr	x8, [sp, #152]
         └─>  cbz	x8, LBB1681_2
         └─>  b	LBB1681_3
         └─>  sturh	wzr, [x29, #-144]
         └─>  stur	x8, [x29, #-152]
         └─>  ldurh	w8, [x29, #-144]
         └─>  cbz	w8, LBB1681_6
         └─>  b	LBB1681_7
         └─>  b	LBB1681_1
         └─>  ldur	q0, [x29, #-152]
         └─>  str	q0, [x8]
         └─>  ldur	x9, [x29, #-24]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  subs	x8, x8, x9
         └─>  b.ne	LBB1681_41
         └─>  b	LBB1681_5
         └─>  ldp	x29, x30, [sp, #336]
         └─>  ldp	x28, x27, [sp, #320]
         └─>  add	sp, sp, #352
         └─>  ret
         └─>  b	LBB1681_4
         └─>  bl	_builtin.returnError
         └─>  b	LBB1681_4

 [1;36m 146 |     const mid = keys.len / 2; [0m
         └─>  ldr	x8, [sp, #152]
         └─>  mov	w9, #2
         └─>  udiv	x8, x8, x9
         └─>  str	x8, [sp, #64]
         └─>  str	x8, [sp, #160]

 [1;36m 147 |     var new_tree = try bts_std.BinaryTreeStd(f32).insert(allocator, keys[mid], tree); [0m
         └─>  ldr	x9, [sp, #144]
         └─>  str	x9, [sp, #72]
         └─>  ldr	x9, [sp, #152]
         └─>  str	x9, [sp, #80]
         └─>  subs	x8, x8, x9
         └─>  b.lo	LBB1681_9
         └─>  b	LBB1681_10
         └─>  ldr	s0, [x8, x9, lsl #2]
         └─>  sub	x8, x29, #136
         └─>  bl	"_binary_tree_std.BinaryTreeStd(f32).insert"
         └─>  ldurh	w8, [x29, #-128]
         └─>  cbnz	w8, LBB1681_11
         └─>  b	LBB1681_12
         └─>  b	LBB1681_8
         └─>  bl	"_debug.FullPanic((function 'defaultPanic')).outOfBounds"
         └─>  ldurh	w8, [x29, #-128]
         └─>  sturh	w8, [x29, #-112]
         └─>  ldurh	w8, [x29, #-112]
         └─>  cbz	w8, LBB1681_15
         └─>  b	LBB1681_16
         └─>  ldur	x9, [x29, #-136]
         └─>  str	x9, [sp, #168]
         └─>  ldur	q0, [x29, #-120]
         └─>  str	q0, [x8]
         └─>  ldur	x9, [x29, #-24]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  subs	x8, x8, x9
         └─>  b.ne	LBB1681_41
         └─>  b	LBB1681_14
         └─>  ldp	x29, x30, [sp, #336]
         └─>  ldp	x28, x27, [sp, #320]
         └─>  add	sp, sp, #352
         └─>  ret
         └─>  b	LBB1681_13
         └─>  bl	_builtin.returnError
         └─>  b	LBB1681_13

 [1;36m 148 |     new_tree = try insertBalancedStd(allocator, keys[0..mid], new_tree); [0m
         └─>  ldr	x9, [sp, #144]
         └─>  str	x9, [sp, #40]
         └─>  ldr	x9, [sp, #152]
         └─>  str	x9, [sp, #48]
         └─>  add	x10, x8, #0
         └─>  str	x10, [sp, #56]
         └─>  subs	x8, x8, x9
         └─>  b.ls	LBB1681_18
         └─>  b	LBB1681_19
         └─>  ldr	x4, [sp, #168]
         └─>  sub	x8, x29, #104
         └─>  bl	_main.insertBalancedStd
         └─>  ldurh	w8, [x29, #-96]
         └─>  cbnz	w8, LBB1681_20
         └─>  b	LBB1681_21
         └─>  b	LBB1681_17
         └─>  bl	"_debug.FullPanic((function 'defaultPanic')).outOfBounds"
         └─>  ldurh	w8, [x29, #-96]
         └─>  sturh	w8, [x29, #-80]
         └─>  ldurh	w8, [x29, #-80]
         └─>  cbz	w8, LBB1681_24
         └─>  b	LBB1681_25
         └─>  ldur	x9, [x29, #-104]
         └─>  str	x9, [sp, #168]
         └─>  ldur	q0, [x29, #-88]
         └─>  str	q0, [x8]
         └─>  ldur	x9, [x29, #-24]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  subs	x8, x8, x9
         └─>  b.ne	LBB1681_41
         └─>  b	LBB1681_23
         └─>  ldp	x29, x30, [sp, #336]
         └─>  ldp	x28, x27, [sp, #320]
         └─>  add	sp, sp, #352
         └─>  ret
         └─>  b	LBB1681_22
         └─>  bl	_builtin.returnError
         └─>  b	LBB1681_22

 [1;36m 149 |     new_tree = try insertBalancedStd(allocator, keys[mid + 1..], new_tree); [0m
         └─>  adds	x8, x8, #1
         └─>  str	x8, [sp, #32]
         └─>  cset	w8, hs
         └─>  tbnz	w8, #0, LBB1681_26
         └─>  b	LBB1681_27
         └─>  bl	"_debug.FullPanic((function 'defaultPanic')).integerOverflow"
         └─>  ldr	x10, [sp, #144]
         └─>  ldr	x9, [sp, #152]
         └─>  str	x9, [sp, #16]
         └─>  add	x10, x10, x8, lsl #2
         └─>  str	x10, [sp, #24]
         └─>  subs	x8, x8, x9
         └─>  b.ls	LBB1681_29
         └─>  b	LBB1681_30
         └─>  subs	x9, x8, x9
         └─>  str	x9, [sp, #8]
         └─>  subs	x8, x8, x8
         └─>  b.ls	LBB1681_32
         └─>  b	LBB1681_33
         └─>  b	LBB1681_28
         └─>  bl	"_debug.FullPanic((function 'defaultPanic')).startGreaterThanEnd"
         └─>  ldr	x4, [sp, #168]
         └─>  sub	x8, x29, #72
         └─>  bl	_main.insertBalancedStd
         └─>  ldurh	w8, [x29, #-64]
         └─>  cbnz	w8, LBB1681_34
         └─>  b	LBB1681_35
         └─>  b	LBB1681_31
         └─>  mov	x1, x2
         └─>  bl	"_debug.FullPanic((function 'defaultPanic')).outOfBounds"
         └─>  ldurh	w8, [x29, #-64]
         └─>  sturh	w8, [x29, #-48]
         └─>  ldurh	w8, [x29, #-48]
         └─>  cbz	w8, LBB1681_38
         └─>  b	LBB1681_39
         └─>  ldur	x8, [x29, #-72]
         └─>  str	x8, [sp, #168]
         └─>  ldur	q0, [x29, #-56]
         └─>  str	q0, [x8]
         └─>  ldur	x9, [x29, #-24]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  subs	x8, x8, x9
         └─>  b.ne	LBB1681_41
         └─>  b	LBB1681_37
         └─>  ldp	x29, x30, [sp, #336]
         └─>  ldp	x28, x27, [sp, #320]
         └─>  add	sp, sp, #352
         └─>  ret
         └─>  b	LBB1681_36
         └─>  bl	_builtin.returnError
         └─>  b	LBB1681_36

 [1;36m 150 |     return new_tree; [0m
         └─>  ldr	x8, [sp, #168]
         └─>  sturh	wzr, [x29, #-32]
         └─>  stur	x8, [x29, #-40]
         └─>  ldurh	w8, [x29, #-32]
         └─>  cbz	w8, LBB1681_43
         └─>  b	LBB1681_44
         └─>  ldur	q0, [x29, #-40]
         └─>  str	q0, [x8]
         └─>  ldur	x9, [x29, #-24]
         └─>  adrp	x8, ___stack_chk_guard@GOTPAGE
         └─>  ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
         └─>  ldr	x8, [x8]
         └─>  subs	x8, x8, x9
         └─>  b.eq	LBB1681_42
         └─>  b	LBB1681_41
         └─>  bl	___stack_chk_fail
         └─>  ldp	x29, x30, [sp, #336]
         └─>  ldp	x28, x27, [sp, #320]
         └─>  add	sp, sp, #352
         └─>  ret
         └─>  b	LBB1681_40
         └─>  bl	_builtin.returnError
         └─>  b	LBB1681_40

 [1;36m 151 | } [0m
         └─>  (No instructions / optimized away)


