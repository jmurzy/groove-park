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
	rider_state = RiderState.new()
	rider_state.approach_path_target = 1
	rider_state.approach_path_position = 1.0
	rider_state.course_progress = course.route_start_at(rider_state.approach_path_position)
	rider_state.ground_position = Vector2(rider_state.course_progress, rider_state.lane_position)
	rider_state.vertical_position = course.route_surface_y_at(
		rider_state.course_progress, rider_state.approach_path_position
	)
	_reset_skier_state(course)
	has_started_moving = false


func step(input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	_simulation.step(rider_state, input, course, tuning, delta)
	_simulation.step(skier_state, input, course, tuning, delta)
	if not has_started_moving and rider_state.ground_velocity.length() > 1.0:
		has_started_moving = true


func reset_run(course: ParkCourse) -> void:
	rider_state = RiderState.new()
	rider_state.approach_path_target = 1
	rider_state.approach_path_position = 1.0
	_reset_skier_state(course)
	rider_state.course_progress = course.route_start_at(rider_state.approach_path_position)
	rider_state.ground_position = Vector2(rider_state.course_progress, rider_state.lane_position)
	rider_state.vertical_position = course.route_surface_y_at(
		rider_state.course_progress, rider_state.approach_path_position
	)
	has_started_moving = false


func is_crashed() -> bool:
	return rider_state.landing_outcome == RiderState.LandingOutcome.CRASH


func _reset_skier_state(course: ParkCourse) -> void:
	skier_state = RiderState.new()
	skier_state.approach_path_target = 1
	skier_state.approach_path_position = 1.0
	var center_path := course.approach_paths[1]
	var skier_index := mini(4, center_path.size() - 1)
	skier_state.course_progress = center_path[skier_index].x
	skier_state.ground_position = Vector2(skier_state.course_progress, skier_state.lane_position)
	skier_state.vertical_position = course.route_surface_y_at(
		skier_state.course_progress, skier_state.approach_path_position
	)
