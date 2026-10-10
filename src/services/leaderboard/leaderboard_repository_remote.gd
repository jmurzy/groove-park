## HTTP implementation of the shared leaderboard repository contract.
class_name RemoteLeaderboardRepository
extends LeaderboardRepository

const REQUEST_TIMEOUT_SECONDS := 10.0

var installation_id := ""
var _base_url := ""
var _http_requests: Dictionary = {}


func setup(base_url: String) -> void:
	_base_url = base_url.rstrip("/")
	assert(
		not _base_url.is_empty(), "RemoteLeaderboardRepository requires a configured API base URL."
	)


func get_top_entries() -> LeaderboardRepository.Request:
	var request := _start_request(LeaderboardRepository.Request.Operation.GET)
	_resolve_top_entries(request)
	return request


func _resolve_top_entries(request: LeaderboardRepository.Request) -> void:
	_request_json(request, HTTPClient.METHOD_GET, "/api/leaderboard", {}, _on_top_entries_response)


func _on_top_entries_response(request: LeaderboardRepository.Request, response: Dictionary) -> void:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	var entries: Array[LeaderboardEntry] = []
	if not LeaderboardEntry.entries_from_api(response.get("topEntries"), entries):
		request.error_code = "MALFORMED_RESPONSE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return
	var top_entries_result := LeaderboardTopEntriesResult.new()
	top_entries_result.entries = entries
	request.result = top_entries_result
	_finish_request(request, LeaderboardRepository.Request.Status.SUCCEEDED)


func check_qualification(total_score: int) -> LeaderboardRepository.Request:
	var request := _start_request(LeaderboardRepository.Request.Operation.POST)
	_resolve_qualification(request, total_score)
	return request


func _resolve_qualification(request: LeaderboardRepository.Request, total_score: int) -> void:
	_request_json(
		request,
		HTTPClient.METHOD_POST,
		"/api/leaderboard/qualify",
		{"totalScore": total_score},
		_on_qualification_response
	)


func _on_qualification_response(
	request: LeaderboardRepository.Request, response: Dictionary
) -> void:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	var qualification := LeaderboardQualification.from_api(response)
	if qualification == null:
		request.error_code = "MALFORMED_RESPONSE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return
	request.result = qualification
	_finish_request(request, LeaderboardRepository.Request.Status.SUCCEEDED)


func submit_score(submission: LeaderboardSubmission) -> LeaderboardRepository.Request:
	if _submission_request != null:
		return _submission_request
	var request := _start_request(LeaderboardRepository.Request.Operation.POST)
	_submission_request = request
	if submission == null:
		request.error_code = "INVALID_SUBMISSION"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return request
	_resolve_submission(request, submission)
	return request


func _resolve_submission(
	request: LeaderboardRepository.Request, submission: LeaderboardSubmission
) -> void:
	_request_json(
		request,
		HTTPClient.METHOD_POST,
		"/api/leaderboard/submissions",
		submission.to_api(),
		_on_submission_response
	)


func _on_submission_response(request: LeaderboardRepository.Request, response: Dictionary) -> void:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return
	if response.get("accepted") != true or not response.get("rank") is float:
		request.error_code = "MALFORMED_RESPONSE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return
	var submission_result := LeaderboardSubmissionResult.new()
	submission_result.rank = int(response.rank)
	request.result = submission_result
	_finish_request(request, LeaderboardRepository.Request.Status.SUCCEEDED)


func _cancel_request(request: LeaderboardRepository.Request) -> void:
	var http_request: HTTPRequest = _http_requests.get(request)
	if http_request:
		_http_requests.erase(request)
		http_request.cancel_request()
		http_request.queue_free()
	super._cancel_request(request)


func _request_json(
	request: LeaderboardRepository.Request,
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary,
	on_response: Callable
) -> void:
	request.endpoint = path
	var http_request := HTTPRequest.new()
	http_request.timeout = REQUEST_TIMEOUT_SECONDS
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
		request.error_code = "REQUEST_START_FAILED"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return
	http_request.request_completed.connect(
		func(
			request_result: int,
			response_code: int,
			_headers: PackedStringArray,
			body: PackedByteArray
		) -> void:
			_on_http_request_completed(
				request, http_request, on_response, request_result, response_code, body
			),
		CONNECT_ONE_SHOT
	)


func _on_http_request_completed(
	request: LeaderboardRepository.Request,
	http_request: HTTPRequest,
	on_response: Callable,
	request_result: int,
	response_code: int,
	body: PackedByteArray
) -> void:
	if _http_requests.get(request) != http_request:
		return
	_http_requests.erase(request)
	http_request.queue_free()
	var response := _decode_response(request, request_result, response_code, body)
	if request.status == LeaderboardRepository.Request.Status.PENDING:
		on_response.call(request, response)


func _decode_response(
	request: LeaderboardRepository.Request,
	request_result: int,
	response_code: int,
	body: PackedByteArray
) -> Dictionary:
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		return {}
	if request_result != HTTPRequest.RESULT_SUCCESS:
		request.error_code = "NETWORK_UNAVAILABLE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return {}
	if response_code == 503 or response_code < 200 or response_code >= 300:
		if response_code == 503:
			request.error_code = "SERVICE_UNAVAILABLE"
			_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		else:
			request.error_code = "HTTP_%d" % response_code
			_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		request.error_code = "MALFORMED_RESPONSE"
		_finish_request(request, LeaderboardRepository.Request.Status.FAILED)
		return {}
	return json.data
