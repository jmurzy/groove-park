## Platform-neutral cancellable leaderboard interface.
class_name LeaderboardRepository
extends Node

signal availability_changed(available: bool)
signal operation_completed(result: LeaderboardOperationResult)

enum State {
	AVAILABLE,
	UNAVAILABLE,
	QUALIFYING,
	SUBMITTING,
	ACCEPTED,
	FAILED,
}

var state := State.AVAILABLE
var _available := true
var _next_operation_id := 1
var _pending: Dictionary = {}


func get_top_entries(_session_generation: int) -> int:
	return -1


func check_qualification(_total_score: int, _session_generation: int) -> int:
	return -1


func submit_score(_submission: LeaderboardSubmission, _session_generation: int) -> int:
	return -1


func cancel(operation_id: int) -> void:
	var result: LeaderboardOperationResult = _pending.get(operation_id)
	if result == null:
		return
	_pending.erase(operation_id)
	result.status = LeaderboardOperationResult.Status.CANCELLED
	operation_completed.emit(result)


func _start_operation(
	kind: LeaderboardOperationResult.Kind, session_generation: int
) -> LeaderboardOperationResult:
	var result := LeaderboardOperationResult.new()
	result.operation_id = _next_operation_id
	_next_operation_id += 1
	result.session_generation = session_generation
	result.kind = kind
	_pending[result.operation_id] = result
	return result


func _finish_operation(result: LeaderboardOperationResult) -> void:
	if not _pending.erase(result.operation_id):
		return
	operation_completed.emit(result)


func _set_available(next_available: bool) -> void:
	if _available == next_available:
		return
	_available = next_available
	availability_changed.emit(_available)


func _pending_submission_id() -> int:
	for result: LeaderboardOperationResult in _pending.values():
		if result.kind == LeaderboardOperationResult.Kind.SUBMISSION:
			return result.operation_id
	return -1
