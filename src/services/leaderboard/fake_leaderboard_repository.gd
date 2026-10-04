## Deterministic in-memory repository for session and presentation tests.
class_name FakeLeaderboardRepository
extends LeaderboardRepository

var entries: Array[LeaderboardEntry] = []
var is_available := true
var deferred := false
var _deferred_results: Dictionary = {}


func get_top_entries(session_generation: int) -> int:
	var result := _start_operation(LeaderboardOperationResult.Kind.TOP_ENTRIES, session_generation)
	result.entries = entries.duplicate()
	_complete(result)
	return result.operation_id


func check_qualification(total_score: int, session_generation: int) -> int:
	var result := _start_operation(
		LeaderboardOperationResult.Kind.QUALIFICATION, session_generation
	)
	state = State.QUALIFYING
	var qualification := LeaderboardQualification.new()
	qualification.qualified = entries.size() < 10 or total_score > entries[9].total_score
	qualification.rank = entries.size() + 1 if qualification.qualified else null
	result.qualification = qualification
	result.rank = qualification.rank
	_complete(result)
	return result.operation_id


func submit_score(submission: LeaderboardSubmission, session_generation: int) -> int:
	var active_submission_id := _pending_submission_id()
	if active_submission_id >= 0:
		return active_submission_id
	var result := _start_operation(LeaderboardOperationResult.Kind.SUBMISSION, session_generation)
	state = State.SUBMITTING
	if submission == null:
		result.status = LeaderboardOperationResult.Status.FAILED
		result.error_code = "INVALID_SUBMISSION"
		_complete(result)
		return result.operation_id
	var entry := LeaderboardEntry.new()
	entry.round_id = submission.round_id
	entry.player_name = submission.player_name
	entry.rider_kind = submission.rider_kind
	entry.total_score = submission.total_score
	entry.platform = submission.platform
	entry.created_at = "test"
	entries.append(entry)
	entries.sort_custom(
		func(a: LeaderboardEntry, b: LeaderboardEntry) -> bool: return a.total_score > b.total_score
	)
	result.rank = entries.find(entry) + 1
	result.entries = entries.slice(0, 10)
	_complete(result)
	return result.operation_id


func complete_deferred(operation_id: int) -> void:
	var result: LeaderboardOperationResult = _deferred_results.get(operation_id)
	if result == null:
		return
	_deferred_results.erase(operation_id)
	_finish_completed(result)


func _complete(result: LeaderboardOperationResult) -> void:
	if not is_available:
		result.status = LeaderboardOperationResult.Status.UNAVAILABLE
		result.error_code = "SERVICE_UNAVAILABLE"
		state = State.UNAVAILABLE
		_set_available(false)
		_finish_operation(result)
		return
	result.status = LeaderboardOperationResult.Status.SUCCEEDED
	if deferred:
		_deferred_results[result.operation_id] = result
		return
	_finish_completed(result)


func _finish_completed(result: LeaderboardOperationResult) -> void:
	state = (
		State.ACCEPTED
		if result.kind == LeaderboardOperationResult.Kind.SUBMISSION
		else State.AVAILABLE
	)
	_set_available(true)
	_finish_operation(result)
