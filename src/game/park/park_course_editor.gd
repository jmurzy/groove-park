@tool
## Visual authoring surface for the three selectable approach terrain profiles.
## Select a path in the 2D viewport to use Godot's native Curve2D handles.
class_name ParkCourseEditor
extends Node2D

const PARK_COURSE_PATH := "res://src/game/park/park_course.tres"

@onready var _park_approach_paths: Array[ParkApproachPath] = [
	$UpperApproachPath, $CenterApproachPath, $LowerApproachPath
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
	var paths := course.approach_paths
	if paths.size() != _park_approach_paths.size():
		paths = [course.approach_path, course.approach_path, course.approach_path]
	for path_index in _park_approach_paths.size():
		var curve := Curve2D.new()
		for point in paths[path_index]:
			curve.add_point(point)
		_park_approach_paths[path_index].curve = curve
		_park_approach_paths[path_index].refresh_preview()


func save_to_course() -> void:
	var course := load(PARK_COURSE_PATH) as ParkCourse
	if course == null:
		push_error("Could not load ParkCourse from %s." % PARK_COURSE_PATH)
		return
	var paths: Array[PackedVector2Array] = []
	for approach_path in _park_approach_paths:
		if approach_path.curve == null:
			push_error("%s needs a Curve2D before it can be saved." % approach_path.name)
			return
		var points := PackedVector2Array()
		for point_index in approach_path.curve.point_count:
			points.append(approach_path.curve.get_point_position(point_index))
		paths.append(points)
	course.approach_paths = paths
	# The middle route is the course's default profile for systems outside the approach.
	course.approach_path = paths[1]
	var errors := course.validation_errors()
	if not errors.is_empty():
		push_error("Approach rider path not saved:\n%s" % "\n".join(errors))
		return
	var error := ResourceSaver.save(course, PARK_COURSE_PATH)
	if error != OK:
		push_error("Could not save ParkCourse: %s" % error_string(error))
