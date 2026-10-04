## Headless contract checks for deterministic leaderboard repository behavior.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_available_operations_return_typed_values()
	_test_unavailable_service_returns_typed_failure()
	_test_submission_is_not_duplicated_while_in_flight()
	_test_cancelled_operation_cannot_complete_late()
	if _failures.is_empty():
		print("Leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_available_operations_return_typed_values() -> void:
	var repository := FakeLeaderboardRepository.new()
	var request := repository.check_qualification(250)
	_expect(
		request.status != LeaderboardRequest.Status.PENDING,
		"Available fake qualification must complete."
	)
	_expect(
		request.status == LeaderboardRequest.Status.SUCCEEDED and request.qualification.qualified,
		"Qualification must preserve its typed result."
	)


func _test_unavailable_service_returns_typed_failure() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.is_available = false
	var request := repository.get_top_entries()
	_expect(
		request.status != LeaderboardRequest.Status.PENDING,
		"Unavailable requests must finish exactly once."
	)
	_expect(
		request.status == LeaderboardRequest.Status.UNAVAILABLE,
		"Unavailable requests must return an unavailable result."
	)


func _test_submission_is_not_duplicated_while_in_flight() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var submission := LeaderboardSubmission.create(
		"018f3d8e-6b1c-7ef9-8cf6-252ff3d07123", "PLAYER", RiderKind.SKIER, 400, &"ags"
	)
	var first_request := repository.submit_score(submission)
	var duplicate_request := repository.submit_score(submission)
	_expect(
		first_request == duplicate_request,
		"An in-flight submission must not create a second request."
	)
	_expect(repository.entries.size() == 1, "An in-flight duplicate must not create another entry.")
	repository.complete_deferred(first_request)


func _test_cancelled_operation_cannot_complete_late() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var request := repository.check_qualification(400)
	request.cancel()
	repository.complete_deferred(request)
	_expect(
		request.status != LeaderboardRequest.Status.PENDING,
		"Cancelled requests must finish exactly once."
	)
	_expect(
		request.status == LeaderboardRequest.Status.CANCELLED,
		"Cancellation must emit an explicit cancelled result."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
