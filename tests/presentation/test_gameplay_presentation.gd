## Headless checks for gameplay terminal controls and release-deadline presentation.
extends SceneTree

const ShippedParkCourse := preload("res://src/game/park/park_course.tres")
const GameplayInputControllerScene := preload(
	"res://src/presentation/gameplay/gameplay_input_controller.gd"
)
const ReleaseDeadlineWarningScene := preload(
	"res://src/presentation/gameplay/release_deadline_warning.gd"
)
const RiderRunManagerScene := preload("res://src/game/park/rider_run_manager.gd")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_terminal_start_restarts_and_active_start_pauses()
	_test_r_key_restarts()
	_test_release_deadline_warning_visibility()
	if _failures.is_empty():
		print("Gameplay presentation checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_terminal_start_restarts_and_active_start_pauses() -> void:
	var controller := GameplayInputControllerScene.new()
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	var start_event := InputEventAction.new()
	start_event.action = &"controller_start"
	start_event.pressed = true
	_expect(
		controller.screen_command(start_event, manager) == &"pause",
		"Start must pause an active run."
	)
	manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	_expect(
		controller.screen_command(start_event, manager) == &"restart",
		"Start must restart a completed run."
	)


func _test_r_key_restarts() -> void:
	var controller := GameplayInputControllerScene.new()
	var manager := RiderRunManagerScene.new()
	manager.setup(ShippedParkCourse)
	var restart_event := InputEventKey.new()
	restart_event.keycode = KEY_R
	restart_event.pressed = true
	_expect(
		controller.screen_command(restart_event, manager) == &"restart", "R must restart a run."
	)


func _test_release_deadline_warning_visibility() -> void:
	var warning := ReleaseDeadlineWarningScene.new()
	var state := RiderStateScene.new()
	state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	state.jump.release_deadline_y = 1000.0
	state.kinematics.course_progress = 500.0
	state.kinematics.vertical_position = 850.0
	state.kinematics.vertical_speed = 100.0
	warning.update_from_state(state)
	_expect(warning.visible, "The release deadline must appear during the descending approach.")
	_expect(
		warning.position == Vector2(500.0, 1000.0),
		"The warning must render at the captured lip height."
	)
	state.jump.trick_tracker.start_grab()
	warning.update_from_state(state)
	_expect(warning.modulate == Color("ff4d68"), "An active grab must make the deadline urgent.")
	state.kinematics.vertical_speed = -100.0
	warning.update_from_state(state)
	_expect(not warning.visible, "The warning must hide while ascending.")
	state.kinematics.vertical_speed = 100.0
	state.kinematics.vertical_position = 779.0
	warning.update_from_state(state)
	_expect(not warning.visible, "The warning must hide outside its approach distance.")
	state.kinematics.vertical_position = 850.0
	state.jump.release_deadline_crossed = true
	warning.update_from_state(state)
	_expect(not warning.visible, "The warning must hide after the deadline crossing.")
	warning.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
