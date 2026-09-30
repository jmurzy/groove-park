## Immutable completed-run contract.
class_name RunResult
extends RefCounted

var jump_results: Array[JumpResult]:
	get:
		return _jump_results.duplicate()
var total_score: int:
	get:
		return _total_score

var _jump_results: Array[JumpResult]
var _total_score := 0


func _init(initial_jump_results: Array[JumpResult]) -> void:
	_jump_results = initial_jump_results.duplicate()
	for jump_result in _jump_results:
		_total_score += jump_result.score


static func from_rider_state(rider_state: RiderState) -> RunResult:
	return RunResult.new([JumpResult.from_rider_state(rider_state)])
