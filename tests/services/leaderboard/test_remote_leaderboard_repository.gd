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
		request.status == LeaderboardRequest.Status.UNAVAILABLE,
		"An unconfigured remote client must report unavailable."
	)


func _test_malformed_success_response_fails_without_retry() -> void:
	var repository := RemoteLeaderboardRepository.new()
	var entries: Array[LeaderboardEntry] = []
	_expect(
		not repository._entries_from_api({}, entries),
		"A malformed top-entry response must be rejected."
	)
	_expect(entries.is_empty(), "Malformed top-entry responses must not produce partial entries.")
	repository.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
