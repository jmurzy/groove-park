## Headless parsing and failure checks for the Worker-backed repository.
extends SceneTree


class StubHttpClient:
	extends LeaderboardHttpClient

	func request_json(
		_operation_id: int, _url: String, _method: HTTPClient.Method, _payload: Dictionary = {}
	) -> Error:
		return OK


var _failures := PackedStringArray()


func _init() -> void:
	_test_unconfigured_client_is_unavailable()
	_test_malformed_success_response_fails_without_retry()
	if _failures.is_empty():
		print("Remote leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_unconfigured_client_is_unavailable() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var results: Array[LeaderboardOperationResult] = []
	repository.operation_completed.connect(
		func(result: LeaderboardOperationResult) -> void: results.append(result)
	)
	repository.setup("")
	repository.check_qualification(100, 1)
	_expect(
		results.size() == 1 and results[0].status == LeaderboardOperationResult.Status.UNAVAILABLE,
		"An unconfigured remote client must report unavailable."
	)


func _test_malformed_success_response_fails_without_retry() -> void:
	var http := StubHttpClient.new()
	var repository := RemoteLeaderboardRepository.new()
	var results: Array[LeaderboardOperationResult] = []
	repository.operation_completed.connect(
		func(result: LeaderboardOperationResult) -> void: results.append(result)
	)
	repository.setup("https://example.test", http)
	var operation_id := repository.get_top_entries(3)
	http.response_received.emit(
		operation_id, HTTPRequest.RESULT_SUCCESS, 200, "{}".to_utf8_buffer()
	)
	_expect(results.size() == 1, "A malformed response must finish once.")
	_expect(
		(
			results[0].status == LeaderboardOperationResult.Status.FAILED
			and results[0].error_code == "MALFORMED_RESPONSE"
		),
		"Malformed responses must fail without being retried."
	)
	repository.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
