## Advances the rider through the authored approach zone only.
## Future jump zones own their rules; a RunSimulation dispatcher will select them.
class_name ApproachSimulation
extends RefCounted


func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var phase_path := course.phase_path_at(state.course_progress)
	if phase_path == null or phase_path.phase != ParkPhasePath.Phase.APPROACH:
		_stop_at_approach_edge(state)
		return

	state.phase = RiderState.Phase.GROUNDED
	state.current_control_zone_id = phase_path.id
	state.control_mode = RiderState.ControlMode.APPROACH
	state.current_surface_id = StringName()
	var steering_heading := input.heading
	# The approach only permits downhill and across-slope steering, never uphill travel.
	steering_heading.x = maxf(steering_heading.x, 0.0)
	if not steering_heading.is_zero_approx():
		steering_heading = steering_heading.normalized()
	var downhill_held := input.heading.x > 0.0
	var left_braking := input.heading.x < 0.0
	state.tuck_active = input.tuck_pressed
	state.brake_active = input.brake_pressed or left_braking
	state.edge_active = (
		input.edge_pressed or (not downhill_held and not state.ground_velocity.is_zero_approx())
	)

	if not steering_heading.is_zero_approx():
		state.desired_heading = steering_heading
		if not state.has_ground_intent and downhill_held:
			state.has_ground_intent = true
	if not state.has_ground_intent:
		_sync_ground_state(state, course)
		return

	_turn_toward_input(state, steering_heading, input, tuning, delta)
	_apply_approach_forces(
		state, input, course, phase_path, tuning, delta, downhill_held, left_braking
	)
	_move_within_approach(state, course, phase_path, delta)
	_sync_ground_state(state, course)


func _turn_toward_input(
	state: RiderState,
	steering_heading: Vector2,
	input: RiderInputFrame,
	tuning: RiderTuning,
	delta: float
) -> void:
	if steering_heading.is_zero_approx():
		return
	var turn_rate := tuning.maximum_turn_rate
	if input.tuck_pressed:
		turn_rate *= tuning.tuck_steering_multiplier
	if input.edge_pressed:
		turn_rate *= tuning.strong_edge_turn_multiplier
	if input.brake_pressed:
		turn_rate *= tuning.brake_turn_multiplier
	state.heading = state.heading.rotated(
		clampf(state.heading.angle_to(steering_heading), -turn_rate * delta, turn_rate * delta)
	)


func _apply_approach_forces(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	phase_path: ParkPhasePath,
	tuning: RiderTuning,
	delta: float,
	downhill_held: bool,
	left_braking: bool
) -> void:
	var fall_line := phase_path.fall_line_direction.normalized()
	var gradient := course.gradient_at(state.course_progress, state.lane_position)
	# Gravity along the slope: downhill pitches accelerate, uphill pitches
	# decelerate. Capped at slope_gravity on steep faces.
	state.ground_velocity.x += (
		tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient) * delta
	)
	if downhill_held:
		# Pumping only works on flat and downhill ground. Uphill the rider
		# coasts on entry momentum, so slow entries stall instead of creeping up.
		var pump_scale := clampf(
			1.0 + gradient / maxf(tuning.uphill_pump_cut_gradient, 0.01), 0.0, 1.0
		)
		state.ground_velocity += fall_line * tuning.fall_line_acceleration * pump_scale * delta
	var speed := state.ground_velocity.length()
	# Preserve backward slides so a stalled rider rolls back down instead of
	# the steering snapping the velocity forward again.
	if speed > 0.0 and state.ground_velocity.x >= 0.0:
		state.ground_velocity = state.ground_velocity.move_toward(
			state.heading * speed, tuning.steering_response * delta
		)
	var drag := tuning.snow_resistance * phase_path.snow_resistance_multiplier
	drag += tuning.aerodynamic_drag * speed * speed
	drag += tuning.edge_drag * phase_path.edge_grip_multiplier * absf(state.heading.y)
	if input.tuck_pressed:
		drag *= tuning.tuck_drag_multiplier
	if input.edge_pressed:
		drag += tuning.strong_edge_drag * phase_path.edge_grip_multiplier
	if input.brake_pressed or left_braking:
		drag += tuning.brake_drag
	if not downhill_held:
		drag += tuning.release_carve_drag
	state.ground_velocity = state.ground_velocity.move_toward(Vector2.ZERO, drag * delta)
	if state.ground_velocity.length() <= 1.0:
		_stop_at_approach_edge(state)


func _move_within_approach(
	state: RiderState, course: ParkCourse, phase_path: ParkPhasePath, delta: float
) -> void:
	var next_position := (
		Vector2(state.course_progress, state.lane_position) + state.ground_velocity * delta
	)
	state.course_progress = clampf(
		next_position.x, phase_path.progress_start(), phase_path.progress_end()
	)
	var lane_bounds := course.lane_bounds_at(state.course_progress)
	state.lane_position = clampf(next_position.y, lane_bounds.x, lane_bounds.y)
	if not is_equal_approx(state.course_progress, next_position.x):
		_stop_at_approach_edge(state)


func _stop_at_approach_edge(state: RiderState) -> void:
	state.ground_velocity = Vector2.ZERO
	state.has_ground_intent = false
	state.tuck_active = false
	state.brake_active = false
	state.edge_active = false


func _sync_ground_state(state: RiderState, course: ParkCourse) -> void:
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.vertical_position = course.surface_y_at(state.course_progress, state.lane_position)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = state.ground_velocity.y
