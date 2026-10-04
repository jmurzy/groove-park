## Platform-neutral cancellable leaderboard interface.
class_name LeaderboardRepository
extends Node

signal availability_changed(available: bool)

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
var _pending: Dictionary = {}


func get_top_entries() -> LeaderboardRequest:
	return null


func check_qualification(_total_score: int) -> LeaderboardRequest:
	return null


func submit_score(_submission: LeaderboardSubmission) -> LeaderboardRequest:
	return null


func _cancel_request(request: LeaderboardRequest) -> void:
	if not _pending.erase(request):
		return
	var result := LeaderboardOperationResult.new()
	result.status = LeaderboardOperationResult.Status.CANCELLED
	request._complete(result)


func _start_request(kind: LeaderboardOperationResult.Kind) -> LeaderboardRequest:
	var request := LeaderboardRequest.new()
	request.kind = kind
	request.cancel_requested.connect(_cancel_request)
	_pending[request] = true
	return request


func _finish_request(request: LeaderboardRequest, result: LeaderboardOperationResult) -> void:
	if not _pending.erase(request):
		return
	request._complete(result)


func _set_available(next_available: bool) -> void:
	if _available == next_available:
		return
	_available = next_available
	availability_changed.emit(_available)


func _pending_submission() -> LeaderboardRequest:
	for request: LeaderboardRequest in _pending.keys():
		if request.kind == LeaderboardOperationResult.Kind.SUBMISSION:
			return request
	return null
