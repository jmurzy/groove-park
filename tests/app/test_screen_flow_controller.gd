## Headless integration checks for terminal round screen flow and navigation cleanup.
extends SceneTree

const ScreenFlowControllerScene := preload("res://src/app/screen_flow_controller.gd")
const CrtTransitionScene := preload("res://src/presentation/effects/crt_transition.gd")
const GameArgsScene := preload("res://src/app/game_args.gd")

var _failures := PackedStringArray()


class Fixture:
	extends RefCounted
	var session: GameSession
	var input_router: InputRouter
	var audio_manager: AudioManager
	var flow: ScreenFlowController
	var leaderboard_repository: FakeLeaderboardRepository


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await _test_terminal_phase_signals_and_timeout_cleanup()
	_test_non_crash_game_over_skips_rescue()
	await _test_synchronous_leaderboard_flow_replaces_screens()
	await _test_non_qualifying_round_displays_shared_leaderboard()
	await _test_submission_reaches_results_before_leaderboard_fetch_completes()
	await _test_submission_succeeds_when_board_fetch_fails()
	await _test_offline_qualification_reaches_local_results()
	await _test_leaving_pending_qualification_cancels_request()
	await _test_leaving_pending_submission_cancels_request()
	await _test_results_start_opens_a_new_rider_select_flow()
	await _test_results_back_returns_to_attract()
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
		fixture.session.session_phase == RoundState.SessionPhase.CRASH_RESCUE,
		"A crash rescue phase must start the rescue presentation exactly once."
	)
	_expect(
		fixture.flow._gameplay_screen._game_over_screen == null,
		"The game-over screen must wait until rescue presentation completes."
	)
	var run_phase := fixture.session.run_manager.rider_state.run.run_phase
	fixture.flow._gameplay_screen._physics_process(1.0)
	_expect(
		fixture.session.run_manager.rider_state.run.run_phase == run_phase,
		"Gameplay physics must remain inactive during game over."
	)
	_complete_rescue(fixture.session)
	_expect(
		fixture.flow._gameplay_screen._game_over_screen != null,
		"Completing rescue must present the game-over screen."
	)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
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
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
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


func _test_non_crash_game_over_skips_rescue() -> void:
	var fixture := _gameplay_fixture()
	_complete_non_crash_round(fixture.session)
	_expect(
		fixture.session.session_phase == RoundState.SessionPhase.GAME_OVER,
		"A non-crash terminal outcome must never start the rescue sequence."
	)
	_expect(
		fixture.flow._gameplay_screen._game_over_screen != null,
		"A completed non-crash round must present game over without rescue."
	)
	_free_fixture(fixture)


func _test_synchronous_leaderboard_flow_replaces_screens() -> void:
	var fixture := _gameplay_fixture(true)
	_complete_crash(fixture.session, true)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	_expect(
		fixture.session.session_phase == RoundState.SessionPhase.QUALIFYING,
		"A completed qualification response must wait for the minimum pending display duration."
	)
	await _await_qualification_completion(fixture)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.NAME_ENTRY
			and fixture.flow._gameplay_screen._player_name_entry_screen != null
		),
		"A synchronous qualifying response must replace game over with name entry."
	)
	fixture.flow._gameplay_screen.player_name_submission_requested.emit("PLAYER")
	await _await_repository_completions(fixture)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and fixture.flow._gameplay_screen._round_results_screen != null
			and fixture.session.leaderboard().status() == Leaderboard.Status.OK
			and fixture.session.leaderboard().top_entries().size() == 1
			and (
				(
					fixture
					. flow
					. _gameplay_screen
					. _round_results_screen
					. _leaderboard
					. top_entries()
					. size()
				)
				== 1
			)
		),
		"Round results must fetch leaderboard entries independently of submission."
	)
	_expect(
		(
			(
				fixture
				. flow
				. _gameplay_screen
				. _round_results_screen
				. _leaderboard_overlay
				. _highlighted_rank
			)
			== fixture.session.leaderboard().rank()
		),
		"An accepted submission must highlight its server-returned rank in the fetched leaderboard."
	)
	_free_fixture(fixture)


func _test_non_qualifying_round_displays_shared_leaderboard() -> void:
	var fixture := _gameplay_fixture(true)
	for rank in range(10):
		fixture.leaderboard_repository.entries.append(_leaderboard_entry(rank + 1, 100 - rank))
	_complete_crash(fixture.session)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	await _await_repository_completions(fixture)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and fixture.session.leaderboard().is_qualified() == false
			and fixture.flow._gameplay_screen._round_results_screen._leaderboard_overlay != null
			and (
				(
					fixture
					. flow
					. _gameplay_screen
					. _round_results_screen
					. _leaderboard
					. top_entries()
					. size()
				)
				== 10
			)
		),
		"A non-qualifying online round must display the independently fetched shared leaderboard."
	)
	_free_fixture(fixture)


func _test_submission_succeeds_when_board_fetch_fails() -> void:
	var fixture := _gameplay_fixture(true)
	fixture.leaderboard_repository.are_top_entries_available = false
	_complete_crash(fixture.session, true)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	fixture.flow._gameplay_screen.player_name_submission_requested.emit("PLAYER")
	await _await_repository_completions(fixture)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and fixture.session.leaderboard().status() == Leaderboard.Status.OFFLINE
			and (
				fixture.flow._gameplay_screen._round_results_screen._leaderboard.status()
				== Leaderboard.Status.OFFLINE
			)
			and (
				fixture
				. flow
				. _gameplay_screen
				. _round_results_screen
				. _leaderboard
				. top_entries()
				. is_empty()
			)
		),
		"A failed leaderboard fetch must mark the leaderboard offline."
	)
	_free_fixture(fixture)


func _test_submission_reaches_results_before_leaderboard_fetch_completes() -> void:
	var fixture := _gameplay_fixture(true)
	_complete_crash(fixture.session, true)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	fixture.leaderboard_repository.deferred = true
	fixture.flow._gameplay_screen.player_name_submission_requested.emit("PLAYER")
	var submission_request := fixture.flow._post_round_flow._submission_request
	fixture.leaderboard_repository.complete_deferred(submission_request)
	await process_frame
	var top_entries_request := fixture.flow._post_round_flow._top_entries_request
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and fixture.flow._gameplay_screen._round_results_screen != null
			and fixture.flow._post_round_flow._top_entries_request != null
			and (
				fixture.flow._post_round_flow._top_entries_request.status
				== LeaderboardRepository.Request.Status.PENDING
			)
		),
		"An accepted submission must show results before its independent leaderboard fetch completes."
	)
	fixture.flow._return_to_attract()
	_expect(
		submission_request.status == LeaderboardRepository.Request.Status.SUCCEEDED,
		"Returning to attract must not cancel an already accepted submission."
	)
	_expect(
		(
			top_entries_request.status == LeaderboardRepository.Request.Status.CANCELLED
			and fixture.flow._post_round_flow._top_entries_request == null
		),
		"Returning to attract must cancel and clear the pending leaderboard display request."
	)
	fixture.leaderboard_repository.complete_deferred(top_entries_request)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ATTRACT
			and fixture.flow._gameplay_screen == null
			and fixture.flow._primary_view != null
		),
		"A late cancelled leaderboard response must not restore results or update the attract screen."
	)
	_free_fixture(fixture)


func _test_offline_qualification_reaches_local_results() -> void:
	var fixture := _gameplay_fixture(true)
	fixture.leaderboard_repository.is_available = false
	_complete_crash(fixture.session)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	await _await_repository_completions(fixture)
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and fixture.session.leaderboard().status() == Leaderboard.Status.OFFLINE
		),
		"An unavailable qualification request must reach offline local results."
	)
	_free_fixture(fixture)


func _test_leaving_pending_qualification_cancels_request() -> void:
	var fixture := _gameplay_fixture(true)
	fixture.leaderboard_repository.deferred = true
	_complete_crash(fixture.session)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	_expect(
		fixture.session.session_phase == RoundState.SessionPhase.QUALIFYING,
		"Deferred qualification must remain pending before navigation away."
	)
	var request := fixture.flow._post_round_flow._qualification_request
	fixture.flow._return_to_attract()
	await process_frame
	_expect(
		(
			request.status == LeaderboardRepository.Request.Status.CANCELLED
			and fixture.flow._post_round_flow._qualification_timer.is_stopped()
		),
		"Leaving qualification must cancel its request and stop its minimum-duration timer."
	)
	fixture.leaderboard_repository.complete_deferred(request)
	_expect(
		fixture.session.session_phase == RoundState.SessionPhase.ATTRACT,
		"A late cancelled qualification response must not change the new attract state."
	)
	_free_fixture(fixture)


func _test_leaving_pending_submission_cancels_request() -> void:
	var fixture := _gameplay_fixture(true)
	_complete_crash(fixture.session, true)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	await _await_repository_completions(fixture)
	fixture.leaderboard_repository.deferred = true
	fixture.flow._gameplay_screen.player_name_submission_requested.emit("PLAYER")
	var request := fixture.flow._post_round_flow._submission_request
	fixture.flow._return_to_attract()
	_expect(
		request.status == LeaderboardRepository.Request.Status.CANCELLED,
		"Leaving a pending submission must cancel its request."
	)
	fixture.leaderboard_repository.complete_deferred(request)
	await process_frame
	_expect(
		(
			fixture.session.session_phase == RoundState.SessionPhase.ATTRACT
			and fixture.flow._gameplay_screen == null
			and fixture.leaderboard_repository.entries.is_empty()
		),
		"A late cancelled submission must not restore results or mutate the board."
	)
	_free_fixture(fixture)


func _test_results_back_returns_to_attract() -> void:
	var fixture := _gameplay_fixture()
	_complete_crash(fixture.session)
	_complete_rescue(fixture.session)
	fixture.session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	await _await_qualification_completion(fixture)
	fixture.flow._gameplay_screen._unhandled_input(_button_event(JOY_BUTTON_BACK))
	_expect(
		fixture.flow._gameplay_screen == null and fixture.flow._primary_view != null,
		"Back from results must return to attract."
	)
	_expect(not fixture.input_router.has_owner(), "Back to attract must release the input owner.")
	_free_fixture(fixture)


func _await_qualification_completion(fixture: Fixture) -> void:
	while fixture.session.session_phase == RoundState.SessionPhase.QUALIFYING:
		await process_frame


func _await_repository_completions(fixture: Fixture) -> void:
	while (
		fixture.flow._post_round_flow._qualification_request
		or fixture.flow._post_round_flow._submission_request
		or fixture.flow._post_round_flow._top_entries_request
	):
		await process_frame
	await process_frame


func _gameplay_fixture(with_leaderboard_service := false) -> Fixture:
	var fixture := Fixture.new()
	fixture.session = GameSession.new()
	fixture.input_router = InputRouter.new()
	fixture.input_router.configure(true)
	fixture.input_router.claim_from_rider_select(_button_event(JOY_BUTTON_A))
	fixture.audio_manager = AudioManager.new()
	fixture.audio_manager.configure()
	fixture.leaderboard_repository = FakeLeaderboardRepository.new()
	fixture.leaderboard_repository.is_available = with_leaderboard_service
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
		fixture.leaderboard_repository,
		GameArgsScene.GameOptions.new()
	)
	var transition := CrtTransitionScene.new()
	transition.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.flow.add_child(transition)
	fixture.flow._show_gameplay(RiderKind.SKIER, transition)
	return fixture


func _complete_crash(session: GameSession, with_score := false) -> void:
	if with_score:
		var state := session.run_manager.rider_state
		state.run.jump_outcome = JumpOutcome.Value.CLEAN
		state.run.run_phase = RiderRunState.RunPhase.COMPLETE
		state.jump.takeoff_velocity = Vector2(450.0, -100.0)
		session.step_run(RiderInputFrame.new(), 0.0)
		session.complete_tally()
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CRASH
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	session.step_run(RiderInputFrame.new(), 0.0)


func _complete_non_crash_round(session: GameSession) -> void:
	for _jump_number in range(RoundState.MAX_JUMPS):
		session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
		session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
		session.step_run(RiderInputFrame.new(), 0.0)
		session.complete_tally()


func _complete_rescue(session: GameSession) -> void:
	session.advance(GameSession.CRASH_RESCUE_MINIMUM_DURATION)
	session.request_skip_crash_rescue()


func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 1
	event.button_index = button
	event.pressed = true
	return event


func _leaderboard_entry(rank: int, score: int) -> LeaderboardEntry:
	var entry := LeaderboardEntry.new()
	entry.round_id = "existing-round-%d" % rank
	entry.player_name = "RIDER%d" % rank
	entry.rider_kind = RiderKind.SKIER
	entry.total_score = score
	entry.platform = &"ags"
	entry.created_at = "test-%02d" % rank
	return entry


func _free_fixture(fixture: Fixture) -> void:
	fixture.flow.free()
	fixture.audio_manager.free()
	fixture.input_router.free()
	fixture.session.free()
	if fixture.leaderboard_repository:
		fixture.leaderboard_repository.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
