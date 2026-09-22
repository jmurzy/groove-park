## Mutable world-space movement state for one rider. This never stores scoring,
## trick, or session lifecycle data.
class_name RiderKinematics
extends RefCounted

var course_progress := 0.0
var lane_position := 0.0
var vertical_position := 0.0

var ground_position := Vector2.ZERO
var ground_velocity := Vector2.ZERO
var course_speed := 0.0
var lane_speed := 0.0
var vertical_speed := 0.0

var heading := Vector2.RIGHT
var desired_heading := Vector2.RIGHT
