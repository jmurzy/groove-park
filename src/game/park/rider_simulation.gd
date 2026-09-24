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
		RiderState.RunPhase.LANDING:
			_step_landing(state, course, tuning, delta)
		RiderState.RunPhase.COMPLETE:
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
	state.edge_active = not downhill_held and not state.ground_velocity.is_zero_approx()
	_update_approach_path(state, input, course, tuning, delta)
	_update_compression(state, input, course, tuning, delta)

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
		_cross_approach_endpoint(state, course, tuning)
		if state.run_phase == RiderState.RunPhase.FLIGHT and remaining_delta > 0.0:
			_step_flight(state, course, tuning, remaining_delta)
		elif state.run_phase == RiderState.RunPhase.LANDING and remaining_delta > 0.0:
			_step_landing(state, course, tuning, remaining_delta)


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
	if input.brake_pressed or left_braking:
		drag += tuning.brake_drag
	if not downhill_held:
		drag += tuning.release_carve_drag
	state.ground_velocity = state.ground_velocity.move_toward(Vector2.ZERO, drag * delta)
	if state.ground_velocity.length() <= 1.0:
		_stop_at_approach_edge(state)


func _update_compression(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var distance_to_lip := maxf(_approach_end(state, course) - state.course_progress, 0.0)
	var in_window := distance_to_lip <= maxf(tuning.compression_window_distance, 0.0)
	if input.pop_pressed and in_window and not state.compression_active:
		state.compression_active = true
		if input.pop_just_pressed:
			state.compression_amount = 0.0
			state.compression_release_progress = -1.0
			state.compression_release_quality = 0.0
			state.compression_auto_released = false
	if state.compression_active and input.pop_pressed:
		state.compression_amount = minf(
			state.compression_amount + tuning.compression_rate * delta,
			maxf(tuning.maximum_compression, 0.0)
		)
	if state.compression_active and input.pop_just_released:
		_release_compression(state, course, tuning, state.course_progress)


func _release_compression(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, release_progress: float
) -> void:
	state.compression_active = false
	state.compression_auto_released = false
	state.compression_release_progress = release_progress
	var window_distance := maxf(tuning.compression_window_distance, 0.0)
	if is_zero_approx(window_distance):
		state.compression_release_quality = (
			1.0 if is_equal_approx(release_progress, _approach_end(state, course)) else 0.0
		)
		return
	state.compression_release_quality = clampf(
		1.0 - (_approach_end(state, course) - release_progress) / window_distance, 0.0, 1.0
	)


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


func _cross_approach_endpoint(state: RiderState, course: ParkCourse, tuning: RiderTuning) -> void:
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
	if state.compression_active:
		_release_compression(state, course, tuning, lip.x)
		state.compression_auto_released = true
		state.compression_release_quality = clampf(
			tuning.compression_auto_release_quality, 0.0, 1.0
		)
	_clear_approach_controls(state)
	if course.route_kinds[route_index] == ParkCourse.RouteKind.FLIGHT:
		_begin_flight(state, course, tuning, route_index)
	else:
		_begin_ground_runout(state, course)


func _begin_flight(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, route_index: int
) -> void:
	var lip_progress := state.course_progress
	var tangent := course.route_lip_tangent(route_index)
	var normal := course.route_lip_normal(route_index)
	var surface_speed := state.ground_velocity.x / maxf(tangent.x, 0.001)
	var takeoff_velocity := tangent * surface_speed
	if takeoff_velocity.y < 0.0:
		takeoff_velocity.y *= tuning.flight_arc_height_multiplier
	takeoff_velocity.x = minf(takeoff_velocity.x, tuning.maximum_takeoff_course_speed)
	var charge_fraction := 0.0
	if tuning.maximum_compression > 0.0:
		charge_fraction = clampf(state.compression_amount / tuning.maximum_compression, 0.0, 1.0)
	var pop_impulse := (
		charge_fraction * state.compression_release_quality * tuning.maximum_pop_impulse
	)
	takeoff_velocity += normal * pop_impulse
	state.run_phase = RiderState.RunPhase.FLIGHT
	state.current_surface_id = &"flight"
	state.takeoff_position = Vector2(lip_progress, state.vertical_position)
	state.takeoff_velocity = takeoff_velocity
	state.takeoff_course_speed = takeoff_velocity.x
	state.takeoff_lane_speed = state.ground_velocity.y
	state.takeoff_vertical_speed = takeoff_velocity.y
	state.takeoff_pop_impulse = pop_impulse
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
	var previous_position := Vector2(state.course_progress, state.vertical_position)
	var previous_lane_position := state.lane_position
	var previous_course_speed := state.course_speed
	var previous_lane_speed := state.lane_speed
	var previous_vertical_speed := state.vertical_speed
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
		previous_position, next_position, state.active_route_index
	)
	if not contact.is_empty():
		var contact_time := float(contact["time"])
		state.course_speed = lerpf(previous_course_speed, next_course_speed, contact_time)
		state.lane_speed = lerpf(previous_lane_speed, next_lane_speed, contact_time)
		state.vertical_speed = lerpf(previous_vertical_speed, next_vertical_speed, contact_time)
		state.lane_position = lerpf(previous_lane_position, next_lane_position, contact_time)
		state.airtime += flight_delta * contact_time
		_resolve_landing_contact(state, contact)
		var remaining_delta := delta * (1.0 - contact_time)
		if remaining_delta > 0.0:
			_step_landing(state, course, tuning, remaining_delta)
		return
	state.course_speed = next_course_speed
	state.lane_speed = next_lane_speed
	state.vertical_speed = next_vertical_speed
	state.course_progress = next_position.x
	state.lane_position = next_lane_position
	state.vertical_position = next_position.y
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = Vector2(state.course_speed, state.lane_speed)
	state.airtime += flight_delta
	if _flight_has_overshot_landing(state, course):
		_end_missed_flight(state, tuning)
	elif _flight_should_abandon(state, course):
		_begin_abandoned_runout(state, course)


func _resolve_landing_contact(state: RiderState, contact: Dictionary) -> void:
	if state.landing_resolved:
		return
	var contact_position: Vector2 = contact["position"]
	var tangent: Vector2 = contact["tangent"]
	var normal: Vector2 = contact["normal"]
	var flight_velocity := Vector2(state.course_speed, state.vertical_speed)
	var landing_speed := maxf(flight_velocity.dot(tangent), 0.0)
	state.run_phase = RiderState.RunPhase.LANDING
	state.landing_outcome = RiderState.LandingOutcome.CLEAN
	state.current_surface_id = &"landing"
	state.landing_resolved = true
	state.landing_label = "CLEAN"
	state.landing_quality = 1.0
	state.landing_position = contact_position
	state.landing_tangent = tangent
	state.landing_normal = normal
	state.landing_velocity_alignment = flight_velocity.normalized().dot(tangent)
	state.landing_normal_impact = absf(flight_velocity.dot(normal))
	state.landing_in_zone = true
	state.course_progress = contact_position.x
	state.vertical_position = contact_position.y
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = Vector2(landing_speed * tangent.x, 0.0)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = 0.0
	state.vertical_speed = 0.0
	state.orientation = tangent.angle()
	state.angular_velocity = 0.0
	state.completion_time_remaining = 0.0


func _begin_ground_runout(state: RiderState, course: ParkCourse) -> void:
	var tangent := course.landing_tangent_at(state.course_progress, state.active_route_index)
	state.takeoff_pop_impulse = 0.0
	state.run_phase = RiderState.RunPhase.LANDING
	state.landing_outcome = RiderState.LandingOutcome.ABANDON
	state.current_surface_id = &"landing"
	state.landing_resolved = true
	state.landing_label = "ABANDON"
	state.landing_quality = 0.0
	state.landing_position = Vector2(state.course_progress, state.vertical_position)
	state.landing_tangent = tangent
	state.landing_normal = Vector2(tangent.y, -tangent.x)
	state.landing_in_zone = false
	state.vertical_speed = 0.0
	state.orientation = tangent.angle()
	state.angular_velocity = 0.0
	state.completion_time_remaining = 0.0


func _begin_abandoned_runout(state: RiderState, course: ParkCourse) -> void:
	var landing_path := course.landing_paths[state.active_route_index]
	var lip_progress := course.approach_paths[state.active_route_index][-1].x
	state.course_progress = clampf(state.course_progress, lip_progress, landing_path[-1].x)
	state.vertical_position = course.flight_abandon_trigger_y_at(
		state.course_progress, state.active_route_index
	)
	var tangent := _abandon_tangent_at(state, course)
	var forward_speed := maxf(Vector2(state.course_speed, state.vertical_speed).dot(tangent), 0.0)
	state.run_phase = RiderState.RunPhase.LANDING
	state.landing_outcome = RiderState.LandingOutcome.ABANDON
	state.current_surface_id = &"abandon"
	state.landing_resolved = true
	state.landing_label = "ABANDON"
	state.landing_quality = 0.0
	state.landing_position = Vector2(state.course_progress, state.vertical_position)
	state.landing_tangent = tangent
	state.landing_normal = Vector2(tangent.y, -tangent.x)
	state.landing_in_zone = false
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = Vector2(forward_speed * tangent.x, 0.0)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = 0.0
	state.vertical_speed = 0.0
	state.orientation = tangent.angle()
	state.angular_velocity = 0.0
	state.completion_time_remaining = 0.0


func _step_landing(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if state.landing_outcome == RiderState.LandingOutcome.CRASH:
		state.completion_time_remaining = maxf(state.completion_time_remaining - delta, 0.0)
		if is_zero_approx(state.completion_time_remaining):
			_complete_run(state)
		return
	var runout_end := course.landing_end_at(state.active_route_index)
	if state.course_progress >= runout_end.x:
		_complete_run(state)
		return
	var tangent := _runout_tangent_at(state, course)
	var progress_speed := maxf(state.ground_velocity.x, 0.0)
	progress_speed += tuning.slope_gravity * tangent.y * delta
	progress_speed = move_toward(progress_speed, 0.0, tuning.runout_drag * delta)
	progress_speed = maxf(progress_speed, tuning.minimum_runout_speed)
	state.course_progress = minf(state.course_progress + progress_speed * delta, runout_end.x)
	state.vertical_position = _runout_surface_y_at(state, course)
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	tangent = _runout_tangent_at(state, course)
	state.orientation = tangent.angle()
	state.ground_velocity = Vector2(progress_speed, 0.0)
	state.course_speed = progress_speed
	state.lane_speed = 0.0
	state.vertical_speed = 0.0
	if is_equal_approx(state.course_progress, runout_end.x):
		_complete_run(state)


func _runout_surface_y_at(state: RiderState, course: ParkCourse) -> float:
	if state.current_surface_id == &"abandon":
		return course.flight_abandon_trigger_y_at(state.course_progress, state.active_route_index)
	return course.landing_surface_y_at(state.course_progress, state.active_route_index)


func _runout_tangent_at(state: RiderState, course: ParkCourse) -> Vector2:
	if state.current_surface_id == &"abandon":
		return _abandon_tangent_at(state, course)
	return course.landing_tangent_at(state.course_progress, state.active_route_index)


func _abandon_tangent_at(state: RiderState, course: ParkCourse) -> Vector2:
	var route_index := state.active_route_index
	var start_x := course.approach_paths[route_index][-1].x
	var end_x := course.landing_paths[route_index][-1].x
	var before_x := maxf(state.course_progress - 1.0, start_x)
	var after_x := minf(state.course_progress + 1.0, end_x)
	if is_equal_approx(before_x, after_x):
		return Vector2.RIGHT
	var before_y := course.flight_abandon_trigger_y_at(before_x, route_index)
	var after_y := course.flight_abandon_trigger_y_at(after_x, route_index)
	return Vector2(after_x - before_x, after_y - before_y).normalized()


func _complete_run(state: RiderState) -> void:
	state.run_phase = RiderState.RunPhase.COMPLETE
	state.ground_velocity = Vector2.ZERO
	state.course_speed = 0.0
	state.lane_speed = 0.0
	state.vertical_speed = 0.0
	state.completion_time_remaining = 0.0


func _flight_has_overshot_landing(state: RiderState, course: ParkCourse) -> bool:
	var landing_path := course.landing_paths[state.active_route_index]
	return state.course_progress > landing_path[-1].x


func _flight_should_abandon(state: RiderState, course: ParkCourse) -> bool:
	return (
		state.vertical_speed > 0.0
		and (
			state.vertical_position
			> course.flight_abandon_trigger_y_at(state.course_progress, state.active_route_index)
		)
	)


func _end_missed_flight(state: RiderState, tuning: RiderTuning) -> void:
	state.run_phase = RiderState.RunPhase.LANDING
	state.landing_outcome = RiderState.LandingOutcome.CRASH
	state.current_surface_id = &"landing"
	state.landing_resolved = true
	state.landing_label = "CRASH"
	state.landing_quality = 0.0
	state.landing_position = Vector2(state.course_progress, state.vertical_position)
	state.completion_time_remaining = tuning.crash_completion_delay
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
