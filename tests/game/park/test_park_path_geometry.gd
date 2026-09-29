## Headless checks for reusable ordered course-path geometry.
extends SceneTree

const ParkPathGeometryScene := preload("res://src/game/park/park_path_geometry.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_surface_sampling_and_gradient()
	_test_tangents_and_normals()
	_test_swept_contact_uses_earliest_segment()
	if _failures.is_empty():
		print("Park path geometry checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_surface_sampling_and_gradient() -> void:
	var path := PackedVector2Array([Vector2(0, 10), Vector2(100, 110), Vector2(200, 110)])
	_expect(
		is_equal_approx(ParkPathGeometryScene.surface_y_at(path, -1.0), 10.0),
		"Path start must clamp."
	)
	_expect(
		is_equal_approx(ParkPathGeometryScene.surface_y_at(path, 50.0), 60.0),
		"Path must interpolate segments."
	)
	_expect(
		is_equal_approx(ParkPathGeometryScene.surface_y_at(path, 300.0), 110.0),
		"Path end must clamp."
	)
	_expect(
		is_equal_approx(ParkPathGeometryScene.gradient_at(path, 50.0, 10.0), 1.0),
		"Gradient must sample path slope."
	)


func _test_tangents_and_normals() -> void:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 100), Vector2(200, 100)])
	var tangent := ParkPathGeometryScene.tangent_at(path, 50.0)
	var normal := ParkPathGeometryScene.normal_for_tangent(tangent)
	_expect(
		tangent.is_equal_approx(Vector2(1, 1).normalized()), "Tangent must follow active segment."
	)
	_expect(is_zero_approx(tangent.dot(normal)), "Normal must be perpendicular to tangent.")
	_expect(
		ParkPathGeometryScene.end_tangent(path).is_equal_approx(Vector2.RIGHT),
		"End tangent must use final segment."
	)


func _test_swept_contact_uses_earliest_segment() -> void:
	var path := PackedVector2Array([Vector2(100, 100), Vector2(200, 200), Vector2(300, 100)])
	var contact := ParkPathGeometryScene.swept_terrain_intersection(
		path, Vector2(50, 0), Vector2(250, 300)
	)
	_expect(not contact.is_empty(), "Swept path must detect terrain contact.")
	if contact.is_empty():
		return
	var position: Vector2 = contact["position"]
	_expect(position.is_equal_approx(Vector2(150, 150)), "Earliest segment contact must win.")
	var normal: Vector2 = contact["normal"]
	_expect(
		normal.is_equal_approx(Vector2(1, -1).normalized()),
		"Contact must include the terrain normal."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
