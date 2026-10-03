## Headless checks for immutable round and jump-result contracts.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_new_round_defaults()
	_test_round_score_is_derived_from_immutable_results()
	_test_exposed_results_cannot_mutate_the_round()
	_test_invalid_round_data_is_rejected()
	_test_invalid_jump_result_is_rejected()
	if _failures.is_empty():
		print("Round-state checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_new_round_defaults() -> void:
	var created := RoundState.create(RiderKind.SKIER)
	_expect(created.is_valid, "A valid rider must create a round.")
	var round: RoundState = created.value
	_expect(round.current_jump_number() == 1, "A new round must start on jump 1.")
	_expect(round.round_score() == 0, "A new round must start with zero score.")
	_expect(round.jump_results().is_empty(), "A new round must not have results.")
	_expect(
		round.session_phase() == RoundState.SessionPhase.RIDER_SELECT,
		"A new round must begin at rider select."
	)


func _test_round_score_is_derived_from_immutable_results() -> void:
	var clean := _jump_result(JumpOutcome.Value.CLEAN, 250)
	var sketchy := _jump_result(JumpOutcome.Value.SKETCHY, 75)
	var created := RoundState.create(RiderKind.SNOWBOARDER, 2, [clean, sketchy])
	_expect(created.is_valid, "A round with valid jump results must be created.")
	var round: RoundState = created.value
	_expect(round.round_score() == 325, "Round score must equal the recorded result total.")


func _test_exposed_results_cannot_mutate_the_round() -> void:
	var created := RoundState.create(
		RiderKind.SKIER, 1, [_jump_result(JumpOutcome.Value.LOW_MOMENTUM, 0)]
	)
	var round: RoundState = created.value
	var exposed_results := round.jump_results()
	exposed_results.clear()
	_expect(
		round.jump_results().size() == 1,
		"Mutating an exposed result collection must not mutate the round."
	)


func _test_invalid_round_data_is_rejected() -> void:
	_expect(not RoundState.create(&"sledder").is_valid, "An invalid rider kind must be rejected.")
	_expect(
		not RoundState.create(RiderKind.SKIER, 0).is_valid,
		"Jump numbers below one must be rejected."
	)
	_expect(
		not RoundState.create(RiderKind.SKIER, 4).is_valid,
		"Jump numbers above three must be rejected."
	)
	var results: Array[JumpResult] = []
	for jump_number in 4:
		results.append(_jump_result(JumpOutcome.Value.CLEAN, jump_number))
	_expect(
		not RoundState.create(RiderKind.SKIER, 3, results).is_valid,
		"Rounds with more than three results must be rejected."
	)


func _test_invalid_jump_result_is_rejected() -> void:
	_expect(
		not JumpResult.create(null, JumpScore.new(0, 0, 0, 0, 0, 0, 0, 0)).is_valid,
		"A jump result requires a frozen snapshot."
	)
	_expect(
		not (
			JumpResult
			. create(_snapshot(JumpOutcome.Value.CLEAN), JumpScore.new(0, 0, 0, 0, 0, 0, 0, -1))
			. is_valid
		),
		"A jump result cannot have a negative score."
	)


func _jump_result(outcome: int, score: int) -> JumpResult:
	var created := JumpResult.create(
		_snapshot(outcome), JumpScore.new(0, 0, 0, 0, 0, 0, 1000, score)
	)
	if not created.is_valid:
		_failures.append("Test fixture must create a valid jump result.")
		return null
	return created.value


func _snapshot(outcome: int) -> JumpSnapshot:
	var created := JumpSnapshot.create(outcome, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0)
	if not created.is_valid:
		_failures.append("Test fixture must create a valid score snapshot.")
		return null
	return created.value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
