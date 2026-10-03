## Headless checks for gameplay terminal controls and release-deadline presentation.
extends SceneTree

const GameplayInputControllerScene := preload(
	"res://src/presentation/gameplay/gameplay_input_controller.gd"
)
const ReleaseDeadlineWarningScene := preload(
	"res://src/presentation/gameplay/release_deadline_warning.gd"
)
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_hud_displays_round_score_and_jump()
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


func _test_hud_displays_round_score_and_jump() -> void:
	var hud := GameplayHudScene.new()
	hud._ready()
	hud.set_round_score(450)
	hud.set_jump_number(2)
	_expect(hud.score_text() == "00450", "HUD must display the accumulated round score.")
	_expect(hud.jump_text() == "2 / 3", "HUD must display the current jump out of three.")
	hud.set_round_score(450)
	hud.set_jump_number(2)
	_expect(
		hud.score_text() == "00450" and hud.jump_text() == "2 / 3",
		"Resetting an unrecorded jump must preserve the session HUD values."
	)
	hud.free()


func _test_tally_start_continues_and_active_start_pauses() -> void:
	var controller := GameplayInputControllerScene.new()
	var session := GameSession.new()
	var input_router := _claimed_gamepad_router()
	session.start_game(RiderKind.SKIER)
	var start_event := _button_event(JOY_BUTTON_START)
	_expect(
		controller.screen_command(start_event, session, input_router) == &"pause",
		"Start must pause an active run."
	)
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
	session.step_run(RiderInputFrame.new(), 0.0)
	_expect(
		controller.screen_command(start_event, session, input_router) == &"continue",
		"Start must continue a completed jump tally."
	)
	var unowned_start_event := _button_event(JOY_BUTTON_START)
	unowned_start_event.device = 2
	_expect(
		controller.screen_command(unowned_start_event, session, input_router).is_empty(),
		"An unowned controller must not advance a tally."
	)
	session.free()


func _test_r_key_requires_terrain_debug_mode() -> void:
	var controller := GameplayInputControllerScene.new()
	var session := GameSession.new()
	var input_router := InputRouter.new()
	input_router.configure(true)
	var claim_event := InputEventKey.new()
	claim_event.keycode = KEY_J
	claim_event.pressed = true
	input_router.claim_from_rider_select(claim_event)
	session.start_game(RiderKind.SKIER)
	var restart_event := InputEventKey.new()
	restart_event.keycode = KEY_R
	restart_event.pressed = true
	_expect(
		controller.screen_command(restart_event, session, input_router).is_empty(),
		"R must not restart without terrain debug mode."
	)
	controller.configure(true)
	_expect(
		controller.screen_command(restart_event, session, input_router) == &"restart",
		"R must restart an active run when terrain debug mode is enabled."
	)
	session.free()


func _claimed_gamepad_router() -> InputRouter:
	var router := InputRouter.new()
	router.configure(true)
	var claim_event := _button_event(JOY_BUTTON_A)
	router.claim_from_rider_select(claim_event)
	return router


func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 1
	event.button_index = button
	event.pressed = true
	return event


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
