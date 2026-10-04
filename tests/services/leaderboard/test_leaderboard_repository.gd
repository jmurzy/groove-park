## Headless contract checks for deterministic leaderboard repository behavior.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_available_operations_return_typed_values()
	_test_unavailable_service_preserves_local_operation_context()
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
	var results: Array[LeaderboardOperationResult] = []
	repository.operation_completed.connect(
		func(result: LeaderboardOperationResult) -> void: results.append(result)
	)
	var qualification_id := repository.check_qualification(250, 7)
	_expect(qualification_id > 0, "Qualification must receive an operation ID.")
	_expect(results.size() == 1, "Available fake qualification must complete.")
	_expect(
		(
			results[0].status == LeaderboardOperationResult.Status.SUCCEEDED
			and results[0].qualification.qualified
			and results[0].session_generation == 7
		),
		"Qualification must preserve its typed result and session generation."
	)


func _test_unavailable_service_preserves_local_operation_context() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.is_available = false
	var results: Array[LeaderboardOperationResult] = []
	repository.operation_completed.connect(
		func(result: LeaderboardOperationResult) -> void: results.append(result)
	)
	repository.get_top_entries(4)
	_expect(results.size() == 1, "Unavailable requests must finish exactly once.")
	_expect(
		(
			results[0].status == LeaderboardOperationResult.Status.UNAVAILABLE
			and results[0].session_generation == 4
		),
		"Unavailable requests must not discard their operation context."
	)


func _test_submission_is_not_duplicated_while_in_flight() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var submission := LeaderboardSubmission.create(
		"018f3d8e-6b1c-7ef9-8cf6-252ff3d07123", "PLAYER", RiderKind.SKIER, 400, &"ags"
	)
	var first_id := repository.submit_score(submission, 1)
	var duplicate_id := repository.submit_score(submission, 1)
	_expect(first_id == duplicate_id, "An in-flight submission must not create a second request.")
	_expect(repository.entries.size() == 1, "An in-flight duplicate must not create another entry.")
	repository.complete_deferred(first_id)


func _test_cancelled_operation_cannot_complete_late() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var results: Array[LeaderboardOperationResult] = []
	repository.operation_completed.connect(
		func(result: LeaderboardOperationResult) -> void: results.append(result)
	)
	var operation_id := repository.check_qualification(400, 2)
	repository.cancel(operation_id)
	repository.complete_deferred(operation_id)
	_expect(results.size() == 1, "Cancelled operations must ignore late completion.")
	_expect(
		results[0].status == LeaderboardOperationResult.Status.CANCELLED,
		"Cancellation must emit an explicit cancelled result."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
