## Typed entry returned by the authoritative leaderboard API.
class_name LeaderboardEntry
extends RefCounted

var round_id: String
var player_name: String
var rider_kind: StringName
var total_score: int
var platform: StringName
var created_at: String


static func from_api(value: Dictionary) -> LeaderboardEntry:
	if (
		not value.get("roundId") is String
		or not value.get("playerName") is String
		or not value.get("riderKind") is String
		or not value.get("totalScore") is int
		or not value.get("platform") is String
		or not value.get("createdAt") is String
	):
		return null
	var entry := LeaderboardEntry.new()
	entry.round_id = value.roundId
	entry.player_name = value.playerName
	entry.rider_kind = StringName(value.riderKind)
	entry.total_score = value.totalScore
	entry.platform = StringName(value.platform)
	entry.created_at = value.createdAt
	return entry


static func entries_from_api(values: Variant, entries: Array[LeaderboardEntry]) -> bool:
	if not values is Array:
		return false
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var entry := from_api(value)
		if entry == null:
			return false
		entries.append(entry)
	return true
