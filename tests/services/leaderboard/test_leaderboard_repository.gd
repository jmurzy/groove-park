## Headless contract checks for deterministic leaderboard repository behavior.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_available_operations_return_typed_values()
	_test_unavailable_service_returns_typed_failure()
	_test_submission_is_not_duplicated_while_in_flight()
	_test_cancelled_operation_cannot_complete_late()
	_test_cancelled_submission_does_not_mutate_board()
	_test_installation_id_is_persisted()
	if _failures.is_empty():
		print("Leaderboard repository checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_available_operations_return_typed_values() -> void:
	var repository := FakeLeaderboardRepository.new()
	var entry := LeaderboardEntry.new()
	entry.round_id = "018f3d8e-6b1c-7ef9-8cf6-252ff3d07120"
	entry.player_name = "PLAYER"
	entry.rider_kind = RiderKind.SKIER
	entry.total_score = 250
	entry.platform = &"ags"
	entry.created_at = "test"
	repository.entries.append(entry)
	var entries_request := repository.get_top_entries()
	var request := repository.check_qualification(250)
	var qualification: LeaderboardQualification
	if request.result is LeaderboardQualification:
		qualification = request.result
	var top_entries: Array[LeaderboardEntry] = []
	if entries_request.result is Array:
		top_entries.assign(entries_request.result)
	_expect(
		request.status != LeaderboardRepository.Request.Status.PENDING,
		"Available fake qualification must complete."
	)
	_expect(
		(
			request.status == LeaderboardRepository.Request.Status.SUCCEEDED
			and request.operation == LeaderboardRepository.Request.Operation.POST
			and qualification != null
			and qualification.qualified
		),
		"Qualification must use POST and preserve its typed result."
	)
	_expect(
		(
			entries_request.status == LeaderboardRepository.Request.Status.SUCCEEDED
			and entries_request.operation == LeaderboardRepository.Request.Operation.GET
			and top_entries.size() == 1
			and top_entries[0] == entry
		),
		"Top-entry requests must use GET and preserve typed leaderboard entries."
	)


func _test_unavailable_service_returns_typed_failure() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.is_available = false
	var request := repository.get_top_entries()
	_expect(
		request.status != LeaderboardRepository.Request.Status.PENDING,
		"Unavailable requests must finish exactly once."
	)
	_expect(
		request.status == LeaderboardRepository.Request.Status.FAILED,
		"Unavailable services must return a failed request."
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
		(
			first_request == duplicate_request
			and first_request.operation == LeaderboardRepository.Request.Operation.POST
		),
		"An in-flight POST submission must not create a second request."
	)
	_expect(repository.entries.is_empty(), "An in-flight submission must not mutate the board.")
	repository.complete_deferred(first_request)
	var submission_result: LeaderboardSubmissionResult
	if first_request.result is LeaderboardSubmissionResult:
		submission_result = first_request.result
	_expect(
		(
			submission_result != null
			and submission_result.rank == 1
			and submission_result.top_entries.size() == 1
		),
		"Accepted submissions must return their typed rank and top entries."
	)
	repository.deferred = false
	var retry_request := repository.submit_score(submission)
	_expect(
		retry_request.result is LeaderboardSubmissionResult and repository.entries.size() == 1,
		"A repeated round ID must return the original submission without another entry."
	)


func _test_cancelled_operation_cannot_complete_late() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var request := repository.check_qualification(400)
	request.cancel()
	repository.complete_deferred(request)
	_expect(
		request.status != LeaderboardRepository.Request.Status.PENDING,
		"Cancelled requests must finish exactly once."
	)
	_expect(
		request.status == LeaderboardRepository.Request.Status.CANCELLED,
		"Cancellation must emit an explicit cancelled result."
	)


func _test_cancelled_submission_does_not_mutate_board() -> void:
	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var submission := LeaderboardSubmission.create(
		"018f3d8e-6b1c-7ef9-8cf6-252ff3d07124", "PLAYER", RiderKind.SKIER, 400, &"ags"
	)
	var request := repository.submit_score(submission)
	_expect(
		repository.entries.is_empty() and request.result == null,
		"A deferred submission must not mutate the board or expose a result."
	)
	request.cancel()
	repository.complete_deferred(request)
	_expect(
		(
			request.status == LeaderboardRepository.Request.Status.CANCELLED
			and repository.entries.is_empty()
		),
		"A cancelled submission must not mutate the board when its deferred completion arrives."
	)


func _test_installation_id_is_persisted() -> void:
	var settings_path := "user://test-leaderboard-%s.cfg" % Id.generate_id()
	var first_id := Config.resolve_installation_id(settings_path)
	var second_id := Config.resolve_installation_id(settings_path)
	_expect(not first_id.is_empty(), "A new installation ID must be generated.")
	_expect(first_id == second_id, "The generated installation ID must persist across reads.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
