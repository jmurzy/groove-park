@tool
## Visual authoring surface for the three selectable approach and landing profiles.
## Select a path in the 2D viewport to use Godot's native Curve2D handles.
class_name ParkCourseEditor
extends Node2D

const PARK_COURSE_PATH := "res://src/game/park/park_course.tres"

@onready var _park_approach_paths: Array[ParkCoursePath] = [
	$UpperApproachPath, $CenterApproachPath, $LowerApproachPath
]
@onready var _park_landing_paths: Array[ParkCoursePath] = [
	$UpperLandingPath, $CenterLandingPath, $LowerLandingPath
]


func _ready() -> void:
	load_from_course()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		save_to_course()


func load_from_course() -> void:
	var course := load(PARK_COURSE_PATH) as ParkCourse
	if course == null:
		push_error("Could not load ParkCourse from %s." % PARK_COURSE_PATH)
		return
	_load_paths(course.routes, _park_approach_paths, true)
	_load_paths(course.routes, _park_landing_paths, false)


func _load_paths(
	routes: Array[ParkRoute], editor_paths: Array[ParkCoursePath], use_approach: bool
) -> void:
	if routes.size() != editor_paths.size():
		push_error("ParkCourse needs exactly three routes.")
		return
	for path_index in editor_paths.size():
		var curve := Curve2D.new()
		var route := routes[path_index]
		var path := route.approach_path if use_approach else route.landing_path
		for point in path:
			curve.add_point(point)
		editor_paths[path_index].curve = curve
		editor_paths[path_index].refresh_preview()


func save_to_course() -> void:
	var course := load(PARK_COURSE_PATH) as ParkCourse
	if course == null:
		push_error("Could not load ParkCourse from %s." % PARK_COURSE_PATH)
		return
	var approach_paths := _paths_from_editor(_park_approach_paths)
	var landing_paths := _paths_from_editor(_park_landing_paths)
	if approach_paths.is_empty() or landing_paths.is_empty():
		return
	if (
		course.routes.size() != approach_paths.size()
		or course.routes.size() != landing_paths.size()
	):
		push_error("ParkCourse needs exactly three routes.")
		return
	for route_index in course.routes.size():
		course.routes[route_index].approach_path = approach_paths[route_index]
		course.routes[route_index].landing_path = landing_paths[route_index]
	var errors := course.validation_errors()
	if not errors.is_empty():
		push_error("Park course not saved:\n%s" % "\n".join(errors))
		return
	var error := ResourceSaver.save(course, PARK_COURSE_PATH)
	if error != OK:
		push_error("Could not save ParkCourse: %s" % error_string(error))


func _paths_from_editor(editor_paths: Array[ParkCoursePath]) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	for editor_path in editor_paths:
		if editor_path.curve == null:
			push_error("%s needs a Curve2D before it can be saved." % editor_path.name)
			return []
		var points := PackedVector2Array()
		for point_index in editor_path.curve.point_count:
			points.append(editor_path.curve.get_point_position(point_index))
		paths.append(points)
	return paths
