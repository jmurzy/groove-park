## Projects authoritative park coordinates into side-view world coordinates.
class_name ParkProjection
extends RefCounted

var course: ParkCourse


func _init(initial_course: ParkCourse) -> void:
	course = initial_course


func project_rider(state: RiderState) -> Vector2:
	return Vector2(
		state.kinematics.course_progress,
		(
			state.kinematics.vertical_position
			+ state.kinematics.lane_position * GameConstants.LANE_PROJECTION_SCALE
		)
	)


func project_rider_ground(state: RiderState) -> Vector2:
	if state.run.current_surface_id == &"abandon":
		return Vector2(
			state.kinematics.ground_position.x,
			course.flight_abandon_trigger_y_at(
				state.kinematics.ground_position.x, state.kinematics.active_route_index
			)
		)
	if (
		state.kinematics.active_route_index >= 0
		and state.run.run_phase != RiderRunState.RunPhase.APPROACH
	):
		return course.landing_surface_position_at(
			state.kinematics.ground_position.x, state.kinematics.active_route_index
		)
	return course.route_surface_position_at(
		state.kinematics.ground_position.x, state.kinematics.approach_path_position
	)
