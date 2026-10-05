## Headless checks for authoritative round progression in GameSession.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_completed_simulation_records_each_outcome_once()
	_test_completed_run_freezes_and_scores_terminal_measurements()
	_test_active_run_previews_current_score()
	_test_restarting_an_unrecorded_run_discards_partial_measurements()
	_test_result_requires_a_completed_active_run_and_records_once()
	_test_non_crash_tallies_advance_through_three_jumps()
	_test_crash_completes_the_round_once()
	_test_crash_rescue_timeout_enters_game_over_once()
	_test_game_over_enters_local_round_results_once()
	_test_starting_and_bailing_rounds_reset_only_in_memory_round_data()
	_test_session_notifications_follow_mutation()
	if _failures.is_empty():
		print("Game-session checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_completed_simulation_records_each_outcome_once() -> void:
	var outcomes: Array[int] = [
		JumpOutcome.Value.LOW_MOMENTUM,
		JumpOutcome.Value.BAIL,
		JumpOutcome.Value.CLEAN,
		JumpOutcome.Value.SKETCHY,
		JumpOutcome.Value.CRASH,
	]
	for outcome: int in outcomes:
		var session := _active_session()
		var completed_run := session.run_manager
		completed_run.rider_state.run.jump_outcome = outcome
		completed_run.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
		session.step_run(RiderInputFrame.new(), 0.0)
		_expect(
			session.round_state().jump_results().size() == 1,
			"Each terminal outcome must record one result."
		)
		_expect(
			session.round_state().round_score() == 0,
			"Empty terminal measurements must resolve to zero score."
		)
		session.step_run(RiderInputFrame.new(), 0.0)
		_expect(
			session.round_state().jump_results().size() == 1,
			"Repeated completion frames must not duplicate a result."
		)
		if outcome == JumpOutcome.Value.CRASH:
			_expect(
				session.session_phase == RoundState.SessionPhase.CRASH_RESCUE,
				"A crash must enter rescue without a new run."
			)
		else:
			_expect(
				session.session_phase == RoundState.SessionPhase.JUMP_TALLY,
				"A non-crash result must enter tally."
			)
			session.complete_tally()
			_expect(
				session.run_manager != completed_run,
				"The next jump must receive fresh simulation state."
			)
			_expect(
				session.run_manager.rider_state.run.run_phase == RiderRunState.RunPhase.APPROACH,
				"A next jump must start in approach."
			)
		session.free()


func _test_completed_run_freezes_and_scores_terminal_measurements() -> void:
	var session := _active_session()
	var state := session.run_manager.rider_state
	state.run.jump_outcome = JumpOutcome.Value.CLEAN
	state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	state.jump.takeoff_velocity = Vector2(450.0, -100.0)
	state.jump.takeoff_pop_impulse = 130.0
	state.jump.airtime = 0.75
	state.jump.completed_rotations = 1
	state.jump.scored_grab_style = JumpSnapshot.GrabStyle.TWEAK
	state.jump.trick_tracker.valid_grab_duration = 0.4
	session.step_run(RiderInputFrame.new(), 0.0)
	var result: JumpResult = session.round_state().jump_results().front()
	_expect(result.resolved_score() == 686, "Completed runs must use their frozen score snapshot.")
	_expect(
		result.trick_summary() == "CLEAN 360 TWEAK GRAB",
		"Trick summaries must derive from the resolved result."
	)
	state.jump.airtime = 10.0
	state.jump.completed_rotations = 10
	session.step_run(RiderInputFrame.new(), 0.0)
	_expect(
		result.resolved_score() == 686 and result.snapshot().airtime() == 0.75,
		"Repeated completion frames cannot alter a recorded score."
	)
	session.free()


func _test_active_run_previews_current_score() -> void:
	var session := _active_session()
	var state := session.run_manager.rider_state
	state.jump.takeoff_velocity = Vector2(450.0, -100.0)
	state.jump.takeoff_pop_impulse = 130.0
	state.jump.airtime = 0.75
	state.jump.completed_rotations = 1
	state.jump.scored_grab_style = JumpSnapshot.GrabStyle.TWEAK
	state.jump.trick_tracker.valid_grab_duration = 0.4
	_expect(
		session.run_manager.preview_score(session.tuning()) == 686,
		"An active run must preview its current score as a clean landing."
	)
	_expect(
		session.round_state().round_score() == 0,
		"Previewing an active score must not mutate the authoritative round total."
	)
	session.free()


func _test_restarting_an_unrecorded_run_discards_partial_measurements() -> void:
	var session := _active_session()
	var state := session.run_manager.rider_state
	state.jump.takeoff_velocity.x = 900.0
	state.jump.airtime = 1.5
	state.jump.completed_rotations = 2
	session.restart_run()
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
	_complete_active_run(session)
	session.step_run(RiderInputFrame.new(), 0.0)
	var result: JumpResult = session.round_state().jump_results().front()
	_expect(
		result.resolved_score() == 0,
		"Restarting an unrecorded jump must discard partial score measurements."
	)
	session.free()


func _test_result_requires_a_completed_active_run_and_records_once() -> void:
	var session := _active_session()
	var result := _jump_result(JumpOutcome.Value.CLEAN, 120)
	_expect(
		not session.record_active_jump_result(result), "An incomplete run must not record a result."
	)
	_complete_active_run(session)
	_expect(
		session.record_active_jump_result(result), "A completed active run must record one result."
	)
	_expect(
		not session.record_active_jump_result(result),
		"Repeated completion observations must not record the result twice."
	)
	_expect(session.round_state().jump_results().size() == 1, "Only one result must be recorded.")
	_expect(
		session.session_phase == RoundState.SessionPhase.JUMP_TALLY,
		"A non-crash result must enter tally."
	)
	session.free()


func _test_non_crash_tallies_advance_through_three_jumps() -> void:
	var session := _active_session()
	_record_completed_result(session, JumpOutcome.Value.CLEAN, 100)
	_expect(session.complete_tally(), "The first tally must complete.")
	_expect(
		session.round_state().current_jump_number() == 2, "The first tally must advance to jump 2."
	)
	_expect(
		session.round_state().round_score() == 100, "Prior result score must survive the next jump."
	)
	_expect(not session.complete_tally(), "A next jump cannot advance before it records a result.")
	_record_completed_result(session, JumpOutcome.Value.SKETCHY, 50)
	_expect(session.complete_tally(), "The second tally must complete.")
	_expect(
		session.round_state().current_jump_number() == 3, "The second tally must advance to jump 3."
	)
	_record_completed_result(session, JumpOutcome.Value.BAIL, 0)
	_expect(session.complete_tally(), "The third tally must complete the round.")
	_expect(
		session.session_phase == RoundState.SessionPhase.GAME_OVER,
		"The third tally must enter game over."
	)
	_expect(
		session.round_state().jump_results().size() == 3,
		"A completed three-jump round must contain three results."
	)
	_expect(not session.complete_tally(), "Game over must not complete the final tally twice.")
	print("Session trace: JUMP 1 -> TALLY -> JUMP 2 -> TALLY -> JUMP 3 -> TALLY -> GAME OVER")
	session.free()


func _test_crash_completes_the_round_once() -> void:
	var session := _active_session()
	_complete_active_run(session)
	_expect(
		session.record_active_jump_result(_jump_result(JumpOutcome.Value.CRASH, 0)),
		"A completed crash must record."
	)
	_expect(
		session.session_phase == RoundState.SessionPhase.CRASH_RESCUE,
		"A crash must enter rescue without a tally."
	)
	_expect(not session.complete_tally(), "A crash must prevent later jumps from starting.")
	_expect(
		session.round_state().jump_results().size() == 1,
		"A crash must retain its recorded current-jump result."
	)
	session.free()


func _test_crash_rescue_timeout_enters_game_over_once() -> void:
	var session := _active_session()
	_record_completed_result(session, JumpOutcome.Value.CRASH, 0)
	session.advance(GameSession.CRASH_RESCUE_MINIMUM_DURATION - 0.01)
	_expect(
		session.session_phase == RoundState.SessionPhase.CRASH_RESCUE,
		"Rescue must remain active before its minimum duration."
	)
	_expect(
		not session.request_skip_crash_rescue(),
		"Rescue cannot be skipped before its minimum duration."
	)
	session.advance(0.01)
	_expect(
		session.request_skip_crash_rescue(),
		"Rescue must enter game over after its minimum duration."
	)
	_expect(
		session.session_phase == RoundState.SessionPhase.GAME_OVER,
		"Rescue completion must enter game over exactly once."
	)
	_expect(
		not session.request_skip_crash_rescue(), "A completed rescue cannot enter game over twice."
	)
	session.free()

	var timed_session := _active_session()
	_record_completed_result(timed_session, JumpOutcome.Value.CRASH, 0)
	timed_session.advance(GameSession.CRASH_RESCUE_AUTO_ADVANCE_TIMEOUT - 0.01)
	_expect(
		timed_session.session_phase == RoundState.SessionPhase.CRASH_RESCUE,
		"Rescue must remain active until its authoritative timeout."
	)
	timed_session.advance(0.01)
	_expect(
		timed_session.session_phase == RoundState.SessionPhase.GAME_OVER,
		"Rescue timeout must enter game over without presentation callbacks."
	)
	timed_session.free()


func _test_game_over_enters_local_round_results_once() -> void:
	for delta: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		var session := _active_session()
		_record_completed_result(session, JumpOutcome.Value.CLEAN, 100)
		session.complete_tally()
		_record_completed_result(session, JumpOutcome.Value.SKETCHY, 50)
		session.complete_tally()
		_record_completed_result(session, JumpOutcome.Value.BAIL, 0)
		session.complete_tally()
		session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY - delta)
		_expect(
			session.session_phase == RoundState.SessionPhase.GAME_OVER,
			"Game over must remain active until its authoritative delay expires."
		)
		session.advance(delta)
		_expect(
			session.session_phase == RoundState.SessionPhase.ROUND_RESULTS,
			"GameSession must enter round results after its deterministic game-over delay."
		)
		_expect(
			(
				session.round_state().round_score() == 150
				and session.round_state().jump_results().size() == 3
			),
			"Entering round results must preserve every immutable recorded result and total."
		)
		session.advance(GameSession.ROUND_RESULTS_AUTO_RETURN_TIMEOUT - delta)
		_expect(
			session.session_phase == RoundState.SessionPhase.ROUND_RESULTS,
			"Round results must remain active until their authoritative timeout expires."
		)
		session.advance(delta)
		_expect(
			(
				session.session_phase == RoundState.SessionPhase.ATTRACT
				and session.round_state() == null
			),
			"GameSession must return to attract after the deterministic results timeout."
		)
		session.free()


func _test_starting_and_bailing_rounds_reset_only_in_memory_round_data() -> void:
	var session := _active_session()
	_record_completed_result(session, JumpOutcome.Value.CLEAN, 200)
	session.start_game(RiderKind.SNOWBOARDER)
	_expect(
		session.round_state().rider_kind() == RiderKind.SNOWBOARDER,
		"Starting a new round must use the selected rider."
	)
	_expect(
		session.round_state().jump_results().is_empty(),
		"Starting a new round must clear prior results."
	)
	_expect(session.round_state().round_score() == 0, "Starting a new round must clear score.")
	session.return_to_attract()
	_expect(session.round_state() == null, "Returning to attract must bail the in-memory round.")
	_expect(
		session.session_phase == RoundState.SessionPhase.ATTRACT,
		"Returning to attract must enter attract phase."
	)
	session.free()


func _test_session_notifications_follow_mutation() -> void:
	var session := GameSession.new()
	var phase_events: Array[int] = []
	var jump_start_numbers: Array[int] = []
	var recorded_scores: Array[int] = []
	var completed_scores: Array[int] = []
	session.phase_changed.connect(func(phase: int) -> void: phase_events.append(phase))
	session.jump_started.connect(
		func(round_state: RoundState) -> void:
			jump_start_numbers.append(round_state.current_jump_number())
	)
	session.jump_result_recorded.connect(
		func(round_state: RoundState, jump_result: JumpResult) -> void:
			recorded_scores.append(round_state.round_score())
			_expect(
				round_state.jump_results().back() == jump_result,
				"Recorded-result notifications must observe the stored result."
			)
	)
	session.round_completed.connect(
		func(round_state: RoundState) -> void: completed_scores.append(round_state.round_score())
	)
	session.start_game(RiderKind.SKIER)
	_record_completed_result(session, JumpOutcome.Value.CLEAN, 80)
	session.complete_tally()
	_record_completed_result(session, JumpOutcome.Value.CRASH, 0)
	_expect(
		(
			phase_events
			== [
				RoundState.SessionPhase.JUMP_ACTIVE,
				RoundState.SessionPhase.JUMP_TALLY,
				RoundState.SessionPhase.JUMP_ACTIVE,
				RoundState.SessionPhase.CRASH_RESCUE,
			]
		),
		"Phase notifications must emit once after each accepted transition."
	)
	_expect(
		jump_start_numbers == [1, 2], "Jump-start notifications must identify each accepted jump."
	)
	_expect(
		recorded_scores == [80, 80],
		"Recorded-result notifications must observe derived round scores."
	)
	_expect(completed_scores == [80], "Crash completion must emit the completed round once.")
	session.free()


func _active_session() -> GameSession:
	var session := GameSession.new()
	session.start_game(RiderKind.SKIER)
	return session


func _record_completed_result(session: GameSession, outcome: int, score: int) -> void:
	_complete_active_run(session)
	_expect(
		session.record_active_jump_result(_jump_result(outcome, score)),
		"A completed active run must record its jump result."
	)


func _complete_active_run(session: GameSession) -> void:
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE


func _jump_result(outcome: int, score: int) -> JumpResult:
	var snapshot := _snapshot(outcome)
	var created := JumpResult.create(snapshot, JumpScore.new(0, 0, 0, 0, 0, 0, 1000, score))
	if not created.is_valid:
		_failures.append("Test fixture must create a valid jump result.")
		return null
	return created.value


func _snapshot(outcome: int) -> JumpSnapshot:
	var created := JumpSnapshot.create(outcome, 0.0, 0.0, 0.0, 0, JumpSnapshot.GrabStyle.NONE, 0.0)
	if not created.is_valid:
		_failures.append("Test fixture must create a valid score snapshot.")
		return null
	return created.value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
