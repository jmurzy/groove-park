## Immutable leaderboard state associated with a completed local round.
class_name Leaderboard
extends RefCounted

enum Status {
	OK,
	OFFLINE,
}

var _status: Status
var _qualified: Variant
var _rank: Variant
var _entries: Array[LeaderboardEntry]


func _init(
	next_status: Status = Status.OK,
	next_qualified: Variant = null,
	next_rank: Variant = null,
	next_entries: Array[LeaderboardEntry] = []
) -> void:
	_status = next_status
	_qualified = next_qualified
	_rank = next_rank
	_entries.assign(next_entries)


static func offline() -> Leaderboard:
	return Leaderboard.new(Status.OFFLINE)


func with_qualification(qualification: LeaderboardQualification) -> Leaderboard:
	return Leaderboard.new(Status.OK, qualification.qualified)


func with_submission(submission_result: LeaderboardSubmissionResult) -> Leaderboard:
	return Leaderboard.new(Status.OK, _qualified, submission_result.rank)


func with_top_entries(entries: Array[LeaderboardEntry]) -> Leaderboard:
	return Leaderboard.new(Status.OK, _qualified, _rank, entries)


func with_skipped() -> Leaderboard:
	return Leaderboard.new(Status.OK, _qualified, _rank)


func status() -> Status:
	return _status


func is_qualified() -> Variant:
	return _qualified


func rank() -> Variant:
	return _rank


func top_entries() -> Array[LeaderboardEntry]:
	return _entries.duplicate()
