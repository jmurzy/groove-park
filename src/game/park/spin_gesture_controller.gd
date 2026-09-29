## Tracks the two-press spin gesture independently from physics and presentation.
class_name SpinGestureController
extends RefCounted

enum Phase { WAITING_DIRECTION, ROTATING_FIRST_HALF, WAITING_SECOND_PRESS, ROTATING_SECOND_HALF }

var phase := Phase.WAITING_DIRECTION
var direction := 0
var rearmed := true
var progress := 0.0
var target := 0.0
var tweak := false


func reset() -> void:
	phase = Phase.WAITING_DIRECTION
	direction = 0
	rearmed = true
	progress = 0.0
	target = 0.0
	tweak = false


func stop() -> void:
	phase = Phase.WAITING_DIRECTION
	target = progress


func update_input(
	left_pressed: bool,
	right_pressed: bool,
	left_just_pressed: bool,
	right_just_pressed: bool,
	can_rotate: bool,
	is_tweak: bool,
	half_turn: float,
	full_turn: float
) -> bool:
	if not left_pressed and not right_pressed:
		rearmed = true
	if not can_rotate:
		stop()
		return false
	if (
		phase == Phase.WAITING_DIRECTION
		and rearmed
		and direction != 0
		and is_equal_approx(progress, full_turn)
		and not left_just_pressed
		and not right_just_pressed
	):
		reset()
	if phase == Phase.WAITING_DIRECTION:
		if rearmed and (left_just_pressed or right_just_pressed):
			direction = -1 if left_just_pressed else 1
			rearmed = false
			progress = 0.0
			target = half_turn
			tweak = is_tweak
			phase = Phase.ROTATING_FIRST_HALF
			return true
		return false
	if phase != Phase.WAITING_SECOND_PRESS:
		return false
	var same_trigger_pressed := (
		(left_just_pressed and direction < 0) or (right_just_pressed and direction > 0)
	)
	if rearmed and same_trigger_pressed:
		rearmed = false
		target = full_turn
		phase = Phase.ROTATING_SECOND_HALF
		return true
	return false


func advance(delta: float, rate: float) -> bool:
	if not is_advancing():
		return false
	progress = move_toward(progress, target, rate * delta)
	if not is_equal_approx(progress, target):
		return false
	if phase == Phase.ROTATING_FIRST_HALF:
		phase = Phase.WAITING_SECOND_PRESS
		return false
	phase = Phase.WAITING_DIRECTION
	return true


func is_advancing() -> bool:
	return phase in [Phase.ROTATING_FIRST_HALF, Phase.ROTATING_SECOND_HALF]
