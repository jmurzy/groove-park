## Immutable leaderboard state associated with a completed local round.
class_name Leaderboard
extends RefCounted

enum Status {
	UNKNOWN,
	AVAILABLE,
	OFFLINE,
	SUBMITTED,
	SUBMISSION_FAILED,
	NAME_ENTRY_SKIPPED,
}

var _status: Status
var _qualified: Variant
var _rank: Variant
var _entries: Array[LeaderboardEntry]


func _init(
	next_status: Status = Status.UNKNOWN,
	next_qualified: Variant = null,
	next_rank: Variant = null,
	next_entries: Array[LeaderboardEntry] = []
) -> void:
	_status = next_status
	_qualified = next_qualified
	_rank = next_rank
	_entries.assign(next_entries)


static func available(qualification: LeaderboardQualification) -> Leaderboard:
	return Leaderboard.new(Status.AVAILABLE, qualification.qualified, qualification.rank)


static func offline() -> Leaderboard:
	return Leaderboard.new(Status.OFFLINE)


func with_submission(submission_result: LeaderboardSubmissionResult) -> Leaderboard:
	return Leaderboard.new(
		Status.SUBMITTED, _qualified, submission_result.rank, submission_result.top_entries
	)


func with_submission_failure() -> Leaderboard:
	return Leaderboard.new(Status.SUBMISSION_FAILED, _qualified, _rank, _entries)


func with_skipped() -> Leaderboard:
	return Leaderboard.new(Status.NAME_ENTRY_SKIPPED, _qualified, _rank, _entries)


func status() -> Status:
	return _status


func qualified() -> Variant:
	return _qualified


func rank() -> Variant:
	return _rank


func entries() -> Array[LeaderboardEntry]:
	return _entries.duplicate()
