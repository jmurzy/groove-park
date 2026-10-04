## Headless parsing and failure checks for the Worker-backed repository.
extends SceneTree

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
	repository.setup("")
	var request := repository.check_qualification(100)
	_expect(
		(
			request.result != null
			and request.result.status == LeaderboardOperationResult.Status.UNAVAILABLE
		),
		"An unconfigured remote client must report unavailable."
	)


func _test_malformed_success_response_fails_without_retry() -> void:
	var repository := RemoteLeaderboardRepository.new()
	repository.setup("https://example.test")
	var request := repository._start_request(LeaderboardOperationResult.Kind.TOP_ENTRIES)
	repository._on_response_received(
		request, HTTPRequest.RESULT_SUCCESS, 200, "{}".to_utf8_buffer()
	)
	_expect(request.result != null, "A malformed response must finish once.")
	_expect(
		(
			request.result.status == LeaderboardOperationResult.Status.FAILED
			and request.result.error_code == "MALFORMED_RESPONSE"
		),
		"Malformed responses must fail without being retried."
	)
	repository.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
