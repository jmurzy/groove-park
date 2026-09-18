class_name ParkCourse
extends Resource

@export var terrain_points := PackedVector2Array()
@export var lane_min := -360.0
@export var lane_max := 360.0
@export var start_progress := 75.0
@export var approach_start := 848.0
@export var compression_start := 1323.0
@export var compression_end := 1514.0
@export var lip_progress := 1702.0
@export var landing_start := 1768.0
@export var landing_end := 1914.0
@export var recovery_progress := 1977.0
@export var camera_start := 75.0
@export var camera_end := 1977.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if terrain_points.size() < 2:
		errors.append("ParkCourse needs at least two terrain points.")
		return errors

	for point_index in range(terrain_points.size() - 1):
		var start := terrain_points[point_index]
		var end := terrain_points[point_index + 1]
		if end.x <= start.x:
			errors.append(
				(
					"Terrain points %d and %d must be strictly ordered by progress."
					% [point_index, point_index + 1]
				)
			)

	if lane_min >= lane_max:
		errors.append("ParkCourse lane_min must be less than lane_max.")
	if not _markers_are_ordered():
		errors.append("ParkCourse feature markers must be ordered from start through camera end.")
	if camera_start < terrain_points[0].x or camera_end > terrain_points[-1].x:
		errors.append("ParkCourse camera and feature markers must lie within the terrain range.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func surface_position_at(course_progress: float) -> Vector2:
	return Vector2(course_progress, surface_y_at(course_progress))


func surface_y_at(course_progress: float) -> float:
	if terrain_points.is_empty():
		push_error("ParkCourse has no terrain points.")
		return 0.0
	if course_progress <= terrain_points[0].x:
		return terrain_points[0].y
	for point_index in range(terrain_points.size() - 1):
		var start := terrain_points[point_index]
		var end := terrain_points[point_index + 1]
		if course_progress <= end.x:
			return lerpf(start.y, end.y, inverse_lerp(start.x, end.x, course_progress))
	return terrain_points[-1].y


func tangent_at(course_progress: float) -> Vector2:
	if terrain_points.size() < 2:
		push_error("ParkCourse needs at least two terrain points to calculate a tangent.")
		return Vector2.RIGHT
	return _segment_at(course_progress).normalized()


func normal_at(course_progress: float) -> Vector2:
	var tangent := tangent_at(course_progress)
	return Vector2(tangent.y, -tangent.x)


func lane_bounds_at(_course_progress: float) -> Vector2:
	return Vector2(lane_min, lane_max)


func is_within_lane(course_progress: float, lane_position: float) -> bool:
	var bounds := lane_bounds_at(course_progress)
	return lane_position >= bounds.x and lane_position <= bounds.y


func crosses_progress(
	previous_progress: float, next_progress: float, marker_progress: float
) -> bool:
	return previous_progress < marker_progress and next_progress >= marker_progress


func crosses_lip(previous_progress: float, next_progress: float) -> bool:
	return crosses_progress(previous_progress, next_progress, lip_progress)


func _markers_are_ordered() -> bool:
	return (
		camera_start <= start_progress
		and start_progress <= approach_start
		and approach_start <= compression_start
		and compression_start <= compression_end
		and compression_end <= lip_progress
		and lip_progress <= landing_start
		and landing_start <= landing_end
		and landing_end <= recovery_progress
		and recovery_progress <= camera_end
	)


func _segment_at(course_progress: float) -> Vector2:
	if course_progress <= terrain_points[0].x:
		return terrain_points[1] - terrain_points[0]
	for point_index in range(terrain_points.size() - 1):
		var start := terrain_points[point_index]
		var end := terrain_points[point_index + 1]
		if course_progress <= end.x:
			return end - start
	return terrain_points[-1] - terrain_points[-2]
