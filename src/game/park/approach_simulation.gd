## Advances the rider through the authored approach zone only.
## Future jump zones own their rules; a RunSimulation dispatcher will select them.
class_name ApproachSimulation
extends RefCounted

const APPROACH_PATH_SWITCH_SPEED := 2.5
const COAST_PREDICTION_STEP := 1.0 / 60.0

func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if (
		state.course_progress < course.spawn_progress()
		or state.course_progress > _approach_end(course)
	):
		_stop_at_approach_edge(state)
		return

	state.phase = RiderState.Phase.GROUNDED
	state.current_control_zone_id = &"approach"
	state.control_mode = RiderState.ControlMode.APPROACH
	state.current_surface_id = StringName()
	var steering_heading := Vector2(input.heading.x, 0.0)
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
	_update_approach_path(state, input, course, tuning, delta)

	if not steering_heading.is_zero_approx():
		state.desired_heading = steering_heading
		if not state.has_ground_intent and downhill_held:
			state.has_ground_intent = true
	if not state.has_ground_intent:
		_sync_ground_state(state, course)
		return

	_turn_toward_input(state, steering_heading, input, tuning, delta)
	_apply_approach_forces(state, input, course, tuning, delta, downhill_held, left_braking)
	_move_within_approach(state, course, delta)
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
	tuning: RiderTuning,
	delta: float,
	downhill_held: bool,
	left_braking: bool
) -> void:
	var fall_line := Vector2.RIGHT
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
	var drag := tuning.snow_resistance
	drag += tuning.aerodynamic_drag * speed * speed
	drag += tuning.edge_drag * absf(state.heading.y)
	if input.tuck_pressed:
		drag *= tuning.tuck_drag_multiplier
	if input.edge_pressed:
		drag += tuning.strong_edge_drag
	if input.brake_pressed or left_braking:
		drag += tuning.brake_drag
	if not downhill_held:
		drag += tuning.release_carve_drag
	state.ground_velocity = state.ground_velocity.move_toward(Vector2.ZERO, drag * delta)
	if state.ground_velocity.length() <= 1.0:
		_stop_at_approach_edge(state)


func _move_within_approach(state: RiderState, course: ParkCourse, delta: float) -> void:
	var next_position := (
		Vector2(state.course_progress, state.lane_position) + state.ground_velocity * delta
	)
	state.course_progress = clampf(next_position.x, course.spawn_progress(), _approach_end(course))
	state.lane_position = 0.0
	if not is_equal_approx(state.course_progress, next_position.x):
		_stop_at_approach_edge(state)


func _stop_at_approach_edge(state: RiderState) -> void:
	state.ground_velocity = Vector2.ZERO
	state.has_ground_intent = false
	state.tuck_active = false
	state.brake_active = false
	state.edge_active = false


func _approach_end(course: ParkCourse) -> float:
	return course.approach_path[-1].x


func _sync_ground_state(state: RiderState, course: ParkCourse) -> void:
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.vertical_position = course.route_surface_y_at(
		state.course_progress, state.approach_path_position
	)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = state.ground_velocity.y


func _update_approach_path(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if course.approach_paths.size() != 3:
		return
	var requested_path := clampi(
		state.approach_path_target + input.approach_path_change, 0, course.approach_paths.size() - 1
	)
	if (
		requested_path != state.approach_path_target
		and _can_coast_through_path_change(state, requested_path, course, tuning)
	):
		state.approach_path_target = clampi(
			requested_path, 0, course.approach_paths.size() - 1
		)
	state.approach_path_position = move_toward(
		state.approach_path_position,
		float(state.approach_path_target),
		APPROACH_PATH_SWITCH_SPEED * delta
	)


func _can_coast_through_path_change(
	state: RiderState, requested_path: int, course: ParkCourse, tuning: RiderTuning
) -> bool:
	var remaining_transition_time := (
		absf(float(requested_path) - state.approach_path_position) / APPROACH_PATH_SWITCH_SPEED
	)
	var simulated_progress := state.course_progress
	var simulated_speed := maxf(state.ground_velocity.x, 0.0)
	while remaining_transition_time > 0.0:
		var step := minf(COAST_PREDICTION_STEP, remaining_transition_time)
		var gradient := course.gradient_at(simulated_progress)
		simulated_speed += (
			tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient) * step
		)
		var drag := (
			tuning.snow_resistance
			+ tuning.aerodynamic_drag * simulated_speed * simulated_speed
			+ tuning.release_carve_drag
		)
		simulated_speed = move_toward(simulated_speed, 0.0, drag * step)
		if simulated_speed <= 1.0:
			return false
		simulated_progress += simulated_speed * step
		remaining_transition_time -= step
	return true
