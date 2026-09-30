## Immutable resolved score and contact snapshot for one judged jump.
class_name JumpResult
extends RefCounted

var score: int:
	get:
		return _score
var landing_outcome: int:
	get:
		return _landing_outcome
var trick_call: String:
	get:
		return _trick_call
var score_breakdown: Dictionary:
	get:
		return _score_breakdown.duplicate(true)

var _score: int
var _landing_outcome: int
var _trick_call: String
var _score_breakdown: Dictionary


func _init(
	initial_score: int,
	initial_landing_outcome: int,
	initial_trick_call: String,
	initial_score_breakdown: Dictionary
) -> void:
	_score = initial_score
	_landing_outcome = initial_landing_outcome
	_trick_call = initial_trick_call
	_score_breakdown = initial_score_breakdown.duplicate(true)


static func from_rider_state(rider_state: RiderState) -> JumpResult:
	return JumpResult.new(
		rider_state.jump.jump_score,
		rider_state.run.landing_outcome,
		rider_state.jump.trick_call,
		rider_state.jump.score_breakdown
	)
