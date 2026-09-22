## Mutable measurements for the jump currently in progress. Reset this at
## takeoff; turn it into a JumpResult once first landing contact resolves.
class_name JumpState
extends RefCounted

const TrickTrackerScene := preload("res://src/game/park/trick_tracker.gd")

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
var approach_speed := 0.0
var approach_speed_captured := false

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
