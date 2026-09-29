## Steps the park run for its rider.
## Owns the RiderState, the shared RiderSimulation, and run lifecycle:
## setup / step / restart / spawn placement. Presentation (views, HUD, camera)
## stays in GameplayScreen. Example: `run.step(input, course, tuning, delta)`.
class_name RiderRunManager
extends RefCounted

var rider_state: RiderState
var has_started_moving := false

var _simulation: RiderSimulation


func setup(course: ParkCourse) -> void:
	_simulation = RiderSimulation.new()
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false


func step(input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	_simulation.step(rider_state, input, course, tuning, delta)
	if not has_started_moving and rider_state.kinematics.ground_velocity.length() > 1.0:
		has_started_moving = true


func reset_run(course: ParkCourse) -> void:
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false


func is_crashed() -> bool:
	return rider_state.run.landing_outcome == RiderRunState.LandingOutcome.CRASH


func is_complete() -> bool:
	return rider_state.run.run_phase == RiderRunState.RunPhase.COMPLETE


func _spawn_at_route(course: ParkCourse, route_index: int) -> RiderState:
	var state := RiderState.new()
	state.kinematics.approach_path_target = route_index
	state.kinematics.approach_path_position = float(route_index)
	state.kinematics.course_progress = course.route_start_at(
		state.kinematics.approach_path_position
	)
	_sync_spawn_position(state, course)
	return state


func _sync_spawn_position(state: RiderState, course: ParkCourse) -> void:
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.vertical_position = course.route_surface_y_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)
