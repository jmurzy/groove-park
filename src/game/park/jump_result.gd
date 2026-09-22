## Immutable resolved score and contact snapshot for one judged jump.
class_name JumpResult
extends RefCounted

var score: int:
	get:
		return _score
var landing_label: String:
	get:
		return _landing_label
var trick_call: String:
	get:
		return _trick_call
var score_breakdown: Dictionary:
	get:
		return _score_breakdown.duplicate(true)

var _score: int
var _landing_label: String
var _trick_call: String
var _score_breakdown: Dictionary


func _init(
	initial_score: int,
	initial_landing_label: String,
	initial_trick_call: String,
	initial_score_breakdown: Dictionary
) -> void:
	_score = initial_score
	_landing_label = initial_landing_label
	_trick_call = initial_trick_call
	_score_breakdown = initial_score_breakdown.duplicate(true)


static func from_jump_state(jump: JumpState) -> JumpResult:
	return JumpResult.new(
		jump.jump_score, jump.landing_label, jump.trick_call, jump.score_breakdown
	)
