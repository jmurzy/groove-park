## Owns authoritative round lifecycle, rider selection, park run, and pause state.
class_name GameSession
extends Node

signal phase_changed(phase: int)
signal jump_started(round_state: RoundState)
signal jump_result_recorded(round_state: RoundState, jump_result: JumpResult)
signal round_completed(round_state: RoundState)

const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")

var session_phase := RoundState.SessionPhase.ATTRACT
var rider_kind: StringName = RiderKind.SNOWBOARDER
var round_id := ""
var leaderboard_generation := 0
var run_manager: RiderRunManager
var is_paused := false
var _round_state: RoundState
var _course: ParkCourse = PARK_COURSE_RESOURCE.duplicate()
var _tuning: RiderTuning = RIDER_TUNING_RESOURCE


func start_game(selected_rider_kind: StringName) -> void:
	if not RiderKind.is_valid(selected_rider_kind):
		push_error("A game can only start with a valid rider kind.")
		return
	rider_kind = selected_rider_kind
	leaderboard_generation += 1
	round_id = Id.generate_id()
	run_manager = null
	is_paused = false
	var created := RoundState.create(rider_kind, 1, [], RoundState.SessionPhase.JUMP_ACTIVE)
	if not created.is_valid:
		push_error("Unable to start a round: %s" % "; ".join(created.errors))
		return
	_replace_round_state(created.value)
	_begin_current_jump()


func step_run(input: RiderInputFrame, delta: float) -> void:
	if not run_manager or is_paused or not _is_jump_active():
		return
	run_manager.step(input, _course, _tuning, delta)
	if run_manager.is_complete():
		_record_completed_run()


func restart_run() -> void:
	if not _is_jump_active():
		return
	if not run_manager:
		_begin_current_jump()
		return
	run_manager.reset_run(_course)


func set_paused(next_paused: bool) -> void:
	if is_paused == next_paused:
		return
	is_paused = next_paused


func return_to_attract() -> void:
	leaderboard_generation += 1
	is_paused = false
	run_manager = null
	_round_state = null
	round_id = ""
	_set_session_phase(RoundState.SessionPhase.ATTRACT)


func round_state() -> RoundState:
	return _round_state


func current_leaderboard_generation() -> int:
	return leaderboard_generation


func course() -> ParkCourse:
	return _course


func tuning() -> RiderTuning:
	return _tuning


func record_active_jump_result(jump_result: JumpResult) -> bool:
	if (
		jump_result == null
		or not _is_jump_active()
		or run_manager == null
		or not run_manager.is_complete()
	):
		return false
	var results := _round_state.jump_results()
	results.append(jump_result)
	var next_phase := (
		RoundState.SessionPhase.GAME_OVER
		if jump_result.outcome() == JumpOutcome.Value.CRASH
		else RoundState.SessionPhase.JUMP_TALLY
	)
	var created := RoundState.create(
		rider_kind, _round_state.current_jump_number(), results, next_phase
	)
	if not created.is_valid:
		push_error("Unable to record a jump result: %s" % "; ".join(created.errors))
		return false
	_replace_round_state(created.value)
	jump_result_recorded.emit(_round_state, jump_result)
	if session_phase == RoundState.SessionPhase.GAME_OVER:
		round_completed.emit(_round_state)
	return true


func complete_tally() -> bool:
	if _round_state == null or session_phase != RoundState.SessionPhase.JUMP_TALLY:
		return false
	if _round_state.current_jump_number() >= RoundState.MAX_JUMPS:
		return _complete_round()
	var created := RoundState.create(
		rider_kind,
		_round_state.current_jump_number() + 1,
		_round_state.jump_results(),
		RoundState.SessionPhase.JUMP_ACTIVE
	)
	if not created.is_valid:
		push_error("Unable to begin the next jump: %s" % "; ".join(created.errors))
		return false
	_replace_round_state(created.value)
	_begin_current_jump()
	return true


func _set_session_phase(next_phase: int) -> void:
	if session_phase == next_phase:
		return
	session_phase = next_phase
	phase_changed.emit(session_phase)


func _replace_round_state(next_round_state: RoundState) -> void:
	_round_state = next_round_state
	_set_session_phase(_round_state.session_phase())


func _complete_round() -> bool:
	var created := RoundState.create(
		rider_kind,
		_round_state.current_jump_number(),
		_round_state.jump_results(),
		RoundState.SessionPhase.GAME_OVER
	)
	if not created.is_valid:
		push_error("Unable to complete a round: %s" % "; ".join(created.errors))
		return false
	_replace_round_state(created.value)
	round_completed.emit(_round_state)
	return true


func _begin_current_jump() -> void:
	if not _is_jump_active():
		return
	run_manager = RiderRunManager.new()
	run_manager.setup(_course)
	jump_started.emit(_round_state)


func _record_completed_run() -> void:
	var snapshot := run_manager.terminal_snapshot()
	if snapshot == null:
		push_error("A completed run must provide frozen terminal measurements.")
		return
	var created := JumpResult.create(snapshot, JumpScorer.score_jump(snapshot, _tuning))
	if not created.is_valid:
		push_error("Unable to resolve the completed run: %s" % "; ".join(created.errors))
		return
	record_active_jump_result(created.value)


func _is_jump_active() -> bool:
	return _round_state != null and session_phase == RoundState.SessionPhase.JUMP_ACTIVE
