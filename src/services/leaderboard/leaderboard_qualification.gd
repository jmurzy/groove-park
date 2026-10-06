## Typed result of checking whether a completed round may be submitted.
class_name LeaderboardQualification
extends RefCounted

var qualified: bool
var rank: Variant


static func from_api(value: Dictionary) -> LeaderboardQualification:
	if not value.get("qualified") is bool:
		return null
	var api_rank: Variant = value.get("rank")
	if api_rank != null and not api_rank is float:
		return null
	var qualification := LeaderboardQualification.new()
	qualification.qualified = value.qualified
	qualification.rank = int(api_rank) if api_rank != null else null
	return qualification
