## Coordinates launch, flight physics, tricks, and landing outcomes.
class_name FlightSimulation
extends RefCounted

var _integrator := FlightIntegrator.new()
var _tricks := AirTrickController.new()


func begin(state: RiderState, course: ParkCourse, tuning: RiderTuning, route_index: int) -> void:
	var lip_progress := state.kinematics.course_progress
	var tangent := course.route_lip_tangent(route_index)
	var normal := course.route_lip_normal(route_index)
	var surface_speed := state.kinematics.ground_velocity.x / maxf(tangent.x, 0.001)
	var takeoff_velocity := tangent * surface_speed
	if takeoff_velocity.y < 0.0:
		takeoff_velocity.y *= tuning.flight_arc_height_multiplier
	takeoff_velocity.x = minf(takeoff_velocity.x, tuning.maximum_takeoff_course_speed)
	var charge_fraction := 0.0
	if tuning.maximum_compression > 0.0:
		charge_fraction = clampf(
			state.jump.compression_amount / tuning.maximum_compression, 0.0, 1.0
		)
	var pop_impulse := (
		charge_fraction * state.jump.compression_release_quality * tuning.maximum_pop_impulse
	)
	takeoff_velocity += normal * pop_impulse
	var takeoff_speed := takeoff_velocity.length()
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.run.current_surface_id = &"flight"
	state.jump.takeoff_position = Vector2(lip_progress, state.kinematics.vertical_position)
	state.jump.takeoff_velocity = takeoff_velocity
	state.jump.takeoff_pop_impulse = pop_impulse
	state.jump.takeoff_tangent = tangent
	state.jump.takeoff_normal = normal
	state.jump.release_deadline_y = state.kinematics.vertical_position
	state.jump.landing_prep_active = false
	state.kinematics.course_speed = takeoff_velocity.x
	state.kinematics.lane_speed = state.kinematics.ground_velocity.y
	state.kinematics.vertical_speed = takeoff_velocity.y
	state.jump.orientation = tangent.angle()
	_tricks.begin(state, takeoff_speed, tuning)
	if OS.is_debug_build():
		print_verbose(
			(
				"Takeoff speed %.2f | required rotations %d | rotation rate %.2f rad/s"
				% [
					takeoff_speed,
					state.jump.required_rotations,
					state.jump.rotation_rate,
				]
			)
		)
	state.jump.landing_resolved = false


func step(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float,
	landing: LandingSimulation
) -> float:
	state.jump.landing_prep_active = input.landing_prep_pressed
	_tricks.update_input(state, input, tuning)
	var previous_y := state.kinematics.vertical_position
	var result := _integrator.advance(state, course, tuning, delta)
	var airtime_delta := float(result["airtime_delta"])
	_tricks.advance(state, tuning, airtime_delta)
	state.jump.airtime += airtime_delta
	if result.has("contact"):
		_cross_release_deadline(state, previous_y, float(result["contact"]["position"].y))
		landing.resolve_contact(state, result["contact"])
		return float(result["remaining_delta"])
	_cross_release_deadline(state, previous_y, state.kinematics.vertical_position)
	if _integrator.has_overshot_landing(state, course):
		landing.crash(state, tuning)
	elif _integrator.should_bail(state, course):
		landing.begin_bailed_runout(state, course)
	return -1.0


func _cross_release_deadline(state: RiderState, previous_y: float, current_y: float) -> void:
	if state.jump.release_deadline_crossed:
		return
	if state.kinematics.vertical_speed <= 0.0:
		return
	if previous_y < state.jump.release_deadline_y and current_y >= state.jump.release_deadline_y:
		state.jump.release_deadline_crossed = true
		state.jump.grab_active_at_deadline = state.jump.trick_tracker.grab_active
