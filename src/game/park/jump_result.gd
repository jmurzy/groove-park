## Immutable terminal result for one scored jump.
class_name JumpResult
extends RefCounted

var _outcome: int
var _resolved_score: int


func _init(outcome: int, resolved_score: int) -> void:
	_outcome = outcome
	_resolved_score = resolved_score


static func create(outcome: int, resolved_score: int) -> RecordValidationResult:
	var errors := PackedStringArray()
	if not JumpOutcome.is_terminal(outcome):
		errors.append("JumpResult requires a terminal JumpOutcome.")
	if resolved_score < 0:
		errors.append("JumpResult score must be non-negative.")
	if not errors.is_empty():
		return RecordValidationResult.failure(errors)
	return RecordValidationResult.success(JumpResult.new(outcome, resolved_score))


func outcome() -> int:
	return _outcome


func resolved_score() -> int:
	return _resolved_score
