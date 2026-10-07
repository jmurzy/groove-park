## Typed result of checking whether a completed round may be submitted.
class_name LeaderboardQualification
extends RefCounted

var qualified: bool


static func from_api(value: Dictionary) -> LeaderboardQualification:
	if not value.get("qualified") is bool:
		return null
	var qualification := LeaderboardQualification.new()
	qualification.qualified = value.qualified
	return qualification
