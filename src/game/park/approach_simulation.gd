## Advances a rider across an authored approach and reports unused tick time at the lip.
class_name ApproachSimulation
extends RefCounted

const PATH_SWITCH_SPEED := RouteChangePredictor.PATH_SWITCH_SPEED

var _motion := ApproachMotion.new()
var _compression := CompressionController.new()
var _route_change_predictor := RouteChangePredictor.new()


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
	_update_path(state, input, course, tuning, delta)
	_compression.update(state, input, _end(state, course), tuning, delta)

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

	if not steering_heading.is_zero_approx():
		state.kinematics.desired_heading = steering_heading
		if not state.run.has_ground_intent and downhill_held:
			state.run.has_ground_intent = true
	if not state.run.has_ground_intent:
		_sync_ground_state(state, course)
		return -1.0
	_update_low_momentum_detection(state, course, tuning, delta)

	_motion.turn_toward_input(state, steering_heading, input, tuning, delta)
	if (
		_motion.apply_forces(state, input, course, tuning, delta, downhill_held, left_braking)
		and not _is_rolling_back_from_low_momentum(state)
	):
		_stop_at_edge(state)
	var remaining_delta := _motion.move_within_bounds(
		state, course, delta, _stop_at_edge.bind(state)
	)
	_sync_ground_state(state, course)
	if _should_end_for_low_momentum(state, tuning, delta):
		_complete_for_low_momentum(state)
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
		_compression.release(state, _end(state, course), tuning, lip.x)
		state.jump.compression_auto_released = true
		state.jump.compression_release_quality = clampf(
			tuning.compression_auto_release_quality, 0.0, 1.0
		)
	_clear_controls(state)
	return route_index


func _stop_at_edge(state: RiderState) -> void:
	state.kinematics.ground_velocity = Vector2.ZERO
	_clear_controls(state)


func _clear_controls(state: RiderState) -> void:
	state.run.has_ground_intent = false
	state.run.tuck_active = false
	state.run.brake_active = false
	state.run.edge_active = false


func _update_low_momentum_detection(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if _is_rolling_back_from_low_momentum(state):
		return
	var route_index := clampi(
		roundi(state.kinematics.approach_path_position), 0, course.routes.size() - 1
	)
	var near_lip := (
		_end(state, course) - state.kinematics.course_progress
		<= maxf(tuning.low_momentum_detection_distance, 0.0)
	)
	var route_change_complete := is_equal_approx(
		state.kinematics.approach_path_position, float(state.kinematics.approach_path_target)
	)
	var low_speed := state.kinematics.ground_velocity.x <= tuning.low_momentum_speed_threshold
	if (
		course.route_at(route_index).kind != ParkRoute.Kind.FLIGHT
		or not route_change_complete
		or not near_lip
		or not low_speed
		or _best_recoverable_forward_acceleration(state, course, tuning) > 0.0
	):
		_reset_low_momentum_detection(state)
		return
	if (
		state.kinematics.course_progress
		> state.run.low_momentum_last_progress + tuning.low_momentum_progress_epsilon
	):
		state.run.low_momentum_last_progress = state.kinematics.course_progress
		state.run.low_momentum_no_progress_time = 0.0
		return
	state.run.low_momentum_no_progress_time += delta
	if state.run.low_momentum_no_progress_time >= tuning.low_momentum_detection_duration:
		_begin_low_momentum(state)


func _begin_low_momentum(state: RiderState) -> void:
	state.run.landing_outcome = RiderRunState.LandingOutcome.LOW_MOMENTUM
	state.run.low_momentum_start_progress = state.kinematics.course_progress
	state.run.low_momentum_stop_time = 0.0
	state.jump.compression_active = false
	state.jump.compression_amount = 0.0


func _should_end_for_low_momentum(state: RiderState, tuning: RiderTuning, delta: float) -> bool:
	if not _is_rolling_back_from_low_momentum(state):
		return false
	if (
		state.kinematics.course_progress
		<= state.run.low_momentum_start_progress - maxf(tuning.low_momentum_slide_distance, 0.0)
	):
		return true
	if absf(state.kinematics.ground_velocity.x) > tuning.low_momentum_speed_threshold:
		state.run.low_momentum_stop_time = 0.0
		return false
	state.run.low_momentum_stop_time += delta
	return state.run.low_momentum_stop_time >= tuning.low_momentum_stop_duration


func _complete_for_low_momentum(state: RiderState) -> void:
	state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	state.run.current_surface_id = &"low_momentum"
	state.run.completion_time_remaining = 0.0
	state.run.low_momentum_no_progress_time = 0.0
	state.run.low_momentum_stop_time = 0.0
	state.jump.compression_active = false
	state.jump.compression_amount = 0.0
	state.jump.compression_release_progress = -1.0
	state.jump.compression_release_quality = 0.0
	state.jump.compression_auto_released = false
	state.kinematics.ground_velocity = Vector2.ZERO
	state.kinematics.course_speed = 0.0
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0
	_clear_controls(state)


func _reset_low_momentum_detection(state: RiderState) -> void:
	state.run.low_momentum_last_progress = state.kinematics.course_progress
	state.run.low_momentum_no_progress_time = 0.0


func _best_recoverable_forward_acceleration(
	state: RiderState, course: ParkCourse, tuning: RiderTuning
) -> float:
	var gradient := course.route_gradient_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)
	var slope_acceleration := tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient)
	var pump_scale := clampf(1.0 + gradient / maxf(tuning.uphill_pump_cut_gradient, 0.01), 0.0, 1.0)
	var speed := maxf(state.kinematics.ground_velocity.x, 0.0)
	var drag := tuning.snow_resistance + tuning.aerodynamic_drag * speed * speed
	drag *= tuning.tuck_drag_multiplier
	return slope_acceleration + tuning.fall_line_acceleration * pump_scale - drag


func _is_rolling_back_from_low_momentum(state: RiderState) -> bool:
	return (
		state.run.run_phase == RiderRunState.RunPhase.APPROACH
		and state.run.landing_outcome == RiderRunState.LandingOutcome.LOW_MOMENTUM
	)


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
		and _route_change_predictor.can_coast_through(state, requested_path, course, tuning)
	):
		state.kinematics.approach_path_target = requested_path
	state.kinematics.approach_path_position = move_toward(
		state.kinematics.approach_path_position,
		float(state.kinematics.approach_path_target),
		PATH_SWITCH_SPEED * delta
	)
