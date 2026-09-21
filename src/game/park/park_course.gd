class_name ParkCourse
extends Resource

const ParkSurfaceScene := preload("res://src/game/park/park_surface.gd")
const ParkControlZoneScene := preload("res://src/game/park/park_control_zone.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

@export var course_version := "park-course-v1"
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
@export var surfaces: Array[ParkSurfaceScene] = []
@export var control_zones: Array[ParkControlZoneScene] = []


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
	for surface in surfaces:
		errors.append_array(surface.validation_errors())
	for zone in control_zones:
		errors.append_array(zone.validation_errors())
	if not _markers_are_ordered():
		errors.append("ParkCourse feature markers must be ordered from start through camera end.")
	var terrain_start := terrain_points[0].x
	var terrain_end := terrain_points[-1].x
	if (
		(camera_start < terrain_start and not is_equal_approx(camera_start, terrain_start))
		or (camera_end > terrain_end and not is_equal_approx(camera_end, terrain_end))
	):
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


func crosses_launch_edge(previous_position: Vector2, next_position: Vector2) -> Dictionary:
	var surface := surface_at(previous_position)
	if surface == null or surface.role != ParkSurfaceScene.Role.TAKEOFF:
		return {}
	var position := surface.launch_intersection(previous_position, next_position)
	if not position.is_finite():
		return {}
	return {"surface": surface, "position": position}


func crosses_progress(
	previous_progress: float, next_progress: float, marker_progress: float
) -> bool:
	return previous_progress < marker_progress and next_progress >= marker_progress


func crosses_lip(previous_progress: float, next_progress: float) -> bool:
	return crosses_progress(previous_progress, next_progress, lip_progress)


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
			&"approach", ParkSurfaceScene.Role.APPROACH, start_progress, compression_start
		),
		_make_surface(&"takeoff", ParkSurfaceScene.Role.TAKEOFF, compression_start, lip_progress),
		_make_surface(&"landing", ParkSurfaceScene.Role.LANDING, landing_start, landing_end),
		_make_surface(&"runout", ParkSurfaceScene.Role.RUNOUT, landing_end, recovery_progress),
	]


func _legacy_control_zones() -> Array[ParkControlZoneScene]:
	return [
		_make_zone(
			&"approach", RiderStateScene.ControlMode.APPROACH, start_progress, compression_start, 0
		),
		_make_zone(
			&"compression",
			RiderStateScene.ControlMode.COMPRESSION,
			compression_start,
			compression_end,
			1
		),
		_make_zone(
			&"takeoff", RiderStateScene.ControlMode.TAKEOFF, compression_end, lip_progress, 0
		),
		_make_zone(&"landing", RiderStateScene.ControlMode.LANDING, landing_start, landing_end, 0),
		_make_zone(
			&"runout", RiderStateScene.ControlMode.RUNOUT, landing_end, recovery_progress, 0
		),
	]


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
	if terrain_points.size() < 2 or next_position.x <= previous_position.x:
		return {}
	var earliest_contact := {}
	for point_index in range(terrain_points.size() - 1):
		var terrain_start := terrain_points[point_index]
		var terrain_end := terrain_points[point_index + 1]
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
