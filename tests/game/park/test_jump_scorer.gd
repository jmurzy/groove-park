## Headless checks for the pure immutable jump scoring contract.
extends SceneTree

const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_identical_snapshots_are_deterministic()
	_test_components_cap_and_round_independently()
	_test_incomplete_rotations_do_not_score()
	_test_clean_scores_more_than_sketchy()
	_test_failure_outcomes_score_zero()
	_test_zero_and_invalid_caps_contribute_zero()
	_test_grab_styles_are_alternatives()
	_test_snapshot_validation()
	_print_representative_breakdowns()
	if _failures.is_empty():
		print("Jump scorer checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_identical_snapshots_are_deterministic() -> void:
	var snapshot := _snapshot(
		JumpOutcome.Value.CLEAN, 450.0, 130.0, 0.75, 1, JumpSnapshot.GrabStyle.TWEAK, 0.4
	)
	var tuning := RiderTuningScene.new()
	var first := JumpScorer.score_jump(snapshot, tuning)
	var second := JumpScorer.score_jump(snapshot, tuning)
	_expect(first.approach_points() == second.approach_points(), "Scores must be deterministic.")
	_expect(
		first.takeoff_points() == second.takeoff_points(), "Takeoff scores must be deterministic."
	)
	_expect(
		first.airtime_points() == second.airtime_points(), "Airtime scores must be deterministic."
	)
	_expect(
		first.rotation_points() == second.rotation_points(),
		"Rotation scores must be deterministic."
	)
	_expect(first.grab_points() == second.grab_points(), "Grab scores must be deterministic.")
	_expect(
		first.style_bonus_points() == second.style_bonus_points(),
		"Style bonuses must be deterministic."
	)
	_expect(first.total() == second.total(), "Totals must be deterministic.")


func _test_components_cap_and_round_independently() -> void:
	var result := JumpScorer.score_jump(
		_snapshot(
			JumpOutcome.Value.CLEAN, 1800.0, 520.0, 3.0, 2, JumpSnapshot.GrabStyle.TWEAK, 1.6
		),
		RiderTuningScene.new()
	)
	_expect(result.approach_points() == 250, "Approach points must cap at the configured maximum.")
	_expect(result.takeoff_points() == 175, "Takeoff points must cap at the configured maximum.")
	_expect(result.airtime_points() == 175, "Airtime points must cap at the configured maximum.")
	_expect(result.rotation_points() == 600, "Completed rotations must use the configured value.")
	_expect(result.grab_points() == 120, "Grab points must cap at the configured duration.")
	_expect(
		result.style_bonus_points() == 25, "A valid tweak grab must earn its fixed style bonus."
	)
	_expect(result.subtotal() == 1345, "Subtotal must equal its integer components.")
	_expect(result.total() == result.subtotal(), "A clean result must retain the full subtotal.")


func _test_incomplete_rotations_do_not_score() -> void:
	var result := JumpScorer.score_jump(
		_snapshot(JumpOutcome.Value.CLEAN, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0),
		RiderTuningScene.new()
	)
	_expect(result.rotation_points() == 0, "Only completed rotations may score.")


func _test_clean_scores_more_than_sketchy() -> void:
	var tuning := RiderTuningScene.new()
	var clean := JumpScorer.score_jump(
		_snapshot(
			JumpOutcome.Value.CLEAN, 450.0, 130.0, 0.75, 1, JumpSnapshot.GrabStyle.TWEAK, 0.4
		),
		tuning
	)
	var sketchy := JumpScorer.score_jump(
		_snapshot(
			JumpOutcome.Value.SKETCHY, 450.0, 130.0, 0.75, 1, JumpSnapshot.GrabStyle.TWEAK, 0.4
		),
		tuning
	)
	_expect(clean.total() == 686, "Clean totals must include the fixed tweak style bonus.")
	_expect(sketchy.total() == 343, "Sketchy totals must apply the configured multiplier once.")
	_expect(
		clean.total() > sketchy.total(), "Clean must score more than sketchy for the same trick."
	)
	_expect(
		sketchy.landing_multiplier_milli() == 500,
		"Sketchy multiplier must be persisted as fixed point."
	)


func _test_failure_outcomes_score_zero() -> void:
	var failure_outcomes: Array[int] = [
		JumpOutcome.Value.LOW_MOMENTUM, JumpOutcome.Value.BAIL, JumpOutcome.Value.CRASH
	]
	for outcome: int in failure_outcomes:
		var result := JumpScorer.score_jump(
			_snapshot(outcome, 900.0, 260.0, 1.5, 2, JumpSnapshot.GrabStyle.TWEAK, 0.8),
			RiderTuningScene.new()
		)
		_expect(result.total() == 0, "Failure outcomes must resolve to zero points.")
		_expect(
			result.landing_multiplier_milli() == 0, "Failure outcomes must have a zero multiplier."
		)


func _test_zero_and_invalid_caps_contribute_zero() -> void:
	var tuning := RiderTuningScene.new()
	tuning.score_approach_speed_cap = 0.0
	tuning.maximum_pop_impulse = -1.0
	tuning.score_airtime_cap = 0.0
	tuning.score_grab_duration_cap = -1.0
	var result := JumpScorer.score_jump(
		_snapshot(
			JumpOutcome.Value.CLEAN, 900.0, 260.0, 1.5, 1, JumpSnapshot.GrabStyle.STANDARD, 0.8
		),
		tuning
	)
	_expect(result.approach_points() == 0, "A zero approach cap must contribute zero.")
	_expect(result.takeoff_points() == 0, "An invalid pop cap must contribute zero.")
	_expect(result.airtime_points() == 0, "A zero airtime cap must contribute zero.")
	_expect(result.grab_points() == 0, "An invalid grab cap must contribute zero.")
	_expect(
		result.total() == result.rotation_points(), "Invalid caps must not affect valid components."
	)


func _test_grab_styles_are_alternatives() -> void:
	var tuning := RiderTuningScene.new()
	var standard := JumpScorer.score_jump(
		_snapshot(JumpOutcome.Value.CLEAN, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.STANDARD, 0.4),
		tuning
	)
	var tweak := JumpScorer.score_jump(
		_snapshot(JumpOutcome.Value.CLEAN, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.TWEAK, 0.4),
		tuning
	)
	_expect(standard.grab_points() == 60, "Standard grabs must score their valid duration.")
	_expect(standard.style_bonus_points() == 0, "Standard grabs must not receive a tweak bonus.")
	_expect(tweak.grab_points() == 60, "Tweak grabs must score the same valid duration.")
	_expect(tweak.style_bonus_points() == 25, "Tweak grabs must receive one fixed style bonus.")
	_expect(
		tweak.total() == standard.total() + 25, "A tweak bonus must not duplicate grab duration."
	)


func _test_snapshot_validation() -> void:
	_expect(
		not (
			JumpSnapshot
			. create(JumpOutcome.Value.NONE, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0)
			. is_valid
		),
		"A score snapshot requires a terminal outcome."
	)
	_expect(
		not (
			JumpSnapshot
			. create(JumpOutcome.Value.CLEAN, -1.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0)
			. is_valid
		),
		"Negative measurements must be rejected."
	)


func _print_representative_breakdowns() -> void:
	var representative_snapshots: Array[JumpSnapshot] = [
		_snapshot(
			JumpOutcome.Value.CLEAN, 450.0, 130.0, 0.75, 1, JumpSnapshot.GrabStyle.TWEAK, 0.4
		),
		_snapshot(
			JumpOutcome.Value.SKETCHY, 900.0, 260.0, 1.5, 2, JumpSnapshot.GrabStyle.STANDARD, 0.8
		),
		_snapshot(JumpOutcome.Value.BAIL, 900.0, 260.0, 1.5, 2, JumpSnapshot.GrabStyle.TWEAK, 0.8),
	]
	for snapshot: JumpSnapshot in representative_snapshots:
		var result := JumpScorer.score_jump(snapshot, RiderTuningScene.new())
		print(
			(
				(
					"Score breakdown: outcome=%d approach=%d takeoff=%d airtime=%d rotation=%d "
					+ "grab=%d style=%d multiplier=%d total=%d"
				)
				% [
					snapshot.outcome(),
					result.approach_points(),
					result.takeoff_points(),
					result.airtime_points(),
					result.rotation_points(),
					result.grab_points(),
					result.style_bonus_points(),
					result.landing_multiplier_milli(),
					result.total(),
				]
			)
		)


func _snapshot(
	outcome: int,
	takeoff_speed: float,
	takeoff_pop_impulse: float,
	airtime: float,
	completed_rotations: int,
	grab_style: int,
	valid_grab_duration: float
) -> JumpSnapshot:
	var created := JumpSnapshot.create(
		outcome,
		takeoff_speed,
		takeoff_pop_impulse,
		airtime,
		completed_rotations,
		grab_style,
		valid_grab_duration
	)
	if not created.is_valid:
		_failures.append("Test fixture must create a valid score snapshot.")
		return null
	return created.value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
