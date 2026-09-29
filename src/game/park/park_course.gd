@tool
## Authored terrain profiles for the selectable park routes.
class_name ParkCourse
extends Resource

enum RouteKind { FLIGHT = ParkRoute.Kind.FLIGHT, GROUND_RUNOUT = ParkRoute.Kind.GROUND_RUNOUT }

const ROUTE_COUNT := 3
const FLIGHT_ABANDON_CLEARANCE := 0.0
const FLIGHT_ABANDON_CURVE_SEGMENTS := 24
const FLIGHT_ABANDON_TRIGGER_RATIO := 0.5

@export var routes: Array[ParkRoute] = []
@export var default_route_id: StringName = &"center"
@export var flight_abandon_y := 624.0
@export var lane_min := -360.0
@export var lane_max := 360.0

# Temporary serialization/test migration accessors. Route data is stored only in `routes`.
var approach_paths: Array[PackedVector2Array]:
	get:
		var paths: Array[PackedVector2Array] = []
		for route in routes:
			paths.append(route.approach_path)
		return paths
	set(value):
		_ensure_routes(value.size())
		for route_index in value.size():
			routes[route_index].approach_path = value[route_index]
var landing_paths: Array[PackedVector2Array]:
	get:
		var paths: Array[PackedVector2Array] = []
		for route in routes:
			paths.append(route.landing_path)
		return paths
	set(value):
		_ensure_routes(value.size())
		for route_index in value.size():
			routes[route_index].landing_path = value[route_index]
var route_kinds: Array[ParkRoute.Kind]:
	get:
		var kinds: Array[ParkRoute.Kind] = []
		for route in routes:
			kinds.append(route.kind)
		return kinds
	set(value):
		_ensure_routes(value.size())
		for route_index in value.size():
			routes[route_index].kind = value[route_index]


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if routes.size() != ROUTE_COUNT:
		errors.append("ParkCourse needs exactly three routes.")
	for route_index in routes.size():
		var route := routes[route_index]
		if route == null:
			errors.append("Route %d is missing." % route_index)
			continue
		if route.id.is_empty():
			errors.append("Route %d needs an id." % route_index)
		elif route_index_for_id(route.id) != route_index:
			errors.append("Route id %s is duplicated." % route.id)
		errors.append_array(route.validation_errors(route_index))
	if routes.size() == ROUTE_COUNT:
		for route_index in ROUTE_COUNT:
			var route := routes[route_index]
			if route == null:
				continue
			var expected_kind := (
				ParkRoute.Kind.GROUND_RUNOUT
				if route_index == ROUTE_COUNT - 1
				else ParkRoute.Kind.FLIGHT
			)
			if route.kind != expected_kind:
				(
					errors
					. append(
						(
							"Route %d must be %s."
							% [
								route_index,
								(
									"GROUND_RUNOUT"
									if expected_kind == ParkRoute.Kind.GROUND_RUNOUT
									else "FLIGHT"
								),
							]
						)
					)
				)
	if route_index_for_id(default_route_id) < 0:
		errors.append("ParkCourse default route %s is missing." % default_route_id)
	if lane_min >= lane_max:
		errors.append("ParkCourse lane_min must be less than lane_max.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func route_at(route_index: int) -> ParkRoute:
	return routes[clampi(route_index, 0, routes.size() - 1)]


func route_index_for_id(route_id: StringName) -> int:
	for route_index in routes.size():
		if routes[route_index] != null and routes[route_index].id == route_id:
			return route_index
	return -1


func default_route_index() -> int:
	return route_index_for_id(default_route_id)


func route_surface_y_at(course_progress: float, route_position: float) -> float:
	var lower_index := clampi(floori(route_position), 0, routes.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, routes.size() - 1)
	var blend := clampf(route_position - lower_index, 0.0, 1.0)
	return lerpf(
		route_at(lower_index).approach_surface_y_at(course_progress),
		route_at(upper_index).approach_surface_y_at(course_progress),
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


func route_lip_tangent(route_index: int) -> Vector2:
	return route_at(route_index).lip_tangent()


func route_lip_normal(route_index: int) -> Vector2:
	return route_at(route_index).lip_normal()


func landing_surface_y_at(course_progress: float, route_index: int) -> float:
	return route_at(route_index).landing_surface_y_at(course_progress)


func landing_surface_position_at(course_progress: float, route_index: int) -> Vector2:
	return Vector2(course_progress, landing_surface_y_at(course_progress, route_index))


func landing_tangent_at(course_progress: float, route_index: int) -> Vector2:
	return route_at(route_index).landing_tangent_at(course_progress)


func landing_end_at(route_index: int) -> Vector2:
	return route_at(route_index).landing_path[-1]


func flight_miss_boundary_y_at(course_progress: float, route_index: int) -> float:
	return ParkPathGeometry.surface_y_at(flight_miss_boundary_points(route_index), course_progress)


func flight_miss_boundary_points(route_index: int) -> PackedVector2Array:
	return route_at(route_index).flight_miss_boundary_points()


func flight_abandon_floor_points(route_index: int) -> PackedVector2Array:
	var miss_boundary := flight_miss_boundary_points(route_index)
	var abandon_floor := PackedVector2Array()
	var start := miss_boundary[0]
	var end := Vector2(miss_boundary[-1].x, _flight_abandon_y_at(route_index))
	var span := end - start
	for sample_index in range(FLIGHT_ABANDON_CURVE_SEGMENTS + 1):
		var angle := float(sample_index) / FLIGHT_ABANDON_CURVE_SEGMENTS * PI * 0.5
		abandon_floor.append(
			Vector2(start.x + span.x * (1.0 - cos(angle)), start.y + span.y * sin(angle))
		)
	return abandon_floor


func flight_abandon_floor_y_at(course_progress: float, route_index: int) -> float:
	return ParkPathGeometry.surface_y_at(flight_abandon_floor_points(route_index), course_progress)


func flight_abandon_trigger_y_at(course_progress: float, route_index: int) -> float:
	return lerpf(
		flight_miss_boundary_y_at(course_progress, route_index),
		flight_abandon_floor_y_at(course_progress, route_index),
		FLIGHT_ABANDON_TRIGGER_RATIO
	)


func route_end_at(route_position: float) -> float:
	return _blend_approach_x(route_position, true)


func route_start_at(route_position: float) -> float:
	return _blend_approach_x(route_position, false)


func landing_swept_terrain_intersection(
	previous_position: Vector2, next_position: Vector2, route_index: int
) -> Dictionary:
	if route_index < 0 or route_index >= routes.size():
		return {}
	return routes[route_index].landing_swept_terrain_intersection(previous_position, next_position)


func _ensure_routes(route_count: int) -> void:
	while routes.size() < route_count:
		var route := ParkRoute.new()
		route.id = (
			[&"upper", &"center", &"lower"][routes.size()]
			if routes.size() < 3
			else &"route_%d" % routes.size()
		)
		route.kind = ParkRoute.Kind.GROUND_RUNOUT if routes.size() == 2 else ParkRoute.Kind.FLIGHT
		routes.append(route)
	if routes.size() > route_count:
		routes.resize(route_count)


func _flight_abandon_y_at(route_index: int) -> float:
	var landing_path := route_at(route_index).landing_path
	var lowest_landing_y := landing_path[0].y
	for point in landing_path:
		lowest_landing_y = maxf(lowest_landing_y, point.y)
	return maxf(flight_abandon_y, lowest_landing_y + FLIGHT_ABANDON_CLEARANCE)


func _blend_approach_x(route_position: float, use_end: bool) -> float:
	var lower_index := clampi(floori(route_position), 0, routes.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, routes.size() - 1)
	var blend := clampf(route_position - lower_index, 0.0, 1.0)
	var lower_path := route_at(lower_index).approach_path
	var upper_path := route_at(upper_index).approach_path
	var point_index := -1 if use_end else 0
	return lerpf(lower_path[point_index].x, upper_path[point_index].x, blend)
