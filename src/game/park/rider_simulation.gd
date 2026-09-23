## Advances one rider according to the authoritative run phase.
## Flight and landing integration are added incrementally behind this dispatcher.
class_name RiderSimulation
extends RefCounted

const APPROACH_PATH_SWITCH_SPEED := 2.5
const COAST_PREDICTION_STEP := 1.0 / 60.0


func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	match state.run_phase:
		RiderState.RunPhase.APPROACH:
			_step_approach(state, input, course, tuning, delta)
		RiderState.RunPhase.FLIGHT:
			_step_flight(state, course, tuning, delta)
		RiderState.RunPhase.LANDING, RiderState.RunPhase.COMPLETE:
			return


func _step_approach(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if (
		state.course_progress < course.route_start_at(state.approach_path_position)
		or state.course_progress > _approach_end(state, course)
	):
		_stop_at_approach_edge(state)
		return

	state.run_phase = RiderState.RunPhase.APPROACH
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
	var remaining_delta := _move_within_approach(state, course, delta)
	_sync_ground_state(state, course)
	if remaining_delta >= 0.0:
		_cross_approach_endpoint(state, course)
		if state.run_phase == RiderState.RunPhase.FLIGHT and remaining_delta > 0.0:
			_step_flight(state, course, tuning, remaining_delta)


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
	var gradient := course.route_gradient_at(state.course_progress, state.approach_path_position)
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


func _move_within_approach(state: RiderState, course: ParkCourse, delta: float) -> float:
	var next_position := (
		Vector2(state.course_progress, state.lane_position) + state.ground_velocity * delta
	)
	var approach_end := _approach_end(state, course)
	if next_position.x >= approach_end and state.ground_velocity.x > 0.0:
		var time_to_endpoint := (approach_end - state.course_progress) / state.ground_velocity.x
		state.course_progress = approach_end
		state.lane_position = 0.0
		return maxf(delta - time_to_endpoint, 0.0)
	state.course_progress = clampf(
		next_position.x, course.route_start_at(state.approach_path_position), approach_end
	)
	state.lane_position = 0.0
	if not is_equal_approx(state.course_progress, next_position.x):
		_stop_at_approach_edge(state)
	return -1.0


func _cross_approach_endpoint(state: RiderState, course: ParkCourse) -> void:
	var route_index := clampi(
		roundi(state.approach_path_position), 0, course.approach_paths.size() - 1
	)
	state.active_route_index = route_index
	state.approach_path_target = route_index
	state.approach_path_position = float(route_index)
	var lip: Vector2 = course.approach_paths[route_index][-1]
	state.course_progress = lip.x
	state.lane_position = 0.0
	state.ground_position = Vector2(lip.x, 0.0)
	state.vertical_position = lip.y
	_clear_approach_controls(state)
	if course.route_kinds[route_index] == ParkCourse.RouteKind.FLIGHT:
		_begin_flight(state, course, route_index)
	else:
		state.run_phase = RiderState.RunPhase.LANDING
		state.current_surface_id = &"landing"


func _begin_flight(state: RiderState, course: ParkCourse, route_index: int) -> void:
	var lip_progress := state.course_progress
	var tangent := course.route_lip_tangent(route_index)
	var normal := course.route_lip_normal(route_index)
	var surface_speed := state.ground_velocity.x / maxf(tangent.x, 0.001)
	var takeoff_velocity := tangent * surface_speed
	state.run_phase = RiderState.RunPhase.FLIGHT
	state.current_surface_id = &"flight"
	state.takeoff_position = Vector2(lip_progress, state.vertical_position)
	state.takeoff_velocity = takeoff_velocity
	state.takeoff_course_speed = takeoff_velocity.x
	state.takeoff_lane_speed = state.ground_velocity.y
	state.takeoff_vertical_speed = takeoff_velocity.y
	state.takeoff_pop_impulse = 0.0
	state.takeoff_tangent = tangent
	state.takeoff_normal = normal
	state.release_deadline_y = state.vertical_position
	state.approach_speed = takeoff_velocity.length()
	state.approach_speed_captured = true
	state.course_speed = takeoff_velocity.x
	state.lane_speed = state.ground_velocity.y
	state.vertical_speed = takeoff_velocity.y
	state.orientation = tangent.angle()
	state.angular_velocity = 0.0
	state.airtime = 0.0
	state.landing_resolved = false
	state.trick_tracker.reset(state.orientation)


func _step_flight(state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	var flight_delta := delta * tuning.air_time_scale
	state.vertical_speed += tuning.gravity * flight_delta
	var drag_factor := maxf(0.0, 1.0 - tuning.air_drag * flight_delta)
	state.course_speed *= drag_factor
	state.lane_speed *= drag_factor
	state.vertical_speed *= drag_factor
	state.course_progress += state.course_speed * flight_delta
	state.lane_position += state.lane_speed * flight_delta
	state.vertical_position += state.vertical_speed * flight_delta
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = Vector2(state.course_speed, state.lane_speed)
	state.airtime += flight_delta
	if _flight_is_out_of_bounds(state, course, tuning):
		_end_missed_flight(state)


func _flight_is_out_of_bounds(state: RiderState, course: ParkCourse, tuning: RiderTuning) -> bool:
	var landing_path := course.landing_paths[state.active_route_index]
	if state.course_progress > landing_path[-1].x:
		return true
	var maximum_landing_y := landing_path[0].y
	for point in landing_path:
		maximum_landing_y = maxf(maximum_landing_y, point.y)
	return state.vertical_position > maximum_landing_y + tuning.flight_bounds_margin


func _end_missed_flight(state: RiderState) -> void:
	state.run_phase = RiderState.RunPhase.LANDING
	state.landing_outcome = RiderState.LandingOutcome.CRASH
	state.current_surface_id = &"landing"
	state.landing_resolved = true
	state.landing_label = "CRASH"
	state.landing_quality = 0.0
	state.landing_position = Vector2(state.course_progress, state.vertical_position)
	state.ground_velocity = Vector2.ZERO
	state.course_speed = 0.0
	state.lane_speed = 0.0
	state.vertical_speed = 0.0


func _stop_at_approach_edge(state: RiderState) -> void:
	state.ground_velocity = Vector2.ZERO
	_clear_approach_controls(state)


func _clear_approach_controls(state: RiderState) -> void:
	state.has_ground_intent = false
	state.tuck_active = false
	state.brake_active = false
	state.edge_active = false


func _approach_end(state: RiderState, course: ParkCourse) -> float:
	return course.route_end_at(state.approach_path_position)


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
		state.approach_path_target = clampi(requested_path, 0, course.approach_paths.size() - 1)
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
	var simulated_route_position := state.approach_path_position
	while remaining_transition_time > 0.0:
		var step := minf(COAST_PREDICTION_STEP, remaining_transition_time)
		simulated_route_position = move_toward(
			simulated_route_position, float(requested_path), APPROACH_PATH_SWITCH_SPEED * step
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
