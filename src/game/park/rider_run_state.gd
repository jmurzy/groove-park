## Mutable lifecycle and ground-control state for one rider's active run.
class_name RiderRunState
extends RefCounted

enum RunPhase { APPROACH, FLIGHT, LANDING, COMPLETE }
enum LandingOutcome { NONE, CLEAN, SKETCHY, CRASH }

var run_phase := RunPhase.APPROACH
var landing_outcome := LandingOutcome.NONE
var current_surface_id: StringName
var has_ground_intent := false
var tuck_active := false
var brake_active := false
var edge_active := false
var recovery_time_remaining := 0.0
