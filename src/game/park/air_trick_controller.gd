## Handles grab and spin state while a rider is airborne.
class_name AirTrickController
extends RefCounted


func begin(state: RiderState, takeoff_speed: float, tuning: RiderTuning) -> void:
	state.jump.angular_velocity = 0.0
	state.jump.spin_gesture.reset()
	_sync_spin_gesture(state)
	state.jump.rotation_rate = _rotation_rate_for_speed(takeoff_speed, tuning)
	state.jump.completed_rotations = 0
	state.jump.required_rotations = _required_rotations_for_speed(takeoff_speed, tuning)
	state.jump.rotation_incomplete = false
	state.jump.airtime = 0.0
	state.jump.grab_reach_active = false
	state.jump.tweak_active = false
	state.jump.grab_started_airtime = -1.0
	state.jump.grab_active_at_deadline = false
	state.jump.grab_active_at_landing = false
	state.jump.grab_released_after_deadline = false
	state.jump.trick_tracker.reset(state.jump.orientation)


func update_input(state: RiderState, input: RiderInputFrame, tuning: RiderTuning) -> void:
	_update_grab_input(state, input, tuning)
	_update_rotation_gesture_input(state, input)


func advance(state: RiderState, tuning: RiderTuning, delta: float) -> void:
	_advance_grab(state, tuning, delta)
	_advance_rotation(state, delta)


func _update_grab_input(state: RiderState, input: RiderInputFrame, tuning: RiderTuning) -> void:
	if state.jump.trick_tracker.grab_active:
		var active_button_held := (
			input.tweak_pressed if state.jump.tweak_active else input.grab_pressed
		)
		if not active_button_held:
			_release_grab(state, tuning)
		return
	if input.grab_just_pressed and input.grab_pressed:
		_start_grab(state, false)
	elif input.tweak_just_pressed and input.tweak_pressed:
		_start_grab(state, true)


func _start_grab(state: RiderState, tweak: bool) -> void:
	state.jump.trick_tracker.start_grab()
	state.jump.grab_started_airtime = state.jump.airtime
	if state.jump.release_deadline_crossed:
		state.jump.grab_released_after_deadline = true
	state.jump.grab_reach_active = not tweak
	state.jump.tweak_active = tweak


func _release_grab(state: RiderState, tuning: RiderTuning) -> void:
	state.jump.trick_tracker.release_grab(state.jump.airtime, tuning.minimum_grab_duration)
	if state.jump.release_deadline_crossed:
		state.jump.grab_released_after_deadline = true
	state.jump.grab_reach_active = false
	state.jump.tweak_active = false


func _advance_grab(state: RiderState, tuning: RiderTuning, delta: float) -> void:
	state.jump.trick_tracker.step_grab(delta, state.jump.tweak_active)
	if (
		state.jump.grab_reach_active
		and (
			state.jump.airtime + delta - state.jump.grab_started_airtime
			>= tuning.grab_reach_duration
		)
	):
		state.jump.grab_reach_active = false


func _update_rotation_gesture_input(state: RiderState, input: RiderInputFrame) -> void:
	var gesture := state.jump.spin_gesture
	var was_advancing := gesture.is_advancing()
	gesture.update_input(
		input.spin_lt_pressed,
		input.spin_rt_pressed,
		input.spin_lt_just_pressed,
		input.spin_rt_just_pressed,
		state.jump.trick_tracker.grab_active,
		state.jump.tweak_active,
		PI,
		TAU
	)
	if not state.jump.trick_tracker.grab_active and was_advancing:
		state.jump.rotation_incomplete = true
		state.jump.angular_velocity = 0.0
	_sync_spin_gesture(state)


func _advance_rotation(state: RiderState, delta: float) -> void:
	var gesture := state.jump.spin_gesture
	if not state.jump.trick_tracker.grab_active or not gesture.is_advancing():
		state.jump.angular_velocity = 0.0
		return
	state.jump.angular_velocity = state.jump.rotation_rate * gesture.direction
	var completed_rotation := gesture.advance(delta, state.jump.rotation_rate)
	state.jump.angular_velocity = 0.0
	if completed_rotation:
		state.jump.completed_rotations += 1
		state.jump.trick_tracker.complete_rotation(gesture.direction)
	_sync_spin_gesture(state)


func _sync_spin_gesture(state: RiderState) -> void:
	var gesture := state.jump.spin_gesture
	state.jump.rotation_gesture_phase = gesture.phase
	state.jump.spin_direction = gesture.direction
	state.jump.spin_rearmed = gesture.rearmed
	state.jump.spin_progress = gesture.progress
	state.jump.spin_target = gesture.target
	state.jump.spin_grab_tweak = gesture.tweak


func _rotation_rate_for_speed(takeoff_speed: float, tuning: RiderTuning) -> float:
	var speed_range := tuning.max_rotation_speed - tuning.min_rotation_speed
	var speed_factor := 0.0
	if not is_zero_approx(speed_range):
		speed_factor = clampf((takeoff_speed - tuning.min_rotation_speed) / speed_range, 0.0, 1.0)
	elif takeoff_speed >= tuning.max_rotation_speed:
		speed_factor = 1.0
	return lerpf(tuning.min_rotation_rate, tuning.max_rotation_rate, speed_factor)


func _required_rotations_for_speed(takeoff_speed: float, tuning: RiderTuning) -> int:
	var excess_speed := maxf(0.0, takeoff_speed - tuning.safe_no_rotation_speed)
	var speed_per_rotation := maxf(tuning.speed_per_required_rotation, 0.001)
	return ceili(excess_speed / speed_per_rotation)
