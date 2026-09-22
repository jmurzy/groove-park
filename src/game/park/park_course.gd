@tool
## Authored terrain profile for the current approach-only course.
class_name ParkCourse
extends Resource

@export var course_version := "park-course-v1"
## Three editor-authored routes ordered top-to-bottom.
@export var approach_paths: Array[PackedVector2Array] = []
@export var lane_min := -360.0
@export var lane_max := 360.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if approach_paths.size() != 3:
		errors.append("ParkCourse needs exactly three approach paths when routes are authored.")
		return errors
	for path_index in approach_paths.size():
		if approach_paths[path_index].size() < 2:
			errors.append("Approach path %d needs at least two points." % path_index)
			continue
		for point_index in range(approach_paths[path_index].size() - 1):
			if (
				approach_paths[path_index][point_index + 1].x
				<= approach_paths[path_index][point_index].x
			):
				errors.append(
					"Approach path %d points must be strictly ordered by progress." % path_index
				)

	if lane_min >= lane_max:
		errors.append("ParkCourse lane_min must be less than lane_max.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func route_surface_y_at(course_progress: float, route_position: float) -> float:
	var lower_index := clampi(floori(route_position), 0, approach_paths.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, approach_paths.size() - 1)
	var blend := clampf(route_position - lower_index, 0.0, 1.0)
	return lerpf(
		_path_surface_y_at(approach_paths[lower_index], course_progress),
		_path_surface_y_at(approach_paths[upper_index], course_progress),
		blend
	)


func route_surface_position_at(course_progress: float, route_position: float) -> Vector2:
	return Vector2(course_progress, route_surface_y_at(course_progress, route_position))


func route_gradient_at(
	course_progress: float, route_position: float, sample_distance := 4.0
) -> float:
	var forward := route_surface_y_at(course_progress + sample_distance, route_position)
	var backward := route_surface_y_at(course_progress - sample_distance, route_position)
	return (forward - backward) / (2.0 * sample_distance)


func route_tangent_at(course_progress: float, route_position: float) -> Vector2:
	return Vector2(1.0, route_gradient_at(course_progress, route_position, 1.0)).normalized()


func route_normal_at(course_progress: float, route_position: float) -> Vector2:
	var tangent := route_tangent_at(course_progress, route_position)
	return Vector2(tangent.y, -tangent.x)


func route_end_at(route_position: float) -> float:
	var lower_index := clampi(floori(route_position), 0, approach_paths.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, approach_paths.size() - 1)
	var blend := clampf(route_position - lower_index, 0.0, 1.0)
	return lerpf(approach_paths[lower_index][-1].x, approach_paths[upper_index][-1].x, blend)


func lane_bounds_at(_course_progress: float) -> Vector2:
	return Vector2(lane_min, lane_max)


func route_start_at(route_position: float) -> float:
	var lower_index := clampi(floori(route_position), 0, approach_paths.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, approach_paths.size() - 1)
	var blend := clampf(route_position - lower_index, 0.0, 1.0)
	return lerpf(approach_paths[lower_index][0].x, approach_paths[upper_index][0].x, blend)


func route_swept_terrain_intersection(
	previous_position: Vector2, next_position: Vector2, route_position: float
) -> Dictionary:
	# Return the earliest forward flight/terrain contact, including contacts at terrain seams.
	if next_position.x <= previous_position.x:
		return {}
	var path_index := clampi(roundi(route_position), 0, approach_paths.size() - 1)
	var path := approach_paths[path_index]
	var earliest_contact := {}
	for point_index in range(path.size() - 1):
		var terrain_start := path[point_index]
		var terrain_end := path[point_index + 1]
		if terrain_end.x < previous_position.x or terrain_start.x > next_position.x:
			continue
		var contact := _segment_intersection(
			previous_position, next_position, terrain_start, terrain_end
		)
		if contact.is_empty():
			continue
		var contact_position: Vector2 = contact["position"]
		if earliest_contact.is_empty() or float(contact["time"]) < float(earliest_contact["time"]):
			earliest_contact = contact
			var tangent := (terrain_end - terrain_start).normalized()
			earliest_contact["tangent"] = tangent
			earliest_contact["normal"] = Vector2(tangent.y, -tangent.x)
	return earliest_contact


func _path_surface_y_at(path: PackedVector2Array, course_progress: float) -> float:
	if course_progress <= path[0].x:
		return path[0].y
	for point_index in range(path.size() - 1):
		var start := path[point_index]
		var end := path[point_index + 1]
		if course_progress <= end.x:
			return lerpf(start.y, end.y, inverse_lerp(start.x, end.x, course_progress))
	return path[-1].y


func _segment_intersection(
	flight_start: Vector2, flight_end: Vector2, terrain_start: Vector2, terrain_end: Vector2
) -> Dictionary:
	var flight := flight_end - flight_start
	var terrain := terrain_end - terrain_start
	var denominator := flight.cross(terrain)
	if is_zero_approx(denominator):
		return {}
	var offset := terrain_start - flight_start
	var flight_time := offset.cross(terrain) / denominator
	var terrain_time := offset.cross(flight) / denominator
	# A takeoff starts on terrain; that separation point is not a landing.
	if flight_time <= 0.0001 or flight_time > 1.0 or terrain_time < 0.0 or terrain_time > 1.0:
		return {}
	return {"position": flight_start.lerp(flight_end, flight_time), "time": flight_time}
