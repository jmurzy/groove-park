## Headless checks for held standard and tweak grabs.
extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")

const DELTA := 1.0 / 60.0
var _failures := PackedStringArray()
var _course: ParkCourse
var _simulation: RiderSimulation
var _tuning: RiderTuning


func _init() -> void:
	_course = _test_course()
	_simulation = RiderSimulationScene.new()
	_tuning = RiderTuningScene.new()
	_test_standard_grab_reaches_holds_and_releases()
	_test_tweak_grab_holds_and_releases()
	_test_approach_buttons_do_not_start_takeoff_grabs()
	_test_takeoff_resets_grab_state()
	_test_grounded_buttons_keep_approach_roles()
	if _failures.is_empty():
		print("Rider grab checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_standard_grab_reaches_holds_and_releases() -> void:
	var state := _flight_state()
	var press := RiderInputFrameScene.new()
	press.grab_pressed = true
	press.grab_just_pressed = true
	_simulation.step(state, press, _course, _tuning, DELTA)
	_expect(state.trick_tracker.grab_active, "A fresh airborne A press must start a grab.")
	_expect(state.grab_reach_active, "A grab must begin with its reach presentation.")
	var hold := RiderInputFrameScene.new()
	hold.grab_pressed = true
	for _tick in 20:
		_simulation.step(state, hold, _course, _tuning, DELTA)
	_expect(state.trick_tracker.grab_active, "Holding A must keep the standard grab active.")
	_expect(not state.grab_reach_active, "The A grab must transition from reach to hold.")
	_simulation.step(state, RiderInputFrameScene.new(), _course, _tuning, DELTA)
	_expect(not state.trick_tracker.grab_active, "Releasing A must end the standard grab.")


func _test_tweak_grab_holds_and_releases() -> void:
	var state := _flight_state()
	var press := RiderInputFrameScene.new()
	press.tweak_pressed = true
	press.tweak_just_pressed = true
	_simulation.step(state, press, _course, _tuning, DELTA)
	_expect(state.trick_tracker.grab_active, "A fresh airborne B press must start a grab.")
	_expect(state.tweak_active, "Holding B must select the tweak-grab presentation.")
	var hold := RiderInputFrameScene.new()
	hold.tweak_pressed = true
	_simulation.step(state, hold, _course, _tuning, DELTA)
	_expect(state.tweak_active, "Holding B must keep the tweak grab active.")
	_simulation.step(state, RiderInputFrameScene.new(), _course, _tuning, DELTA)
	_expect(
		not state.trick_tracker.grab_active and not state.tweak_active,
		"Releasing B must end the tweak grab."
	)


func _test_approach_buttons_do_not_start_takeoff_grabs() -> void:
	for use_tweak: bool in [false, true]:
		var state := _approach_state()
		var input := RiderInputFrameScene.new()
		input.heading = Vector2.RIGHT
		if use_tweak:
			input.brake_pressed = true
			input.tweak_pressed = true
			input.tweak_just_pressed = true
		else:
			input.tuck_pressed = true
			input.grab_pressed = true
			input.grab_just_pressed = true
		_simulation.step(state, input, _course, _tuning, DELTA)
		_expect(
			state.run_phase == RiderState.RunPhase.FLIGHT,
			"An approach button test must cross into flight."
		)
		_expect(
			not state.trick_tracker.grab_active,
			"A button pressed before takeoff must not leak into a flight grab."
		)


func _test_takeoff_resets_grab_state() -> void:
	var state := _approach_state()
	state.trick_tracker.start_grab()
	state.grab_reach_active = true
	state.tweak_active = true
	state.grab_started_airtime = 1.0
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(
		(
			not state.trick_tracker.grab_active
			and not state.grab_reach_active
			and not state.tweak_active
			and state.grab_started_airtime < 0.0
		),
		"Takeoff must reset all transient grab state."
	)


func _test_grounded_buttons_keep_approach_roles() -> void:
	var tuck_state := RiderStateScene.new()
	var tuck_input := RiderInputFrameScene.new()
	tuck_input.tuck_pressed = true
	tuck_input.grab_pressed = true
	_simulation.step(tuck_state, tuck_input, _course, _tuning, DELTA)
	_expect(tuck_state.tuck_active, "Grounded A must retain its tuck behavior.")
	_expect(not tuck_state.trick_tracker.grab_active, "Grounded A must not start a grab.")
	var brake_state := RiderStateScene.new()
	var brake_input := RiderInputFrameScene.new()
	brake_input.brake_pressed = true
	brake_input.tweak_pressed = true
	_simulation.step(brake_state, brake_input, _course, _tuning, DELTA)
	_expect(brake_state.brake_active, "Grounded B must retain its brake behavior.")
	_expect(not brake_state.trick_tracker.grab_active, "Grounded B must not start a grab.")


func _approach_state() -> RiderState:
	var state := RiderStateScene.new()
	state.course_progress = 2995.0
	state.ground_velocity = Vector2(600.0, 0.0)
	state.has_ground_intent = true
	return state


func _flight_state() -> RiderState:
	var state := RiderStateScene.new()
	state.run_phase = RiderState.RunPhase.FLIGHT
	state.active_route_index = 1
	state.course_progress = 3000.0
	state.vertical_position = 100.0
	state.ground_position = Vector2(state.course_progress, 0.0)
	state.course_speed = 100.0
	state.vertical_speed = -50.0
	state.takeoff_velocity = Vector2(state.course_speed, state.vertical_speed)
	state.orientation = 0.25
	return state


func _test_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	var approach := PackedVector2Array([Vector2(0, 0), Vector2(3000, 1500)])
	course.approach_paths = [approach, approach, approach]
	var flight_landing := PackedVector2Array([Vector2(3100, 1700), Vector2(6000, 2000)])
	var ground_runout := PackedVector2Array([Vector2(3000, 1500), Vector2(6000, 1800)])
	course.landing_paths = [flight_landing, flight_landing, ground_runout]
	course.flight_abandon_y = 1800.0
	return course


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
