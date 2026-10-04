## One HTTPRequest per in-flight leaderboard operation; no request is retried implicitly.
class_name LeaderboardHttpClient
extends Node

signal response_received(operation_id: int, result: int, response_code: int, body: PackedByteArray)

var installation_id := ""
var _requests: Dictionary = {}


func request_json(
	operation_id: int, url: String, method: HTTPClient.Method, payload: Dictionary = {}
) -> Error:
	var request := HTTPRequest.new()
	add_child(request)
	_requests[operation_id] = request
	request.request_completed.connect(_on_request_completed.bind(operation_id, request))
	var headers := PackedStringArray(["Accept: application/json"])
	if not installation_id.is_empty():
		headers.append("X-Installation-Id: %s" % installation_id)
	var body := ""
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var error := request.request(url, headers, method, body)
	if error != OK:
		_requests.erase(operation_id)
		request.queue_free()
	return error


func cancel(operation_id: int) -> void:
	var request: HTTPRequest = _requests.get(operation_id)
	if request == null:
		return
	request.cancel_request()
	_requests.erase(operation_id)
	request.queue_free()


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	operation_id: int,
	request: HTTPRequest
) -> void:
	if _requests.get(operation_id) != request:
		return
	_requests.erase(operation_id)
	request.queue_free()
	response_received.emit(operation_id, result, response_code, body)
