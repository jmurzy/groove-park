## Headless parsing and failure checks for the Worker-backed repository.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_service_unavailable_response_marks_request_unavailable()
	_test_network_failures_mark_request_unavailable()
	_test_http_failure_marks_request_failed()
	_test_malformed_json_response_fails()
	_test_cancelled_request_ignores_late_response()
	_test_top_entries_require_entry_dictionaries()
	_test_top_entries_parse_typed_values()
	if _failures.is_empty():
		print("Remote leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_service_unavailable_response_marks_request_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request(LeaderboardRepository.Request.Operation.GET)
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


func _test_network_failures_mark_request_unavailable() -> void:
	var results: Array[int] = [
		HTTPRequest.RESULT_TIMEOUT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
	]
	for result: int in results:
		var repository := RemoteLeaderboardRepository.new()
		var request := repository._start_request(LeaderboardRepository.Request.Operation.GET)
		repository._decode_response(request, result, 0, PackedByteArray())
		_expect(
			request.status == LeaderboardRepository.Request.Status.FAILED,
			"Network failures must fail their requests."
		)
		_expect(
			request.error_code == "NETWORK_UNAVAILABLE",
			"Network failures must report an unavailable error on their requests."
		)
		repository.queue_free()


func _test_http_failure_marks_request_failed() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request(LeaderboardRepository.Request.Operation.GET)
	repository._decode_response(request, HTTPRequest.RESULT_SUCCESS, 500, PackedByteArray())
	_expect(
		request.status == LeaderboardRepository.Request.Status.FAILED,
		"A non-503 HTTP response must fail its request."
	)
	_expect(
		request.error_code == "HTTP_500",
		"A non-503 HTTP response must retain its status in the error code."
	)
	repository.queue_free()


func _test_malformed_json_response_fails() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var request := repository._start_request(LeaderboardRepository.Request.Operation.GET)
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
	var request := repository._start_request(LeaderboardRepository.Request.Operation.GET)
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


func _test_top_entries_parse_typed_values() -> void:
	var entries: Array[LeaderboardEntry] = []
	_expect(
		(
			(
				LeaderboardEntry
				. entries_from_api(
					[
						{
							"roundId": "018f3d8e-6b1c-7ef9-8cf6-252ff3d07123",
							"playerName": "PLAYER",
							"riderKind": "skier",
							"totalScore": 420,
							"platform": "ags",
							"createdAt": "2026-10-04T12:00:00+00:00",
						},
					],
					entries
				)
			)
			and entries.size() == 1
			and entries[0].rider_kind == RiderKind.SKIER
			and entries[0].platform == &"ags"
		),
		"Valid API entries must parse into typed leaderboard entries."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
