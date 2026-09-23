@tool
## Authored terrain profiles for the three selectable park routes.
class_name ParkCourse
extends Resource

enum RouteKind { FLIGHT, GROUND_RUNOUT }

const ROUTE_COUNT := 3

@export var course_version := "park-course-v2"
## Three editor-authored routes ordered top-to-bottom.
@export var approach_paths: Array[PackedVector2Array] = []
## Matching landing/runout routes. Flight routes leave an intentional gap
## between the approach endpoint (the lip) and the landing path.
@export var landing_paths: Array[PackedVector2Array] = []
@export
var route_kinds: Array[RouteKind] = [RouteKind.FLIGHT, RouteKind.FLIGHT, RouteKind.GROUND_RUNOUT]
@export var lane_min := -360.0
@export var lane_max := 360.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_append_path_errors(errors, approach_paths, "Approach")
	_append_path_errors(errors, landing_paths, "Landing")
	if route_kinds.size() != ROUTE_COUNT:
		errors.append("ParkCourse needs exactly three route kinds.")
	if (
		approach_paths.size() == ROUTE_COUNT
		and landing_paths.size() == ROUTE_COUNT
		and route_kinds.size() == ROUTE_COUNT
	):
		for route_index in ROUTE_COUNT:
			if approach_paths[route_index].is_empty() or landing_paths[route_index].is_empty():
				continue
			var approach_end := approach_paths[route_index][-1]
			var landing_start := landing_paths[route_index][0]
			match route_kinds[route_index]:
				RouteKind.FLIGHT:
					if landing_start.x <= approach_end.x:
						errors.append(
							"Flight route %d landing must start after its lip." % route_index
						)
				RouteKind.GROUND_RUNOUT:
					if not landing_start.is_equal_approx(approach_end):
						errors.append(
							(
								"Ground route %d landing must start at its approach endpoint."
								% route_index
							)
						)
				_:
					errors.append("Route %d has an unknown route kind." % route_index)

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


func route_lip_tangent(route_index: int) -> Vector2:
	var path := approach_paths[clampi(route_index, 0, approach_paths.size() - 1)]
	return (path[-1] - path[-2]).normalized()


func route_lip_normal(route_index: int) -> Vector2:
	var tangent := route_lip_tangent(route_index)
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


func landing_swept_terrain_intersection(
	previous_position: Vector2, next_position: Vector2, route_index: int
) -> Dictionary:
	# Only landing geometry participates, so a flight route has no collision across its gap.
	if next_position.x <= previous_position.x:
		return {}
	if route_index < 0 or route_index >= landing_paths.size():
		return {}
	var path := landing_paths[route_index]
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
			earliest_contact["normal"] = Vector2(tangent.y, -tangent.x)
	return earliest_contact


func _append_path_errors(
	errors: PackedStringArray, paths: Array[PackedVector2Array], label: String
) -> void:
	if paths.size() != ROUTE_COUNT:
		errors.append("ParkCourse needs exactly three %s paths." % label.to_lower())
		return
	for path_index in paths.size():
		if paths[path_index].size() < 2:
			errors.append("%s path %d needs at least two points." % [label, path_index])
			continue
		for point_index in range(paths[path_index].size() - 1):
			if paths[path_index][point_index + 1].x <= paths[path_index][point_index].x:
				errors.append(
					"%s path %d points must be strictly ordered by progress." % [label, path_index]
				)
				break


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
