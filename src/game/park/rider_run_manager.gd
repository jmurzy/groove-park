## Steps the park run for both riders (snowboarder primary + skier ghost).
## Owns the two RiderStates, the shared RiderSimulation, and run lifecycle:
## setup / step / restart / spawn placement. Presentation (views, HUD, camera)
## stays in GameplayScreen. Example: `run.step(input, course, tuning, delta)`.
class_name RiderRunManager
extends RefCounted

var rider_state: RiderState
var skier_state: RiderState
var has_started_moving := false

var _simulation: RiderSimulation


func setup(course: ParkCourse) -> void:
	_simulation = RiderSimulation.new()
	rider_state = _spawn_at_route(course, course.default_route_index())
	_reset_skier_state(course)
	has_started_moving = false


func step(input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	_simulation.step(rider_state, input, course, tuning, delta)
	_simulation.step(skier_state, input, course, tuning, delta)
	if not has_started_moving and rider_state.kinematics.ground_velocity.length() > 1.0:
		has_started_moving = true


func reset_run(course: ParkCourse) -> void:
	rider_state = _spawn_at_route(course, course.default_route_index())
	_reset_skier_state(course)
	has_started_moving = false


func is_crashed() -> bool:
	return rider_state.run.landing_outcome == RiderRunState.LandingOutcome.CRASH


func is_complete() -> bool:
	return rider_state.run.run_phase == RiderRunState.RunPhase.COMPLETE


func _reset_skier_state(course: ParkCourse) -> void:
	var route_index := course.default_route_index()
	skier_state = _spawn_at_route(course, route_index)
	var center_path := course.route_at(route_index).approach_path
	var skier_index := mini(4, center_path.size() - 1)
	skier_state.kinematics.course_progress = center_path[skier_index].x
	_sync_spawn_position(skier_state, course)


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
