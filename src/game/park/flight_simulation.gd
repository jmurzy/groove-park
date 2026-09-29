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
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.run.current_surface_id = &"flight"
	state.jump.takeoff_position = Vector2(lip_progress, state.kinematics.vertical_position)
	state.jump.takeoff_velocity = takeoff_velocity
	state.jump.takeoff_course_speed = takeoff_velocity.x
	state.jump.takeoff_lane_speed = state.kinematics.ground_velocity.y
	state.jump.takeoff_vertical_speed = takeoff_velocity.y
	state.jump.takeoff_pop_impulse = pop_impulse
	state.jump.takeoff_tangent = tangent
	state.jump.takeoff_normal = normal
	state.jump.release_deadline_y = state.kinematics.vertical_position
	state.jump.approach_speed = takeoff_velocity.length()
	state.jump.approach_speed_captured = true
	state.kinematics.course_speed = takeoff_velocity.x
	state.kinematics.lane_speed = state.kinematics.ground_velocity.y
	state.kinematics.vertical_speed = takeoff_velocity.y
	state.jump.orientation = tangent.angle()
	_tricks.begin(state, takeoff_velocity.length(), tuning)
	state.jump.landing_resolved = false


func step(
	state: RiderState,
	input: RiderInputFrame,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float,
	landing: LandingSimulation
) -> float:
	_tricks.update_input(state, input, tuning)
	var result := _integrator.advance(state, course, tuning, delta)
	var airtime_delta := float(result["airtime_delta"])
	_tricks.advance(state, tuning, airtime_delta)
	state.jump.airtime += airtime_delta
	if result.has("contact"):
		landing.resolve_contact(state, result["contact"])
		return float(result["remaining_delta"])
	if _integrator.has_overshot_landing(state, course):
		landing.crash(state, tuning)
	elif _integrator.should_abandon(state, course):
		landing.begin_abandoned_runout(state, course)
	return -1.0
