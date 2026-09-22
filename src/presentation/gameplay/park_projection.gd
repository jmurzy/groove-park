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
	return course.route_surface_position_at(state.ground_position.x, state.approach_path_position)
