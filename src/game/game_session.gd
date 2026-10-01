## Owns the active player session: phase, rider selection, park run, and pause state.
class_name GameSession
extends Node

signal session_phase_changed(phase: int)

var session_phase := RoundState.SessionPhase.ATTRACT
var rider_kind: StringName = RiderKind.SNOWBOARDER
var run_manager: RiderRunManager
var is_paused := false


func start_game(selected_rider_kind: StringName) -> void:
	if not RiderKind.is_valid(selected_rider_kind):
		push_error("A game can only start with a valid rider kind.")
		return
	rider_kind = selected_rider_kind
	run_manager = null
	is_paused = false
	_set_session_phase(RoundState.SessionPhase.JUMP_ACTIVE)


func begin_run(course: ParkCourse) -> void:
	if session_phase != RoundState.SessionPhase.JUMP_ACTIVE:
		push_error("A run can only begin while playing.")
		return
	run_manager = RiderRunManager.new()
	run_manager.setup(course)


func step_run(
	input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if not run_manager or is_paused or session_phase != RoundState.SessionPhase.JUMP_ACTIVE:
		return
	run_manager.step(input, course, tuning, delta)


func restart_run(course: ParkCourse) -> void:
	if not run_manager:
		begin_run(course)
		return
	run_manager.reset_run(course)


func set_paused(next_paused: bool) -> void:
	if is_paused == next_paused:
		return
	is_paused = next_paused


func return_to_attract() -> void:
	is_paused = false
	run_manager = null
	_set_session_phase(RoundState.SessionPhase.ATTRACT)


func _set_session_phase(next_phase: int) -> void:
	if session_phase == next_phase:
		return
	session_phase = next_phase
	session_phase_changed.emit(session_phase)
