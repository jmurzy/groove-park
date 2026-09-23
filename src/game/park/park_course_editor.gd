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
	_load_paths(course.approach_paths, _park_approach_paths, "approach")
	_load_paths(course.landing_paths, _park_landing_paths, "landing")


func _load_paths(
	paths: Array[PackedVector2Array], editor_paths: Array[ParkCoursePath], label: String
) -> void:
	if paths.size() != editor_paths.size():
		push_error("ParkCourse needs exactly three %s paths." % label)
		return
	for path_index in editor_paths.size():
		var curve := Curve2D.new()
		for point in paths[path_index]:
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
	course.approach_paths = approach_paths
	course.landing_paths = landing_paths
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
