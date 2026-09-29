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
	_compression.update(state, input, _end(state, course), tuning, delta)

	if not steering_heading.is_zero_approx():
		state.kinematics.desired_heading = steering_heading
		if not state.run.has_ground_intent and downhill_held:
			state.run.has_ground_intent = true
	if not state.run.has_ground_intent:
		_sync_ground_state(state, course)
		return -1.0

	_motion.turn_toward_input(state, steering_heading, input, tuning, delta)
	if _motion.apply_forces(state, input, course, tuning, delta, downhill_held, left_braking):
		_stop_at_edge(state)
	var remaining_delta := _motion.move_within_bounds(
		state, course, delta, _stop_at_edge.bind(state)
	)
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
