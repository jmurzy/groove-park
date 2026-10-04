## Deterministic in-memory repository for session and presentation tests.
class_name FakeLeaderboardRepository
extends LeaderboardRepository

var entries: Array[LeaderboardEntry] = []
var is_available := true
var deferred := false
var _deferred_requests: Dictionary = {}


func get_top_entries() -> LeaderboardRequest:
	var request := _start_request()
	request.result = entries.duplicate()
	_complete(request)
	return request


func check_qualification(total_score: int) -> LeaderboardRequest:
	var request := _start_request()
	var qualification := LeaderboardQualification.new()
	qualification.qualified = entries.size() < 10 or total_score > entries[9].total_score
	qualification.rank = entries.size() + 1 if qualification.qualified else null
	request.result = qualification
	_complete(request)
	return request


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRequest:
	var active_submission := _pending_submission()
	if active_submission != null:
		return active_submission
	var request := _start_submission()
	if submission == null:
		request.error_code = "INVALID_SUBMISSION"
		_finish_request(request, LeaderboardRequest.Status.FAILED)
		return request
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
	var response := LeaderboardSubmissionResponse.new()
	response.rank = entries.find(entry) + 1
	response.entries = entries.slice(0, 10)
	request.result = response
	_complete(request)
	return request


func complete_deferred(request: LeaderboardRequest) -> void:
	if not _deferred_requests.erase(request):
		return
	_finish_completed(request)


func _complete(request: LeaderboardRequest) -> void:
	if not is_available:
		request.error_code = "SERVICE_UNAVAILABLE"
		_set_available(false)
		_finish_request(request, LeaderboardRequest.Status.UNAVAILABLE)
		return
	if deferred:
		_deferred_requests[request] = true
		return
	_finish_completed(request)


func _finish_completed(request: LeaderboardRequest) -> void:
	if request.status != LeaderboardRequest.Status.PENDING:
		return
	_set_available(true)
	_finish_request(request, LeaderboardRequest.Status.SUCCEEDED)
