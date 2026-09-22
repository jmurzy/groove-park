@tool
## Authored terrain profile and ordered movement phase paths.
class_name ParkCourse
extends Resource

const ParkPhasePathScene := preload("res://src/game/park/park_phase_path.gd")

@export var course_version := "park-course-v1"
@export var approach_rider_path := PackedVector2Array()
@export var lane_min := -360.0
@export var lane_max := 360.0
@export var phase_paths: Array[ParkPhasePathScene] = []


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
	if phase_paths.is_empty():
		errors.append("ParkCourse needs at least one phase path.")
	var previous_phase_end := -INF
	var has_approach_path := false
	for phase_path in phase_paths:
		errors.append_array(phase_path.validation_errors())
		if phase_path.phase == ParkPhasePath.Phase.APPROACH:
			has_approach_path = true
		if phase_path.progress_start() < previous_phase_end:
			errors.append("ParkPhasePaths must be ordered without overlapping progress ranges.")
		previous_phase_end = phase_path.progress_end()
	if not has_approach_path:
		errors.append("ParkCourse needs an approach phase path.")
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
	return Vector2(lane_min, lane_max)


func phase_path_at(course_progress: float) -> ParkPhasePathScene:
	for phase_path in phase_paths:
		if phase_path.contains_progress(course_progress):
			return phase_path
	return null


func spawn_progress() -> float:
	if approach_rider_path.is_empty():
		return 0.0
	return approach_rider_path[0].x


func swept_terrain_intersection(
	previous_position: Vector2,
	next_position: Vector2,
	_previous_lane_position := 0.0,
	_next_lane_position := 0.0
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
