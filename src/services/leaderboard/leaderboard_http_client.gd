## One HTTPRequest per in-flight leaderboard operation; no request is retried implicitly.
class_name LeaderboardHttpClient
extends Node

var installation_id := ""
var _requests: Dictionary = {}


func request_json(
	operation: LeaderboardRequest, url: String, method: HTTPClient.Method, payload: Dictionary = {}
) -> LeaderboardHttpResponse:
	var response := LeaderboardHttpResponse.new()
	var request := HTTPRequest.new()
	add_child(request)
	_requests[operation] = request
	var headers := PackedStringArray(["Accept: application/json"])
	if not installation_id.is_empty():
		headers.append("X-Installation-Id: %s" % installation_id)
	var body := ""
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	response.request_error = request.request(url, headers, method, body)
	if response.request_error != OK:
		_requests.erase(operation)
		request.queue_free()
		return response
	var completed: Array = await request.request_completed
	if _requests.erase(operation):
		response.request_result = completed[0]
		response.response_code = completed[1]
		response.body = completed[3]
	request.queue_free()
	return response


func cancel(operation: LeaderboardRequest) -> void:
	var request: HTTPRequest = _requests.get(operation)
	if request == null:
		return
	request.cancel_request()
