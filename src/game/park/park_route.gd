@tool
## One selectable park line, including its approach, landing/runout, and transition kind.
class_name ParkRoute
extends Resource

enum Kind { FLIGHT, GROUND_RUNOUT }

@export var id: StringName
@export var approach_path: PackedVector2Array = []
@export var landing_path: PackedVector2Array = []
@export var kind: Kind = Kind.FLIGHT


func validation_errors(route_index: int) -> PackedStringArray:
	var errors := PackedStringArray()
	_append_path_errors(errors, approach_path, "Approach", route_index)
	_append_path_errors(errors, landing_path, "Landing", route_index)
	if approach_path.size() < 2 or landing_path.size() < 2:
		return errors
	match kind:
		Kind.FLIGHT:
			if landing_path[0].x <= approach_path[-1].x:
				errors.append("Flight route %d landing must start after its lip." % route_index)
		Kind.GROUND_RUNOUT:
			if not landing_path[0].is_equal_approx(approach_path[-1]):
				errors.append(
					"Ground route %d landing must start at its approach endpoint." % route_index
				)
		_:
			errors.append("Route %d has an unknown route kind." % route_index)
	return errors


func approach_surface_y_at(course_progress: float) -> float:
	return _path_surface_y_at(approach_path, course_progress)


func approach_gradient_at(course_progress: float, sample_distance := 4.0) -> float:
	var forward := approach_surface_y_at(course_progress + sample_distance)
	var backward := approach_surface_y_at(course_progress - sample_distance)
	return (forward - backward) / (2.0 * sample_distance)


func lip_tangent() -> Vector2:
	return (approach_path[-1] - approach_path[-2]).normalized()


func lip_normal() -> Vector2:
	var tangent := lip_tangent()
	return Vector2(tangent.y, -tangent.x)


func landing_surface_y_at(course_progress: float) -> float:
	return _path_surface_y_at(landing_path, course_progress)


func landing_tangent_at(course_progress: float) -> Vector2:
	if course_progress <= landing_path[0].x:
		return (landing_path[1] - landing_path[0]).normalized()
	for point_index in range(landing_path.size() - 1):
		if course_progress <= landing_path[point_index + 1].x:
			return (landing_path[point_index + 1] - landing_path[point_index]).normalized()
	return (landing_path[-1] - landing_path[-2]).normalized()


func flight_miss_boundary_points() -> PackedVector2Array:
	var points := PackedVector2Array([approach_path[-1]])
	points.append_array(landing_path)
	return points


func landing_swept_terrain_intersection(
	previous_position: Vector2, next_position: Vector2
) -> Dictionary:
	if next_position.x <= previous_position.x:
		return {}
	var earliest_contact := {}
	for point_index in range(landing_path.size() - 1):
		var terrain_start := landing_path[point_index]
		var terrain_end := landing_path[point_index + 1]
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
			earliest_contact["normal"] = Vector2(tangent.y, -tangent.x)
	return earliest_contact


func _append_path_errors(
	errors: PackedStringArray, path: PackedVector2Array, label: String, route_index: int
) -> void:
	if path.size() < 2:
		errors.append("%s path %d needs at least two points." % [label, route_index])
		return
	for point_index in range(path.size() - 1):
		if path[point_index + 1].x <= path[point_index].x:
			errors.append(
				"%s path %d points must be strictly ordered by progress." % [label, route_index]
			)
			return


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
	if flight_time <= 0.0001 or flight_time > 1.0 or terrain_time < 0.0 or terrain_time > 1.0:
		return {}
	return {"position": flight_start.lerp(flight_end, flight_time), "time": flight_time}
