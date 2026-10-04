## One cancellable leaderboard operation and its terminal response.
class_name LeaderboardRequest
extends RefCounted

signal completed(request: LeaderboardRequest)
signal cancel_requested(request: LeaderboardRequest)

enum Status {
	PENDING,
	SUCCEEDED,
	UNAVAILABLE,
	FAILED,
	CANCELLED,
}

var status := Status.PENDING
var entries: Array[LeaderboardEntry] = []
var qualification: LeaderboardQualification
var rank: Variant
var error_code := ""


func cancel() -> void:
	if status == Status.PENDING:
		cancel_requested.emit(self)


func _complete(next_status: Status) -> void:
	if status != Status.PENDING:
		return
	status = next_status
	completed.emit(self)
