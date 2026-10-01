## Mutable lifecycle and ground-control state for one rider's active run.
class_name RiderRunState
extends RefCounted

enum RunPhase { APPROACH, FLIGHT, LANDING, COMPLETE }

var run_phase := RunPhase.APPROACH
var jump_outcome := JumpOutcome.Value.NONE
var current_surface_id: StringName
var has_ground_intent := false
var tuck_active := false
var brake_active := false
var edge_active := false
var low_momentum_start_progress := 0.0
var low_momentum_last_progress := 0.0
var low_momentum_no_progress_time := 0.0
var low_momentum_stop_time := 0.0
var completion_time_remaining := 0.0
