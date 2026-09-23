## Headless checks for authored approach, landing, abandon, and runout geometry.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const ShippedParkCourse := preload("res://src/game/park/park_course.tres")

var _failures := PackedStringArray()


func _init() -> void:
	_test_shipped_course_contract()
	_test_flight_landing_must_start_after_lip()
	_test_ground_route_requires_a_continuous_join()
	_test_landing_paths_are_ordered()
	_test_landing_collision_uses_authored_segments_only()
	_test_landing_collision_handles_segment_seams()
	_test_flight_miss_boundary_connects_lip_and_landing()
	_test_flight_abandon_floor_stays_below_landing_geometry()
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


func _test_flight_landing_must_start_after_lip() -> void:
	var course := _valid_course()
	var landing_path := course.landing_paths[0]
	landing_path[0] = course.approach_paths[0][-1]
	course.landing_paths[0] = landing_path
	_expect(
		course.validation_errors().has("Flight route 0 landing must start after its lip."),
		"A flight landing path must begin after its approach lip."
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
		"The grounded route must join its runout continuously."
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
	course.landing_paths[0] = PackedVector2Array(
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
		boundary[0].is_equal_approx(course.approach_paths[0][-1]),
		"The miss boundary should begin at the selected approach lip."
	)
	_expect(
		boundary[-1].is_equal_approx(course.landing_paths[0][-1]),
		"The miss boundary should follow the landing path to its endpoint."
	)
	_expect(
		is_equal_approx(course.flight_miss_boundary_y_at(150.0, 0), 50.0),
		"The miss boundary should connect the active lip to its landing path."
	)


func _test_flight_abandon_floor_stays_below_landing_geometry() -> void:
	var course := _valid_course()
	course.flight_abandon_y = 50.0
	var miss_boundary := course.flight_miss_boundary_points(0)
	var abandon_floor := course.flight_abandon_floor_points(0)
	_expect(
		abandon_floor[-1].y >= course.landing_paths[0][-1].y,
		"The abandon floor must not preempt a later landing-path intersection."
	)
	_expect(
		abandon_floor[0].is_equal_approx(miss_boundary[0]),
		"The curved abandon floor should begin at the active lip."
	)
	_expect(
		is_equal_approx(abandon_floor[-1].y, 200.0),
		"The curved abandon boundary should end at the route floor."
	)
	_expect(
		abandon_floor.size() > miss_boundary.size(),
		"The abandon floor should contain enough samples to render a smooth arc."
	)
	var sample_x := 150.0
	_expect(
		is_equal_approx(
			course.flight_abandon_trigger_y_at(sample_x, 0),
			(
				(
					course.flight_miss_boundary_y_at(sample_x, 0)
					+ course.flight_abandon_floor_y_at(sample_x, 0)
				)
				* 0.5
			)
		),
		"The abandon trigger should stay centered inside the zone."
	)
	for point in abandon_floor:
		_expect(
			point.y >= course.flight_miss_boundary_y_at(point.x, 0),
			"The abandon floor must remain below its miss boundary."
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
