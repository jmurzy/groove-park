## HTTP implementation of the shared leaderboard repository contract.
class_name RemoteLeaderboardRepository
extends LeaderboardRepository

var installation_id := ""
var _base_url := ""
var _http_requests: Dictionary = {}


func setup(base_url: String) -> void:
	_base_url = base_url.rstrip("/")


func get_top_entries() -> LeaderboardRequest:
	var request := _start_request()
	_resolve_top_entries(request)
	return request


func _resolve_top_entries(request: LeaderboardRequest) -> void:
	if not _can_request(request):
		return
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_GET, "/api/leaderboard"
	)
	if request.status != LeaderboardRequest.Status.PENDING:
		return
	var entries: Array[LeaderboardEntry] = []
	if not _entries_from_api(response, entries):
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	request.entries = entries
	_complete_success(request)


func check_qualification(total_score: int) -> LeaderboardRequest:
	var request := _start_request()
	_resolve_qualification(request, total_score)
	return request


func _resolve_qualification(request: LeaderboardRequest, total_score: int) -> void:
	if not _can_request(request):
		return
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_POST, "/api/leaderboard/qualify", {"totalScore": total_score}
	)
	if request.status != LeaderboardRequest.Status.PENDING:
		return
	var qualification := LeaderboardQualification.from_api(response)
	if qualification == null:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	request.qualification = qualification
	request.rank = qualification.rank
	_complete_success(request)


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRequest:
	var active_submission := _pending_submission()
	if active_submission != null:
		return active_submission
	var request := _start_submission()
	if submission == null:
		_complete_failure(request, "INVALID_SUBMISSION")
		return request
	_resolve_submission(request, submission)
	return request


func _resolve_submission(request: LeaderboardRequest, submission: LeaderboardSubmission) -> void:
	if not _can_request(request):
		return
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_POST, "/api/leaderboard/submissions", submission.to_api()
	)
	if request.status != LeaderboardRequest.Status.PENDING:
		return
	if response.get("accepted") != true or not response.get("rank") is int:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	var entries: Array[LeaderboardEntry] = []
	if not _entries_from_api(response, entries):
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	request.entries = entries
	request.rank = response.rank
	_complete_success(request)


func _cancel_request(request: LeaderboardRequest) -> void:
	var http_request: HTTPRequest = _http_requests.get(request)
	if http_request:
		http_request.cancel_request()
	super._cancel_request(request)


func _request_json(
	request: LeaderboardRequest, method: HTTPClient.Method, path: String, payload: Dictionary = {}
) -> Dictionary:
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
		return {}
	var completed: Array = await http_request.request_completed
	var is_active := _http_requests.erase(request)
	http_request.queue_free()
	if not is_active or request.status != LeaderboardRequest.Status.PENDING:
		return {}
	if completed[0] != HTTPRequest.RESULT_SUCCESS:
		_complete_unavailable(request, "NETWORK_UNAVAILABLE")
		return {}
	if completed[1] == 503 or completed[1] < 200 or completed[1] >= 300:
		if completed[1] == 503:
			_complete_unavailable(request, "SERVICE_UNAVAILABLE")
		else:
			_complete_failure(request, "HTTP_%d" % completed[1])
		return {}
	var response_body := PackedByteArray(completed[3])
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return {}
	return parsed


func _can_request(request: LeaderboardRequest) -> bool:
	if not _base_url.is_empty():
		return true
	_complete_unavailable(request, "API_UNCONFIGURED")
	return false


func _complete_success(request: LeaderboardRequest) -> void:
	_set_available(true)
	_finish_request(request, LeaderboardRequest.Status.SUCCEEDED)


func _complete_unavailable(request: LeaderboardRequest, error_code: String) -> void:
	request.error_code = error_code
	_set_available(false)
	_finish_request(request, LeaderboardRequest.Status.UNAVAILABLE)


func _complete_failure(request: LeaderboardRequest, error_code: String) -> void:
	request.error_code = error_code
	_finish_request(request, LeaderboardRequest.Status.FAILED)


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
