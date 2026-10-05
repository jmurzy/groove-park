## Headless integration checks for terminal round screen flow and navigation cleanup.
extends SceneTree

const ScreenFlowControllerScene := preload("res://src/app/screen_flow_controller.gd")
const CrtTransitionScene := preload("res://src/presentation/effects/crt_transition.gd")

var _failures := PackedStringArray()


class Fixture:
	extends RefCounted
	var session: GameSession
	var input_router: InputRouter
	var audio_manager: AudioManager
	var flow: ScreenFlowController


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_terminal_phase_signals_and_timeout_cleanup()
	await _test_results_start_opens_a_new_rider_select_flow()
	_test_results_back_returns_to_attract()
	if _failures.is_empty():
		print("Screen-flow controller checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_terminal_phase_signals_and_timeout_cleanup() -> void:
	var fixture := _gameplay_fixture()
	_complete_crash(fixture.session)
	_expect(
		fixture.flow._gameplay_screen._game_over_screen != null,
		"A GAME_OVER phase signal must present the game-over screen."
	)
	var run_phase := fixture.session.run_manager.rider_state.run.run_phase
	fixture.flow._gameplay_screen._physics_process(1.0)
	_expect(
		fixture.session.run_manager.rider_state.run.run_phase == run_phase,
		"Gameplay physics must remain inactive during game over."
	)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	_expect(
		fixture.flow._gameplay_screen._round_results_screen != null,
		"A ROUND_RESULTS phase signal must replace game over with round results."
	)
	fixture.session.advance(GameSession.ROUND_RESULTS_AUTO_RETURN_TIMEOUT)
	_expect(
		fixture.flow._gameplay_screen == null and fixture.flow._primary_view != null,
		"The results timeout must clean up gameplay and return to attract."
	)
	_expect(
		not fixture.input_router.has_owner(), "Returning to attract must release the input owner."
	)
	_free_fixture(fixture)


func _test_results_start_opens_a_new_rider_select_flow() -> void:
	var fixture := _gameplay_fixture()
	_complete_crash(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	fixture.flow._gameplay_screen._unhandled_input(_button_event(JOY_BUTTON_START))
	await process_frame
	_expect(
		(
			fixture.flow._gameplay_screen == null
			and fixture.flow._primary_view != null
			and fixture.flow._primary_view._player_select != null
		),
		"Start from results must replace gameplay with the rider-select flow."
	)
	_expect(not fixture.input_router.has_owner(), "A new round flow must release the prior owner.")
	_free_fixture(fixture)


func _test_results_back_returns_to_attract() -> void:
	var fixture := _gameplay_fixture()
	_complete_crash(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	fixture.flow._gameplay_screen._unhandled_input(_button_event(JOY_BUTTON_BACK))
	_expect(
		fixture.flow._gameplay_screen == null and fixture.flow._primary_view != null,
		"Back from results must return to attract."
	)
	_expect(not fixture.input_router.has_owner(), "Back to attract must release the input owner.")
	_free_fixture(fixture)


func _gameplay_fixture() -> Fixture:
	var fixture := Fixture.new()
	fixture.session = GameSession.new()
	fixture.input_router = InputRouter.new()
	fixture.input_router.configure(true)
	fixture.input_router.claim_from_rider_select(_button_event(JOY_BUTTON_A))
	fixture.audio_manager = AudioManager.new()
	fixture.audio_manager.configure()
	fixture.flow = ScreenFlowControllerScene.new()
	get_root().add_child(fixture.session)
	get_root().add_child(fixture.input_router)
	get_root().add_child(fixture.audio_manager)
	get_root().add_child(fixture.flow)
	fixture.flow.setup(
		fixture.session,
		fixture.input_router,
		fixture.audio_manager,
		LiftieStateService.new(),
		0,
		DevOptions.new()
	)
	var transition := CrtTransitionScene.new()
	transition.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.flow.add_child(transition)
	fixture.flow._show_gameplay(RiderKind.SKIER, transition)
	return fixture


func _complete_crash(session: GameSession) -> void:
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CRASH
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	session.step_run(RiderInputFrame.new(), 0.0)


func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 1
	event.button_index = button
	event.pressed = true
	return event


func _free_fixture(fixture: Fixture) -> void:
	fixture.flow.free()
	fixture.audio_manager.free()
	fixture.input_router.free()
	fixture.session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
