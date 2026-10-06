## Platform-neutral cancellable leaderboard interface.
class_name LeaderboardRepository
extends Node


class Request:
	extends RefCounted
	signal completed(request: Request)
	signal cancel_requested(request: Request)

	enum Operation {
		GET,
		POST,
	}

	enum Status {
		PENDING,
		SUCCEEDED,
		FAILED,
		CANCELLED,
	}

	var operation: Operation
	var endpoint := ""
	var status := Status.PENDING
	var result: Variant
	var error_code := ""

	func cancel() -> void:
		if status == Status.PENDING:
			cancel_requested.emit(self)

	func _complete(next_status: Status) -> void:
		if status != Status.PENDING:
			return
		status = next_status
		_log_completion()
		completed.emit(self)

	func _log_completion() -> void:
		var operation_name := "GET" if operation == Operation.GET else "POST"
		var target := (
			"%s %s" % [operation_name, endpoint] if not endpoint.is_empty() else operation_name
		)
		match status:
			Status.SUCCEEDED:
				print("Leaderboard %s request succeeded: %s" % [target, result])
			Status.FAILED:
				print(
					(
						"Leaderboard %s request failed: %s."
						% [target, error_code if not error_code.is_empty() else "UNKNOWN"]
					)
				)
			Status.CANCELLED:
				print("Leaderboard %s request cancelled." % target)


var _submission_request: Request


func get_top_entries() -> Request:
	return null


func check_qualification(_total_score: int) -> Request:
	return null


func submit_score(_submission: LeaderboardSubmission) -> Request:
	return null


func _cancel_request(request: Request) -> void:
	if request.status != Request.Status.PENDING:
		return
	if request == _submission_request:
		_submission_request = null
	request._complete(Request.Status.CANCELLED)


func _start_request(operation: Request.Operation) -> Request:
	var request := Request.new()
	request.operation = operation
	request.cancel_requested.connect(_cancel_request)
	return request


func _finish_request(request: Request, next_status: Request.Status) -> void:
	if request == _submission_request:
		_submission_request = null
	request._complete(next_status)
