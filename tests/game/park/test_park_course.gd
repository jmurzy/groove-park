## Headless checks for authored approach, gap, landing, and runout geometry.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const ShippedParkCourse := preload("res://src/game/park/park_course.tres")

var _failures := PackedStringArray()


func _init() -> void:
	_test_shipped_course_contract()
	_test_flight_routes_require_a_gap()
	_test_ground_route_requires_a_continuous_join()
	_test_landing_paths_are_ordered()
	_test_landing_collision_ignores_the_gap()
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
		ShippedParkCourse.approach_paths.size() == ParkCourse.ROUTE_COUNT,
		"The shipped course must define three approach paths."
	)
	_expect(
		ShippedParkCourse.landing_paths.size() == ParkCourse.ROUTE_COUNT,
		"The shipped course must define three landing paths."
	)
	_expect(
		(
			ShippedParkCourse.route_kinds
			== [
				ParkCourse.RouteKind.FLIGHT,
				ParkCourse.RouteKind.FLIGHT,
				ParkCourse.RouteKind.GROUND_RUNOUT,
			]
		),
		"The upper and center routes should fly while the lower route stays grounded."
	)


func _test_flight_routes_require_a_gap() -> void:
	var course := _valid_course()
	var landing_path := course.landing_paths[0]
	landing_path[0] = Vector2(course.approach_paths[0][-1].x, landing_path[0].y)
	course.landing_paths[0] = landing_path
	_expect(
		course.validation_errors().has("Flight route 0 landing must start after its lip."),
		"A flight landing must not connect directly to its lip."
	)


func _test_ground_route_requires_a_continuous_join() -> void:
	var course := _valid_course()
	var landing_path := course.landing_paths[2]
	landing_path[0] += Vector2(1.0, 0.0)
	course.landing_paths[2] = landing_path
	_expect(
		course.validation_errors().has(
			"Ground route 2 landing must start at its approach endpoint."
		),
		"The grounded route must join its runout without a gap."
	)


func _test_landing_paths_are_ordered() -> void:
	var course := _valid_course()
	course.landing_paths[1] = PackedVector2Array([Vector2(300, 100), Vector2(200, 200)])
	_expect(
		course.validation_errors().has(
			"Landing path 1 points must be strictly ordered by progress."
		),
		"Landing path points must move forward through the course."
	)


func _test_landing_collision_ignores_the_gap() -> void:
	var course := _valid_course()
	var gap_contact := course.landing_swept_terrain_intersection(
		Vector2(100, 0), Vector2(190, 90), 0
	)
	var landing_contact := course.landing_swept_terrain_intersection(
		Vector2(150, 0), Vector2(250, 200), 0
	)
	_expect(gap_contact.is_empty(), "Flight through the authored gap must not hit terrain.")
	_expect(not landing_contact.is_empty(), "Flight crossing a landing path must hit terrain.")
	if not landing_contact.is_empty():
		var contact_position: Vector2 = landing_contact["position"]
		_expect(
			contact_position.is_equal_approx(Vector2(200, 100)),
			"Landing collision should report the first swept contact."
		)


func _valid_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.approach_paths = [
		PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		PackedVector2Array([Vector2(0, 100), Vector2(100, 100)]),
		PackedVector2Array([Vector2(0, 200), Vector2(100, 200)]),
	]
	course.landing_paths = [
		PackedVector2Array([Vector2(200, 100), Vector2(300, 200)]),
		PackedVector2Array([Vector2(220, 200), Vector2(320, 300)]),
		PackedVector2Array([Vector2(100, 200), Vector2(300, 300)]),
	]
	return course


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
