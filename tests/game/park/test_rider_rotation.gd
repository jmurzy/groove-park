## Headless checks for grab-gated, direction-specific LT/RT horizontal spins.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")
const SnowboarderViewScene := preload("res://src/presentation/gameplay/snowboarder_view.gd")

const DELTA := 1.0 / 60.0
var _failures := PackedStringArray()
var _course: ParkCourse
var _simulation: RiderSimulation
var _tuning: RiderTuning


func _init() -> void:
	_course = _test_course()
	_simulation = RiderSimulationScene.new()
	_tuning = RiderTuningScene.new()
	_tuning.gravity = 0.0
	_tuning.air_drag = 0.0
	_tuning.air_time_scale = 1.0
	_tuning.min_rotation_rate = TAU
	_tuning.max_rotation_rate = TAU * 2.0
	_test_lt_completes_left_regular_rotation()
	_test_rt_completes_right_tweak_rotation()
	_test_first_half_holds_and_requires_rearm()
	_test_opposite_trigger_does_not_complete_rotation()
	_test_held_trigger_does_not_repeat()
	_test_second_pair_counts_again()
	_test_faster_takeoff_rotates_faster()
	_test_rotation_requires_active_grab()
	_test_early_grab_release_freezes_incomplete_rotation()
	_test_rotation_does_not_change_trajectory_or_pitch()
	_test_takeoff_resets_spin_state()
	_test_directional_view_clips()
	if _failures.is_empty():
		print("Rider rotation checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_lt_completes_left_regular_rotation() -> void:
	var state := _grabbed_flight_state(false)
	_complete_rotation(state, -1)
	_expect(state.completed_rotations == 1, "LT 2X must count one left rotation.")
	_expect(state.spin_direction == -1, "LT must select the left/backside direction.")
	_expect(is_equal_approx(state.spin_progress, TAU), "LT 2X must finish at 360 degrees.")
	_expect(not state.spin_grab_tweak, "An A spin must retain the regular-grab style.")
	_expect(state.trick_tracker.cumulative_rotation < 0.0, "LT must record negative rotation.")


func _test_rt_completes_right_tweak_rotation() -> void:
	var state := _grabbed_flight_state(true)
	_complete_rotation(state, 1)
	_expect(state.completed_rotations == 1, "RT 2X must count one right rotation.")
	_expect(state.spin_direction == 1, "RT must select the right/frontside direction.")
	_expect(state.spin_grab_tweak, "A B spin must retain the tweak-grab style.")
	_expect(state.trick_tracker.cumulative_rotation > 0.0, "RT must record positive rotation.")


func _test_first_half_holds_and_requires_rearm() -> void:
	var state := _grabbed_flight_state(false)
	_complete_half_turn(state, -1)
	_expect(is_equal_approx(state.spin_progress, PI), "The first tap must stop at 180 degrees.")
	_expect(
		state.rotation_gesture_phase == JumpState.RotationGesturePhase.WAITING_SECOND_PRESS,
		"The first half must wait for a second press."
	)
	_press_trigger(state, -1)
	_expect(
		state.rotation_gesture_phase == JumpState.RotationGesturePhase.WAITING_SECOND_PRESS,
		"A second press without trigger release must not start the second half."
	)
	_release_triggers(state)
	_press_trigger(state, -1)
	_expect(
		_rotation_is_advancing(state), "A re-armed same-trigger press must start the second half."
	)


func _test_opposite_trigger_does_not_complete_rotation() -> void:
	var state := _grabbed_flight_state(false)
	_complete_half_turn(state, -1)
	_release_triggers(state)
	_press_trigger(state, 1)
	_expect(
		state.rotation_gesture_phase == JumpState.RotationGesturePhase.WAITING_SECOND_PRESS,
		"The opposite trigger must not complete an active spin."
	)
	_expect(
		is_equal_approx(state.spin_progress, PI), "The opposite trigger must preserve 180 degrees."
	)


func _test_held_trigger_does_not_repeat() -> void:
	var state := _grabbed_flight_state(false)
	_complete_half_turn(state, 1)
	for _tick in 60:
		_step_spin(state, 1, false, true)
	_expect(is_equal_approx(state.spin_progress, PI), "Holding RT must not start the second half.")
	_expect(state.completed_rotations == 0, "Holding a trigger must not count a rotation.")


func _test_second_pair_counts_again() -> void:
	var state := _grabbed_flight_state(false)
	_complete_rotation(state, -1)
	_release_triggers(state)
	_complete_rotation(state, 1)
	_expect(state.completed_rotations == 2, "A second trigger pair must count a second rotation.")
	_expect(
		state.trick_tracker.completed_rotations == 2,
		"The trick tracker must count opposite completed turns independently."
	)


func _test_faster_takeoff_rotates_faster() -> void:
	var slow := _takeoff_state(150.0)
	var fast := _takeoff_state(500.0)
	_expect(fast.rotation_rate > slow.rotation_rate, "Faster takeoff must set a faster spin rate.")
	_start_grab(slow, false)
	_start_grab(fast, false)
	_press_trigger(slow, -1)
	_press_trigger(fast, -1)
	for _tick in 8:
		_step_spin(slow, -1, false, true)
		_step_spin(fast, -1, false, true)
	_expect(fast.spin_progress > slow.spin_progress, "Faster takeoff must advance a spin faster.")


func _test_rotation_requires_active_grab() -> void:
	var state := _flight_state()
	var input := RiderInputFrameScene.new()
	input.spin_lt_pressed = true
	input.spin_lt_just_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(is_zero_approx(state.spin_progress), "LT without an active grab must do nothing.")
	_expect(state.spin_direction == 0, "Spin input without a grab must not select a direction.")


func _test_early_grab_release_freezes_incomplete_rotation() -> void:
	var state := _grabbed_flight_state(false)
	_press_trigger(state, -1)
	for _tick in 5:
		_step_spin(state, -1, false, true)
	var released_progress := state.spin_progress
	var input := RiderInputFrameScene.new()
	input.spin_lt_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	for _tick in 10:
		_simulation.step(state, RiderInputFrameScene.new(), _course, _tuning, DELTA)
	_expect(state.rotation_incomplete, "Grab release during a half-turn must record incompletion.")
	_expect(
		is_equal_approx(state.spin_progress, released_progress),
		"An incomplete spin must freeze at its release progress."
	)


func _test_rotation_does_not_change_trajectory_or_pitch() -> void:
	var neutral := _grabbed_flight_state(false)
	var spinning := _grabbed_flight_state(false)
	var takeoff_pitch := spinning.orientation
	_step_spin(neutral)
	_press_trigger(spinning, 1)
	for _tick in 12:
		_step_spin(neutral)
		_step_spin(spinning, 1, false, true)
	_expect(
		Vector2(neutral.course_progress, neutral.vertical_position).is_equal_approx(
			Vector2(spinning.course_progress, spinning.vertical_position)
		),
		"Horizontal spin input must not change the ballistic trajectory."
	)
	_expect(
		is_equal_approx(spinning.orientation, takeoff_pitch), "A spin must not change rider pitch."
	)


func _test_takeoff_resets_spin_state() -> void:
	var state := RiderStateScene.new()
	state.course_progress = 99.0
	state.vertical_position = 0.0
	state.ground_velocity = Vector2(300.0, 0.0)
	state.has_ground_intent = true
	state.spin_direction = -1
	state.spin_progress = PI
	state.rotation_incomplete = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(
		state.spin_direction == 0 and is_zero_approx(state.spin_progress),
		"Takeoff must reset spin."
	)
	_expect(
		not state.rotation_incomplete and state.spin_rearmed,
		"Takeoff must re-arm clean spin state."
	)


func _test_directional_view_clips() -> void:
	var skier := SkierViewScene.new()
	var snowboarder := SnowboarderViewScene.new()
	skier._ready()
	snowboarder._ready()
	var skier_frames := (skier.get_node("Sprite") as AnimatedSprite2D).sprite_frames
	var snowboarder_frames := (snowboarder.get_node("Sprite") as AnimatedSprite2D).sprite_frames
	for animation: StringName in [
		&"spin_regular_left", &"spin_regular_right", &"spin_tweak_left", &"spin_tweak_right"
	]:
		_expect(skier_frames.has_animation(animation), "Missing skier clip %s." % animation)
		_expect(
			skier_frames.get_frame_count(animation) == 8,
			"Skier clip %s needs 8 frames." % animation
		)
	for animation: StringName in [
		&"spin_regular_backside",
		&"spin_regular_frontside",
		&"spin_tweak_backside",
		&"spin_tweak_frontside",
	]:
		_expect(
			snowboarder_frames.has_animation(animation), "Missing snowboarder clip %s." % animation
		)
		_expect(
			snowboarder_frames.get_frame_count(animation) == 8,
			"Snowboarder clip %s needs 8 frames." % animation
		)
	skier.free()
	snowboarder.free()


func _complete_rotation(state: RiderState, direction: int) -> void:
	_complete_half_turn(state, direction)
	_release_triggers(state)
	_complete_half_turn(state, direction)


func _complete_half_turn(state: RiderState, direction: int) -> void:
	_press_trigger(state, direction)
	for _tick in 120:
		if not _rotation_is_advancing(state):
			return
		_step_spin(state, direction, false, true)
	_expect(false, "A half-turn did not finish within the expected time.")


func _rotation_is_advancing(state: RiderState) -> bool:
	return (
		state.rotation_gesture_phase
		in [
			JumpState.RotationGesturePhase.ROTATING_FIRST_HALF,
			JumpState.RotationGesturePhase.ROTATING_SECOND_HALF,
		]
	)


func _grabbed_flight_state(tweak: bool) -> RiderState:
	var state := _flight_state()
	state.rotation_rate = TAU
	_start_grab(state, tweak)
	return state


func _start_grab(state: RiderState, tweak: bool) -> void:
	var input := RiderInputFrameScene.new()
	if tweak:
		input.tweak_pressed = true
		input.tweak_just_pressed = true
	else:
		input.grab_pressed = true
		input.grab_just_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)


func _press_trigger(state: RiderState, direction: int) -> void:
	_step_spin(state, direction, true, true)


func _release_triggers(state: RiderState) -> void:
	_step_spin(state)


func _step_spin(
	state: RiderState, direction := 0, just_pressed := false, trigger_held := false
) -> void:
	var input := RiderInputFrameScene.new()
	if state.trick_tracker.grab_active:
		if state.tweak_active:
			input.tweak_pressed = true
		else:
			input.grab_pressed = true
	if direction < 0:
		input.spin_lt_pressed = trigger_held
		input.spin_lt_just_pressed = just_pressed
	elif direction > 0:
		input.spin_rt_pressed = trigger_held
		input.spin_rt_just_pressed = just_pressed
	_simulation.step(state, input, _course, _tuning, DELTA)


func _takeoff_state(speed: float) -> RiderState:
	var state := RiderStateScene.new()
	state.course_progress = 99.0
	state.vertical_position = 0.0
	state.ground_velocity = Vector2(speed, 0.0)
	state.has_ground_intent = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(state.run_phase == RiderState.RunPhase.FLIGHT, "Rotation-rate test must reach takeoff.")
	return state


func _flight_state() -> RiderState:
	var state := RiderStateScene.new()
	state.run_phase = RiderState.RunPhase.FLIGHT
	state.active_route_index = 1
	state.course_progress = 100.0
	state.vertical_position = 0.0
	state.ground_position = Vector2(100.0, 0.0)
	state.course_speed = 10.0
	state.takeoff_velocity = Vector2(10.0, 0.0)
	state.orientation = 0.25
	state.trick_tracker.reset(state.orientation)
	return state


func _test_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	var approach := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	course.approach_paths = [approach, approach, approach]
	var landing := PackedVector2Array([Vector2(1000, 1000), Vector2(2000, 1000)])
	course.landing_paths = [landing, landing, landing]
	course.flight_abandon_y = 2000.0
	return course


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
