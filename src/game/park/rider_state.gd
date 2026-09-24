## Compatibility facade for one rider's mutable runtime state. Focused models
## own movement, lifecycle, and jump data; callers can continue reading this
## facade while simulations migrate to the focused contracts.
class_name RiderState
extends RefCounted

enum RunPhase {
	APPROACH = RiderRunState.RunPhase.APPROACH,
	FLIGHT = RiderRunState.RunPhase.FLIGHT,
	LANDING = RiderRunState.RunPhase.LANDING,
	COMPLETE = RiderRunState.RunPhase.COMPLETE,
}
enum LandingOutcome {
	NONE = RiderRunState.LandingOutcome.NONE,
	ABANDON = RiderRunState.LandingOutcome.ABANDON,
	CLEAN = RiderRunState.LandingOutcome.CLEAN,
	SKETCHY = RiderRunState.LandingOutcome.SKETCHY,
	CRASH = RiderRunState.LandingOutcome.CRASH,
}

var kinematics := RiderKinematics.new()
var run := RiderRunState.new()
var jump := JumpState.new()

var course_progress: float:
	get:
		return kinematics.course_progress
	set(value):
		kinematics.course_progress = value
var lane_position: float:
	get:
		return kinematics.lane_position
	set(value):
		kinematics.lane_position = value
var vertical_position: float:
	get:
		return kinematics.vertical_position
	set(value):
		kinematics.vertical_position = value
var approach_path_target: int:
	get:
		return kinematics.approach_path_target
	set(value):
		kinematics.approach_path_target = value
var approach_path_position: float:
	get:
		return kinematics.approach_path_position
	set(value):
		kinematics.approach_path_position = value
var active_route_index: int:
	get:
		return kinematics.active_route_index
	set(value):
		kinematics.active_route_index = value
var ground_position: Vector2:
	get:
		return kinematics.ground_position
	set(value):
		kinematics.ground_position = value
var ground_velocity: Vector2:
	get:
		return kinematics.ground_velocity
	set(value):
		kinematics.ground_velocity = value
var course_speed: float:
	get:
		return kinematics.course_speed
	set(value):
		kinematics.course_speed = value
var lane_speed: float:
	get:
		return kinematics.lane_speed
	set(value):
		kinematics.lane_speed = value
var vertical_speed: float:
	get:
		return kinematics.vertical_speed
	set(value):
		kinematics.vertical_speed = value
var heading: Vector2:
	get:
		return kinematics.heading
	set(value):
		kinematics.heading = value
var desired_heading: Vector2:
	get:
		return kinematics.desired_heading
	set(value):
		kinematics.desired_heading = value

var run_phase: int:
	get:
		return run.run_phase
	set(value):
		run.run_phase = value
var landing_outcome: int:
	get:
		return run.landing_outcome
	set(value):
		run.landing_outcome = value
var current_surface_id: StringName:
	get:
		return run.current_surface_id
	set(value):
		run.current_surface_id = value
var has_ground_intent: bool:
	get:
		return run.has_ground_intent
	set(value):
		run.has_ground_intent = value
var tuck_active: bool:
	get:
		return run.tuck_active
	set(value):
		run.tuck_active = value
var brake_active: bool:
	get:
		return run.brake_active
	set(value):
		run.brake_active = value
var edge_active: bool:
	get:
		return run.edge_active
	set(value):
		run.edge_active = value
var recovery_time_remaining: float:
	get:
		return run.recovery_time_remaining
	set(value):
		run.recovery_time_remaining = value
var completion_time_remaining: float:
	get:
		return run.completion_time_remaining
	set(value):
		run.completion_time_remaining = value

var compression_active: bool:
	get:
		return jump.compression_active
	set(value):
		jump.compression_active = value
var compression_amount: float:
	get:
		return jump.compression_amount
	set(value):
		jump.compression_amount = value
var compression_release_progress: float:
	get:
		return jump.compression_release_progress
	set(value):
		jump.compression_release_progress = value
var compression_release_quality: float:
	get:
		return jump.compression_release_quality
	set(value):
		jump.compression_release_quality = value
var compression_auto_released: bool:
	get:
		return jump.compression_auto_released
	set(value):
		jump.compression_auto_released = value
var takeoff_position: Vector2:
	get:
		return jump.takeoff_position
	set(value):
		jump.takeoff_position = value
var takeoff_velocity: Vector2:
	get:
		return jump.takeoff_velocity
	set(value):
		jump.takeoff_velocity = value
var takeoff_course_speed: float:
	get:
		return jump.takeoff_course_speed
	set(value):
		jump.takeoff_course_speed = value
var takeoff_lane_speed: float:
	get:
		return jump.takeoff_lane_speed
	set(value):
		jump.takeoff_lane_speed = value
var takeoff_vertical_speed: float:
	get:
		return jump.takeoff_vertical_speed
	set(value):
		jump.takeoff_vertical_speed = value
var takeoff_pop_impulse: float:
	get:
		return jump.takeoff_pop_impulse
	set(value):
		jump.takeoff_pop_impulse = value
var takeoff_tangent: Vector2:
	get:
		return jump.takeoff_tangent
	set(value):
		jump.takeoff_tangent = value
var takeoff_normal: Vector2:
	get:
		return jump.takeoff_normal
	set(value):
		jump.takeoff_normal = value
var release_deadline_y: float:
	get:
		return jump.release_deadline_y
	set(value):
		jump.release_deadline_y = value
var approach_speed: float:
	get:
		return jump.approach_speed
	set(value):
		jump.approach_speed = value
var approach_speed_captured: bool:
	get:
		return jump.approach_speed_captured
	set(value):
		jump.approach_speed_captured = value
var orientation: float:
	get:
		return jump.orientation
	set(value):
		jump.orientation = value
var angular_velocity: float:
	get:
		return jump.angular_velocity
	set(value):
		jump.angular_velocity = value
var airtime: float:
	get:
		return jump.airtime
	set(value):
		jump.airtime = value
var body_compact: bool:
	get:
		return jump.body_compact
	set(value):
		jump.body_compact = value
var body_extended: bool:
	get:
		return jump.body_extended
	set(value):
		jump.body_extended = value
var landing_prep_active: bool:
	get:
		return jump.landing_prep_active
	set(value):
		jump.landing_prep_active = value
var grab_reach_active: bool:
	get:
		return jump.grab_reach_active
	set(value):
		jump.grab_reach_active = value
var tweak_active: bool:
	get:
		return jump.tweak_active
	set(value):
		jump.tweak_active = value
var grab_started_airtime: float:
	get:
		return jump.grab_started_airtime
	set(value):
		jump.grab_started_airtime = value
var grab_active_at_landing: bool:
	get:
		return jump.grab_active_at_landing
	set(value):
		jump.grab_active_at_landing = value
var trick_tracker: TrickTracker:
	get:
		return jump.trick_tracker
	set(value):
		jump.trick_tracker = value
var trick_call: String:
	get:
		return jump.trick_call
	set(value):
		jump.trick_call = value
var landing_resolved: bool:
	get:
		return jump.landing_resolved
	set(value):
		jump.landing_resolved = value
var landing_label: String:
	get:
		return jump.landing_label
	set(value):
		jump.landing_label = value
var landing_quality: float:
	get:
		return jump.landing_quality
	set(value):
		jump.landing_quality = value
var landing_position: Vector2:
	get:
		return jump.landing_position
	set(value):
		jump.landing_position = value
var landing_tangent: Vector2:
	get:
		return jump.landing_tangent
	set(value):
		jump.landing_tangent = value
var landing_normal: Vector2:
	get:
		return jump.landing_normal
	set(value):
		jump.landing_normal = value
var landing_angle_error_degrees: float:
	get:
		return jump.landing_angle_error_degrees
	set(value):
		jump.landing_angle_error_degrees = value
var landing_velocity_alignment: float:
	get:
		return jump.landing_velocity_alignment
	set(value):
		jump.landing_velocity_alignment = value
var landing_normal_impact: float:
	get:
		return jump.landing_normal_impact
	set(value):
		jump.landing_normal_impact = value
var landing_angular_speed: float:
	get:
		return jump.landing_angular_speed
	set(value):
		jump.landing_angular_speed = value
var landing_in_zone: bool:
	get:
		return jump.landing_in_zone
	set(value):
		jump.landing_in_zone = value
var jump_score: int:
	get:
		return jump.jump_score
	set(value):
		jump.jump_score = value
var score_breakdown: Dictionary:
	get:
		return jump.score_breakdown
	set(value):
		jump.score_breakdown = value


func movement_velocity() -> Vector2:
	if run_phase == RunPhase.FLIGHT:
		return Vector2(course_speed, vertical_speed)
	return ground_velocity
