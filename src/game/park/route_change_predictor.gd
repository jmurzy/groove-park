## Predicts whether a rider can coast through an approach-route transition.
class_name RouteChangePredictor
extends RefCounted

const PATH_SWITCH_SPEED := 2.5
const COAST_PREDICTION_STEP := 1.0 / 60.0


func can_coast_through(
	state: RiderState, requested_path: int, course: ParkCourse, tuning: RiderTuning
) -> bool:
	var remaining_transition_time := (
		absf(float(requested_path) - state.kinematics.approach_path_position) / PATH_SWITCH_SPEED
	)
	var simulated_progress := state.kinematics.course_progress
	var simulated_speed := maxf(state.kinematics.ground_velocity.x, 0.0)
	var simulated_route_position := state.kinematics.approach_path_position
	while remaining_transition_time > 0.0:
		var step := minf(COAST_PREDICTION_STEP, remaining_transition_time)
		simulated_route_position = move_toward(
			simulated_route_position, float(requested_path), PATH_SWITCH_SPEED * step
		)
		var gradient := course.route_gradient_at(simulated_progress, simulated_route_position)
		simulated_speed += (
			tuning.slope_gravity * gradient / sqrt(1.0 + gradient * gradient) * step
		)
		var drag := (
			tuning.snow_resistance
			+ tuning.aerodynamic_drag * simulated_speed * simulated_speed
			+ tuning.release_carve_drag
		)
		simulated_speed = move_toward(simulated_speed, 0.0, drag * step)
		if simulated_speed <= 1.0:
			return false
		simulated_progress += simulated_speed * step
		if simulated_progress >= course.route_end_at(simulated_route_position):
			return false
		remaining_transition_time -= step
	return true
