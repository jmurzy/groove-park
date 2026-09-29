## One physics tick of phase-neutral player intent (stick heading, tuck/brake,
## pop, grab/tweak, spin triggers, landing prep).
class_name RiderInputFrame
extends RefCounted

# One fixed physics tick of phase-neutral player intent.
var heading := Vector2.ZERO
var tuck_pressed := false
var brake_pressed := false
var pop_pressed := false
var pop_just_pressed := false
var pop_just_released := false
var grab_pressed := false
var grab_just_pressed := false
var tweak_pressed := false
var tweak_just_pressed := false
var spin_lt_pressed := false
var spin_lt_just_pressed := false
var spin_rt_pressed := false
var spin_rt_just_pressed := false
var landing_prep_pressed := false
var approach_path_change := 0
