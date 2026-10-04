## Deterministic in-memory repository for session and presentation tests.
class_name FakeLeaderboardRepository
extends LeaderboardRepository

var entries: Array[LeaderboardEntry] = []
var is_available := true
var deferred := false
var _deferred_operations: Dictionary = {}


func get_top_entries() -> LeaderboardRepository.Request:
	var request := _start_request(LeaderboardRepository.Request.Operation.GET)
	_complete(request, func() -> void: request.result = entries.duplicate())
	return request


func check_qualification(total_score: int) -> LeaderboardRepository.Request:
	var request := _start_request(LeaderboardRepository.Request.Operation.POST)
	_complete(
		request,
		func() -> void:
			var qualification := LeaderboardQualification.new()
			qualification.qualified = entries.size() < 10 or total_score > entries[9].total_score
			qualification.rank = entries.size() + 1 if qualification.qualified else null
			request.result = qualification
	)
	return request


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRepository.Request:
	if _submission_request != null:
		return _submission_request
	var request := _start_request(LeaderboardRepository.Request.Operation.POST)
	_submission_request = request
	if submission == null:
		request.error_code = "INVALID_SUBMISSION"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return request
	_complete(request, func() -> void: _accept_submission(request, submission))
	return request


func complete_deferred(request: LeaderboardRepository.Request) -> void:
	if not _deferred_operations.has(request):
		return
	var operation: Callable = _deferred_operations[request]
	_deferred_operations.erase(request)
	_finish_completed(request, operation)


func _cancel_request(request: LeaderboardRepository.Request) -> void:
	_deferred_operations.erase(request)
	super._cancel_request(request)


func _complete(request: LeaderboardRepository.Request, operation: Callable) -> void:
	if not is_available:
		request.error_code = "SERVICE_UNAVAILABLE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return
	if deferred:
		_deferred_operations[request] = operation
		return
	_finish_completed(request, operation)


func _finish_completed(request: LeaderboardRepository.Request, operation: Callable) -> void:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	operation.call()
	_finish_request(request, LeaderboardRepository.Request.Status.SUCCEEDED)


func _accept_submission(
	request: LeaderboardRepository.Request, submission: LeaderboardSubmission
) -> void:
	var entry := _entry_for_round(submission.round_id)
	if entry == null:
		entry = LeaderboardEntry.new()
		entry.round_id = submission.round_id
		entry.player_name = submission.player_name
		entry.rider_kind = submission.rider_kind
		entry.total_score = submission.total_score
		entry.platform = submission.platform
		entry.created_at = "test"
		entries.append(entry)
		entries.sort_custom(_is_higher_ranked)
	var submission_result := LeaderboardSubmissionResult.new()
	submission_result.rank = entries.find(entry) + 1
	submission_result.top_entries.assign(entries.slice(0, 10))
	request.result = submission_result


func _entry_for_round(round_id: String) -> LeaderboardEntry:
	for entry in entries:
		if entry.round_id == round_id:
			return entry
	return null


func _is_higher_ranked(a: LeaderboardEntry, b: LeaderboardEntry) -> bool:
	if a.total_score != b.total_score:
		return a.total_score > b.total_score
	if a.created_at != b.created_at:
		return a.created_at < b.created_at
	return a.round_id < b.round_id
