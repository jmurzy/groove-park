## Mutable measurements for the jump currently in progress. Reset this at
## takeoff; turn it into a JumpResult once first landing contact resolves.
class_name JumpState
extends RefCounted

enum RotationGesturePhase {
	WAITING_DIRECTION,
	ROTATING_FIRST_HALF,
	WAITING_SECOND_PRESS,
	ROTATING_SECOND_HALF,
}

const TrickTrackerScene := preload("res://src/game/park/trick_tracker.gd")

var compression_active := false
var compression_amount := 0.0
var compression_release_progress := -1.0
var compression_release_quality := 0.0
var compression_auto_released := false
var takeoff_position := Vector2.ZERO
var takeoff_velocity := Vector2.ZERO
var takeoff_course_speed := 0.0
var takeoff_lane_speed := 0.0
var takeoff_vertical_speed := 0.0
var takeoff_pop_impulse := 0.0
var takeoff_tangent := Vector2.RIGHT
var takeoff_normal := Vector2.UP
var release_deadline_y := 0.0
var approach_speed := 0.0
var approach_speed_captured := false

var orientation := 0.0
var angular_velocity := 0.0
var rotation_gesture_phase := RotationGesturePhase.WAITING_DIRECTION
var spin_direction := 0
var spin_rearmed := true
var spin_progress := 0.0
var spin_target := 0.0
var spin_grab_tweak := false
var rotation_rate := 0.0
var completed_rotations := 0
var rotation_incomplete := false
var airtime := 0.0
var body_compact := false
var body_extended := false
var landing_prep_active := false
var grab_reach_active := false
var tweak_active := false
var grab_started_airtime := -1.0
var grab_active_at_landing := false
var trick_tracker: TrickTracker = TrickTrackerScene.new()
var trick_call := ""

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
var jump_score := 0
var score_breakdown: Dictionary = {}
