@tool
## Authored approach course: rider path polyline, travel surfaces, and control zones.
class_name ParkCourse
extends Resource

const ParkSurfaceScene := preload("res://src/game/park/park_surface.gd")
const ParkControlZoneScene := preload("res://src/game/park/park_control_zone.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

@export var course_version := "park-course-v1"
@export var approach_rider_path := PackedVector2Array()
@export var lane_min := -360.0
@export var lane_max := 360.0
@export var surfaces: Array[ParkSurfaceScene] = []
@export var control_zones: Array[ParkControlZoneScene] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if approach_rider_path.size() < 2:
		errors.append("ParkCourse needs at least two approach rider path points.")
		return errors

	for point_index in range(approach_rider_path.size() - 1):
		var start := approach_rider_path[point_index]
		var end := approach_rider_path[point_index + 1]
		if end.x <= start.x:
			errors.append(
				(
					"Approach rider path points %d and %d must be strictly ordered by progress."
					% [point_index, point_index + 1]
				)
			)

	if lane_min >= lane_max:
		errors.append("ParkCourse lane_min must be less than lane_max.")
	for surface in surfaces:
		errors.append_array(surface.validation_errors())
	for zone in control_zones:
		errors.append_array(zone.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func surface_position_at(course_progress: float, lane_position := 0.0) -> Vector2:
	return Vector2(course_progress, surface_y_at(course_progress, lane_position))


func surface_y_at(course_progress: float, _lane_position := 0.0) -> float:
	if approach_rider_path.is_empty():
		push_error("ParkCourse has no approach rider path points.")
		return 0.0
	if course_progress <= approach_rider_path[0].x:
		return approach_rider_path[0].y
	for point_index in range(approach_rider_path.size() - 1):
		var start := approach_rider_path[point_index]
		var end := approach_rider_path[point_index + 1]
		if course_progress <= end.x:
			return lerpf(start.y, end.y, inverse_lerp(start.x, end.x, course_progress))
	return approach_rider_path[-1].y


func tangent_at(course_progress: float) -> Vector2:
	if approach_rider_path.size() < 2:
		push_error(
			"ParkCourse needs at least two approach rider path points to calculate a tangent."
		)
		return Vector2.RIGHT
	return _segment_at(course_progress).normalized()


func normal_at(course_progress: float) -> Vector2:
	var tangent := tangent_at(course_progress)
	return Vector2(tangent.y, -tangent.x)


## Terrain pitch dy/dx at a ground position. Positive means downhill (surface Y
## grows with progress), negative means uphill. Example: a kicker lip reads < 0.
func gradient_at(course_progress: float, lane_position := 0.0, sample_distance := 4.0) -> float:
	var forward := surface_y_at(course_progress + sample_distance, lane_position)
	var backward := surface_y_at(course_progress - sample_distance, lane_position)
	return (forward - backward) / (2.0 * sample_distance)


func lane_bounds_at(_course_progress: float) -> Vector2:
	var surface := surface_for_progress(_course_progress)
	if surface != null:
		return surface.lane_bounds_at(_course_progress)
	return Vector2(lane_min, lane_max)


func is_within_lane(course_progress: float, lane_position: float) -> bool:
	return surface_at(Vector2(course_progress, lane_position)) != null


func surface_at(ground_position: Vector2) -> ParkSurfaceScene:
	for surface in _active_surfaces():
		if surface.contains(ground_position):
			return surface
	return null


func control_zone_at(ground_position: Vector2) -> ParkControlZoneScene:
	var selected: ParkControlZoneScene
	for zone in _active_control_zones():
		if (
			zone.contains(ground_position)
			and (selected == null or zone.priority > selected.priority)
		):
			selected = zone
	return selected


func surface_for_progress(course_progress: float) -> ParkSurfaceScene:
	for surface in _active_surfaces():
		if surface.has_progress(course_progress):
			return surface
	return null


func _active_surfaces() -> Array[ParkSurfaceScene]:
	if not surfaces.is_empty():
		return surfaces
	return _legacy_surfaces()


func _active_control_zones() -> Array[ParkControlZoneScene]:
	if not control_zones.is_empty():
		return control_zones
	return _legacy_control_zones()


func _legacy_surfaces() -> Array[ParkSurfaceScene]:
	return [
		_make_surface(
			&"approach", ParkSurfaceScene.Role.APPROACH, spawn_progress(), _approach_path_end()
		)
	]


func _legacy_control_zones() -> Array[ParkControlZoneScene]:
	return [
		_make_zone(
			&"approach",
			RiderStateScene.ControlMode.APPROACH,
			spawn_progress(),
			_approach_path_end(),
			0
		)
	]


func spawn_progress() -> float:
	if approach_rider_path.is_empty():
		return 0.0
	return approach_rider_path[0].x


func _approach_path_end() -> float:
	if approach_rider_path.is_empty():
		return 0.0
	return approach_rider_path[-1].x


func _make_surface(
	id: StringName, role: int, progress_start: float, progress_end: float
) -> ParkSurfaceScene:
	var surface := ParkSurfaceScene.new()
	surface.id = id
	surface.role = role
	surface.footprint = _rectangle_footprint(progress_start, progress_end)
	if role == ParkSurfaceScene.Role.TAKEOFF:
		surface.launch_edge_index = 1
	return surface


func _make_zone(
	id: StringName, mode: int, progress_start: float, progress_end: float, priority: int
) -> ParkControlZoneScene:
	var zone := ParkControlZoneScene.new()
	zone.id = id
	zone.control_mode = mode
	zone.footprint = _rectangle_footprint(progress_start, progress_end)
	zone.priority = priority
	return zone


func _rectangle_footprint(progress_start: float, progress_end: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(progress_start, lane_min),
			Vector2(progress_end, lane_min),
			Vector2(progress_end, lane_max),
			Vector2(progress_start, lane_max),
		]
	)


func swept_terrain_intersection(
	previous_position: Vector2,
	next_position: Vector2,
	previous_lane_position := 0.0,
	next_lane_position := 0.0
) -> Dictionary:
	# Return the earliest forward flight/terrain contact, including contacts at terrain seams.
	if approach_rider_path.size() < 2 or next_position.x <= previous_position.x:
		return {}
	var earliest_contact := {}
	for point_index in range(approach_rider_path.size() - 1):
		var terrain_start := approach_rider_path[point_index]
		var terrain_end := approach_rider_path[point_index + 1]
		if terrain_end.x < previous_position.x or terrain_start.x > next_position.x:
			continue
		var contact := _segment_intersection(
			previous_position, next_position, terrain_start, terrain_end
		)
		if contact.is_empty():
			continue
		var contact_position: Vector2 = contact["position"]
		var contact_lane := lerpf(
			previous_lane_position, next_lane_position, float(contact["time"])
		)
		if surface_at(Vector2(contact_position.x, contact_lane)) == null:
			continue
		if earliest_contact.is_empty() or float(contact["time"]) < float(earliest_contact["time"]):
			earliest_contact = contact
			var tangent := (terrain_end - terrain_start).normalized()
			earliest_contact["tangent"] = tangent
			earliest_contact["normal"] = Vector2(tangent.y, -tangent.x)
	return earliest_contact


func _segment_at(course_progress: float) -> Vector2:
	if course_progress <= approach_rider_path[0].x:
		return approach_rider_path[1] - approach_rider_path[0]
	for point_index in range(approach_rider_path.size() - 1):
		var start := approach_rider_path[point_index]
		var end := approach_rider_path[point_index + 1]
		if course_progress <= end.x:
			return end - start
	return approach_rider_path[-1] - approach_rider_path[-2]


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
