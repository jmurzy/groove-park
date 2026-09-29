## Owns approach compression charge and release-quality state.
class_name CompressionController
extends RefCounted


func update(
	state: RiderState,
	input: RiderInputFrame,
	approach_end: float,
	tuning: RiderTuning,
	delta: float
) -> void:
	var distance_to_lip := maxf(approach_end - state.kinematics.course_progress, 0.0)
	var in_window := distance_to_lip <= maxf(tuning.compression_window_distance, 0.0)
	if input.pop_pressed and in_window and not state.jump.compression_active:
		state.jump.compression_active = true
		if input.pop_just_pressed:
			state.jump.compression_amount = 0.0
			state.jump.compression_release_progress = -1.0
			state.jump.compression_release_quality = 0.0
			state.jump.compression_auto_released = false
	if state.jump.compression_active and input.pop_pressed:
		state.jump.compression_amount = minf(
			state.jump.compression_amount + tuning.compression_rate * delta,
			maxf(tuning.maximum_compression, 0.0)
		)
	if state.jump.compression_active and input.pop_just_released:
		release(state, approach_end, tuning, state.kinematics.course_progress)


func release(
	state: RiderState, approach_end: float, tuning: RiderTuning, release_progress: float
) -> void:
	state.jump.compression_active = false
	state.jump.compression_auto_released = false
	state.jump.compression_release_progress = release_progress
	var window_distance := maxf(tuning.compression_window_distance, 0.0)
	if is_zero_approx(window_distance):
		state.jump.compression_release_quality = (
			1.0 if is_equal_approx(release_progress, approach_end) else 0.0
		)
		return
	state.jump.compression_release_quality = clampf(
		1.0 - (approach_end - release_progress) / window_distance, 0.0, 1.0
	)
