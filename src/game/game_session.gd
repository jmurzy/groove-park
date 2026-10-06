## Owns authoritative round lifecycle, rider selection, park run, and pause state.
class_name GameSession
extends Node

signal phase_changed(phase: int)
signal jump_started(round_state: RoundState)
signal jump_result_recorded(round_state: RoundState, jump_result: JumpResult)
signal round_completed(round_state: RoundState)

const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")

const GAME_OVER_AUTO_ADVANCE_DELAY := 3.0
const ROUND_RESULTS_AUTO_RETURN_TIMEOUT := 60.0
const CRASH_RESCUE_AUTO_ADVANCE_TIMEOUT := 6.5
const CRASH_RESCUE_MINIMUM_DURATION := 5.0

var session_phase := RoundState.SessionPhase.ATTRACT
var rider_kind: StringName = RiderKind.SNOWBOARDER
var round_id := ""
var run_manager: RiderRunManager
var is_paused := false
var _leaderboard := Leaderboard.new()
var _round_state: RoundState
var _course: ParkCourse = PARK_COURSE_RESOURCE.duplicate()
var _tuning: RiderTuning = RIDER_TUNING_RESOURCE
var _game_over_elapsed := 0.0
var _round_results_elapsed := 0.0
var _crash_rescue_elapsed := 0.0


func start_game(selected_rider_kind: StringName) -> void:
	if not RiderKind.is_valid(selected_rider_kind):
		push_error("A game can only start with a valid rider kind.")
		return
	rider_kind = selected_rider_kind
	round_id = Id.generate_id()
	run_manager = null
	is_paused = false
	_leaderboard = Leaderboard.new()
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


func advance(delta: float) -> void:
	if is_paused:
		return
	var elapsed := maxf(delta, 0.0)
	if session_phase == RoundState.SessionPhase.CRASH_RESCUE:
		_crash_rescue_elapsed += elapsed
		if _crash_rescue_elapsed >= CRASH_RESCUE_AUTO_ADVANCE_TIMEOUT:
			_finish_crash_rescue()
	elif session_phase == RoundState.SessionPhase.GAME_OVER:
		_game_over_elapsed += elapsed
		if _game_over_elapsed >= GAME_OVER_AUTO_ADVANCE_DELAY:
			_begin_qualification()
	elif session_phase == RoundState.SessionPhase.ROUND_RESULTS:
		_round_results_elapsed += elapsed
		if _round_results_elapsed >= ROUND_RESULTS_AUTO_RETURN_TIMEOUT:
			return_to_attract()


func return_to_attract() -> void:
	is_paused = false
	run_manager = null
	_round_state = null
	round_id = ""
	_leaderboard = Leaderboard.new()
	_set_session_phase(RoundState.SessionPhase.ATTRACT)


func round_state() -> RoundState:
	return _round_state


func course() -> ParkCourse:
	return _course


func tuning() -> RiderTuning:
	return _tuning


func leaderboard() -> Leaderboard:
	return _leaderboard


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
		RoundState.SessionPhase.CRASH_RESCUE
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
	if jump_result.outcome() == JumpOutcome.Value.CRASH:
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


func request_skip_crash_rescue() -> bool:
	if (
		session_phase != RoundState.SessionPhase.CRASH_RESCUE
		or _crash_rescue_elapsed < CRASH_RESCUE_MINIMUM_DURATION
	):
		return false
	return _finish_crash_rescue()


func _begin_qualification() -> bool:
	if session_phase != RoundState.SessionPhase.GAME_OVER:
		return false
	return _replace_post_round_phase(RoundState.SessionPhase.QUALIFYING)


func qualification_available(qualification: LeaderboardQualification) -> bool:
	if qualification == null or session_phase != RoundState.SessionPhase.QUALIFYING:
		return false
	_leaderboard = Leaderboard.available(qualification)
	var next_phase := (
		RoundState.SessionPhase.NAME_ENTRY
		if qualification.qualified
		else RoundState.SessionPhase.ROUND_RESULTS
	)
	return _replace_post_round_phase(next_phase)


func qualification_unavailable() -> bool:
	if session_phase != RoundState.SessionPhase.QUALIFYING:
		return false
	_leaderboard = Leaderboard.offline()
	return _replace_post_round_phase(RoundState.SessionPhase.ROUND_RESULTS)


func submission_succeeded(submission_result: LeaderboardSubmissionResult) -> bool:
	if submission_result == null or session_phase != RoundState.SessionPhase.NAME_ENTRY:
		return false
	_leaderboard = _leaderboard.with_submission(submission_result)
	return _replace_post_round_phase(RoundState.SessionPhase.ROUND_RESULTS)


func submission_failed() -> bool:
	if session_phase != RoundState.SessionPhase.NAME_ENTRY:
		return false
	_leaderboard = _leaderboard.with_submission_failure()
	return _replace_post_round_phase(RoundState.SessionPhase.ROUND_RESULTS)


func name_entry_skipped() -> bool:
	if session_phase != RoundState.SessionPhase.NAME_ENTRY:
		return false
	_leaderboard = _leaderboard.with_skipped()
	return _replace_post_round_phase(RoundState.SessionPhase.ROUND_RESULTS)


func _replace_post_round_phase(next_phase: int) -> bool:
	if _round_state == null:
		return false
	var created := RoundState.create(
		rider_kind, _round_state.current_jump_number(), _round_state.jump_results(), next_phase
	)
	if not created.is_valid:
		push_error("Unable to change post-round phase: %s" % "; ".join(created.errors))
		return false
	_replace_round_state(created.value)
	return true


func _set_session_phase(next_phase: int) -> void:
	if session_phase == next_phase:
		return
	session_phase = next_phase
	if session_phase == RoundState.SessionPhase.GAME_OVER:
		_game_over_elapsed = 0.0
	elif session_phase == RoundState.SessionPhase.CRASH_RESCUE:
		_crash_rescue_elapsed = 0.0
	elif session_phase == RoundState.SessionPhase.ROUND_RESULTS:
		_round_results_elapsed = 0.0
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


func _finish_crash_rescue() -> bool:
	if _round_state == null or session_phase != RoundState.SessionPhase.CRASH_RESCUE:
		return false
	var created := RoundState.create(
		rider_kind,
		_round_state.current_jump_number(),
		_round_state.jump_results(),
		RoundState.SessionPhase.GAME_OVER
	)
	if not created.is_valid:
		push_error("Unable to enter game over after crash rescue: %s" % "; ".join(created.errors))
		return false
	_replace_round_state(created.value)
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
