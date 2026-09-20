extends SceneTree

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const JumpJudgeScene := preload("res://src/game/park/jump_judge.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")

const DELTA := 1.0 / 60.0
var _trace_paths: PackedStringArray = [
	"res://tests/game/park/traces/straight_tuck.json",
	"res://tests/game/park/traces/shallow_carve.json",
	"res://tests/game/park/traces/hard_brake.json",
	"res://tests/game/park/traces/forward_rotation.json",
	"res://tests/game/park/traces/backward_rotation.json",
]

var _failures := PackedStringArray()
var _course: ParkCourse
var _simulation: RiderSimulation
var _tuning: RiderTuning


func _init() -> void:
	_course = ParkCourseScene.new()
	_course.terrain_points = PackedVector2Array([Vector2(0, 0), Vector2(10000, 0)])
	_course.lane_min = -360.0
	_course.lane_max = 360.0
	_simulation = RiderSimulationScene.new()
	_tuning = RiderTuningScene.new()
	_test_straight_tuck_is_faster()
	_test_traverse_is_slower_than_straight()
	_test_strong_edge_turns_faster_and_costs_speed()
	_test_brake_costs_more_speed_than_strong_edge()
	_test_tuck_reduces_turn_authority()
	_test_neutral_input_preserves_momentum()
	_test_neutral_input_does_not_start_a_run()
	_test_lane_boundary_does_not_reflect_velocity()
	_test_baseline_traces_replay()
	_test_lip_crossing_transitions_to_airborne()
	_test_valid_pop_increases_upward_takeoff_speed()
	_test_held_pop_does_not_add_an_impulse()
	_test_air_input_does_not_change_translation()
	_test_faster_takeoff_travels_farther()
	_test_torque_changes_angular_velocity()
	_test_reversing_torque_reduces_existing_spin()
	_test_body_shape_changes_rotation_rate()
	_test_landing_prep_damps_rotation()
	_test_swept_contact_resolves_once()
	_test_landing_labels_and_continuous_quality()
	_test_terrain_seam_returns_first_contact()
	if _failures.is_empty():
		print("RiderSimulation checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_straight_tuck_is_faster() -> void:
	var untucked := _run(Vector2.RIGHT, false, false, false, 120)
	var tucked := _run(Vector2.RIGHT, true, false, false, 120)
	_expect(
		tucked.ground_velocity.length() > untucked.ground_velocity.length(),
		"Tuck should increase straight-line speed."
	)


func _test_traverse_is_slower_than_straight() -> void:
	var straight := _run(Vector2.RIGHT, false, false, false, 120)
	var traverse := _run(Vector2.DOWN, false, false, false, 120)
	_expect(
		traverse.course_progress < straight.course_progress,
		"Traverse should cover less downhill progress."
	)


func _test_strong_edge_turns_faster_and_costs_speed() -> void:
	var ordinary := _turn_from_speed(false, false)
	var strong_edge := _turn_from_speed(true, false)
	_expect(
		absf(strong_edge.heading.angle()) > absf(ordinary.heading.angle()),
		"Strong edge should turn faster than an ordinary carve."
	)
	_expect(
		strong_edge.ground_velocity.length() < ordinary.ground_velocity.length(),
		"Strong edge should lose more speed than an ordinary carve."
	)


func _test_brake_costs_more_speed_than_strong_edge() -> void:
	var strong_edge := _turn_from_speed(true, false)
	var brake := _turn_from_speed(false, true)
	_expect(
		brake.ground_velocity.length() < strong_edge.ground_velocity.length(),
		"Brake should lose more speed than strong edge."
	)


func _test_tuck_reduces_turn_authority() -> void:
	var normal := _turn_from_speed(false, false)
	var tucked := _turn_from_speed(false, false, true)
	_expect(
		absf(tucked.heading.angle()) < absf(normal.heading.angle()),
		"Tuck should reduce turn authority."
	)


func _test_neutral_input_preserves_momentum() -> void:
	var state := _new_state()
	state.ground_velocity = Vector2(500, 0)
	state.has_ground_intent = true
	_step(state, Vector2.ZERO, false, false, false)
	_expect(
		state.ground_velocity.length() > 0.0, "Neutral input should not instantly stop the rider."
	)


func _test_neutral_input_does_not_start_a_run() -> void:
	var state := _new_state()
	_step(state, Vector2.ZERO, false, false, false)
	_expect(
		is_zero_approx(state.ground_velocity.length()),
		"Neutral input should not start a run before the player chooses a line."
	)


func _test_lane_boundary_does_not_reflect_velocity() -> void:
	var state := _new_state()
	state.lane_position = _course.lane_max - 1.0
	state.ground_velocity = Vector2(300, 500)
	state.has_ground_intent = true
	_step(state, Vector2.DOWN, false, false, false)
	_expect(state.lane_speed > 0.0, "Soft lane containment should not reflect lane velocity.")


func _test_baseline_traces_replay() -> void:
	for trace_path in _trace_paths:
		var trace := _load_trace(trace_path)
		if trace.is_empty():
			continue
		var state := (
			_new_airborne_state()
			if trace.get("initial_phase", "grounded") == "airborne"
			else _new_state()
		)
		var frames: Array = trace.get("frames", [])
		for frame_value: Variant in frames:
			var frame: Dictionary = frame_value
			var heading_values: Array = frame.get("heading", [])
			if heading_values.size() != 2:
				_failures.append("%s has an invalid heading." % trace_path)
				break
			_step(
				state,
				Vector2(float(heading_values[0]), float(heading_values[1])),
				bool(frame.get("tuck_pressed", false)),
				bool(frame.get("edge_pressed", false)),
				bool(frame.get("brake_pressed", false)),
				bool(frame.get("landing_prep_pressed", false))
			)
		_expect(
			state.ground_position.is_finite() and state.ground_velocity.is_finite(),
			"%s produced invalid simulation state." % trace_path
		)
		if trace.has("expected_rotation_direction"):
			var direction: float = float(trace["expected_rotation_direction"])
			_expect(
				state.orientation * direction > 0.0,
				"%s did not rotate in its expected direction." % trace_path
			)


func _test_lip_crossing_transitions_to_airborne() -> void:
	var course := _takeoff_course()
	var state := _new_state_for_course(course)
	state.course_progress = 195.0
	state.ground_velocity = Vector2(1200.0, 30.0)
	state.has_ground_intent = true
	_step_with_pop(state, course, false, false, false)
	_expect(
		state.phase == RiderState.Phase.AIRBORNE,
		"A high-speed rider crossing the lip should transition to airborne."
	)
	_expect(
		is_equal_approx(state.course_progress, course.lip_progress),
		"Takeoff should resolve at the authored lip position."
	)
	_expect(
		state.vertical_speed < 0.0,
		"An uphill ramp tangent should produce upward takeoff velocity without a pop."
	)


func _test_valid_pop_increases_upward_takeoff_speed() -> void:
	var unpopped := _launch_from_course(false)
	var popped := _launch_from_course(true)
	_expect(
		popped.takeoff_pop_impulse > 0.0,
		"Releasing compression before the lip should produce a bounded pop impulse."
	)
	_expect(
		popped.takeoff_vertical_speed < unpopped.takeoff_vertical_speed,
		"A valid pop should increase upward takeoff velocity."
	)


func _test_held_pop_does_not_add_an_impulse() -> void:
	var state := _new_state_for_course(_takeoff_course())
	var course := _takeoff_course()
	state.course_progress = 185.0
	state.ground_velocity = Vector2(900.0, 0.0)
	state.has_ground_intent = true
	state.compression_active = true
	state.compression_amount = 1.0
	_step_with_pop(state, course, true, false, false)
	_expect(
		is_zero_approx(state.takeoff_pop_impulse),
		"Holding compression through the lip should not add a pop impulse."
	)


func _test_air_input_does_not_change_translation() -> void:
	var neutral := _new_airborne_state()
	var rotating := _new_airborne_state()
	for _tick in 60:
		_step(neutral, Vector2.ZERO, false, false, false)
		_step(rotating, Vector2(1.0, 1.0), false, false, false)
	_expect(
		(
			neutral.course_progress == rotating.course_progress
			and neutral.lane_position == rotating.lane_position
			and neutral.vertical_position == rotating.vertical_position
		),
		"Air input must not alter ballistic translation."
	)


func _test_faster_takeoff_travels_farther() -> void:
	var slower := _new_airborne_state()
	var faster := _new_airborne_state()
	faster.course_speed *= 1.5
	for _tick in 60:
		_step(slower, Vector2.ZERO, false, false, false)
		_step(faster, Vector2.ZERO, false, false, false)
	_expect(
		faster.course_progress > slower.course_progress,
		"A faster takeoff should travel farther during the same flight time."
	)


func _test_torque_changes_angular_velocity() -> void:
	var state := _new_airborne_state()
	_step(state, Vector2.RIGHT, false, false, false)
	_expect(state.angular_velocity > 0.0, "Right air input should add positive angular velocity.")
	_expect(
		state.orientation > 0.0,
		"Orientation should integrate angular velocity instead of snapping."
	)


func _test_reversing_torque_reduces_existing_spin() -> void:
	var state := _new_airborne_state()
	for _tick in 20:
		_step(state, Vector2.RIGHT, false, false, false)
	var forward_spin := state.angular_velocity
	_step(state, Vector2.LEFT, false, false, false)
	_expect(
		state.angular_velocity > 0.0 and state.angular_velocity < forward_spin,
		"Reverse torque should first reduce existing angular momentum."
	)


func _test_body_shape_changes_rotation_rate() -> void:
	var compact := _new_airborne_state()
	var neutral := _new_airborne_state()
	var extended := _new_airborne_state()
	_step(compact, Vector2(1.0, 1.0), false, false, false)
	_step(neutral, Vector2.RIGHT, false, false, false)
	_step(extended, Vector2(1.0, -1.0), false, false, false)
	_expect(
		(
			compact.angular_velocity > neutral.angular_velocity
			and neutral.angular_velocity > extended.angular_velocity
		),
		"Compact and extended body positions should change rotation rate predictably."
	)


func _test_landing_prep_damps_rotation() -> void:
	var unprepared := _new_airborne_state()
	var prepared := _new_airborne_state()
	unprepared.angular_velocity = 4.0
	prepared.angular_velocity = 4.0
	_step(unprepared, Vector2.ZERO, false, false, false)
	_step(prepared, Vector2.ZERO, false, false, false, true)
	_expect(
		prepared.angular_velocity < unprepared.angular_velocity,
		"Landing preparation should add bounded angular damping."
	)


func _test_swept_contact_resolves_once() -> void:
	var course := _landing_course()
	var state := RiderStateScene.new()
	state.phase = RiderState.Phase.AIRBORNE
	state.course_progress = 60.0
	state.vertical_position = -10.0
	state.course_speed = 600.0
	state.vertical_speed = 300.0
	state.orientation = 0.0
	for _tick in 30:
		_step_with_course(state, course, Vector2.ZERO)
		if state.landing_resolved:
			break
	_expect(
		state.landing_resolved,
		"A descending swept flight should resolve its first terrain contact."
	)
	_expect(state.phase == RiderState.Phase.LANDED, "A controlled in-zone contact should land.")
	var first_contact := state.landing_position
	for _tick in 10:
		_step_with_course(state, course, Vector2.ZERO)
	_expect(
		state.landing_position == first_contact,
		"Recovery must not resolve another landing after the first contact."
	)


func _test_landing_labels_and_continuous_quality() -> void:
	var course := _landing_course()
	var perfect := _landing_result(course, 7.0)
	var clean := _landing_result(course, 15.0)
	var sketchy := _landing_result(course, 30.0)
	var crash := _landing_result(course, 36.0)
	_expect(perfect["label"] == "PERFECT", "A low-angle controlled contact should be perfect.")
	_expect(clean["label"] == "CLEAN", "A 15 degree contact should be clean.")
	_expect(sketchy["label"] == "SKETCHY", "A 30 degree contact should be sketchy.")
	_expect(crash["label"] == "CRASH", "A contact beyond the crash angle should crash.")
	var below_boundary := _landing_result(course, 19.0)
	var above_boundary := _landing_result(course, 20.0)
	_expect(
		absf(float(below_boundary["quality"]) - float(above_boundary["quality"])) < 0.05,
		"Landing quality should remain continuous at the clean/sketchy label boundary."
	)


func _test_terrain_seam_returns_first_contact() -> void:
	var course := _landing_course()
	var contact := course.swept_terrain_intersection(Vector2(140.0, -10.0), Vector2(160.0, 10.0))
	_expect(not contact.is_empty(), "A sweep through a terrain seam should find contact.")
	if not contact.is_empty():
		var position: Vector2 = contact["position"]
		_expect(
			is_equal_approx(position.x, 150.0), "Terrain-seam contact should resolve at the seam."
		)


func _load_trace(trace_path: String) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(trace_path))
	if parse_error != OK:
		_failures.append("Could not parse %s: %s" % [trace_path, json.get_error_message()])
		return {}
	var data: Variant = json.data
	if not data is Dictionary:
		_failures.append("%s must contain a JSON object." % trace_path)
		return {}
	return data


func _run(heading: Vector2, tuck: bool, edge: bool, brake: bool, ticks: int) -> RiderState:
	var state := _new_state()
	for _tick in ticks:
		_step(state, heading, tuck, edge, brake)
	return state


func _turn_from_speed(edge: bool, brake: bool, tuck: bool = false) -> RiderState:
	var state := _new_state()
	state.ground_velocity = Vector2(500, 0)
	state.has_ground_intent = true
	for _tick in 30:
		_step(state, Vector2.DOWN, tuck, edge, brake)
	return state


func _step(
	state: RiderState,
	heading: Vector2,
	tuck: bool,
	edge: bool,
	brake: bool,
	landing_prep: bool = false
) -> void:
	var input := RiderInputFrameScene.new()
	input.heading = heading.normalized() if not heading.is_zero_approx() else Vector2.ZERO
	input.tuck_pressed = tuck
	input.edge_pressed = edge
	input.brake_pressed = brake
	input.landing_prep_pressed = landing_prep
	_simulation.step(state, input, _course, _tuning, DELTA)


func _step_with_pop(
	state: RiderState,
	course: ParkCourse,
	pop_pressed: bool,
	pop_just_pressed: bool,
	pop_just_released: bool
) -> void:
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	input.pop_pressed = pop_pressed
	input.pop_just_pressed = pop_just_pressed
	input.pop_just_released = pop_just_released
	_simulation.step(state, input, course, _tuning, DELTA)


func _step_with_course(state: RiderState, course: ParkCourse, heading: Vector2) -> void:
	var input := RiderInputFrameScene.new()
	input.heading = heading
	_simulation.step(state, input, course, _tuning, DELTA)


func _new_state() -> RiderState:
	var state := RiderStateScene.new()
	state.vertical_position = _course.surface_y_at(state.course_progress)
	return state


func _new_state_for_course(course: ParkCourse) -> RiderState:
	var state := RiderStateScene.new()
	state.course_progress = course.start_progress
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.vertical_position = course.surface_y_at(state.course_progress)
	return state


func _new_airborne_state() -> RiderState:
	var state := _new_state()
	state.phase = RiderState.Phase.AIRBORNE
	state.course_speed = 480.0
	state.lane_speed = 75.0
	state.vertical_speed = -320.0
	state.ground_velocity = Vector2(state.course_speed, state.lane_speed)
	return state


func _takeoff_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.terrain_points = PackedVector2Array(
		[Vector2(0, 0), Vector2(150, 0), Vector2(200, -80), Vector2(400, 40)]
	)
	course.start_progress = 100.0
	course.approach_start = 100.0
	course.compression_start = 150.0
	course.compression_end = 190.0
	course.lip_progress = 200.0
	course.landing_start = 250.0
	course.landing_end = 350.0
	course.recovery_progress = 400.0
	course.camera_start = 0.0
	course.camera_end = 400.0
	return course


func _landing_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	course.terrain_points = PackedVector2Array([Vector2(0, 0), Vector2(150, 0), Vector2(300, 0)])
	course.start_progress = 0.0
	course.approach_start = 0.0
	course.compression_start = 0.0
	course.compression_end = 0.0
	course.lip_progress = 20.0
	course.landing_start = 50.0
	course.landing_end = 280.0
	course.recovery_progress = 300.0
	course.camera_start = 0.0
	course.camera_end = 300.0
	return course


func _landing_result(course: ParkCourse, angle_degrees: float) -> Dictionary:
	var state := RiderStateScene.new()
	state.orientation = deg_to_rad(angle_degrees)
	state.course_speed = 400.0
	state.vertical_speed = 40.0
	state.angular_velocity = 0.2
	return JumpJudgeScene.evaluate(
		state, course, Vector2(150, 0), Vector2.RIGHT, Vector2.UP, _tuning
	)


func _launch_from_course(with_pop: bool) -> RiderState:
	var course := _takeoff_course()
	var state := _new_state_for_course(course)
	state.course_progress = 165.0
	state.ground_velocity = Vector2(300.0, 0.0)
	state.has_ground_intent = true
	if with_pop:
		_step_with_pop(state, course, true, true, false)
		_step_with_pop(state, course, true, false, false)
		_step_with_pop(state, course, false, false, true)
	_step_with_pop(state, course, false, false, false)
	_step_with_pop(state, course, false, false, false)
	_step_with_pop(state, course, false, false, false)
	_step_with_pop(state, course, false, false, false)
	_step_with_pop(state, course, false, false, false)
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
