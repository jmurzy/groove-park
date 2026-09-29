## Integrates rider heading, ground forces, and approach-bound movement.
class_name ApproachMotion
extends RefCounted


func turn_toward_input(
	state: RiderState,
	steering_heading: Vector2,
	input: RiderInputFrame,
	tuning: RiderTuning,
	delta: float
) -> void:
	if steering_heading.is_zero_approx():
		return
	var turn_rate := tuning.maximum_turn_rate
	if input.tuck_pressed:
		turn_rate *= tuning.tuck_steering_multiplier
	if input.brake_pressed:
		turn_rate *= tuning.brake_turn_multiplier
	state.kinematics.heading = state.kinematics.heading.rotated(
		clampf(
			state.kinematics.heading.angle_to(steering_heading),
			-turn_rate * delta,
			turn_rate * delta
		)
	)


func apply_forces(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float,
	downhill_held: bool,
	left_braking: bool
) -> bool:
	var gradient := course.route_gradient_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)
	state.kinematics.ground_velocity.x += (
		tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient) * delta
	)
	if downhill_held:
		var pump_scale := clampf(
			1.0 + gradient / maxf(tuning.uphill_pump_cut_gradient, 0.01), 0.0, 1.0
		)
		state.kinematics.ground_velocity += (
			Vector2.RIGHT * tuning.fall_line_acceleration * pump_scale * delta
		)
	var speed := state.kinematics.ground_velocity.length()
	if speed > 0.0 and state.kinematics.ground_velocity.x >= 0.0:
		state.kinematics.ground_velocity = state.kinematics.ground_velocity.move_toward(
			state.kinematics.heading * speed, tuning.steering_response * delta
		)
	var drag := tuning.snow_resistance + tuning.aerodynamic_drag * speed * speed
	drag += tuning.edge_drag * absf(state.kinematics.heading.y)
	if input.tuck_pressed:
		drag *= tuning.tuck_drag_multiplier
	if input.brake_pressed or left_braking:
		drag += tuning.brake_drag
	if not downhill_held:
		drag += tuning.release_carve_drag
	state.kinematics.ground_velocity = state.kinematics.ground_velocity.move_toward(
		Vector2.ZERO, drag * delta
	)
	return state.kinematics.ground_velocity.length() <= 1.0


func move_within_bounds(
	state: RiderState, course: ParkCourse, delta: float, stop_at_edge: Callable
) -> float:
	var next_position := (
		Vector2(state.kinematics.course_progress, state.kinematics.lane_position)
		+ state.kinematics.ground_velocity * delta
	)
	var approach_end := course.route_end_at(state.kinematics.approach_path_position)
	if next_position.x >= approach_end and state.kinematics.ground_velocity.x > 0.0:
		var time_to_endpoint := (
			(approach_end - state.kinematics.course_progress) / state.kinematics.ground_velocity.x
		)
		state.kinematics.course_progress = approach_end
		state.kinematics.lane_position = 0.0
		return maxf(delta - time_to_endpoint, 0.0)
	state.kinematics.course_progress = clampf(
		next_position.x,
		course.route_start_at(state.kinematics.approach_path_position),
		approach_end
	)
	state.kinematics.lane_position = 0.0
	if not is_equal_approx(state.kinematics.course_progress, next_position.x):
		stop_at_edge.call()
	return -1.0
