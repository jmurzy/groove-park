## Shared fixtures and assertions for focused park simulation test suites.
# gdlint: disable=max-file-lines
class_name ParkSimulationHarness
extends RefCounted

const ParkCourseScene := preload("res://src/game/park/park_course.gd")
const ParkProjectionScene := preload("res://src/presentation/gameplay/park_projection.gd")
const ShippedParkCourse := preload("res://src/game/park/park_course.tres")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderTuningScene := preload("res://src/game/park/rider_tuning.gd")

const DELTA := 1.0 / 60.0
var failures := PackedStringArray()
var _course: ParkCourse
var _simulation: RiderSimulation
var _tuning: RiderTuning


func _init() -> void:
	_course = _approach_course()
	_simulation = RiderSimulationScene.new()
	_tuning = RiderTuningScene.new()


func _test_neutral_input_does_not_start_a_run() -> void:
	var state := _new_state()
	_step(state, Vector2.ZERO)
	_expect(state.kinematics.ground_velocity.is_zero_approx(), "Neutral input moved.")


func _test_shipped_course_has_an_approach_line() -> void:
	_expect(ShippedParkCourse.routes.size() == 3, "The shipped course needs three paths.")


func _test_downhill_input_starts_a_run() -> void:
	var state := _run(Vector2.RIGHT, false, 60)
	_expect(state.kinematics.course_progress > 20.0, "Downhill input did not move.")
	_expect(state.kinematics.ground_velocity.x > 0.0, "Downhill input should build forward speed.")


func _test_releasing_right_carves_to_a_stop() -> void:
	var state := _run(Vector2.RIGHT, false, 60)
	var speed_before_release := state.kinematics.ground_velocity.length()
	for _tick in 600:
		_step(state, Vector2.ZERO)
	_expect(speed_before_release > 0.0, "Holding Right should create speed before release.")
	_expect(state.kinematics.ground_velocity.is_zero_approx(), "Release did not stop the rider.")


func _test_left_brakes_without_turning_uphill() -> void:
	var centered := _run(Vector2.RIGHT, false, 60)
	var left := _run(Vector2.RIGHT, false, 60)
	var starting_speed := centered.kinematics.ground_velocity.length()
	_step(centered, Vector2.ZERO)
	_step(left, Vector2.LEFT)
	var centered_deceleration := starting_speed - centered.kinematics.ground_velocity.length()
	var left_deceleration := starting_speed - left.kinematics.ground_velocity.length()
	_expect(
		left_deceleration >= centered_deceleration * 2.0, "Left input did not brake hard enough."
	)
	_expect(left.kinematics.heading.x >= 0.0, "Left input must not turn the rider uphill.")


func _test_tuck_builds_more_speed() -> void:
	var neutral := _run(Vector2.RIGHT, false, 120)
	var tucked := _run(Vector2.RIGHT, true, 120)
	_expect(
		tucked.kinematics.ground_velocity.length() > neutral.kinematics.ground_velocity.length(),
		"Tucking should reduce drag."
	)


func _test_vertical_heading_does_not_free_carve() -> void:
	var state := _run(Vector2.RIGHT, false, 30)
	for _tick in 60:
		_step(state, Vector2.DOWN)
	_expect(is_zero_approx(state.kinematics.lane_position), "W/S must not free-carve.")


func _test_vertical_input_switches_approach_paths_smoothly() -> void:
	var routed_course := _approach_course()
	routed_course.approach_paths = [
		PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)]),
		PackedVector2Array([Vector2(0, 100), Vector2(3000, 100)]),
		PackedVector2Array([Vector2(0, 200), Vector2(3000, 200)]),
	]
	var state := _new_state()
	var kinematics := state.kinematics
	kinematics.approach_path_target = 1
	kinematics.approach_path_position = 1.0
	var input := RiderInputFrameScene.new()
	input.approach_path_change = 1
	_simulation.step(state, input, routed_course, _tuning, DELTA)
	_expect(
		kinematics.approach_path_target == 1,
		"A rider who would stop before the next path must not begin a route change."
	)
	kinematics.ground_velocity = Vector2(600.0, 0.0)
	_simulation.step(state, input, routed_course, _tuning, DELTA)
	_expect(kinematics.approach_path_target == 2, "S should select the lower approach path.")
	_expect(
		kinematics.approach_path_position > 1.0 and kinematics.approach_path_position < 2.0,
		"Approach path changes should blend rather than snap."
	)
	var projection := ParkProjectionScene.new(routed_course)
	_expect(
		is_equal_approx(projection.project_rider_ground(state).y, kinematics.vertical_position),
		"The ground projection must follow the rider's blended approach path."
	)
	for _tick in 60:
		_simulation.step(state, RiderInputFrameScene.new(), routed_course, _tuning, DELTA)
	_expect(
		is_equal_approx(kinematics.vertical_position, 200.0), "The rider should reach the path."
	)


func _test_braking_reduces_speed() -> void:
	var coasting := _run(Vector2.RIGHT, false, 120)
	var braking := _run(Vector2.RIGHT, false, 120, true)
	_expect(
		braking.kinematics.ground_velocity.length() < coasting.kinematics.ground_velocity.length(),
		"Braking should reduce speed."
	)


func _test_compression_only_charges_near_lip() -> void:
	var state := _new_state()
	state.kinematics.course_progress = 2700.0
	var input := RiderInputFrameScene.new()
	input.pop_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(
		is_zero_approx(state.jump.compression_amount), "X outside the window must not compress."
	)


func _test_compression_charge_caps_at_maximum() -> void:
	var state := _new_state()
	state.kinematics.course_progress = 2900.0
	var input := RiderInputFrameScene.new()
	input.pop_pressed = true
	for _tick in 120:
		_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(
		is_equal_approx(state.jump.compression_amount, _tuning.maximum_compression),
		"Compression charge must cap at the configured maximum."
	)


func _test_compression_release_records_timing_quality() -> void:
	var state := _new_state()
	state.kinematics.course_progress = 2890.0
	state.jump.compression_active = true
	state.jump.compression_amount = 0.5
	var input := RiderInputFrameScene.new()
	input.pop_just_released = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(not state.jump.compression_active, "Releasing X must end active compression.")
	_expect(
		is_equal_approx(state.jump.compression_release_progress, 2890.0), "Wrong release progress."
	)
	_expect(is_equal_approx(state.jump.compression_release_quality, 0.5), "Wrong release quality.")


func _test_ideal_release_adds_maximum_pop() -> void:
	var baseline := _new_state()
	var popped := _new_state()
	var states: Array[RiderState] = [baseline, popped]
	for state in states:
		state.kinematics.course_progress = 3000.0
		state.kinematics.ground_velocity = Vector2(600.0, 0.0)
		state.run.has_ground_intent = true
	popped.jump.compression_active = true
	popped.jump.compression_amount = _tuning.maximum_compression
	var neutral_input := RiderInputFrameScene.new()
	neutral_input.heading = Vector2.RIGHT
	var release_input := RiderInputFrameScene.new()
	release_input.heading = Vector2.RIGHT
	release_input.pop_just_released = true
	_simulation.step(baseline, neutral_input, _course, _tuning, DELTA)
	_simulation.step(popped, release_input, _course, _tuning, DELTA)
	_expect(
		is_zero_approx(baseline.jump.takeoff_pop_impulse),
		"Takeoff without compression adds no pop."
	)
	_expect(
		is_equal_approx(popped.jump.takeoff_pop_impulse, _tuning.maximum_pop_impulse),
		"A full ideal release must produce the maximum configured pop."
	)
	_expect(
		popped.jump.takeoff_velocity.is_equal_approx(
			(
				baseline.jump.takeoff_velocity
				+ popped.jump.takeoff_normal * _tuning.maximum_pop_impulse
			)
		),
		"Pop must add impulse along the authored lip normal."
	)


func _test_held_compression_auto_releases_at_lip() -> void:
	var state := _new_state()
	state.kinematics.course_progress = 2995.0
	state.kinematics.ground_velocity = Vector2(600.0, 0.0)
	state.run.has_ground_intent = true
	state.jump.compression_active = true
	state.jump.compression_amount = _tuning.maximum_compression
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	input.pop_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(
		not state.jump.compression_active, "Compression held through the lip must auto-release."
	)
	_expect(
		is_equal_approx(state.jump.compression_release_progress, 3000.0),
		"Auto-release must capture the exact authored lip."
	)
	var quality := _tuning.compression_auto_release_quality
	var pop := _tuning.maximum_pop_impulse * quality
	_expect(state.jump.compression_auto_released, "Lip release must be marked automatic.")
	_expect(is_equal_approx(state.jump.compression_release_quality, quality), "Wrong auto quality.")
	_expect(is_equal_approx(state.jump.takeoff_pop_impulse, pop), "Wrong auto-release pop.")


func _test_flight_route_transitions_at_lip() -> void:
	var state := _new_state()
	var kinematics := state.kinematics
	var run := state.run
	var jump := state.jump
	kinematics.course_progress = 2995.0
	kinematics.ground_velocity = Vector2(600.0, 0.0)
	run.has_ground_intent = true
	_step(state, Vector2.RIGHT)
	_expect(kinematics.course_progress >= 3000.0, "The rider should cross the exact authored lip.")
	_expect(run.run_phase == RiderRunState.RunPhase.FLIGHT, "Crossing the lip should enter flight.")
	_expect(kinematics.active_route_index == 1, "Takeoff should freeze the selected route index.")
	_expect(
		jump.takeoff_position.is_equal_approx(Vector2(3000.0, 1500.0)), "Wrong takeoff position."
	)
	_expect(jump.takeoff_velocity.x > 0.0, "Takeoff must preserve approach momentum.")
	_expect(
		is_equal_approx(jump.takeoff_velocity.x, jump.takeoff_course_speed),
		"Takeoff should preserve its captured horizontal velocity."
	)
	_expect(jump.takeoff_velocity.y > 0.0, "A downhill lip should add downward launch velocity.")
	_expect(
		jump.takeoff_tangent.is_equal_approx(Vector2(2.0, 1.0).normalized()),
		"Takeoff should use the final authored path segment as the lip tangent."
	)
	_expect(
		is_equal_approx(jump.release_deadline_y, jump.takeoff_position.y), "Wrong release deadline."
	)
	var previous_position := Vector2(kinematics.course_progress, kinematics.vertical_position)
	var captured_velocity := jump.takeoff_velocity
	_step(state, Vector2.LEFT, false, true)
	_expect(
		kinematics.course_progress > previous_position.x, "Flight should advance from momentum."
	)
	_expect(
		jump.takeoff_velocity.is_equal_approx(captured_velocity),
		"Flight must preserve takeoff velocity."
	)


func _test_arc_height_multiplier_steepens_uphill_launch() -> void:
	var routed_course := _approach_course()
	var ramp := PackedVector2Array([Vector2(0, 100), Vector2(100, 0)])
	routed_course.approach_paths = [ramp, ramp, ramp]
	var state := RiderStateScene.new()
	var jump := state.jump
	state.kinematics.approach_path_target = 1
	state.kinematics.approach_path_position = 1.0
	state.kinematics.course_progress = 95.0
	state.kinematics.vertical_position = routed_course.route_surface_y_at(95.0, 1.0)
	state.kinematics.ground_velocity = Vector2(600.0, 0.0)
	state.run.has_ground_intent = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	var tuning := RiderTuningScene.new()
	tuning.flight_arc_height_multiplier = 1.5
	tuning.maximum_takeoff_course_speed = 10_000.0
	_simulation.step(state, input, routed_course, tuning, DELTA)
	var unboosted_vertical_speed := (
		jump.takeoff_course_speed * jump.takeoff_tangent.y / jump.takeoff_tangent.x
	)
	_expect(
		is_equal_approx(jump.takeoff_vertical_speed, unboosted_vertical_speed * 1.5),
		"Wrong multiplier."
	)
	_expect(jump.takeoff_vertical_speed < unboosted_vertical_speed, "The launch should be steeper.")


func _test_takeoff_speed_cap_shortens_fast_launches() -> void:
	var routed_course := _approach_course()
	var ramp := PackedVector2Array([Vector2(0, 100), Vector2(100, 0)])
	routed_course.approach_paths = [ramp, ramp, ramp]
	var state := RiderStateScene.new()
	var jump := state.jump
	state.kinematics.approach_path_target = 1
	state.kinematics.approach_path_position = 1.0
	state.kinematics.course_progress = 95.0
	state.kinematics.vertical_position = routed_course.route_surface_y_at(95.0, 1.0)
	state.kinematics.ground_velocity = Vector2(900.0, 0.0)
	state.run.has_ground_intent = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	var tuning := RiderTuningScene.new()
	tuning.flight_arc_height_multiplier = 1.5
	tuning.maximum_takeoff_course_speed = 300.0
	_simulation.step(state, input, routed_course, tuning, DELTA)
	_expect(jump.takeoff_course_speed <= 300.0, "Fast approaches must respect the speed cap.")
	_expect(
		absf(jump.takeoff_vertical_speed) > jump.takeoff_course_speed, "The cap must preserve lift."
	)


func _test_arc_height_multiplier_preserves_flight_range() -> void:
	var baseline := flight_state()
	baseline.kinematics.vertical_position = 0.0
	baseline.kinematics.vertical_speed = -100.0
	var boosted := flight_state()
	boosted.kinematics.vertical_position = 0.0
	boosted.kinematics.vertical_speed = -150.0
	var baseline_tuning := RiderTuningScene.new()
	baseline_tuning.gravity = 100.0
	baseline_tuning.air_drag = 0.0
	baseline_tuning.air_time_scale = 1.0
	baseline_tuning.flight_arc_height_multiplier = 1.0
	var boosted_tuning := RiderTuningScene.new()
	boosted_tuning.gravity = 100.0
	boosted_tuning.air_drag = 0.0
	boosted_tuning.air_time_scale = 1.0
	boosted_tuning.flight_arc_height_multiplier = 1.5
	var baseline_min_y := 0.0
	var boosted_min_y := 0.0
	var baseline_ticks := -1
	var boosted_ticks := -1
	for tick in 600:
		if baseline_ticks < 0:
			_simulation.step(baseline, RiderInputFrameScene.new(), _course, baseline_tuning, DELTA)
			baseline_min_y = minf(baseline_min_y, baseline.kinematics.vertical_position)
			if (
				baseline.kinematics.vertical_speed > 0.0
				and baseline.kinematics.vertical_position >= 0.0
			):
				baseline_ticks = tick
		if boosted_ticks < 0:
			_simulation.step(boosted, RiderInputFrameScene.new(), _course, boosted_tuning, DELTA)
			boosted_min_y = minf(boosted_min_y, boosted.kinematics.vertical_position)
			if (
				boosted.kinematics.vertical_speed > 0.0
				and boosted.kinematics.vertical_position >= 0.0
			):
				boosted_ticks = tick
		if baseline_ticks >= 0 and boosted_ticks >= 0:
			break
	_expect(boosted_min_y < baseline_min_y, "The boosted arc should reach a higher apex.")
	_expect(absi(baseline_ticks - boosted_ticks) <= 1, "The boosted arc should preserve duration.")
	_expect(
		absf(baseline.kinematics.course_progress - boosted.kinematics.course_progress) <= 2.0,
		"A taller arc should preserve horizontal flight range."
	)


func _test_ground_route_transitions_to_landing() -> void:
	var routed_course := _approach_course()
	routed_course.approach_paths = [
		PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)]),
		PackedVector2Array([Vector2(0, 100), Vector2(3000, 100)]),
		PackedVector2Array([Vector2(0, 200), Vector2(3200, 200)]),
	]
	var state := RiderStateScene.new()
	var kinematics := state.kinematics
	var run := state.run
	var jump := state.jump
	kinematics.approach_path_target = 2
	kinematics.approach_path_position = 2.0
	kinematics.course_progress = 3195.0
	kinematics.ground_velocity = Vector2(600.0, 0.0)
	run.has_ground_intent = true
	_step_on(state, routed_course, Vector2.RIGHT)
	_expect(
		kinematics.course_progress >= 3200.0, "The lower path must reach its authored endpoint."
	)
	_expect(run.run_phase == RiderRunState.RunPhase.LANDING, "The lower route should enter runout.")
	_expect(kinematics.active_route_index == 2, "Grounded runout should freeze the lower route.")
	_expect(kinematics.ground_velocity.x > 0.0, "Grounded runout must preserve approach momentum.")
	_expect(
		(
			run.landing_outcome == RiderRunState.LandingOutcome.ABANDON
			and is_equal_approx(jump.landing_position.x, 3200.0)
		),
		"Grounded runout should abandon at the approach endpoint."
	)


func _test_lip_crossing_is_fixed_step_safe() -> void:
	var fast_step_state := _new_state()
	var slow_step_state := _new_state()
	var states: Array[RiderState] = [fast_step_state, slow_step_state]
	for state in states:
		state.kinematics.course_progress = 2995.0
		state.kinematics.ground_velocity = Vector2(600.0, 0.0)
		state.run.has_ground_intent = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	_simulation.step(fast_step_state, input, _course, _tuning, 1.0 / 30.0)
	_simulation.step(slow_step_state, input, _course, _tuning, 1.0 / 120.0)
	_expect(
		(
			fast_step_state.run.run_phase == RiderRunState.RunPhase.FLIGHT
			and slow_step_state.run.run_phase == RiderRunState.RunPhase.FLIGHT
		),
		"Lip crossing should transition at supported fixed-step sizes."
	)
	_expect(
		(
			is_equal_approx(fast_step_state.jump.takeoff_position.x, 3000.0)
			and is_equal_approx(slow_step_state.jump.takeoff_position.x, 3000.0)
		),
		"Lip crossing should capture the authored endpoint at every fixed-step size."
	)


func _test_ballistic_flight_matches_known_step() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	var tuning := RiderTuningScene.new()
	tuning.gravity = 100.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	tuning.flight_arc_height_multiplier = 1.0
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.1)
	_expect(
		is_equal_approx(kinematics.course_progress, 3010.0), "Flight should integrate horizontally."
	)
	_expect(
		(
			is_equal_approx(kinematics.vertical_speed, -40.0)
			and is_equal_approx(kinematics.vertical_position, 96.0)
		),
		"Ballistic flight should apply gravity before integrating vertical position."
	)
	_expect(is_equal_approx(state.jump.airtime, 0.1), "Flight should advance scaled airtime.")


func _test_air_drag_cannot_reverse_velocity() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 100.0
	tuning.air_time_scale = 1.0
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 1.0)
	_expect(
		is_zero_approx(kinematics.course_speed) and is_zero_approx(kinematics.vertical_speed),
		"Air drag may stop flight velocity but must never reverse it."
	)


func _test_air_input_does_not_steer() -> void:
	var neutral := flight_state()
	var controlled := flight_state()
	var neutral_kinematics := neutral.kinematics
	var controlled_kinematics := controlled.kinematics
	var input := RiderInputFrameScene.new()
	input.heading = Vector2(-1.0, 1.0).normalized()
	input.tuck_pressed = true
	input.brake_pressed = true
	input.pop_pressed = true
	for _tick in 30:
		_simulation.step(neutral, RiderInputFrameScene.new(), _course, _tuning, DELTA)
		_simulation.step(controlled, input, _course, _tuning, DELTA)
	_expect(
		(
			Vector2(neutral_kinematics.course_progress, neutral_kinematics.vertical_position)
			. is_equal_approx(
				Vector2(
					controlled_kinematics.course_progress, controlled_kinematics.vertical_position
				)
			)
		),
		"Air input must not steer the ballistic trajectory."
	)
	_expect(
		is_equal_approx(neutral.jump.orientation, controlled.jump.orientation),
		"Air input must not rotate."
	)


func _test_flight_projection_uses_landing_path() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	kinematics.course_progress = 3500.0
	kinematics.ground_position = Vector2(kinematics.course_progress, kinematics.lane_position)
	var projection := ParkProjectionScene.new(_course)
	_expect(
		projection.project_rider_ground(state).is_equal_approx(
			_course.landing_surface_position_at(
				kinematics.course_progress, kinematics.active_route_index
			)
		),
		"An airborne rider's ground projection should follow the selected landing path."
	)


func _test_swept_landing_contact_resolves_once() -> void:
	var state := _landing_contact_state()
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	var landing_prep := RiderInputFrameScene.new()
	landing_prep.landing_prep_pressed = true
	_simulation.step(state, landing_prep, _course, tuning, 0.2)
	_expect(
		(
			state.run.run_phase == RiderRunState.RunPhase.LANDING
			and state.run.landing_outcome == RiderRunState.LandingOutcome.CLEAN
		),
		"Swept flight contact should resolve a clean landing."
	)
	_expect(state.jump.landing_resolved, "Landing contact must resolve exactly once.")
	_expect(
		state.jump.landing_position.x > 3100.0 and state.jump.landing_position.x < 3130.0,
		"Swept collision should catch terrain crossed between physics positions."
	)
	var first_contact := state.jump.landing_position
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.5)
	_expect(state.jump.landing_position.is_equal_approx(first_contact), "Runout must not reland.")


func _test_contact_outcome_priority() -> void:
	var landing := LandingSimulation.new()
	var contact := {
		"position": Vector2(100.0, 100.0), "tangent": Vector2.RIGHT, "normal": Vector2.UP
	}
	var still_grabbing := _landing_contact_state()
	still_grabbing.jump.landing_prep_active = true
	still_grabbing.jump.trick_tracker.grab_active = true
	still_grabbing.jump.rotation_incomplete = true
	still_grabbing.jump.required_rotations = 1
	still_grabbing.jump.grab_released_after_deadline = true
	landing.resolve_contact(still_grabbing, contact)
	_expect(
		still_grabbing.run.landing_outcome == RiderRunState.LandingOutcome.CRASH,
		"An active grab at contact must take crash priority."
	)
	var incomplete_rotation := _landing_contact_state()
	incomplete_rotation.jump.landing_prep_active = true
	incomplete_rotation.jump.rotation_incomplete = true
	incomplete_rotation.jump.required_rotations = 1
	incomplete_rotation.jump.grab_released_after_deadline = true
	landing.resolve_contact(incomplete_rotation, contact)
	_expect(
		incomplete_rotation.run.landing_outcome == RiderRunState.LandingOutcome.CRASH,
		"An incomplete rotation at contact must crash."
	)
	var missing_rotation := _landing_contact_state()
	missing_rotation.jump.landing_prep_active = true
	missing_rotation.jump.required_rotations = 1
	missing_rotation.jump.grab_released_after_deadline = true
	landing.resolve_contact(missing_rotation, contact)
	_expect(
		missing_rotation.run.landing_outcome == RiderRunState.LandingOutcome.SKETCHY,
		"A missed rotation requirement must not crash."
	)
	var late_release := _landing_contact_state()
	late_release.jump.landing_prep_active = true
	late_release.jump.required_rotations = 1
	late_release.jump.completed_rotations = 1
	late_release.jump.grab_released_after_deadline = true
	landing.resolve_contact(late_release, contact)
	_expect(
		late_release.run.landing_outcome == RiderRunState.LandingOutcome.SKETCHY,
		"A late release with enough rotations must be sketchy."
	)
	var clean := _landing_contact_state()
	clean.jump.landing_prep_active = true
	clean.jump.required_rotations = 1
	clean.jump.completed_rotations = 1
	landing.resolve_contact(clean, contact)
	_expect(
		clean.run.landing_outcome == RiderRunState.LandingOutcome.CLEAN,
		"An early release with enough rotations must land clean."
	)
	var no_landing_prep := _landing_contact_state()
	landing.resolve_contact(no_landing_prep, contact)
	_expect(
		no_landing_prep.run.landing_outcome == RiderRunState.LandingOutcome.CRASH,
		"Landing without X held must crash."
	)


func _test_flight_input_activates_landing_prep() -> void:
	var state := flight_state()
	var input := RiderInputFrameScene.new()
	input.landing_prep_pressed = true
	_simulation.step(state, input, _course, _tuning, DELTA)
	_expect(state.jump.landing_prep_active, "Holding X in flight must activate landing prep.")


func _test_contact_outcome_resolves_once() -> void:
	var state := _landing_contact_state()
	state.jump.landing_prep_active = true
	var landing := LandingSimulation.new()
	var contact := {
		"position": Vector2(100.0, 100.0), "tangent": Vector2.RIGHT, "normal": Vector2.UP
	}
	landing.resolve_contact(state, contact)
	var outcome := state.run.landing_outcome
	state.jump.trick_tracker.grab_active = true
	landing.resolve_contact(state, contact)
	_expect(
		state.run.landing_outcome == outcome, "Landing outcome must not change after first contact."
	)


func _test_flight_only_hits_selected_landing_path() -> void:
	var routed_course := _approach_course()
	routed_course.landing_paths = [
		PackedVector2Array([Vector2(100, 10), Vector2(200, 10)]),
		PackedVector2Array([Vector2(100, 100), Vector2(200, 100)]),
		PackedVector2Array([Vector2(100, 200), Vector2(200, 200)]),
	]
	var state := RiderStateScene.new()
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.kinematics.active_route_index = 1
	state.kinematics.course_progress = 90.0
	state.kinematics.vertical_position = 0.0
	state.kinematics.ground_position = Vector2(90.0, 0.0)
	state.kinematics.course_speed = 100.0
	state.kinematics.vertical_speed = 100.0
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	_simulation.step(state, RiderInputFrameScene.new(), routed_course, tuning, 0.2)
	_expect(
		state.run.run_phase == RiderRunState.RunPhase.FLIGHT, "Flight must ignore other routes."
	)


func _test_runout_ignores_input_and_completes() -> void:
	var neutral := _runout_state()
	var controlled := _runout_state()
	var kinematics := neutral.kinematics
	var run := neutral.run
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.LEFT
	input.tuck_pressed = true
	input.brake_pressed = true
	input.pop_pressed = true
	_simulation.step(neutral, RiderInputFrameScene.new(), _course, _tuning, 0.5)
	_simulation.step(controlled, input, _course, _tuning, 0.5)
	_expect(
		is_equal_approx(kinematics.course_progress, controlled.kinematics.course_progress),
		"Landing input must not affect automatic runout."
	)
	kinematics.course_progress = _course.landing_end_at(kinematics.active_route_index).x - 5.0
	kinematics.vertical_position = _course.landing_surface_y_at(
		kinematics.course_progress, kinematics.active_route_index
	)
	_simulation.step(neutral, input, _course, _tuning, 1.0)
	_expect(
		run.run_phase == RiderRunState.RunPhase.COMPLETE, "Runout should complete at its endpoint."
	)
	var completed_position := Vector2(kinematics.course_progress, kinematics.vertical_position)
	_simulation.step(neutral, input, _course, _tuning, 1.0)
	_expect(
		Vector2(kinematics.course_progress, kinematics.vertical_position).is_equal_approx(
			completed_position
		),
		"A completed run must remain frozen."
	)


func _test_descending_below_abandon_line_enters_runout() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	var run := state.run
	kinematics.course_progress = 3050.0
	kinematics.vertical_position = (
		_course.flight_abandon_trigger_y_at(
			kinematics.course_progress, kinematics.active_route_index
		)
		+ 10.0
	)
	kinematics.ground_position = Vector2(kinematics.course_progress, 0.0)
	kinematics.course_speed = 10.0
	kinematics.vertical_speed = 50.0
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.1)
	_expect(
		(
			run.run_phase == RiderRunState.RunPhase.LANDING
			and run.landing_outcome == RiderRunState.LandingOutcome.ABANDON
			and run.current_surface_id == &"abandon"
		),
		"A descending rider below the abandon line should enter automatic runout."
	)
	_expect(
		is_equal_approx(
			kinematics.vertical_position,
			_course.flight_abandon_trigger_y_at(
				kinematics.course_progress, kinematics.active_route_index
			)
		),
		"An airborne abandon should snap onto the active abandon line."
	)
	var previous_progress := kinematics.course_progress
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.5)
	_expect(kinematics.course_progress > previous_progress, "An abandon should auto-advance.")
	_expect(
		is_equal_approx(
			kinematics.vertical_position,
			_course.flight_abandon_trigger_y_at(
				kinematics.course_progress, kinematics.active_route_index
			)
		),
		"Airborne abandon runout should continue along the abandon line."
	)
	var projection := ParkProjectionScene.new(_course)
	_expect(
		projection.project_rider_ground(state).is_equal_approx(
			Vector2(kinematics.course_progress, kinematics.vertical_position)
		),
		"Abandon projection should follow the abandon line."
	)


func _test_ascending_below_abandon_line_can_recover() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	kinematics.course_progress = 3050.0
	kinematics.vertical_position = (
		_course.flight_abandon_trigger_y_at(
			kinematics.course_progress, kinematics.active_route_index
		)
		+ 50.0
	)
	kinematics.ground_position = Vector2(kinematics.course_progress, 0.0)
	kinematics.course_speed = 10.0
	kinematics.vertical_speed = -100.0
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.1)
	_expect(
		state.run.run_phase == RiderRunState.RunPhase.FLIGHT, "Ascending riders must not abandon."
	)


func _test_abandon_floor_does_not_preempt_landing_contact() -> void:
	var routed_course := _approach_course()
	routed_course.flight_abandon_y = 100.0
	routed_course.route_at(1).landing_path = PackedVector2Array(
		[Vector2(100, 0), Vector2(200, 200)]
	)
	var state := RiderStateScene.new()
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.kinematics.active_route_index = 1
	state.kinematics.course_progress = 90.0
	state.kinematics.vertical_position = 90.0
	state.kinematics.ground_position = Vector2(90.0, 0.0)
	state.kinematics.course_speed = 60.0
	state.kinematics.vertical_speed = 60.0
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	var landing_prep := RiderInputFrameScene.new()
	landing_prep.landing_prep_pressed = true
	_simulation.step(state, landing_prep, routed_course, tuning, 1.0)
	_expect(
		state.run.run_phase == RiderRunState.RunPhase.FLIGHT,
		"The nominal floor must not end flight."
	)
	_simulation.step(state, landing_prep, routed_course, tuning, 1.0)
	_expect(
		state.run.landing_outcome == RiderRunState.LandingOutcome.CLEAN,
		"Later contact must land cleanly."
	)


func _test_missed_flight_is_terminal() -> void:
	var state := flight_state()
	var kinematics := state.kinematics
	var run := state.run
	var landing_end := _course.landing_end_at(kinematics.active_route_index)
	kinematics.course_progress = landing_end.x - 5.0
	kinematics.ground_position = Vector2(kinematics.course_progress, kinematics.lane_position)
	kinematics.course_speed = 100.0
	var tuning := RiderTuningScene.new()
	tuning.gravity = 0.0
	tuning.air_drag = 0.0
	tuning.air_time_scale = 1.0
	tuning.crash_completion_delay = 0.5
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.1)
	_expect(
		(
			run.run_phase == RiderRunState.RunPhase.LANDING
			and run.landing_outcome == RiderRunState.LandingOutcome.CRASH
		),
		"Flight past the landing path must become a terminal crash."
	)
	_expect(kinematics.ground_velocity.is_zero_approx(), "A terminal missed flight must stop.")
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.2)
	_expect(
		run.run_phase == RiderRunState.RunPhase.LANDING,
		"A missed flight should hold crash presentation."
	)
	_simulation.step(state, RiderInputFrameScene.new(), _course, tuning, 0.3)
	_expect(
		run.run_phase == RiderRunState.RunPhase.COMPLETE,
		"A missed flight should complete after delay."
	)


func _test_shipped_routes_complete_with_landing_prep() -> void:
	for route_index in ParkCourse.ROUTE_COUNT:
		var state := RiderStateScene.new()
		var kinematics := state.kinematics
		var run := state.run
		var jump := state.jump
		kinematics.approach_path_target = route_index
		kinematics.approach_path_position = float(route_index)
		kinematics.course_progress = (
			ShippedParkCourse.route_at(route_index).approach_path[-1].x - 5.0
		)
		kinematics.vertical_position = ShippedParkCourse.route_surface_y_at(
			kinematics.course_progress, kinematics.approach_path_position
		)
		kinematics.ground_velocity = Vector2(500.0, 0.0)
		run.has_ground_intent = true
		var input := RiderInputFrameScene.new()
		input.heading = Vector2.RIGHT
		input.landing_prep_pressed = true
		for _tick in 3000:
			_simulation.step(state, input, ShippedParkCourse, _tuning, DELTA)
			if run.run_phase == RiderRunState.RunPhase.COMPLETE:
				break
		_expect(
			run.run_phase == RiderRunState.RunPhase.COMPLETE,
			"Route %d should complete." % route_index
		)
		var outcome_is_valid := run.landing_outcome == RiderRunState.LandingOutcome.ABANDON
		if ShippedParkCourse.route_at(route_index).kind == ParkRoute.Kind.FLIGHT:
			outcome_is_valid = run.landing_outcome == RiderRunState.LandingOutcome.CLEAN
		_expect(
			outcome_is_valid,
			(
				(
					"Shipped route %d should resolve its expected outcome; outcome=%d, "
					+ "takeoff=%s, terminal=%s."
				)
				% [route_index, run.landing_outcome, jump.takeoff_velocity, jump.landing_position]
			)
		)


func _test_path_change_is_rejected_too_close_to_lip() -> void:
	var routed_course := _approach_course()
	routed_course.approach_paths = [
		PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		PackedVector2Array([Vector2(0, 100), Vector2(100, 100)]),
		PackedVector2Array([Vector2(0, 200), Vector2(100, 200)]),
	]
	var state := RiderStateScene.new()
	state.kinematics.approach_path_target = 1
	state.kinematics.approach_path_position = 1.0
	state.kinematics.course_progress = 95.0
	state.kinematics.ground_velocity = Vector2(600.0, 0.0)
	state.run.has_ground_intent = true
	var input := RiderInputFrameScene.new()
	input.heading = Vector2.RIGHT
	input.approach_path_change = 1
	_simulation.step(state, input, routed_course, _tuning, DELTA)
	_expect(state.kinematics.approach_path_target == 1, "A late route change must be rejected.")
	_expect(state.kinematics.active_route_index == 1, "Late input must not change the route.")


func _test_route_tangent_follows_selected_path() -> void:
	var routed_course := _approach_course()
	routed_course.approach_paths = [
		PackedVector2Array([Vector2(0, 200), Vector2(3000, 0)]),
		PackedVector2Array([Vector2(0, 100), Vector2(3000, 100)]),
		PackedVector2Array([Vector2(0, 0), Vector2(3000, 200)]),
	]
	_expect(
		routed_course.route_tangent_at(1000.0, 0.0).y < 0.0,
		"The upper tangent should point uphill."
	)
	_expect(
		is_zero_approx(routed_course.route_tangent_at(1000.0, 1.0).y),
		"The center should stay flat."
	)
	_expect(
		routed_course.route_tangent_at(1000.0, 2.0).y > 0.0,
		"The lower tangent should point downhill."
	)


func _run(heading: Vector2, tuck: bool, ticks: int, brake: bool = false) -> RiderState:
	var state := _new_state()
	for _tick in ticks:
		_step(state, heading, tuck, brake)
	return state


func _step(state: RiderState, heading: Vector2, tuck := false, brake := false) -> void:
	_step_on(state, _course, heading, tuck, brake)


func _step_on(
	state: RiderState, course: ParkCourse, heading: Vector2, tuck := false, brake := false
) -> void:
	var input := RiderInputFrameScene.new()
	input.heading = heading
	input.tuck_pressed = tuck
	input.brake_pressed = brake
	_simulation.step(state, input, course, _tuning, DELTA)


func _new_state() -> RiderState:
	var state := RiderStateScene.new()
	var kinematics := state.kinematics
	kinematics.course_progress = 20.0
	kinematics.vertical_position = _course.route_surface_y_at(
		kinematics.course_progress, kinematics.approach_path_position
	)
	return state


func flight_state() -> RiderState:
	var state := RiderStateScene.new()
	var kinematics := state.kinematics
	var jump := state.jump
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	kinematics.active_route_index = 1
	kinematics.course_progress = 3000.0
	kinematics.vertical_position = 100.0
	kinematics.ground_position = Vector2(kinematics.course_progress, 0.0)
	kinematics.course_speed = 100.0
	kinematics.vertical_speed = -50.0
	jump.takeoff_velocity = Vector2(kinematics.course_speed, kinematics.vertical_speed)
	jump.orientation = 0.25
	return state


func _landing_contact_state() -> RiderState:
	var state := RiderStateScene.new()
	var kinematics := state.kinematics
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	kinematics.active_route_index = 1
	kinematics.course_progress = 3090.0
	kinematics.vertical_position = 1600.0
	kinematics.ground_position = Vector2(kinematics.course_progress, 0.0)
	kinematics.course_speed = 200.0
	kinematics.vertical_speed = 1000.0
	return state


func _runout_state() -> RiderState:
	var state := RiderStateScene.new()
	var kinematics := state.kinematics
	var run := state.run
	run.run_phase = RiderRunState.RunPhase.LANDING
	run.landing_outcome = RiderRunState.LandingOutcome.CLEAN
	state.jump.landing_resolved = true
	kinematics.active_route_index = 1
	kinematics.course_progress = 3200.0
	kinematics.vertical_position = _course.landing_surface_y_at(
		kinematics.course_progress, kinematics.active_route_index
	)
	kinematics.ground_position = Vector2(kinematics.course_progress, 0.0)
	kinematics.ground_velocity = Vector2(200.0, 0.0)
	kinematics.course_speed = 200.0
	return state


func _approach_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	var path := PackedVector2Array([Vector2(0, 0), Vector2(3000, 1500)])
	course.approach_paths = [path, path, path]
	var flight_landing := PackedVector2Array([Vector2(3100, 1700), Vector2(6000, 2000)])
	var ground_runout := PackedVector2Array([Vector2(3000, 1500), Vector2(6000, 1800)])
	course.landing_paths = [flight_landing, flight_landing, ground_runout]
	course.flight_abandon_y = 1800.0
	course.lane_min = -100.0
	course.lane_max = 100.0
	return course


func approach_course() -> ParkCourse:
	return _approach_course()


func _roller_course() -> ParkCourse:
	var course := ParkCourseScene.new()
	var path := PackedVector2Array(
		[Vector2(0, 400), Vector2(400, 560), Vector2(600, 360), Vector2(1000, 520)]
	)
	course.approach_paths = [path, path, path]
	var flight_landing := PackedVector2Array([Vector2(1100, 600), Vector2(3000, 900)])
	var ground_runout := PackedVector2Array([Vector2(1000, 520), Vector2(3000, 900)])
	course.landing_paths = [flight_landing, flight_landing, ground_runout]
	course.lane_min = -100.0
	course.lane_max = 100.0
	return course


func _test_gradient_sign_matches_terrain_pitch() -> void:
	var roller := _roller_course()
	_expect(_course.route_gradient_at(500.0, 1.0) > 0.0, "Downhill should have positive gradient.")
	_expect(roller.route_gradient_at(500.0, 1.0) < 0.0, "Uphill should have negative gradient.")


func _test_uphill_stalls_without_momentum() -> void:
	var roller := _roller_course()
	var state := RiderStateScene.new()
	state.kinematics.course_progress = 380.0
	state.kinematics.ground_velocity = Vector2(120.0, 0.0)
	state.run.has_ground_intent = true
	for _tick in 300:
		_step_on(state, roller, Vector2.RIGHT)
	_expect(state.kinematics.course_progress < 590.0, "Slow entries must stall before the crest.")


func _test_uphill_clears_with_momentum() -> void:
	var roller := _roller_course()
	var state := RiderStateScene.new()
	state.kinematics.course_progress = 100.0
	state.kinematics.ground_velocity = Vector2(700.0, 0.0)
	state.run.has_ground_intent = true
	for _tick in 300:
		_step_on(state, roller, Vector2.RIGHT)
		if state.kinematics.course_progress >= 620.0:
			break
	_expect(state.kinematics.course_progress >= 600.0, "Fast entries should clear the crest.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
