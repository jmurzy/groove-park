## HTTP implementation of the shared leaderboard repository contract.
class_name RemoteLeaderboardRepository
extends LeaderboardRepository

const TOP_ENTRIES_PATH := "/api/leaderboard"
const QUALIFICATION_PATH := "/api/leaderboard/qualify"
const SUBMISSIONS_PATH := "/api/leaderboard/submissions"

var installation_id := ""
var _base_url := ""
var _http_requests: Dictionary = {}


func setup(base_url: String) -> void:
	_base_url = base_url.rstrip("/")


func get_top_entries() -> LeaderboardRequest:
	var request := _start_request(LeaderboardOperationResult.Kind.TOP_ENTRIES)
	_resolve_request(request, HTTPClient.METHOD_GET, TOP_ENTRIES_PATH)
	return request


func check_qualification(total_score: int) -> LeaderboardRequest:
	var request := _start_request(LeaderboardOperationResult.Kind.QUALIFICATION)
	state = State.QUALIFYING
	_resolve_request(
		request, HTTPClient.METHOD_POST, QUALIFICATION_PATH, {"totalScore": total_score}
	)
	return request


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRequest:
	var active_submission := _pending_submission()
	if active_submission != null:
		return active_submission
	var request := _start_request(LeaderboardOperationResult.Kind.SUBMISSION)
	state = State.SUBMITTING
	if submission == null:
		_complete_failure(request, "INVALID_SUBMISSION")
		return request
	_resolve_request(request, HTTPClient.METHOD_POST, SUBMISSIONS_PATH, submission.to_api())
	return request


func _cancel_request(request: LeaderboardRequest) -> void:
	var http_request: HTTPRequest = _http_requests.get(request)
	if http_request:
		http_request.cancel_request()
	super._cancel_request(request)


func _resolve_request(
	request: LeaderboardRequest, method: HTTPClient.Method, path: String, payload: Dictionary = {}
) -> void:
	if _base_url.is_empty():
		_complete_unavailable(request, "API_UNCONFIGURED")
		return
	var http_request := HTTPRequest.new()
	add_child(http_request)
	_http_requests[request] = http_request
	var headers := PackedStringArray(["Accept: application/json"])
	if not installation_id.is_empty():
		headers.append("X-Installation-Id: %s" % installation_id)
	var body := ""
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var request_error := http_request.request(_base_url + path, headers, method, body)
	if request_error != OK:
		_http_requests.erase(request)
		http_request.queue_free()
		_complete_unavailable(request, "REQUEST_START_FAILED")
		return
	var completed: Array = await http_request.request_completed
	if not _http_requests.erase(request):
		http_request.queue_free()
		return
	http_request.queue_free()
	if not _pending.has(request):
		return
	_on_response_received(request, completed[0], completed[1], completed[3])


func _on_response_received(
	request: LeaderboardRequest, request_result: int, response_code: int, body: PackedByteArray
) -> void:
	if request_result != HTTPRequest.RESULT_SUCCESS:
		_complete_unavailable(request, "NETWORK_UNAVAILABLE")
		return
	if response_code == 503:
		_complete_unavailable(request, "SERVICE_UNAVAILABLE")
		return
	if response_code < 200 or response_code >= 300:
		_complete_failure(request, "HTTP_%d" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	_apply_success(request, parsed)


func _apply_success(request: LeaderboardRequest, response: Dictionary) -> void:
	var result := LeaderboardOperationResult.new()
	match request.kind:
		LeaderboardOperationResult.Kind.TOP_ENTRIES:
			var top_entries: Array[LeaderboardEntry] = []
			if not _entries_from_api(response, top_entries):
				_complete_failure(request, "MALFORMED_RESPONSE")
				return
			result.entries = top_entries
		LeaderboardOperationResult.Kind.QUALIFICATION:
			var qualification := LeaderboardQualification.from_api(response)
			if qualification == null:
				_complete_failure(request, "MALFORMED_RESPONSE")
				return
			result.qualification = qualification
			result.rank = qualification.rank
		LeaderboardOperationResult.Kind.SUBMISSION:
			if response.get("accepted") != true or not response.get("rank") is int:
				_complete_failure(request, "MALFORMED_RESPONSE")
				return
			var submission_entries: Array[LeaderboardEntry] = []
			if not _entries_from_api(response, submission_entries):
				_complete_failure(request, "MALFORMED_RESPONSE")
				return
			result.entries = submission_entries
			result.rank = response.rank
	result.status = LeaderboardOperationResult.Status.SUCCEEDED
	state = (
		State.ACCEPTED
		if request.kind == LeaderboardOperationResult.Kind.SUBMISSION
		else State.AVAILABLE
	)
	_set_available(true)
	_finish_request(request, result)


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


func _complete_unavailable(request: LeaderboardRequest, error_code: String) -> void:
	var result := LeaderboardOperationResult.new()
	result.status = LeaderboardOperationResult.Status.UNAVAILABLE
	result.error_code = error_code
	state = State.UNAVAILABLE
	_set_available(false)
	_finish_request(request, result)


func _complete_failure(request: LeaderboardRequest, error_code: String) -> void:
	var result := LeaderboardOperationResult.new()
	result.status = LeaderboardOperationResult.Status.FAILED
	result.error_code = error_code
	state = State.FAILED
	_finish_request(request, result)
