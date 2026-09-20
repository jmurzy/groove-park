class_name RiderState
extends RefCounted

enum Phase { GROUNDED, AIRBORNE, LANDED, CRASHED, RECOVERING }

const TrickTrackerScene := preload("res://src/game/park/trick_tracker.gd")

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

# Air orientation is unwrapped so completed rotations can be measured later.
var orientation := 0.0
var angular_velocity := 0.0
var airtime := 0.0
var body_compact := false
var body_extended := false
var landing_prep_active := false
var grab_reach_active := false
var tweak_active := false
var grab_active_at_landing := false
var trick_tracker: TrickTracker = TrickTrackerScene.new()
var trick_call := ""

# First meaningful terrain contact is authoritative for the whole jump.
var landing_resolved := false
var landing_label := ""
var landing_quality := 0.0
var landing_position := Vector2.ZERO
var landing_tangent := Vector2.RIGHT
var landing_normal := Vector2.UP
var landing_angle_error_degrees := 0.0
var landing_velocity_alignment := 0.0
var landing_normal_impact := 0.0
var landing_angular_speed := 0.0
var landing_in_zone := false
var recovery_time_remaining := 0.0
