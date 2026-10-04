## Platform-neutral cancellable leaderboard interface.
class_name LeaderboardRepository
extends Node

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


func _finish_request(request: LeaderboardRequest, next_status: LeaderboardRequest.Status) -> void:
	if request == _submission_request:
		_submission_request = null
	request._complete(next_status)
