## Mutable lifecycle and ground-control state for one rider's active run.
class_name RiderRunState
extends RefCounted

enum MotionPhase { GROUNDED, AIRBORNE, LANDED, CRASHED, RECOVERING }
enum ControlMode { APPROACH, COMPRESSION, TAKEOFF, FLIGHT, LANDING, RUNOUT }

var motion_phase := MotionPhase.GROUNDED
var current_surface_id: StringName
var current_control_zone_id: StringName
var control_mode := ControlMode.APPROACH
var has_ground_intent := false
var tuck_active := false
var brake_active := false
var edge_active := false
var recovery_time_remaining := 0.0
