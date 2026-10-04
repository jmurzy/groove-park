## Platform-neutral cancellable leaderboard interface.
class_name LeaderboardRepository
extends Node

signal availability_changed(available: bool)

var _is_service_available := true
var _submission_request: LeaderboardRequest


func get_top_entries() -> LeaderboardRequest:
	return null


func check_qualification(_total_score: int) -> LeaderboardRequest:
	return null


func submit_score(_submission: LeaderboardSubmission) -> LeaderboardRequest:
	return null


func _cancel_request(request: LeaderboardRequest) -> void:
	if request.status != LeaderboardRequest.Status.PENDING:
		return
	if request == _submission_request:
		_submission_request = null
	request._complete(LeaderboardRequest.Status.CANCELLED)


func _start_request() -> LeaderboardRequest:
	var request := LeaderboardRequest.new()
	request.cancel_requested.connect(_cancel_request)
	return request


func _start_submission() -> LeaderboardRequest:
	_submission_request = _start_request()
	return _submission_request


func _finish_request(request: LeaderboardRequest, next_status: LeaderboardRequest.Status) -> void:
	if request == _submission_request:
		_submission_request = null
	request._complete(next_status)


func _set_available(next_available: bool) -> void:
	if _is_service_available == next_available:
		return
	_is_service_available = next_available
	availability_changed.emit(_is_service_available)


func _pending_submission() -> LeaderboardRequest:
	return _submission_request
