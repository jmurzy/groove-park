@tool
## Visual authoring surface for the course terrain profile.
## Select ApproachRiderPath in the 2D viewport to use Godot's native Curve2D handles.
class_name ParkCourseEditor
extends Node2D

const PARK_COURSE_PATH := "res://src/game/park/park_course.tres"

@onready var _approach_rider_path: ApproachRiderPath = $ApproachRiderPath


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
	var curve := Curve2D.new()
	for point in course.approach_rider_path:
		curve.add_point(point)
	_approach_rider_path.curve = curve
	_approach_rider_path.refresh_preview()


func save_to_course() -> void:
	if _approach_rider_path.curve == null:
		push_error("ApproachRiderPath needs a Curve2D before it can be saved.")
		return
	var course := load(PARK_COURSE_PATH) as ParkCourse
	if course == null:
		push_error("Could not load ParkCourse from %s." % PARK_COURSE_PATH)
		return
	var points := PackedVector2Array()
	for point_index in _approach_rider_path.curve.point_count:
		points.append(_approach_rider_path.curve.get_point_position(point_index))
	course.approach_rider_path = points
	var errors := course.validation_errors()
	if not errors.is_empty():
		push_error("Approach rider path not saved:\n%s" % "\n".join(errors))
		return
	var error := ResourceSaver.save(course, PARK_COURSE_PATH)
	if error != OK:
		push_error("Could not save ParkCourse: %s" % error_string(error))
