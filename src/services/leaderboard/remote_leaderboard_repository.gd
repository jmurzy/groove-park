## HTTP implementation of the shared leaderboard repository contract.
class_name RemoteLeaderboardRepository
extends LeaderboardRepository

var installation_id := ""
var _base_url := ""
var _http_requests: Dictionary = {}


func setup(base_url: String) -> void:
	_base_url = base_url.rstrip("/")
	assert(
		not _base_url.is_empty(), "RemoteLeaderboardRepository requires a configured API base URL."
	)


func get_top_entries() -> LeaderboardRepository.Request:
	var request := _start_request()
	_resolve_top_entries(request)
	return request


func _resolve_top_entries(request: LeaderboardRepository.Request) -> void:
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_GET, "/api/leaderboard"
	)
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	var entries: Array[LeaderboardEntry] = []
	if not _entries_from_api(response, entries):
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	request.result = entries
	_complete_success(request)


func check_qualification(total_score: int) -> LeaderboardRepository.Request:
	var request := _start_request()
	_resolve_qualification(request, total_score)
	return request


func _resolve_qualification(request: LeaderboardRepository.Request, total_score: int) -> void:
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_POST, "/api/leaderboard/qualify", {"totalScore": total_score}
	)
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	var qualification := LeaderboardQualification.from_api(response)
	if qualification == null:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	request.result = qualification
	_complete_success(request)


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRepository.Request:
	if _submission_request != null:
		return _submission_request
	var request := _start_request()
	_submission_request = request
	if submission == null:
		_complete_failure(request, "INVALID_SUBMISSION")
		return request
	_resolve_submission(request, submission)
	return request


func _resolve_submission(
	request: LeaderboardRepository.Request, submission: LeaderboardSubmission
) -> void:
	var response: Dictionary = await _request_json(
		request, HTTPClient.METHOD_POST, "/api/leaderboard/submissions", submission.to_api()
	)
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	if response.get("accepted") != true or not response.get("rank") is int:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	var entries: Array[LeaderboardEntry] = []
	if not _entries_from_api(response, entries):
		_complete_failure(request, "MALFORMED_RESPONSE")
		return
	var submission_result := LeaderboardSubmissionResult.new()
	submission_result.top_entries = entries
	submission_result.rank = response.rank
	request.result = submission_result
	_complete_success(request)


func _cancel_request(request: LeaderboardRepository.Request) -> void:
	var http_request: HTTPRequest = _http_requests.get(request)
	if http_request:
		http_request.cancel_request()
	super._cancel_request(request)


func _request_json(
	request: LeaderboardRepository.Request,
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary = {}
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
	if not is_active:
		return {}
	return _decode_response(request, completed[0], completed[1], PackedByteArray(completed[3]))


func _decode_response(
	request: LeaderboardRepository.Request,
	request_result: int,
	response_code: int,
	body: PackedByteArray
) -> Dictionary:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return {}
	if request_result != HTTPRequest.RESULT_SUCCESS:
		_complete_unavailable(request, "NETWORK_UNAVAILABLE")
		return {}
	if response_code == 503 or response_code < 200 or response_code >= 300:
		if response_code == 503:
			_complete_unavailable(request, "SERVICE_UNAVAILABLE")
		else:
			_complete_failure(request, "HTTP_%d" % response_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		_complete_failure(request, "MALFORMED_RESPONSE")
		return {}
	return json.data


func _complete_success(request: LeaderboardRepository.Request) -> void:
	_finish_request(request, LeaderboardRepository.Request.Status.SUCCEEDED)


func _complete_unavailable(request: LeaderboardRepository.Request, error_code: String) -> void:
	request.error_code = error_code
	_finish_request(request, LeaderboardRepository.Request.Status.UNAVAILABLE)


func _complete_failure(request: LeaderboardRepository.Request, error_code: String) -> void:
	request.error_code = error_code
	_finish_request(request, LeaderboardRepository.Request.Status.FAILED)


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
