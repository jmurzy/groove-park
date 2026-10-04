## Headless parsing and failure checks for the Worker-backed repository.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_unconfigured_client_is_unavailable()
	_test_service_unavailable_response_marks_request_unavailable()
	_test_malformed_json_response_fails()
	_test_cancelled_request_ignores_late_response()
	if _failures.is_empty():
		print("Remote leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_unconfigured_client_is_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	repository.setup("")
	var request := repository.check_qualification(100)
	_expect(
		request.status == LeaderboardRequest.Status.UNAVAILABLE,
		"An unconfigured remote client must report unavailable."
	)


func _test_service_unavailable_response_marks_request_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request()
	repository._decode_response(request, HTTPRequest.RESULT_SUCCESS, 503, PackedByteArray())
	_expect(
		request.status == LeaderboardRequest.Status.UNAVAILABLE,
		"A 503 response must mark its request unavailable."
	)
	_expect(
		request.error_code == "SERVICE_UNAVAILABLE",
		"A 503 response must report an unavailable error on its request."
	)
	repository.queue_free()


func _test_malformed_json_response_fails() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request()
	repository._decode_response(
		request, HTTPRequest.RESULT_SUCCESS, 200, "not json".to_utf8_buffer()
	)
	_expect(
		(
			request.status == LeaderboardRequest.Status.FAILED
			and request.error_code == "MALFORMED_RESPONSE"
		),
		"Malformed JSON must fail the request."
	)
	repository.queue_free()


func _test_cancelled_request_ignores_late_response() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request()
	request.cancel()
	repository._decode_response(request, HTTPRequest.RESULT_SUCCESS, 503, PackedByteArray())
	_expect(
		request.status == LeaderboardRequest.Status.CANCELLED,
		"A late response must not replace a cancelled request result."
	)
	repository.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
