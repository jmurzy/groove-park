## Advances a rider across an authored approach and reports unused tick time at the lip.
class_name ApproachSimulation
extends RefCounted

const PATH_SWITCH_SPEED := 2.5
const COAST_PREDICTION_STEP := 1.0 / 60.0


func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> float:
	if (
		(
			state.kinematics.course_progress
			< course.route_start_at(state.kinematics.approach_path_position)
		)
		or state.kinematics.course_progress > _end(state, course)
	):
		_stop_at_edge(state)
		return -1.0

	state.run.run_phase = RiderRunState.RunPhase.APPROACH
	state.run.current_surface_id = StringName()
	var steering_heading := Vector2(input.heading.x, 0.0)
	# The approach only permits downhill and across-slope steering, never uphill travel.
	steering_heading.x = maxf(steering_heading.x, 0.0)
	if not steering_heading.is_zero_approx():
		steering_heading = steering_heading.normalized()
	var downhill_held := input.heading.x > 0.0
	var left_braking := input.heading.x < 0.0
	state.run.tuck_active = input.tuck_pressed
	state.run.brake_active = input.brake_pressed or left_braking
	state.run.edge_active = (
		not downhill_held and not state.kinematics.ground_velocity.is_zero_approx()
	)
	_update_path(state, input, course, tuning, delta)
	_update_compression(state, input, course, tuning, delta)

	if not steering_heading.is_zero_approx():
		state.kinematics.desired_heading = steering_heading
		if not state.run.has_ground_intent and downhill_held:
			state.run.has_ground_intent = true
	if not state.run.has_ground_intent:
		_sync_ground_state(state, course)
		return -1.0

	_turn_toward_input(state, steering_heading, input, tuning, delta)
	_apply_forces(state, input, course, tuning, delta, downhill_held, left_braking)
	var remaining_delta := _move_within_bounds(state, course, delta)
	_sync_ground_state(state, course)
	return remaining_delta


func cross_endpoint(state: RiderState, course: ParkCourse, tuning: RiderTuning) -> int:
	var route_index := clampi(
		roundi(state.kinematics.approach_path_position), 0, course.routes.size() - 1
	)
	state.kinematics.active_route_index = route_index
	state.kinematics.approach_path_target = route_index
	state.kinematics.approach_path_position = float(route_index)
	var lip: Vector2 = course.route_at(route_index).approach_path[-1]
	state.kinematics.course_progress = lip.x
	state.kinematics.lane_position = 0.0
	state.kinematics.ground_position = Vector2(lip.x, 0.0)
	state.kinematics.vertical_position = lip.y
	if state.jump.compression_active:
		release_compression(state, course, tuning, lip.x)
		state.jump.compression_auto_released = true
		state.jump.compression_release_quality = clampf(
			tuning.compression_auto_release_quality, 0.0, 1.0
		)
	_clear_controls(state)
	return route_index


func release_compression(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, release_progress: float
) -> void:
	state.jump.compression_active = false
	state.jump.compression_auto_released = false
	state.jump.compression_release_progress = release_progress
	var window_distance := maxf(tuning.compression_window_distance, 0.0)
	if is_zero_approx(window_distance):
		state.jump.compression_release_quality = (
			1.0 if is_equal_approx(release_progress, _end(state, course)) else 0.0
		)
		return
	state.jump.compression_release_quality = clampf(
		1.0 - (_end(state, course) - release_progress) / window_distance, 0.0, 1.0
	)


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
	if input.brake_pressed:
		turn_rate *= tuning.brake_turn_multiplier
	state.kinematics.heading = state.kinematics.heading.rotated(
		clampf(
			state.kinematics.heading.angle_to(steering_heading),
			-turn_rate * delta,
			turn_rate * delta
		)
	)


func _apply_forces(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float,
	downhill_held: bool,
	left_braking: bool
) -> void:
	var gradient := course.route_gradient_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)
	state.kinematics.ground_velocity.x += (
		tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient) * delta
	)
	if downhill_held:
		var pump_scale := clampf(
			1.0 + gradient / maxf(tuning.uphill_pump_cut_gradient, 0.01), 0.0, 1.0
		)
		state.kinematics.ground_velocity += (
			Vector2.RIGHT * tuning.fall_line_acceleration * pump_scale * delta
		)
	var speed := state.kinematics.ground_velocity.length()
	if speed > 0.0 and state.kinematics.ground_velocity.x >= 0.0:
		state.kinematics.ground_velocity = state.kinematics.ground_velocity.move_toward(
			state.kinematics.heading * speed, tuning.steering_response * delta
		)
	var drag := tuning.snow_resistance + tuning.aerodynamic_drag * speed * speed
	drag += tuning.edge_drag * absf(state.kinematics.heading.y)
	if input.tuck_pressed:
		drag *= tuning.tuck_drag_multiplier
	if input.brake_pressed or left_braking:
		drag += tuning.brake_drag
	if not downhill_held:
		drag += tuning.release_carve_drag
	state.kinematics.ground_velocity = state.kinematics.ground_velocity.move_toward(
		Vector2.ZERO, drag * delta
	)
	if state.kinematics.ground_velocity.length() <= 1.0:
		_stop_at_edge(state)


func _update_compression(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var distance_to_lip := maxf(_end(state, course) - state.kinematics.course_progress, 0.0)
	var in_window := distance_to_lip <= maxf(tuning.compression_window_distance, 0.0)
	if input.pop_pressed and in_window and not state.jump.compression_active:
		state.jump.compression_active = true
		if input.pop_just_pressed:
			state.jump.compression_amount = 0.0
			state.jump.compression_release_progress = -1.0
			state.jump.compression_release_quality = 0.0
			state.jump.compression_auto_released = false
	if state.jump.compression_active and input.pop_pressed:
		state.jump.compression_amount = minf(
			state.jump.compression_amount + tuning.compression_rate * delta,
			maxf(tuning.maximum_compression, 0.0)
		)
	if state.jump.compression_active and input.pop_just_released:
		release_compression(state, course, tuning, state.kinematics.course_progress)


func _move_within_bounds(state: RiderState, course: ParkCourse, delta: float) -> float:
	var next_position := (
		Vector2(state.kinematics.course_progress, state.kinematics.lane_position)
		+ state.kinematics.ground_velocity * delta
	)
	var approach_end := _end(state, course)
	if next_position.x >= approach_end and state.kinematics.ground_velocity.x > 0.0:
		var time_to_endpoint := (
			(approach_end - state.kinematics.course_progress) / state.kinematics.ground_velocity.x
		)
		state.kinematics.course_progress = approach_end
		state.kinematics.lane_position = 0.0
		return maxf(delta - time_to_endpoint, 0.0)
	state.kinematics.course_progress = clampf(
		next_position.x,
		course.route_start_at(state.kinematics.approach_path_position),
		approach_end
	)
	state.kinematics.lane_position = 0.0
	if not is_equal_approx(state.kinematics.course_progress, next_position.x):
		_stop_at_edge(state)
	return -1.0


func _stop_at_edge(state: RiderState) -> void:
	state.kinematics.ground_velocity = Vector2.ZERO
	_clear_controls(state)


func _clear_controls(state: RiderState) -> void:
	state.run.has_ground_intent = false
	state.run.tuck_active = false
	state.run.brake_active = false
	state.run.edge_active = false


func _end(state: RiderState, course: ParkCourse) -> float:
	return course.route_end_at(state.kinematics.approach_path_position)


func _sync_ground_state(state: RiderState, course: ParkCourse) -> void:
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.vertical_position = course.route_surface_y_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)
	state.kinematics.course_speed = state.kinematics.ground_velocity.x
	state.kinematics.lane_speed = state.kinematics.ground_velocity.y


func _update_path(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if course.routes.size() != ParkCourse.ROUTE_COUNT:
		return
	var requested_path := clampi(
		state.kinematics.approach_path_target + input.approach_path_change,
		0,
		course.routes.size() - 1
	)
	if (
		requested_path != state.kinematics.approach_path_target
		and _can_coast_through_path_change(state, requested_path, course, tuning)
	):
		state.kinematics.approach_path_target = requested_path
	state.kinematics.approach_path_position = move_toward(
		state.kinematics.approach_path_position,
		float(state.kinematics.approach_path_target),
		PATH_SWITCH_SPEED * delta
	)


func _can_coast_through_path_change(
	state: RiderState, requested_path: int, course: ParkCourse, tuning: RiderTuning
) -> bool:
	var remaining_transition_time := (
		absf(float(requested_path) - state.kinematics.approach_path_position) / PATH_SWITCH_SPEED
	)
	var simulated_progress := state.kinematics.course_progress
	var simulated_speed := maxf(state.kinematics.ground_velocity.x, 0.0)
	var simulated_route_position := state.kinematics.approach_path_position
	while remaining_transition_time > 0.0:
		var step := minf(COAST_PREDICTION_STEP, remaining_transition_time)
		simulated_route_position = move_toward(
			simulated_route_position, float(requested_path), PATH_SWITCH_SPEED * step
		)
		var gradient := course.route_gradient_at(simulated_progress, simulated_route_position)
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
		if simulated_progress >= course.route_end_at(simulated_route_position):
			return false
		remaining_transition_time -= step
	return true
