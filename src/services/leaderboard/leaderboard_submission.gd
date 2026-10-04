## Typed payload for a single idempotent leaderboard submission.
class_name LeaderboardSubmission
extends RefCounted

var round_id: String
var player_name: String
var rider_kind: StringName
var total_score: int
var platform: StringName


static func create(
	next_round_id: String,
	next_player_name: String,
	next_rider_kind: StringName,
	next_total_score: int,
	next_platform: StringName
) -> LeaderboardSubmission:
	var submission := LeaderboardSubmission.new()
	submission.round_id = next_round_id
	submission.player_name = next_player_name
	submission.rider_kind = next_rider_kind
	submission.total_score = next_total_score
	submission.platform = next_platform
	return submission


func to_api() -> Dictionary:
	return {
		"roundId": round_id,
		"playerName": player_name,
		"riderKind": str(rider_kind),
		"totalScore": total_score,
		"platform": str(platform),
	}
