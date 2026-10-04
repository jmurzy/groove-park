## Headless parsing and failure checks for the Worker-backed repository.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_service_unavailable_response_marks_request_unavailable()
	_test_timeout_response_marks_request_unavailable()
	_test_malformed_json_response_fails()
	_test_cancelled_request_ignores_late_response()
	_test_top_entries_require_entry_dictionaries()
	if _failures.is_empty():
		print("Remote leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_service_unavailable_response_marks_request_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request()
	repository._decode_response(request, HTTPRequest.RESULT_SUCCESS, 503, PackedByteArray())
	_expect(
		request.status == LeaderboardRepository.Request.Status.FAILED,
		"A 503 response must fail its request."
	)
	_expect(
		request.error_code == "SERVICE_UNAVAILABLE",
		"A 503 response must report an unavailable error on its request."
	)
	repository.queue_free()


func _test_timeout_response_marks_request_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request()
	repository._decode_response(request, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	_expect(
		request.status == LeaderboardRepository.Request.Status.FAILED,
		"A timed-out request must fail its request."
	)
	_expect(
		request.error_code == "NETWORK_UNAVAILABLE",
		"A timed-out request must report an unavailable error on its request."
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
			request.status == LeaderboardRepository.Request.Status.FAILED
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
		request.status == LeaderboardRepository.Request.Status.CANCELLED,
		"A late response must not replace a cancelled request result."
	)
	repository.queue_free()


func _test_top_entries_require_entry_dictionaries() -> void:
	var entries: Array[LeaderboardEntry] = []
	_expect(
		not LeaderboardEntry.entries_from_api(["invalid"], entries) and entries.is_empty(),
		"Top-entry parsing must reject non-dictionary values."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
