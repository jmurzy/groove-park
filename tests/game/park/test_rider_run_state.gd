## Headless checks for run lifecycle phases, landing outcomes, and reset behavior.
extends SceneTree

const ShippedParkCourse := preload("res://src/game/park/park_course.tres")
const RiderRunManagerScene := preload("res://src/game/park/rider_run_manager.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_new_rider_starts_approaching()
	_test_manager_setup_initializes_both_riders()
	_test_crash_status_uses_landing_outcome()
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
		state.run_phase == RiderState.RunPhase.APPROACH,
		"A new rider must start in the approach phase."
	)
	_expect(
		state.landing_outcome == RiderState.LandingOutcome.NONE,
		"A new rider must not have a landing outcome."
	)
	_expect(
		is_zero_approx(state.completion_time_remaining),
		"A new rider must not have a completion countdown."
	)


func _test_manager_setup_initializes_both_riders() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	_expect(
		manager.rider_state.run_phase == RiderState.RunPhase.APPROACH,
		"The primary rider must start in the approach phase."
	)
	_expect(
		manager.skier_state.run_phase == RiderState.RunPhase.APPROACH,
		"The skier must start in the approach phase."
	)
	_expect(
		manager.rider_state.landing_outcome == RiderState.LandingOutcome.NONE,
		"Manager setup must clear the primary landing outcome."
	)
	_expect(not manager.is_crashed(), "A newly initialized run must not be crashed.")


func _test_crash_status_uses_landing_outcome() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	manager.rider_state.run_phase = RiderState.RunPhase.LANDING
	manager.rider_state.landing_outcome = RiderState.LandingOutcome.CRASH
	_expect(manager.is_crashed(), "A crash landing outcome must mark the run as crashed.")


func _test_reset_restores_run_lifecycle() -> void:
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	manager.rider_state.run_phase = RiderState.RunPhase.COMPLETE
	manager.rider_state.landing_outcome = RiderState.LandingOutcome.CRASH
	manager.rider_state.active_route_index = 2
	manager.rider_state.completion_time_remaining = 1.0
	manager.rider_state.compression_active = true
	manager.rider_state.compression_amount = 1.0
	manager.rider_state.compression_release_progress = 100.0
	manager.rider_state.compression_release_quality = 1.0
	manager.rider_state.compression_auto_released = true
	manager.rider_state.takeoff_pop_impulse = 260.0
	manager.skier_state.run_phase = RiderState.RunPhase.FLIGHT
	manager.skier_state.landing_outcome = RiderState.LandingOutcome.SKETCHY
	manager.skier_state.active_route_index = 0
	manager.has_started_moving = true
	_expect(manager.is_complete(), "A complete primary phase must mark the manager complete.")
	manager.reset_run(ShippedParkCourse)
	_expect(
		manager.rider_state.run_phase == RiderState.RunPhase.APPROACH,
		"Reset must return the primary rider to approach."
	)
	_expect(
		manager.rider_state.landing_outcome == RiderState.LandingOutcome.NONE,
		"Reset must clear the primary landing outcome."
	)
	_expect(
		manager.skier_state.run_phase == RiderState.RunPhase.APPROACH,
		"Reset must return the skier to approach."
	)
	_expect(
		manager.skier_state.landing_outcome == RiderState.LandingOutcome.NONE,
		"Reset must clear the skier landing outcome."
	)
	_expect(
		(
			manager.rider_state.active_route_index == -1
			and manager.skier_state.active_route_index == -1
		),
		"Reset must clear each rider's frozen route."
	)
	_expect(not manager.has_started_moving, "Reset must clear the movement-started flag.")
	_expect(not manager.is_crashed(), "Reset must clear the manager crash status.")
	_expect(not manager.is_complete(), "Reset must clear the manager completion status.")
	_expect(
		is_zero_approx(manager.rider_state.completion_time_remaining),
		"Reset must clear the completion countdown."
	)
	_expect(
		(
			not manager.rider_state.compression_active
			and is_zero_approx(manager.rider_state.compression_amount)
			and manager.rider_state.compression_release_progress < 0.0
			and is_zero_approx(manager.rider_state.compression_release_quality)
			and not manager.rider_state.compression_auto_released
			and is_zero_approx(manager.rider_state.takeoff_pop_impulse)
		),
		"Reset must clear compression and pop state."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
