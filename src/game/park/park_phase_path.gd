@tool
## Ordered course range for one movement phase. Its path marks progress only;
## ParkCourse remains the sole source of terrain geometry.
class_name ParkPhasePath
extends Resource

enum Phase { APPROACH, COMPRESSION, TAKEOFF, LANDING, RUNOUT }

@export var id: StringName
@export var phase := Phase.APPROACH
@export var path_points := PackedVector2Array()
@export var fall_line_direction := Vector2.RIGHT
@export_range(0.1, 3.0, 0.05) var snow_resistance_multiplier := 1.0
@export_range(0.1, 3.0, 0.05) var edge_grip_multiplier := 1.0


func contains_progress(course_progress: float) -> bool:
	return course_progress >= progress_start() and course_progress <= progress_end()


func progress_start() -> float:
	return path_points[0].x if not path_points.is_empty() else INF


func progress_end() -> float:
	return path_points[-1].x if not path_points.is_empty() else -INF


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("ParkPhasePath needs an id.")
	if path_points.size() < 2:
		errors.append("ParkPhasePath needs at least two path points.")
	for point_index in range(path_points.size() - 1):
		if path_points[point_index + 1].x <= path_points[point_index].x:
			errors.append("ParkPhasePath points must be strictly ordered by progress.")
			break
	if fall_line_direction.is_zero_approx():
		errors.append("ParkPhasePath needs a fall-line direction.")
	return errors
