## Dispatches the authoritative rider simulation to the current run phase.
class_name RiderSimulation
extends RefCounted

var _approach := ApproachSimulation.new()
var _flight := FlightSimulation.new()
var _landing := LandingSimulation.new()


func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	match state.run.run_phase:
		RiderRunState.RunPhase.APPROACH:
			_step_approach(state, input, course, tuning, delta)
		RiderRunState.RunPhase.FLIGHT:
			_step_flight(state, input, course, tuning, delta)
		RiderRunState.RunPhase.LANDING:
			_step_landing(state, course, tuning, delta)


func _step_approach(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var remaining_delta := _approach.step(state, input, course, tuning, delta)
	if remaining_delta < 0.0:
		return
	var route_index := _approach.cross_endpoint(state, course, tuning)
	if course.route_at(route_index).kind == ParkRoute.Kind.FLIGHT:
		_flight.begin(state, course, tuning, route_index)
		if remaining_delta > 0.0:
			# Approach-held buttons cannot become grabs during the takeoff tick.
			_step_flight(state, RiderInputFrame.new(), course, tuning, remaining_delta)
	else:
		_landing.begin_ground_runout(state, course)
		if remaining_delta > 0.0:
			_landing.step(state, course, tuning, remaining_delta)


func _step_flight(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var remaining_delta := _flight.step(state, input, course, tuning, delta, _landing)
	if state.run.run_phase == RiderRunState.RunPhase.LANDING and remaining_delta > 0.0:
		_step_landing(state, course, tuning, remaining_delta)


func _step_landing(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	_landing.step(state, course, tuning, delta)
