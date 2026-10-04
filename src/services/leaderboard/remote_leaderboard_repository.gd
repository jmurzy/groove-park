## HTTP implementation of the shared leaderboard repository contract.
class_name RemoteLeaderboardRepository
extends LeaderboardRepository

const TOP_ENTRIES_PATH := "/api/leaderboard"
const QUALIFICATION_PATH := "/api/leaderboard/qualify"
const SUBMISSIONS_PATH := "/api/leaderboard/submissions"

var _base_url := ""
var _http_client: LeaderboardHttpClient


func setup(base_url: String, http_client: LeaderboardHttpClient = null) -> void:
	_base_url = base_url.rstrip("/")
	_http_client = http_client if http_client else LeaderboardHttpClient.new()
	if _http_client.get_parent() == null:
		add_child(_http_client)
	_http_client.response_received.connect(_on_response_received)


func get_top_entries(session_generation: int) -> int:
	var result := _start_operation(LeaderboardOperationResult.Kind.TOP_ENTRIES, session_generation)
	if not _request(result, HTTPClient.METHOD_GET, TOP_ENTRIES_PATH):
		return result.operation_id
	return result.operation_id


func check_qualification(total_score: int, session_generation: int) -> int:
	var result := _start_operation(
		LeaderboardOperationResult.Kind.QUALIFICATION, session_generation
	)
	state = State.QUALIFYING
	_request(result, HTTPClient.METHOD_POST, QUALIFICATION_PATH, {"totalScore": total_score})
	return result.operation_id


func submit_score(submission: LeaderboardSubmission, session_generation: int) -> int:
	var active_submission_id := _pending_submission_id()
	if active_submission_id >= 0:
		return active_submission_id
	var result := _start_operation(LeaderboardOperationResult.Kind.SUBMISSION, session_generation)
	state = State.SUBMITTING
	if submission == null:
		_complete_failure(result, "INVALID_SUBMISSION")
		return result.operation_id
	_request(result, HTTPClient.METHOD_POST, SUBMISSIONS_PATH, submission.to_api())
	return result.operation_id


func cancel(operation_id: int) -> void:
	if _http_client:
		_http_client.cancel(operation_id)
	super.cancel(operation_id)


func _request(
	result: LeaderboardOperationResult,
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary = {}
) -> bool:
	if _http_client == null or _base_url.is_empty():
		_complete_unavailable(result, "API_UNCONFIGURED")
		return false
	var error := _http_client.request_json(result.operation_id, _base_url + path, method, payload)
	if error != OK:
		_complete_unavailable(result, "REQUEST_START_FAILED")
		return false
	return true


func _on_response_received(
	operation_id: int, request_result: int, response_code: int, body: PackedByteArray
) -> void:
	var result: LeaderboardOperationResult = _pending.get(operation_id)
	if result == null:
		return
	if request_result != HTTPRequest.RESULT_SUCCESS:
		_complete_unavailable(result, "NETWORK_UNAVAILABLE")
		return
	if response_code == 503:
		_complete_unavailable(result, "SERVICE_UNAVAILABLE")
		return
	if response_code < 200 or response_code >= 300:
		_complete_failure(result, "HTTP_%d" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_complete_failure(result, "MALFORMED_RESPONSE")
		return
	_apply_success(result, parsed)


func _apply_success(result: LeaderboardOperationResult, response: Dictionary) -> void:
	match result.kind:
		LeaderboardOperationResult.Kind.TOP_ENTRIES:
			var top_entries: Array[LeaderboardEntry] = []
			if not _entries_from_api(response, top_entries):
				_complete_failure(result, "MALFORMED_RESPONSE")
				return
			result.entries = top_entries
		LeaderboardOperationResult.Kind.QUALIFICATION:
			var qualification := LeaderboardQualification.from_api(response)
			if qualification == null:
				_complete_failure(result, "MALFORMED_RESPONSE")
				return
			result.qualification = qualification
			result.rank = qualification.rank
		LeaderboardOperationResult.Kind.SUBMISSION:
			if response.get("accepted") != true or not response.get("rank") is int:
				_complete_failure(result, "MALFORMED_RESPONSE")
				return
			var submission_entries: Array[LeaderboardEntry] = []
			if not _entries_from_api(response, submission_entries):
				_complete_failure(result, "MALFORMED_RESPONSE")
				return
			result.entries = submission_entries
			result.rank = response.rank
	result.status = LeaderboardOperationResult.Status.SUCCEEDED
	state = (
		State.ACCEPTED
		if result.kind == LeaderboardOperationResult.Kind.SUBMISSION
		else State.AVAILABLE
	)
	_set_available(true)
	_finish_operation(result)


func _entries_from_api(response: Dictionary, entries: Array[LeaderboardEntry]) -> bool:
	var values: Variant = response.get("topEntries")
	if not values is Array:
		return false
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var entry := LeaderboardEntry.from_api(value)
		if entry == null:
			return false
		entries.append(entry)
	return true


func _complete_unavailable(result: LeaderboardOperationResult, error_code: String) -> void:
	result.status = LeaderboardOperationResult.Status.UNAVAILABLE
	result.error_code = error_code
	state = State.UNAVAILABLE
	_set_available(false)
	_finish_operation(result)


func _complete_failure(result: LeaderboardOperationResult, error_code: String) -> void:
	result.status = LeaderboardOperationResult.Status.FAILED
	result.error_code = error_code
	state = State.FAILED
	_finish_operation(result)
