## Headless checks for authored approach, landing, bail, and runout geometry.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const ShippedParkCourse := preload("res://src/game/park/park_course.tres")

var _failures := PackedStringArray()


func _init() -> void:
	_test_shipped_course_contract()
	_test_route_kinds_match_fixed_route_roles()
	_test_flight_landing_must_start_after_lip()
	_test_ground_route_requires_a_continuous_join()
	_test_landing_paths_are_ordered()
	_test_landing_collision_uses_authored_segments_only()
	_test_landing_collision_handles_segment_seams()
	_test_flight_miss_boundary_connects_lip_and_landing()
	_test_flight_bail_floor_stays_below_landing_geometry()
	if _failures.is_empty():
		print("Park course checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_shipped_course_contract() -> void:
	_expect(ShippedParkCourse.is_valid(), "The shipped park course must be valid.")
	_expect(
		ShippedParkCourse.routes.size() == ParkCourse.ROUTE_COUNT,
		"The shipped course must define three approach paths."
	)
	_expect(
		ShippedParkCourse.routes.size() == ParkCourse.ROUTE_COUNT,
		"The shipped course must define three landing paths."
	)
	_expect(
		(
			ShippedParkCourse.route_at(0).kind == ParkRoute.Kind.FLIGHT
			and ShippedParkCourse.route_at(1).kind == ParkRoute.Kind.FLIGHT
			and ShippedParkCourse.route_at(2).kind == ParkRoute.Kind.GROUND_RUNOUT
		),
		"The upper and center routes should fly while the lower route stays grounded."
	)


func _test_route_kinds_match_fixed_route_roles() -> void:
	var course := _valid_course()
	course.route_at(0).kind = ParkRoute.Kind.GROUND_RUNOUT
	_expect(
		course.validation_errors().has("Route 0 must be FLIGHT."),
		"The upper route must be a flight route."
	)
	course = _valid_course()
	course.route_at(2).kind = ParkRoute.Kind.FLIGHT
	_expect(
		course.validation_errors().has("Route 2 must be GROUND_RUNOUT."),
		"The lower route must be a grounded runout."
	)


func _test_flight_landing_must_start_after_lip() -> void:
	var course := _valid_course()
	var landing_path := course.route_at(0).landing_path
	landing_path[0] = course.route_at(0).approach_path[-1]
	course.route_at(0).landing_path = landing_path
	_expect(
		course.validation_errors().has("Flight route 0 landing must start after its lip."),
		"A flight landing path must begin after its approach lip."
	)


func _test_ground_route_requires_a_continuous_join() -> void:
	var course := _valid_course()
	var landing_path := course.route_at(2).landing_path
	landing_path[0] += Vector2(1.0, 0.0)
	course.route_at(2).landing_path = landing_path
	_expect(
		course.validation_errors().has(
			"Ground route 2 landing must start at its approach endpoint."
		),
		"The grounded route must join its runout continuously."
	)


func _test_landing_paths_are_ordered() -> void:
	var course := _valid_course()
	course.route_at(1).landing_path = PackedVector2Array([Vector2(300, 100), Vector2(200, 200)])
	_expect(
		course.validation_errors().has(
			"Landing path 1 points must be strictly ordered by progress."
		),
		"Landing path points must move forward through the course."
	)


func _test_landing_collision_uses_authored_segments_only() -> void:
	var course := _valid_course()
	var outside_contact := course.landing_swept_terrain_intersection(
		Vector2(100, 0), Vector2(190, 90), 0
	)
	var landing_contact := course.landing_swept_terrain_intersection(
		Vector2(150, 0), Vector2(250, 200), 0
	)
	_expect(outside_contact.is_empty(), "Flight outside authored landing segments must not hit.")
	_expect(not landing_contact.is_empty(), "Flight crossing a landing path must hit terrain.")
	if not landing_contact.is_empty():
		var contact_position: Vector2 = landing_contact["position"]
		_expect(
			contact_position.is_equal_approx(Vector2(200, 100)),
			"Landing collision should report the first swept contact."
		)


func _test_landing_collision_handles_segment_seams() -> void:
	var course := _valid_course()
	course.route_at(0).landing_path = PackedVector2Array(
		[Vector2(100, 10), Vector2(150, 20), Vector2(200, 30)]
	)
	var contact := course.landing_swept_terrain_intersection(Vector2(140, 0), Vector2(160, 40), 0)
	_expect(not contact.is_empty(), "Landing collision must detect contact at a segment seam.")
	if not contact.is_empty():
		var contact_position: Vector2 = contact["position"]
		_expect(
			contact_position.is_equal_approx(Vector2(150, 20)),
			"Landing seam collision should resolve the shared endpoint once."
		)


func _test_flight_miss_boundary_connects_lip_and_landing() -> void:
	var course := _valid_course()
	var boundary := course.flight_miss_boundary_points(0)
	_expect(
		boundary[0].is_equal_approx(course.route_at(0).approach_path[-1]),
		"The miss boundary should begin at the selected approach lip."
	)
	_expect(
		boundary[-1].is_equal_approx(course.route_at(0).landing_path[-1]),
		"The miss boundary should follow the landing path to its endpoint."
	)
	_expect(
		is_equal_approx(course.flight_miss_boundary_y_at(150.0, 0), 50.0),
		"The miss boundary should connect the active lip to its landing path."
	)


func _test_flight_bail_floor_stays_below_landing_geometry() -> void:
	var course := _valid_course()
	course.flight_bail_y = 50.0
	var miss_boundary := course.flight_miss_boundary_points(0)
	var bail_floor := course.flight_bail_floor_points(0)
	_expect(
		bail_floor[-1].y >= course.route_at(0).landing_path[-1].y,
		"The bail floor must not preempt a later landing-path intersection."
	)
	_expect(
		bail_floor[0].is_equal_approx(miss_boundary[0]),
		"The curved bail floor should begin at the active lip."
	)
	_expect(
		is_equal_approx(bail_floor[-1].y, 200.0),
		"The curved bail boundary should end at the route floor."
	)
	_expect(
		bail_floor.size() > miss_boundary.size(),
		"The bail floor should contain enough samples to render a smooth arc."
	)
	var sample_x := 150.0
	_expect(
		is_equal_approx(
			course.flight_bail_trigger_y_at(sample_x, 0),
			(
				(
					course.flight_miss_boundary_y_at(sample_x, 0)
					+ course.flight_bail_floor_y_at(sample_x, 0)
				)
				* 0.5
			)
		),
		"The bail trigger should stay centered inside the zone."
	)
	for point in bail_floor:
		_expect(
			point.y >= course.flight_miss_boundary_y_at(point.x, 0),
			"The bail floor must remain below its miss boundary."
		)


func _valid_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.routes = [
		_route(
			&"upper",
			PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
			PackedVector2Array([Vector2(200, 100), Vector2(300, 200)])
		),
		_route(
			&"center",
			PackedVector2Array([Vector2(0, 100), Vector2(100, 100)]),
			PackedVector2Array([Vector2(220, 200), Vector2(320, 300)])
		),
		_route(
			&"lower",
			PackedVector2Array([Vector2(0, 200), Vector2(100, 200)]),
			PackedVector2Array([Vector2(100, 200), Vector2(300, 300)]),
			ParkRoute.Kind.GROUND_RUNOUT
		),
	]
	return course


func _route(
	id: StringName,
	approach_path: PackedVector2Array,
	landing_path: PackedVector2Array,
	kind := ParkRoute.Kind.FLIGHT
) -> ParkRoute:
	var route := ParkRoute.new()
	route.id = id
	route.approach_path = approach_path
	route.landing_path = landing_path
	route.kind = kind
	return route


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
