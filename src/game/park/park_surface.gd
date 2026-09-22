@tool
## Polygonal travel surface with a role (approach / takeoff / landing / runout)
## and an optional launch edge. Example: a TAKEOFF surface fires via `launch_intersection()`.
class_name ParkSurface
extends Resource

enum Role { APPROACH, TAKEOFF, LANDING, RUNOUT }

@export var id: StringName
@export var role := Role.APPROACH
@export var footprint := PackedVector2Array()
@export var launch_edge_index := -1


func contains(ground_position: Vector2) -> bool:
	return Footprint2D.contains(footprint, ground_position)


func lane_bounds_at(course_progress: float) -> Vector2:
	var intersections := PackedFloat32Array()
	for point_index in footprint.size():
		var edge_start := footprint[point_index]
		var edge_end := footprint[(point_index + 1) % footprint.size()]
		if (
			(edge_start.x <= course_progress and edge_end.x > course_progress)
			or (edge_end.x <= course_progress and edge_start.x > course_progress)
		):
			intersections.append(
				lerpf(
					edge_start.y,
					edge_end.y,
					inverse_lerp(edge_start.x, edge_end.x, course_progress)
				)
			)
	if intersections.size() < 2:
		return Vector2(INF, -INF)
	intersections.sort()
	return Vector2(intersections[0], intersections[-1])


func has_progress(course_progress: float) -> bool:
	var bounds := lane_bounds_at(course_progress)
	return bounds.x <= bounds.y


func launch_intersection(start: Vector2, end: Vector2) -> Vector2:
	if launch_edge_index < 0 or launch_edge_index >= footprint.size():
		return Vector2.INF
	return _segment_intersection(
		start,
		end,
		footprint[launch_edge_index],
		footprint[(launch_edge_index + 1) % footprint.size()]
	)


func launch_progress() -> float:
	if launch_edge_index < 0 or launch_edge_index >= footprint.size():
		return INF
	var edge_start := footprint[launch_edge_index]
	var edge_end := footprint[(launch_edge_index + 1) % footprint.size()]
	return (edge_start.x + edge_end.x) * 0.5


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("ParkSurface needs an id.")
	if footprint.size() < 3:
		errors.append("ParkSurface needs at least three footprint points.")
	if role == Role.TAKEOFF and (launch_edge_index < 0 or launch_edge_index >= footprint.size()):
		errors.append("Takeoff ParkSurface needs a valid launch edge.")
	return errors


func _segment_intersection(
	start: Vector2, end: Vector2, edge_start: Vector2, edge_end: Vector2
) -> Vector2:
	var travel := end - start
	var edge := edge_end - edge_start
	var denominator := travel.cross(edge)
	if is_zero_approx(denominator):
		return Vector2.INF
	var offset := edge_start - start
	var travel_time := offset.cross(edge) / denominator
	var edge_time := offset.cross(travel) / denominator
	if travel_time < 0.0 or travel_time > 1.0 or edge_time < 0.0 or edge_time > 1.0:
		return Vector2.INF
	return start.lerp(end, travel_time)
