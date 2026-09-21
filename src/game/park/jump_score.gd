## Converts a resolved jump into a score breakdown (approach, takeoff, airtime,
## rotation, grab, tweak) scaled by landing quality. Crashes score zero.
## Example: `JumpScore.evaluate(state, state.landing_quality, tuning)["total"]`.
class_name JumpScore
extends RefCounted


static func evaluate(state: RiderState, landing_quality: float, tuning: RiderTuning) -> Dictionary:
	if state.landing_label == "CRASH":
		return {
			"approach": 0,
			"takeoff": 0,
			"airtime": 0,
			"rotation": 0,
			"grab": 0,
			"tweak": 0,
			"base": 0,
			"landing_multiplier": 0.0,
			"total": 0,
		}

	var approach := roundi(
		(
			clampf(state.approach_speed / tuning.score_approach_speed_cap, 0.0, 1.0)
			* tuning.score_approach_max
		)
	)
	var takeoff := roundi(
		state.compression_release_quality * state.compression_amount * tuning.score_takeoff_max
	)
	var airtime := roundi(
		clampf(state.airtime / tuning.score_airtime_cap, 0.0, 1.0) * tuning.score_airtime_max
	)
	var rotation := state.trick_tracker.completed_rotations * tuning.score_rotation_per_rotation
	var grab := roundi(
		(
			minf(state.trick_tracker.valid_grab_duration, tuning.score_grab_duration_cap)
			* tuning.score_grab_per_second
		)
	)
	var tweak := roundi(
		(
			minf(state.trick_tracker.tweak_duration, tuning.score_tweak_duration_cap)
			* tuning.score_tweak_per_second
		)
	)
	var base := approach + takeoff + airtime + rotation + grab + tweak
	var landing_multiplier := lerpf(
		tuning.score_minimum_landing_multiplier, 1.0, clampf(landing_quality, 0.0, 1.0)
	)
	return {
		"approach": approach,
		"takeoff": takeoff,
		"airtime": airtime,
		"rotation": rotation,
		"grab": grab,
		"tweak": tweak,
		"base": base,
		"landing_multiplier": landing_multiplier,
		"total": roundi(base * landing_multiplier),
	}
