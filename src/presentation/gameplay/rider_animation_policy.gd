## Pure mapping from rider state and visual definition to sprite playback choices.
class_name RiderAnimationPolicy
extends RefCounted

const GLIDE_REFERENCE_SPEED_MPH := 25.0


static func animation_for_state(state: RiderState, definition: RiderVisualDefinition) -> StringName:
	if state.run.run_phase == RiderRunState.RunPhase.FLIGHT:
		if state.jump.landing_prep_active:
			return &"landing_prep"
		if state.jump.grab_reach_active:
			return &"grab_reach"
		if state.jump.tweak_active:
			return &"grab_tweak"
		if state.jump.trick_tracker.grab_active:
			return &"grab_hold"
		if state.kinematics.vertical_speed < 0.0:
			return &"takeoff_extension"
		return &"neutral_air"
	if state.run.run_phase == RiderRunState.RunPhase.LANDING:
		return landing_animation_for_state(state)
	if state.jump.compression_active:
		return &"compression"
	if state.run.tuck_active:
		return &"tuck"
	if state.run.edge_active or state.run.brake_active:
		return (
			definition.carve_a_animation
			if state.kinematics.heading.y < 0.0
			else definition.carve_b_animation
		)
	return &"neutral_glide"


static func landing_animation_for_state(state: RiderState) -> StringName:
	if state.run.landing_outcome == RiderRunState.LandingOutcome.CRASH:
		return &"crash"
	if state.run.landing_outcome == RiderRunState.LandingOutcome.SKETCHY:
		return &"sketchy_recovery"
	if state.run.landing_outcome == RiderRunState.LandingOutcome.ABANDON:
		return &"deep_landing"
	return &"celebration"


static func spin_is_visible(state: RiderState) -> bool:
	return (
		state.run.run_phase == RiderRunState.RunPhase.FLIGHT
		and state.jump.spin_direction != 0
		and (
			state.jump.rotation_incomplete
			or state.jump.rotation_gesture_phase != JumpState.RotationGesturePhase.WAITING_DIRECTION
			or is_equal_approx(state.jump.spin_progress, TAU)
		)
	)


static func spin_animation_for_state(
	state: RiderState, definition: RiderVisualDefinition
) -> StringName:
	if state.jump.spin_grab_tweak:
		return (
			definition.spin_tweak_negative
			if state.jump.spin_direction < 0
			else definition.spin_tweak_positive
		)
	return (
		definition.spin_regular_negative
		if state.jump.spin_direction < 0
		else definition.spin_regular_positive
	)


static func spin_frame(progress: float) -> int:
	var step := mini(roundi(clampf(progress / TAU, 0.0, 1.0) * 8.0), 8)
	return 0 if step >= 8 else step


static func neutral_glide_speed_scale(world_speed: float) -> float:
	return neutral_glide_speed_scale_for_mph(float(GameConstants.speed_to_mph(world_speed)))


static func neutral_glide_speed_scale_for_mph(speed_mph: float) -> float:
	return speed_mph / GLIDE_REFERENCE_SPEED_MPH
