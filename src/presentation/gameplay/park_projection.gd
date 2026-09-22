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


func project_ground(ground_position: Vector2) -> Vector2:
	return Vector2(
		ground_position.x,
		(
			course.surface_y_at(ground_position.x, ground_position.y)
			+ ground_position.y * GameConstants.LANE_PROJECTION_SCALE
		)
	)


func project_rider_ground(state: RiderState) -> Vector2:
	return Vector2(
		state.ground_position.x,
		course.route_surface_y_at(state.ground_position.x, state.approach_path_position)
	)


func unproject_ground(world_position: Vector2) -> Vector2:
	return Vector2(
		world_position.x,
		(
			(world_position.y - course.surface_y_at(world_position.x))
			/ GameConstants.LANE_PROJECTION_SCALE
		)
	)
