## Headless checks for gameplay terminal controls and release-deadline presentation.
extends SceneTree

const GameplayInputControllerScene := preload(
	"res://src/presentation/gameplay/gameplay_input_controller.gd"
)
const ReleaseDeadlineWarningScene := preload(
	"res://src/presentation/gameplay/release_deadline_warning.gd"
)
const RiderStateScene := preload("res://src/game/park/rider_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_tally_start_continues_and_active_start_pauses()
	_test_r_key_requires_terrain_debug_mode()
	_test_release_deadline_warning_visibility()
	if _failures.is_empty():
		print("Gameplay presentation checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_tally_start_continues_and_active_start_pauses() -> void:
	var controller := GameplayInputControllerScene.new()
	var session := GameSession.new()
	session.start_game(RiderKind.SKIER)
	var start_event := InputEventAction.new()
	start_event.action = &"controller_start"
	start_event.pressed = true
	_expect(
		controller.screen_command(start_event, session) == &"pause",
		"Start must pause an active run."
	)
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
	session.step_run(RiderInputFrame.new(), 0.0)
	_expect(
		controller.screen_command(start_event, session) == &"continue",
		"Start must continue a completed jump tally."
	)
	session.free()


func _test_r_key_requires_terrain_debug_mode() -> void:
	var controller := GameplayInputControllerScene.new()
	var session := GameSession.new()
	session.start_game(RiderKind.SKIER)
	var restart_event := InputEventKey.new()
	restart_event.keycode = KEY_R
	restart_event.pressed = true
	_expect(
		controller.screen_command(restart_event, session).is_empty(),
		"R must not restart a normal gameplay run."
	)
	controller.configure(true)
	_expect(
		controller.screen_command(restart_event, session) == &"restart",
		"R must restart an active run when terrain debug mode is enabled."
	)
	session.free()


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
