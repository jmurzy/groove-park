## One cancellable leaderboard operation that a caller may await directly.
class_name LeaderboardRequest
extends RefCounted

signal completed(result: LeaderboardOperationResult)
signal cancel_requested(request: LeaderboardRequest)

var kind: LeaderboardOperationResult.Kind
var result: LeaderboardOperationResult


func cancel() -> void:
	if result == null:
		cancel_requested.emit(self)


func wait_for_result() -> LeaderboardOperationResult:
	if result != null:
		return result
	return await completed


func _complete(next_result: LeaderboardOperationResult) -> void:
	if result != null:
		return
	result = next_result
	completed.emit(result)
