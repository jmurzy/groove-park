## Owns cancellable qualification and score-submission work after a round ends.
class_name PostRoundFlowController
extends Node

signal submission_started

const QUALIFICATION_MINIMUM_DURATION := 2.0

var _game_session: GameSession
var _leaderboard_repository: LeaderboardRepository
var _qualification_request: LeaderboardRepository.Request
var _submission_request: LeaderboardRepository.Request
var _top_entries_request: LeaderboardRepository.Request


func setup(game_session: GameSession, leaderboard_repository: LeaderboardRepository) -> void:
	assert(
		leaderboard_repository != null, "PostRoundFlowController requires a leaderboard repository."
	)
	_game_session = game_session
	_leaderboard_repository = leaderboard_repository


func fetch_top_entries() -> void:
	if _top_entries_request:
		return
	_top_entries_request = _leaderboard_repository.get_top_entries()
	_top_entries_request.completed.connect(_on_top_entries_completed)


func check_qualification() -> void:
	if _qualification_request != null:
		return
	var request := _leaderboard_repository.check_qualification(
		_game_session.round_state().round_score()
	)
	_qualification_request = request
	var timer := get_tree().create_timer(QUALIFICATION_MINIMUM_DURATION)
	await SignalUtils.await_both(get_tree(), request.completed, timer.timeout)
	_on_qualification_completed(request)


func submit_player_name(player_name: String) -> void:
	if _submission_request != null:
		return
	var state := _game_session.round_state()
	if state == null or _game_session.session_phase != RoundState.SessionPhase.NAME_ENTRY:
		return
	var platform: StringName = &"web" if OS.has_feature("web") else &"ags"
	var submission := LeaderboardSubmission.create(
		_game_session.round_id, player_name, state.rider_kind(), state.round_score(), platform
	)
	_submission_request = _leaderboard_repository.submit_score(submission)
	submission_started.emit()
	_submission_request.completed.connect(_on_submission_completed)


func cancel() -> void:
	if _qualification_request:
		var request := _qualification_request
		_qualification_request = null
		request.cancel()
	if _submission_request:
		var request := _submission_request
		_submission_request = null
		request.cancel()
	if _top_entries_request:
		var request := _top_entries_request
		_top_entries_request = null
		request.cancel()


func _on_qualification_completed(request: LeaderboardRepository.Request) -> void:
	if request != _qualification_request:
		return
	_qualification_request = null
	if (
		request.status == LeaderboardRepository.Request.Status.SUCCEEDED
		and request.result is LeaderboardQualification
	):
		_game_session.qualification_available(request.result)
	else:
		_game_session.qualification_unavailable()


func _on_submission_completed(request: LeaderboardRepository.Request) -> void:
	if request != _submission_request:
		return
	_submission_request = null
	if (
		request.status == LeaderboardRepository.Request.Status.SUCCEEDED
		and request.result is LeaderboardSubmissionResult
	):
		_game_session.submission_succeeded(request.result)
	else:
		_game_session.submission_failed()


func _on_top_entries_completed(request: LeaderboardRepository.Request) -> void:
	if request != _top_entries_request:
		return
	_top_entries_request = null
	if (
		request.status == LeaderboardRepository.Request.Status.SUCCEEDED
		and request.result is LeaderboardTopEntriesResult
	):
		_game_session.top_entries_succeeded(request.result)
	else:
		_game_session.top_entries_failed()
