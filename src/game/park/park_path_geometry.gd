## Geometry queries for ordered course paths shared by authored park resources.
class_name ParkPathGeometry
extends RefCounted


static func surface_y_at(path: PackedVector2Array, course_progress: float) -> float:
	if course_progress <= path[0].x:
		return path[0].y
	for point_index in range(path.size() - 1):
		var start := path[point_index]
		var end := path[point_index + 1]
		if course_progress <= end.x:
			return lerpf(start.y, end.y, inverse_lerp(start.x, end.x, course_progress))
	return path[-1].y


static func gradient_at(
	path: PackedVector2Array, course_progress: float, sample_distance := 4.0
) -> float:
	var forward := surface_y_at(path, course_progress + sample_distance)
	var backward := surface_y_at(path, course_progress - sample_distance)
	return (forward - backward) / (2.0 * sample_distance)


static func tangent_at(path: PackedVector2Array, course_progress: float) -> Vector2:
	if course_progress <= path[0].x:
		return (path[1] - path[0]).normalized()
	for point_index in range(path.size() - 1):
		if course_progress <= path[point_index + 1].x:
			return (path[point_index + 1] - path[point_index]).normalized()
	return (path[-1] - path[-2]).normalized()


static func end_tangent(path: PackedVector2Array) -> Vector2:
	return (path[-1] - path[-2]).normalized()


static func normal_for_tangent(tangent: Vector2) -> Vector2:
	return Vector2(tangent.y, -tangent.x)


static func swept_terrain_intersection(
	path: PackedVector2Array, previous_position: Vector2, next_position: Vector2
) -> Dictionary:
	if next_position.x <= previous_position.x:
		return {}
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
		if earliest_contact.is_empty() or float(contact["time"]) < float(earliest_contact["time"]):
			earliest_contact = contact
			var tangent := (terrain_end - terrain_start).normalized()
			earliest_contact["tangent"] = tangent
			earliest_contact["normal"] = normal_for_tangent(tangent)
	return earliest_contact


static func _segment_intersection(
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
	if flight_time <= 0.0001 or flight_time > 1.0 or terrain_time < 0.0 or terrain_time > 1.0:
		return {}
	return {"position": flight_start.lerp(flight_end, flight_time), "time": flight_time}
