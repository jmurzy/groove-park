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
	return ParkPathGeometry.surface_y_at(approach_path, course_progress)


func approach_gradient_at(course_progress: float, sample_distance := 4.0) -> float:
	return ParkPathGeometry.gradient_at(approach_path, course_progress, sample_distance)


func lip_tangent() -> Vector2:
	return ParkPathGeometry.end_tangent(approach_path)


func lip_normal() -> Vector2:
	return ParkPathGeometry.normal_for_tangent(lip_tangent())


func landing_surface_y_at(course_progress: float) -> float:
	return ParkPathGeometry.surface_y_at(landing_path, course_progress)


func landing_tangent_at(course_progress: float) -> Vector2:
	return ParkPathGeometry.tangent_at(landing_path, course_progress)


func flight_miss_boundary_points() -> PackedVector2Array:
	var points := PackedVector2Array([approach_path[-1]])
	points.append_array(landing_path)
	return points


func landing_swept_terrain_intersection(
	previous_position: Vector2, next_position: Vector2
) -> Dictionary:
	return ParkPathGeometry.swept_terrain_intersection(
		landing_path, previous_position, next_position
	)


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
