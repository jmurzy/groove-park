## Immutable authoritative record for the active arcade round.
class_name RoundState
extends RefCounted

enum SessionPhase {
	ATTRACT,
	RIDER_SELECT,
	JUMP_ACTIVE,
	JUMP_TALLY,
	GAME_OVER,
	QUALIFYING,
	NAME_ENTRY,
	ROUND_RESULTS,
}

const MAX_JUMPS := 3

var _rider_kind: StringName
var _current_jump_number: int
var _jump_results: Array[JumpResult]
var _session_phase: SessionPhase


func _init(
	next_rider_kind: StringName,
	next_current_jump_number: int,
	next_jump_results: Array[JumpResult],
	next_session_phase: SessionPhase
) -> void:
	_rider_kind = next_rider_kind
	_current_jump_number = next_current_jump_number
	_jump_results = next_jump_results.duplicate()
	_session_phase = next_session_phase


static func create(
	rider_kind: StringName,
	current_jump_number := 1,
	jump_results: Array[JumpResult] = [],
	session_phase: SessionPhase = SessionPhase.RIDER_SELECT
) -> RecordValidationResult:
	var errors := PackedStringArray()
	if not RiderKind.is_valid(rider_kind):
		errors.append("RoundState requires a valid RiderKind.")
	if current_jump_number < 1 or current_jump_number > MAX_JUMPS:
		errors.append("RoundState jump number must be between 1 and %d." % MAX_JUMPS)
	if jump_results.size() > MAX_JUMPS:
		errors.append("RoundState cannot contain more than %d jump results." % MAX_JUMPS)
	for result in jump_results:
		if result == null:
			errors.append("RoundState results cannot contain null.")
	if session_phase < SessionPhase.ATTRACT or session_phase > SessionPhase.ROUND_RESULTS:
		errors.append("RoundState requires a valid session phase.")
	if not errors.is_empty():
		return RecordValidationResult.failure(errors)
	return RecordValidationResult.success(
		RoundState.new(rider_kind, current_jump_number, jump_results, session_phase)
	)


func rider_kind() -> StringName:
	return _rider_kind


func current_jump_number() -> int:
	return _current_jump_number


func jump_results() -> Array[JumpResult]:
	return _jump_results.duplicate()


func round_score() -> int:
	var total := 0
	for result in _jump_results:
		total += result.resolved_score()
	return total


func session_phase() -> SessionPhase:
	return _session_phase
