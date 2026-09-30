## Headless checks for run lifecycle phases, landing outcomes, and reset behavior.
extends SceneTree

const ShippedParkCourse := preload("res://src/game/park/park_course.tres")
const RiderRunManagerScene := preload("res://src/game/park/rider_run_manager.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_new_rider_starts_approaching()
	_test_manager_setup_initializes_rider()
	_test_crash_status_uses_landing_outcome()
	_test_abandon_status_uses_landing_outcome()
	_test_reset_restores_run_lifecycle()
	if _failures.is_empty():
		print("Rider run-state checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_new_rider_starts_approaching() -> void:
	var state := RiderStateScene.new()
	_expect(
		state.run.run_phase == RiderRunState.RunPhase.APPROACH,
		"A new rider must start in the approach phase."
	)
	_expect(
		state.run.landing_outcome == RiderRunState.LandingOutcome.NONE,
		"A new rider must not have a landing outcome."
	)
	_expect(
		is_zero_approx(state.run.completion_time_remaining),
		"A new rider must not have a completion countdown."
	)


func _test_manager_setup_initializes_rider() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	_expect(
		manager.rider_state.run.run_phase == RiderRunState.RunPhase.APPROACH,
		"The primary rider must start in the approach phase."
	)
	_expect(
		manager.rider_state.run.landing_outcome == RiderRunState.LandingOutcome.NONE,
		"Manager setup must clear the primary landing outcome."
	)
	_expect(not manager.is_crashed(), "A newly initialized run must not be crashed.")


func _test_crash_status_uses_landing_outcome() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	manager.rider_state.run.run_phase = RiderRunState.RunPhase.LANDING
	manager.rider_state.run.landing_outcome = RiderRunState.LandingOutcome.CRASH
	_expect(manager.is_crashed(), "A crash landing outcome must mark the run as crashed.")


func _test_abandon_status_uses_landing_outcome() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	manager.rider_state.run.run_phase = RiderRunState.RunPhase.LANDING
	manager.rider_state.run.landing_outcome = RiderRunState.LandingOutcome.ABANDON
	_expect(manager.is_abandoned(), "An abandoned landing outcome must mark the run as abandoned.")


func _test_reset_restores_run_lifecycle() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	manager.rider_state.run.landing_outcome = RiderRunState.LandingOutcome.CRASH
	manager.rider_state.kinematics.active_route_index = 2
	manager.rider_state.run.completion_time_remaining = 1.0
	manager.rider_state.jump.compression_active = true
	manager.rider_state.jump.compression_amount = 1.0
	manager.rider_state.jump.compression_release_progress = 100.0
	manager.rider_state.jump.compression_release_quality = 1.0
	manager.rider_state.jump.compression_auto_released = true
	manager.rider_state.jump.takeoff_pop_impulse = 260.0
	manager.rider_state.jump.trick_tracker.start_grab()
	manager.rider_state.jump.grab_reach_active = true
	manager.rider_state.jump.tweak_active = true
	manager.rider_state.jump.grab_started_airtime = 1.0
	manager.rider_state.jump.required_rotations = 3
	manager.rider_state.jump.completed_rotations = 2
	manager.rider_state.jump.rotation_incomplete = true
	manager.rider_state.jump.release_deadline_crossed = true
	manager.rider_state.jump.grab_released_after_deadline = true
	manager.has_started_moving = true
	_expect(manager.is_complete(), "A complete primary phase must mark the manager complete.")
	manager.reset_run(ShippedParkCourse)
	_expect(
		manager.rider_state.run.run_phase == RiderRunState.RunPhase.APPROACH,
		"Reset must return the primary rider to approach."
	)
	_expect(
		manager.rider_state.run.landing_outcome == RiderRunState.LandingOutcome.NONE,
		"Reset must clear the primary landing outcome."
	)
	_expect(
		manager.rider_state.kinematics.active_route_index == -1,
		"Reset must clear the rider's frozen route."
	)
	_expect(not manager.has_started_moving, "Reset must clear the movement-started flag.")
	_expect(not manager.is_crashed(), "Reset must clear the manager crash status.")
	_expect(not manager.is_abandoned(), "Reset must clear the manager abandon status.")
	_expect(not manager.is_complete(), "Reset must clear the manager completion status.")
	_expect(
		is_zero_approx(manager.rider_state.run.completion_time_remaining),
		"Reset must clear the completion countdown."
	)
	_expect(
		(
			not manager.rider_state.jump.compression_active
			and is_zero_approx(manager.rider_state.jump.compression_amount)
			and manager.rider_state.jump.compression_release_progress < 0.0
			and is_zero_approx(manager.rider_state.jump.compression_release_quality)
			and not manager.rider_state.jump.compression_auto_released
			and is_zero_approx(manager.rider_state.jump.takeoff_pop_impulse)
		),
		"Reset must clear compression and pop state."
	)
	_expect(
		(
			not manager.rider_state.jump.trick_tracker.grab_active
			and not manager.rider_state.jump.grab_reach_active
			and not manager.rider_state.jump.tweak_active
			and manager.rider_state.jump.grab_started_airtime < 0.0
		),
		"Reset must clear grab state."
	)
	_expect(
		(
			manager.rider_state.jump.required_rotations == 0
			and manager.rider_state.jump.completed_rotations == 0
			and not manager.rider_state.jump.rotation_incomplete
		),
		"Reset must clear rotation state."
	)
	_expect(
		(
			not manager.rider_state.jump.release_deadline_crossed
			and not manager.rider_state.jump.grab_released_after_deadline
		),
		"Reset must clear release-deadline state."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
