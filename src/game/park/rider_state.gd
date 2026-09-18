class_name RiderState
extends RefCounted

enum Phase { GROUNDED, AIRBORNE }

# World-space simulation coordinates. Presentation projects these into the side view.
var course_progress := 0.0
var lane_position := 0.0
var vertical_position := 0.0

var ground_position := Vector2.ZERO
var ground_velocity := Vector2.ZERO
var course_speed := 0.0
var lane_speed := 0.0
var vertical_speed := 0.0

# Ground orientation is independent from the projected terrain tangent.
var heading := Vector2.RIGHT
var desired_heading := Vector2.RIGHT
var has_ground_intent := false
var tuck_active := false
var brake_active := false
var edge_active := false

# Takeoff is captured once at the lip. Airborne translation is Milestone 5 work.
var phase := Phase.GROUNDED
var compression_active := false
var compression_amount := 0.0
var compression_release_progress := -1.0
var compression_release_quality := 0.0
var takeoff_course_speed := 0.0
var takeoff_lane_speed := 0.0
var takeoff_vertical_speed := 0.0
var takeoff_pop_impulse := 0.0
var takeoff_tangent := Vector2.RIGHT
var takeoff_normal := Vector2.UP
