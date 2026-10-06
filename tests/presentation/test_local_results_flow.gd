## Headless checks for deterministic local results presentation.
extends SceneTree

const RoundResultsScreenScene := preload("res://src/presentation/results/round_results_screen.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_result_rows_preserve_round_data()
	_test_crash_round_displays_its_single_result()
	_test_completed_round_displays_all_three_results()
	if _failures.is_empty():
		print("Local results-flow checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_result_rows_preserve_round_data() -> void:
	var screen := RoundResultsScreenScene.new()
	screen.show_round(_round_state(), Leaderboard.new())
	_expect(
		(
			screen.result_rows()
			== PackedStringArray(["JUMP 1    CLEAN          +100", "JUMP 2    SKETCHY        +50"])
		),
		"Results must list every recorded jump outcome and score in order."
	)
	screen.free()


func _test_crash_round_displays_its_single_result() -> void:
	var screen := RoundResultsScreenScene.new()
	screen.show_round(_round_state([_result(JumpOutcome.Value.CRASH, 0)]), Leaderboard.new())
	_expect(
		screen.result_rows() == PackedStringArray(["JUMP 1    CRASH          +0"]),
		"Crash-ended rounds must display their one recorded result."
	)
	screen.free()


func _test_completed_round_displays_all_three_results() -> void:
	var screen := RoundResultsScreenScene.new()
	(
		screen
		. show_round(
			_round_state(
				[
					_result(JumpOutcome.Value.CLEAN, 100),
					_result(JumpOutcome.Value.SKETCHY, 50),
					_result(JumpOutcome.Value.BAIL, 0),
				]
			),
			Leaderboard.new()
		)
	)
	_expect(
		(
			screen.result_rows()
			== PackedStringArray(
				[
					"JUMP 1    CLEAN          +100",
					"JUMP 2    SKETCHY        +50",
					"JUMP 3    BAIL           +0",
				]
			)
		),
		"Completed rounds must display all three recorded results in order."
	)
	screen.free()


func _round_state(results: Array[JumpResult] = []) -> RoundState:
	if results.is_empty():
		results = [_result(JumpOutcome.Value.CLEAN, 100), _result(JumpOutcome.Value.SKETCHY, 50)]
	var created := RoundState.create(
		RiderKind.SKIER, results.size(), results, RoundState.SessionPhase.ROUND_RESULTS
	)
	if not created.is_valid:
		_failures.append("Test fixture must create results round state.")
		return null
	return created.value


func _result(outcome: int, score: int) -> JumpResult:
	var snapshot := JumpSnapshot.create(outcome, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0)
	var result := JumpResult.create(snapshot.value, JumpScore.new(0, 0, 0, 0, 0, 0, 1000, score))
	if not result.is_valid:
		_failures.append("Test fixture must create a jump result.")
		return null
	return result.value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
