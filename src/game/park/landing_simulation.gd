## Resolves landing outcomes and advances the rider through a runout.
class_name LandingSimulation
extends RefCounted


func resolve_contact(state: RiderState, contact: Dictionary) -> void:
	if state.jump.landing_resolved:
		return
	var contact_position: Vector2 = contact["position"]
	var tangent: Vector2 = contact["tangent"]
	var normal: Vector2 = contact["normal"]
	var flight_velocity := Vector2(state.kinematics.course_speed, state.kinematics.vertical_speed)
	var landing_speed := maxf(flight_velocity.dot(tangent), 0.0)
	state.run.run_phase = RiderRunState.RunPhase.LANDING
	state.run.landing_outcome = RiderRunState.LandingOutcome.CLEAN
	state.run.current_surface_id = &"landing"
	state.jump.landing_resolved = true
	state.jump.landing_label = "CLEAN"
	state.jump.landing_quality = 1.0
	state.jump.landing_position = contact_position
	state.jump.landing_tangent = tangent
	state.jump.landing_normal = normal
	state.jump.landing_velocity_alignment = flight_velocity.normalized().dot(tangent)
	state.jump.landing_normal_impact = absf(flight_velocity.dot(normal))
	state.jump.landing_in_zone = true
	state.kinematics.course_progress = contact_position.x
	state.kinematics.vertical_position = contact_position.y
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.ground_velocity = Vector2(landing_speed * tangent.x, 0.0)
	state.kinematics.course_speed = state.kinematics.ground_velocity.x
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0
	state.jump.orientation = tangent.angle()
	state.jump.angular_velocity = 0.0
	state.run.completion_time_remaining = 0.0


func begin_ground_runout(state: RiderState, course: ParkCourse) -> void:
	var tangent := course.landing_tangent_at(
		state.kinematics.course_progress, state.kinematics.active_route_index
	)
	state.jump.takeoff_pop_impulse = 0.0
	state.run.run_phase = RiderRunState.RunPhase.LANDING
	state.run.landing_outcome = RiderRunState.LandingOutcome.ABANDON
	state.run.current_surface_id = &"landing"
	state.jump.landing_resolved = true
	state.jump.landing_label = "ABANDON"
	state.jump.landing_quality = 0.0
	state.jump.landing_position = Vector2(
		state.kinematics.course_progress, state.kinematics.vertical_position
	)
	state.jump.landing_tangent = tangent
	state.jump.landing_normal = Vector2(tangent.y, -tangent.x)
	state.jump.landing_in_zone = false
	state.kinematics.vertical_speed = 0.0
	state.jump.orientation = tangent.angle()
	state.jump.angular_velocity = 0.0
	state.run.completion_time_remaining = 0.0


func begin_abandoned_runout(state: RiderState, course: ParkCourse) -> void:
	var route_index := state.kinematics.active_route_index
	var route := course.route_at(route_index)
	var landing_path := route.landing_path
	var lip_progress := route.approach_path[-1].x
	state.kinematics.course_progress = clampf(
		state.kinematics.course_progress, lip_progress, landing_path[-1].x
	)
	state.kinematics.vertical_position = course.flight_abandon_trigger_y_at(
		state.kinematics.course_progress, route_index
	)
	var tangent := _abandon_tangent_at(state, course)
	var forward_speed := maxf(
		Vector2(state.kinematics.course_speed, state.kinematics.vertical_speed).dot(tangent), 0.0
	)
	state.run.run_phase = RiderRunState.RunPhase.LANDING
	state.run.landing_outcome = RiderRunState.LandingOutcome.ABANDON
	state.run.current_surface_id = &"abandon"
	state.jump.landing_resolved = true
	state.jump.landing_label = "ABANDON"
	state.jump.landing_quality = 0.0
	state.jump.landing_position = Vector2(
		state.kinematics.course_progress, state.kinematics.vertical_position
	)
	state.jump.landing_tangent = tangent
	state.jump.landing_normal = Vector2(tangent.y, -tangent.x)
	state.jump.landing_in_zone = false
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.ground_velocity = Vector2(forward_speed * tangent.x, 0.0)
	state.kinematics.course_speed = state.kinematics.ground_velocity.x
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0
	state.jump.orientation = tangent.angle()
	state.jump.angular_velocity = 0.0
	state.run.completion_time_remaining = 0.0


func crash(state: RiderState, tuning: RiderTuning) -> void:
	state.run.run_phase = RiderRunState.RunPhase.LANDING
	state.run.landing_outcome = RiderRunState.LandingOutcome.CRASH
	state.run.current_surface_id = &"landing"
	state.jump.landing_resolved = true
	state.jump.landing_label = "CRASH"
	state.jump.landing_quality = 0.0
	state.jump.landing_position = Vector2(
		state.kinematics.course_progress, state.kinematics.vertical_position
	)
	state.run.completion_time_remaining = tuning.crash_completion_delay
	state.kinematics.ground_velocity = Vector2.ZERO
	state.kinematics.course_speed = 0.0
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0


func step(state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	if state.run.landing_outcome == RiderRunState.LandingOutcome.CRASH:
		state.run.completion_time_remaining = maxf(state.run.completion_time_remaining - delta, 0.0)
		if is_zero_approx(state.run.completion_time_remaining):
			_complete(state)
		return
	var runout_end := course.landing_end_at(state.kinematics.active_route_index)
	if state.kinematics.course_progress >= runout_end.x:
		_complete(state)
		return
	var tangent := _runout_tangent_at(state, course)
	var progress_speed := maxf(state.kinematics.ground_velocity.x, 0.0)
	progress_speed += tuning.slope_gravity * tangent.y * delta
	progress_speed = move_toward(progress_speed, 0.0, tuning.runout_drag * delta)
	progress_speed = maxf(progress_speed, tuning.minimum_runout_speed)
	state.kinematics.course_progress = minf(
		state.kinematics.course_progress + progress_speed * delta, runout_end.x
	)
	state.kinematics.vertical_position = _runout_surface_y_at(state, course)
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	tangent = _runout_tangent_at(state, course)
	state.jump.orientation = tangent.angle()
	state.kinematics.ground_velocity = Vector2(progress_speed, 0.0)
	state.kinematics.course_speed = progress_speed
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0
	if is_equal_approx(state.kinematics.course_progress, runout_end.x):
		_complete(state)


func _runout_surface_y_at(state: RiderState, course: ParkCourse) -> float:
	if state.run.current_surface_id == &"abandon":
		return course.flight_abandon_trigger_y_at(
			state.kinematics.course_progress, state.kinematics.active_route_index
		)
	return course.landing_surface_y_at(
		state.kinematics.course_progress, state.kinematics.active_route_index
	)


func _runout_tangent_at(state: RiderState, course: ParkCourse) -> Vector2:
	if state.run.current_surface_id == &"abandon":
		return _abandon_tangent_at(state, course)
	return course.landing_tangent_at(
		state.kinematics.course_progress, state.kinematics.active_route_index
	)


func _abandon_tangent_at(state: RiderState, course: ParkCourse) -> Vector2:
	var route_index := state.kinematics.active_route_index
	var route := course.route_at(route_index)
	var start_x := route.approach_path[-1].x
	var end_x := route.landing_path[-1].x
	var before_x := maxf(state.kinematics.course_progress - 1.0, start_x)
	var after_x := minf(state.kinematics.course_progress + 1.0, end_x)
	if is_equal_approx(before_x, after_x):
		return Vector2.RIGHT
	var before_y := course.flight_abandon_trigger_y_at(before_x, route_index)
	var after_y := course.flight_abandon_trigger_y_at(after_x, route_index)
	return Vector2(after_x - before_x, after_y - before_y).normalized()


func _complete(state: RiderState) -> void:
	state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	state.kinematics.ground_velocity = Vector2.ZERO
	state.kinematics.course_speed = 0.0
	state.kinematics.lane_speed = 0.0
	state.kinematics.vertical_speed = 0.0
	state.run.completion_time_remaining = 0.0
