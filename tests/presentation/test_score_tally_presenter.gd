## Headless checks for deterministic, presentation-only score tally timing.
extends SceneTree

const ScoreTallyPresenterScene := preload(
	"res://src/presentation/gameplay/score_tally_presenter.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	_test_count_up_reaches_authoritative_totals_at_multiple_deltas()
	_test_continue_respects_minimum_display_and_completes_once()
	_test_completion_text_uses_the_recorded_jump_number()
	_test_score_ticks_are_rate_limited()
	if _failures.is_empty():
		print("Score-tally presentation checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_count_up_reaches_authoritative_totals_at_multiple_deltas() -> void:
	for delta: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		var tally := ScoreTallyPresenterScene.new()
		tally.start(_round_state(250, 250), _result(250))
		var completed := false
		while not completed:
			completed = tally.update(delta)
		_expect(tally.displayed_jump_score() == 250, "Count-up must reach the jump total.")
		_expect(tally.displayed_round_score() == 500, "Count-up must reach the round total.")


func _test_continue_respects_minimum_display_and_completes_once() -> void:
	var tally := ScoreTallyPresenterScene.new()
	tally.start(_round_state(0, 0), _result(0))
	_expect(
		not tally.request_continue(), "Continue must not skip the minimum readable display time."
	)
	tally.update(1.0)
	_expect(tally.request_continue(), "Continue must accelerate after the minimum display time.")
	var completed := false
	while not completed:
		completed = tally.update(1.0 / 60.0)
	_expect(not tally.update(1.0), "A completed tally must not complete twice.")
	_expect(tally.displayed_jump_score() == 0, "Zero-point outcomes must tally as +0.")


func _test_completion_text_uses_the_recorded_jump_number() -> void:
	var tally := ScoreTallyPresenterScene.new()
	tally.start(_round_state(250, 250), _result(250))
	_expect(
		tally.completion_text() == "JUMP 2 COMPLETE",
		"The tally must identify the recorded jump as complete."
	)


func _test_score_ticks_are_rate_limited() -> void:
	var tally := ScoreTallyPresenterScene.new()
	var ticks: Array[bool] = []
	tally.score_tick_requested.connect(func() -> void: ticks.append(true))
	tally.start(_round_state(250, 250), _result(250))
	var completed := false
	while not completed:
		completed = tally.update(1.0 / 120.0)
	_expect(not ticks.is_empty(), "A changing score tally must emit score ticks.")
	_expect(ticks.size() <= 13, "Score ticks must be capped at ten per real second.")


func _round_state(previous_score: int, current_score: int) -> RoundState:
	var created := RoundState.create(
		RiderKind.SKIER,
		2,
		[_result(previous_score), _result(current_score)],
		RoundState.SessionPhase.JUMP_TALLY
	)
	if not created.is_valid:
		_failures.append("Test fixture must create a tally round state.")
		return null
	return created.value


func _result(score: int) -> JumpResult:
	var snapshot_result := JumpSnapshot.create(
		JumpOutcome.Value.CLEAN, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0
	)
	var result := JumpResult.create(
		snapshot_result.value, JumpScore.new(10, 20, 30, 40, 50, 100, 1000, score)
	)
	if not result.is_valid:
		_failures.append("Test fixture must create a jump result.")
		return null
	return result.value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
