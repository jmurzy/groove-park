## Pure scoring formula for frozen terminal jump measurements.
class_name JumpScorer
extends RefCounted


static func score_jump(snapshot: JumpSnapshot, tuning: RiderTuning) -> JumpScore:
	var approach_points := _capped_ratio_points(
		snapshot.takeoff_speed(), tuning.score_approach_speed_cap, tuning.score_approach_max
	)
	var takeoff_points := _capped_ratio_points(
		snapshot.takeoff_pop_impulse(), tuning.maximum_pop_impulse, tuning.score_takeoff_max
	)
	var airtime_points := _capped_ratio_points(
		snapshot.airtime(), tuning.score_airtime_cap, tuning.score_airtime_max
	)
	var rotation_points := (
		snapshot.completed_rotations() * maxi(0, tuning.score_rotation_per_rotation)
	)
	var grab_points := _duration_points(
		snapshot.valid_grab_duration(), tuning.score_grab_duration_cap, tuning.score_grab_per_second
	)
	var style_bonus_points := _style_bonus_points(snapshot, tuning)
	var landing_multiplier := _landing_multiplier(snapshot.outcome(), tuning)
	var subtotal := (
		approach_points
		+ takeoff_points
		+ airtime_points
		+ rotation_points
		+ grab_points
		+ style_bonus_points
	)
	return JumpScore.new(
		approach_points,
		takeoff_points,
		airtime_points,
		rotation_points,
		grab_points,
		style_bonus_points,
		roundi(landing_multiplier * 1000.0),
		roundi(subtotal * landing_multiplier)
	)


static func _capped_ratio_points(value: float, cap: float, maximum_points: int) -> int:
	if cap <= 0.0 or maximum_points <= 0:
		return 0
	return roundi(clampf(value / cap, 0.0, 1.0) * maximum_points)


static func _duration_points(duration: float, cap: float, points_per_second: int) -> int:
	if cap <= 0.0 or points_per_second <= 0:
		return 0
	return roundi(minf(duration, cap) * points_per_second)


static func _style_bonus_points(snapshot: JumpSnapshot, tuning: RiderTuning) -> int:
	if (
		snapshot.grab_style() != JumpSnapshot.GrabStyle.TWEAK
		or snapshot.valid_grab_duration() <= 0.0
	):
		return 0
	return maxi(0, tuning.score_tweak_style_bonus)


static func _landing_multiplier(outcome: int, tuning: RiderTuning) -> float:
	match outcome:
		JumpOutcome.Value.CLEAN:
			return 1.0
		JumpOutcome.Value.SKETCHY:
			return clampf(tuning.score_sketchy_landing_multiplier, 0.0, 1.0)
		_:
			return 0.0
