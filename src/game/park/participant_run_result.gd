## Immutable judged jumps for one active player in a completed run.
class_name ParticipantRunResult
extends RefCounted

var player_index: int:
	get:
		return _player_index
var jump_results: Array[JumpResult]:
	get:
		return _jump_results.duplicate()
var total_score: int:
	get:
		return _total_score

var _player_index: int
var _jump_results: Array[JumpResult]
var _total_score := 0


func _init(initial_player_index: int, initial_jump_results: Array[JumpResult]) -> void:
	_player_index = initial_player_index
	_jump_results = initial_jump_results.duplicate()
	for jump_result in _jump_results:
		_total_score += jump_result.score


static func from_rider_state(player_index: int, rider_state: RiderState) -> ParticipantRunResult:
	return ParticipantRunResult.new(player_index, [JumpResult.from_jump_state(rider_state.jump)])
