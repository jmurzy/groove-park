## Immutable terminal result for one scored jump.
class_name JumpResult
extends RefCounted

var _snapshot: JumpSnapshot
var _score: JumpScore


func _init(snapshot: JumpSnapshot, score: JumpScore) -> void:
	_snapshot = snapshot
	_score = score


static func create(snapshot: JumpSnapshot, score: JumpScore) -> RecordValidationResult:
	var errors := PackedStringArray()
	if snapshot == null:
		errors.append("JumpResult requires a frozen JumpSnapshot.")
	if score == null:
		errors.append("JumpResult requires a resolved JumpScore.")
	elif score.total() < 0:
		errors.append("JumpResult score must be non-negative.")
	if not errors.is_empty():
		return RecordValidationResult.failure(errors)
	return RecordValidationResult.success(JumpResult.new(snapshot, score))


func outcome() -> int:
	return _snapshot.outcome()


func resolved_score() -> int:
	return _score.total()


func snapshot() -> JumpSnapshot:
	return _snapshot


func score() -> JumpScore:
	return _score


func trick_summary() -> String:
	var parts := PackedStringArray([JumpOutcome.label(outcome())])
	if _snapshot.completed_rotations() > 0:
		parts.append("%d" % (_snapshot.completed_rotations() * 360))
	if _snapshot.grab_style() == JumpSnapshot.GrabStyle.STANDARD:
		parts.append("GRAB")
	elif _snapshot.grab_style() == JumpSnapshot.GrabStyle.TWEAK:
		parts.append("TWEAK GRAB")
	return " ".join(parts)
