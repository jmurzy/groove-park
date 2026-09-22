## Immutable summary of a completed run. Expand this with per-player results
## when the shared two-player event is introduced.
class_name RunResult
extends RefCounted

var player_count: int:
	get:
		return _player_count
var score: int:
	get:
		return _score
var jump_result: JumpResult:
	get:
		return _jump_result

var _player_count: int
var _score: int
var _jump_result: JumpResult


func _init(initial_player_count: int, initial_jump_result: JumpResult) -> void:
	_player_count = initial_player_count
	_jump_result = initial_jump_result
	_score = _jump_result.score
