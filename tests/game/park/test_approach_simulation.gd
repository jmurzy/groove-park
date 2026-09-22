## Headless checks for the approach-only rider controller.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const ParkPhasePathScene := preload("res://src/game/park/park_phase_path.gd")
const ShippedParkCourse := preload("res://src/game/park/park_course.tres")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const ApproachSimulationScene := preload("res://src/game/park/approach_simulation.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")

const DELTA := 1.0 / 60.0
var _failures := PackedStringArray()
var _course: ParkCourse
var _simulation: ApproachSimulation
var _tuning: RiderTuning


func _init() -> void:
	_course = _approach_course()
	_simulation = ApproachSimulationScene.new()
	_tuning = RiderTuningScene.new()
	_test_neutral_input_does_not_start_a_run()
	_test_shipped_course_has_an_approach_path()
	_test_downhill_input_starts_a_run()
	_test_releasing_right_carves_to_a_stop()
	_test_left_brakes_without_turning_uphill()
	_test_tuck_builds_more_speed()
	_test_carving_redirects_the_rider()
	_test_braking_reduces_speed()
	_test_approach_boundary_ends_the_run()
	_test_gradient_sign_matches_terrain_pitch()
	_test_uphill_stalls_without_momentum()
	_test_uphill_clears_with_momentum()
	if _failures.is_empty():
		print("Approach rider checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_neutral_input_does_not_start_a_run() -> void:
	var state := _new_state()
	_step(state, Vector2.ZERO)
	_expect(state.ground_velocity.is_zero_approx(), "Neutral input must not start an approach run.")


func _test_shipped_course_has_an_approach_path() -> void:
	_expect(
		ShippedParkCourse.phase_paths.size() == 1,
		"The shipped course must define one approach phase path."
	)


func _test_downhill_input_starts_a_run() -> void:
	var state := _run(Vector2.RIGHT, false, false, 60)
	_expect(state.course_progress > 20.0, "Downhill input should move through the approach.")
	_expect(state.ground_velocity.x > 0.0, "Downhill input should build forward speed.")


func _test_releasing_right_carves_to_a_stop() -> void:
	var state := _run(Vector2.RIGHT, false, false, 60)
	var speed_before_release := state.ground_velocity.length()
	for _tick in 600:
		_step(state, Vector2.ZERO)
	_expect(speed_before_release > 0.0, "Holding Right should create speed before release.")
	_expect(
		state.ground_velocity.is_zero_approx(), "Releasing Right should carve the rider to a stop."
	)


func _test_left_brakes_without_turning_uphill() -> void:
	var centered := _run(Vector2.RIGHT, false, false, 60)
	var left := _run(Vector2.RIGHT, false, false, 60)
	var starting_speed := centered.ground_velocity.length()
	_step(centered, Vector2.ZERO)
	_step(left, Vector2.LEFT)
	var centered_deceleration := starting_speed - centered.ground_velocity.length()
	var left_deceleration := starting_speed - left.ground_velocity.length()
	_expect(
		left_deceleration >= centered_deceleration * 2.0,
		"Left input should brake at least twice as hard as a centered stick."
	)
	_expect(left.heading.x >= 0.0, "Left input must not turn the rider uphill.")


func _test_tuck_builds_more_speed() -> void:
	var neutral := _run(Vector2.RIGHT, false, false, 120)
	var tucked := _run(Vector2.RIGHT, true, false, 120)
	_expect(
		tucked.ground_velocity.length() > neutral.ground_velocity.length(),
		"Tucking should reduce drag."
	)


func _test_carving_redirects_the_rider() -> void:
	var state := _run(Vector2.RIGHT, false, false, 30)
	for _tick in 60:
		_step(state, Vector2.DOWN, false, true)
	_expect(state.lane_position > 0.0, "Carving should move the rider across the approach.")


func _test_braking_reduces_speed() -> void:
	var coasting := _run(Vector2.RIGHT, false, false, 120)
	var braking := _run(Vector2.RIGHT, false, false, 120, true)
	_expect(
		braking.ground_velocity.length() < coasting.ground_velocity.length(),
		"Braking should reduce approach speed."
	)


func _test_approach_boundary_ends_the_run() -> void:
	var state := _new_state()
	state.course_progress = 2995.0
	state.ground_velocity = Vector2(600.0, 0.0)
	state.has_ground_intent = true
	_step(state, Vector2.RIGHT)
	_expect(
		is_equal_approx(state.course_progress, 3000.0),
		"The rider should stop at the approach edge."
	)
	_expect(state.ground_velocity.is_zero_approx(), "Leaving the approach should clear velocity.")


func _run(heading: Vector2, tuck: bool, edge: bool, ticks: int, brake: bool = false) -> RiderState:
	var state := _new_state()
	for _tick in ticks:
		_step(state, heading, tuck, edge, brake)
	return state


func _step(
	state: RiderState, heading: Vector2, tuck := false, edge := false, brake := false
) -> void:
	_step_on(state, _course, heading, tuck, edge, brake)


func _step_on(
	state: RiderState,
	course: ParkCourse,
	heading: Vector2,
	tuck := false,
	edge := false,
	brake := false
) -> void:
	var input := RiderInputFrameScene.new()
	input.heading = heading
	input.tuck_pressed = tuck
	input.edge_pressed = edge
	input.brake_pressed = brake
	_simulation.step(state, input, course, _tuning, DELTA)


func _new_state() -> RiderState:
	var state := RiderStateScene.new()
	state.course_progress = 20.0
	state.vertical_position = _course.surface_y_at(state.course_progress)
	return state


func _approach_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.approach_rider_path = PackedVector2Array([Vector2(0, 0), Vector2(3000, 1500)])
	course.lane_min = -100.0
	course.lane_max = 100.0
	var approach := ParkPhasePathScene.new()
	approach.id = &"approach"
	approach.path_points = PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)])
	course.phase_paths = [approach]
	return course


func _roller_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.approach_rider_path = PackedVector2Array(
		[Vector2(0, 400), Vector2(400, 560), Vector2(600, 360), Vector2(1000, 520)]
	)
	course.lane_min = -100.0
	course.lane_max = 100.0
	var approach := ParkPhasePathScene.new()
	approach.id = &"approach"
	approach.path_points = PackedVector2Array([Vector2(0, 0), Vector2(1000, 0)])
	course.phase_paths = [approach]
	return course


func _test_gradient_sign_matches_terrain_pitch() -> void:
	var roller := _roller_course()
	_expect(_course.gradient_at(500.0) > 0.0, "Downhill pitch should read a positive gradient.")
	_expect(roller.gradient_at(500.0) < 0.0, "Uphill pitch should read a negative gradient.")


func _test_uphill_stalls_without_momentum() -> void:
	var roller := _roller_course()
	var state := RiderStateScene.new()
	state.course_progress = 380.0
	state.ground_velocity = Vector2(120.0, 0.0)
	state.has_ground_intent = true
	for _tick in 300:
		_step_on(state, roller, Vector2.RIGHT)
	_expect(
		state.course_progress < 590.0,
		"Slow uphill entries must stall before the crest instead of creeping over."
	)


func _test_uphill_clears_with_momentum() -> void:
	var roller := _roller_course()
	var state := RiderStateScene.new()
	state.course_progress = 100.0
	state.ground_velocity = Vector2(700.0, 0.0)
	state.has_ground_intent = true
	for _tick in 300:
		_step_on(state, roller, Vector2.RIGHT)
		if state.course_progress >= 620.0:
			break
	_expect(state.course_progress >= 600.0, "Fast entries should carry over the uphill crest.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
