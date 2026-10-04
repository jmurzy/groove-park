## Typed terminal value for a cancellable leaderboard operation.
class_name LeaderboardOperationResult
extends RefCounted

enum Kind {
	TOP_ENTRIES,
	QUALIFICATION,
	SUBMISSION,
}

enum Status {
	SUCCEEDED,
	UNAVAILABLE,
	FAILED,
	CANCELLED,
}

var operation_id: int
var session_generation: int
var kind: Kind
var status: Status
var entries: Array[LeaderboardEntry] = []
var qualification: LeaderboardQualification
var rank: Variant
var error_code := ""
