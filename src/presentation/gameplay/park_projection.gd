## Projects authoritative park coordinates into side-view world coordinates.
class_name ParkProjection
extends RefCounted

var course: ParkCourse


func _init(initial_course: ParkCourse) -> void:
	course = initial_course


func project_rider(state: RiderState) -> Vector2:
	return Vector2(
		state.course_progress,
		state.vertical_position + state.lane_position * GameConstants.LANE_PROJECTION_SCALE
	)


func project_rider_ground(state: RiderState) -> Vector2:
	if state.current_surface_id == &"abandon":
		return Vector2(
			state.ground_position.x,
			course.flight_abandon_trigger_y_at(state.ground_position.x, state.active_route_index)
		)
	if state.active_route_index >= 0 and state.run_phase != RiderState.RunPhase.APPROACH:
		return course.landing_surface_position_at(state.ground_position.x, state.active_route_index)
	return course.route_surface_position_at(state.ground_position.x, state.approach_path_position)
