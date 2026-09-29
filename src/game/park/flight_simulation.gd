## Launches and advances airborne riders, including grab and rotation gestures.
class_name FlightSimulation
extends RefCounted


func begin(state: RiderState, course: ParkCourse, tuning: RiderTuning, route_index: int) -> void:
	var lip_progress := state.kinematics.course_progress
	var tangent := course.route_lip_tangent(route_index)
	var normal := course.route_lip_normal(route_index)
	var surface_speed := state.kinematics.ground_velocity.x / maxf(tangent.x, 0.001)
	var takeoff_velocity := tangent * surface_speed
	if takeoff_velocity.y < 0.0:
		takeoff_velocity.y *= tuning.flight_arc_height_multiplier
	takeoff_velocity.x = minf(takeoff_velocity.x, tuning.maximum_takeoff_course_speed)
	var charge_fraction := 0.0
	if tuning.maximum_compression > 0.0:
		charge_fraction = clampf(
			state.jump.compression_amount / tuning.maximum_compression, 0.0, 1.0
		)
	var pop_impulse := (
		charge_fraction * state.jump.compression_release_quality * tuning.maximum_pop_impulse
	)
	takeoff_velocity += normal * pop_impulse
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.run.current_surface_id = &"flight"
	state.jump.takeoff_position = Vector2(lip_progress, state.kinematics.vertical_position)
	state.jump.takeoff_velocity = takeoff_velocity
	state.jump.takeoff_course_speed = takeoff_velocity.x
	state.jump.takeoff_lane_speed = state.kinematics.ground_velocity.y
	state.jump.takeoff_vertical_speed = takeoff_velocity.y
	state.jump.takeoff_pop_impulse = pop_impulse
	state.jump.takeoff_tangent = tangent
	state.jump.takeoff_normal = normal
	state.jump.release_deadline_y = state.kinematics.vertical_position
	state.jump.approach_speed = takeoff_velocity.length()
	state.jump.approach_speed_captured = true
	state.kinematics.course_speed = takeoff_velocity.x
	state.kinematics.lane_speed = state.kinematics.ground_velocity.y
	state.kinematics.vertical_speed = takeoff_velocity.y
	state.jump.orientation = tangent.angle()
	state.jump.angular_velocity = 0.0
	state.jump.rotation_gesture_phase = JumpState.RotationGesturePhase.WAITING_DIRECTION
	state.jump.spin_direction = 0
	state.jump.spin_rearmed = true
	state.jump.spin_progress = 0.0
	state.jump.spin_target = 0.0
	state.jump.spin_grab_tweak = false
	state.jump.rotation_rate = _rotation_rate_for_speed(takeoff_velocity.length(), tuning)
	state.jump.completed_rotations = 0
	state.jump.rotation_incomplete = false
	state.jump.airtime = 0.0
	state.jump.grab_reach_active = false
	state.jump.tweak_active = false
	state.jump.grab_started_airtime = -1.0
	state.jump.grab_active_at_landing = false
	state.jump.landing_resolved = false
	state.jump.trick_tracker.reset(state.jump.orientation)
	state.jump.trick_call = ""


func step(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float,
	landing: LandingSimulation
) -> float:
	var flight_delta := delta * tuning.air_time_scale
	_update_grab_input(state, input, tuning)
	_update_rotation_gesture_input(state, input)
	var previous_position := Vector2(
		state.kinematics.course_progress, state.kinematics.vertical_position
	)
	var previous_lane_position := state.kinematics.lane_position
	var previous_course_speed := state.kinematics.course_speed
	var previous_lane_speed := state.kinematics.lane_speed
	var previous_vertical_speed := state.kinematics.vertical_speed
	var next_vertical_speed := (
		previous_vertical_speed
		+ tuning.gravity * tuning.flight_arc_height_multiplier * flight_delta
	)
	var drag_factor := maxf(0.0, 1.0 - tuning.air_drag * flight_delta)
	var next_course_speed := previous_course_speed * drag_factor
	var next_lane_speed := previous_lane_speed * drag_factor
	next_vertical_speed *= drag_factor
	var next_position := (
		previous_position + Vector2(next_course_speed, next_vertical_speed) * flight_delta
	)
	var next_lane_position := previous_lane_position + next_lane_speed * flight_delta
	var contact := course.landing_swept_terrain_intersection(
		previous_position, next_position, state.kinematics.active_route_index
	)
	if not contact.is_empty():
		var contact_time := float(contact["time"])
		state.kinematics.course_speed = lerpf(
			previous_course_speed, next_course_speed, contact_time
		)
		state.kinematics.lane_speed = lerpf(previous_lane_speed, next_lane_speed, contact_time)
		state.kinematics.vertical_speed = lerpf(
			previous_vertical_speed, next_vertical_speed, contact_time
		)
		state.kinematics.lane_position = lerpf(
			previous_lane_position, next_lane_position, contact_time
		)
		_advance_grab(state, tuning, flight_delta * contact_time)
		_advance_rotation(state, flight_delta * contact_time)
		state.jump.airtime += flight_delta * contact_time
		landing.resolve_contact(state, contact)
		return delta * (1.0 - contact_time)
	state.kinematics.course_speed = next_course_speed
	state.kinematics.lane_speed = next_lane_speed
	state.kinematics.vertical_speed = next_vertical_speed
	state.kinematics.course_progress = next_position.x
	state.kinematics.lane_position = next_lane_position
	state.kinematics.vertical_position = next_position.y
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.ground_velocity = Vector2(
		state.kinematics.course_speed, state.kinematics.lane_speed
	)
	_advance_grab(state, tuning, flight_delta)
	_advance_rotation(state, flight_delta)
	state.jump.airtime += flight_delta
	if _has_overshot_landing(state, course):
		landing.crash(state, tuning)
	elif _should_abandon(state, course):
		landing.begin_abandoned_runout(state, course)
	return -1.0


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
	state.jump.grab_reach_active = not tweak
	state.jump.tweak_active = tweak


func _release_grab(state: RiderState, tuning: RiderTuning) -> void:
	state.jump.trick_tracker.release_grab(state.jump.airtime, tuning.minimum_grab_duration)
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
	if not input.spin_lt_pressed and not input.spin_rt_pressed:
		state.jump.spin_rearmed = true
	if not state.jump.trick_tracker.grab_active:
		if _rotation_is_advancing(state):
			state.jump.rotation_incomplete = true
			state.jump.spin_target = state.jump.spin_progress
		state.jump.rotation_gesture_phase = JumpState.RotationGesturePhase.WAITING_DIRECTION
		state.jump.angular_velocity = 0.0
		return
	match state.jump.rotation_gesture_phase:
		JumpState.RotationGesturePhase.WAITING_DIRECTION:
			if (
				state.jump.spin_rearmed
				and state.jump.spin_direction != 0
				and is_equal_approx(state.jump.spin_progress, TAU)
				and not input.spin_lt_just_pressed
				and not input.spin_rt_just_pressed
			):
				state.jump.spin_direction = 0
				state.jump.spin_progress = 0.0
				state.jump.spin_target = 0.0
			if (
				state.jump.spin_rearmed
				and (input.spin_lt_just_pressed or input.spin_rt_just_pressed)
			):
				state.jump.spin_direction = -1 if input.spin_lt_just_pressed else 1
				state.jump.spin_rearmed = false
				state.jump.spin_progress = 0.0
				state.jump.spin_target = PI
				state.jump.spin_grab_tweak = state.jump.tweak_active
				state.jump.rotation_gesture_phase = (
					JumpState.RotationGesturePhase.ROTATING_FIRST_HALF
				)
		JumpState.RotationGesturePhase.WAITING_SECOND_PRESS:
			var same_trigger_pressed := (
				(input.spin_lt_just_pressed and state.jump.spin_direction < 0)
				or (input.spin_rt_just_pressed and state.jump.spin_direction > 0)
			)
			if state.jump.spin_rearmed and same_trigger_pressed:
				state.jump.spin_rearmed = false
				state.jump.spin_target = TAU
				state.jump.rotation_gesture_phase = (
					JumpState.RotationGesturePhase.ROTATING_SECOND_HALF
				)


func _advance_rotation(state: RiderState, delta: float) -> void:
	if not state.jump.trick_tracker.grab_active or not _rotation_is_advancing(state):
		state.jump.angular_velocity = 0.0
		return
	state.jump.angular_velocity = state.jump.rotation_rate * state.jump.spin_direction
	state.jump.spin_progress = move_toward(
		state.jump.spin_progress, state.jump.spin_target, state.jump.rotation_rate * delta
	)
	if not is_equal_approx(state.jump.spin_progress, state.jump.spin_target):
		return
	state.jump.angular_velocity = 0.0
	if state.jump.rotation_gesture_phase == JumpState.RotationGesturePhase.ROTATING_FIRST_HALF:
		state.jump.rotation_gesture_phase = JumpState.RotationGesturePhase.WAITING_SECOND_PRESS
		return
	state.jump.completed_rotations += 1
	state.jump.trick_tracker.complete_rotation(state.jump.spin_direction)
	state.jump.rotation_gesture_phase = JumpState.RotationGesturePhase.WAITING_DIRECTION


func _rotation_is_advancing(state: RiderState) -> bool:
	return (
		state.jump.rotation_gesture_phase
		in [
			JumpState.RotationGesturePhase.ROTATING_FIRST_HALF,
			JumpState.RotationGesturePhase.ROTATING_SECOND_HALF,
		]
	)


func _rotation_rate_for_speed(takeoff_speed: float, tuning: RiderTuning) -> float:
	var speed_range := tuning.max_rotation_speed - tuning.min_rotation_speed
	var speed_factor := 0.0
	if not is_zero_approx(speed_range):
		speed_factor = clampf((takeoff_speed - tuning.min_rotation_speed) / speed_range, 0.0, 1.0)
	elif takeoff_speed >= tuning.max_rotation_speed:
		speed_factor = 1.0
	return lerpf(tuning.min_rotation_rate, tuning.max_rotation_rate, speed_factor)


func _has_overshot_landing(state: RiderState, course: ParkCourse) -> bool:
	return (
		state.kinematics.course_progress
		> course.landing_end_at(state.kinematics.active_route_index).x
	)


func _should_abandon(state: RiderState, course: ParkCourse) -> bool:
	return (
		state.kinematics.vertical_speed > 0.0
		and (
			state.kinematics.vertical_position
			> course.flight_abandon_trigger_y_at(
				state.kinematics.course_progress, state.kinematics.active_route_index
			)
		)
	)
