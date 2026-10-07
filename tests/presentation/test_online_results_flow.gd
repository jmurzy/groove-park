## Headless checks for the post-round leaderboard and player-name branches.
extends SceneTree

const PlayerNameEntryScreenScene := preload(
	"res://src/presentation/results/player_name_entry_screen.gd"
)

var _failures := PackedStringArray()
var _confirmed_names := PackedStringArray()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_qualification_branches()
	_test_submission_branches()
	await _test_name_entry_normalizes_and_confirms_once()
	if _failures.is_empty():
		print("Online results-flow checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_qualification_branches() -> void:
	var session := _completed_session()
	session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	_expect(
		session.session_phase == RoundState.SessionPhase.QUALIFYING,
		"Game over must enter qualification exactly once."
	)
	var qualified := LeaderboardQualification.new()
	qualified.qualified = true
	_expect(session.qualification_available(qualified), "A valid qualification must be accepted.")
	_expect(
		(
			session.session_phase == RoundState.SessionPhase.NAME_ENTRY
			and session.leaderboard().is_qualified()
		),
		"A qualifying score must enter name entry."
	)
	session.free()

	var offline_session := _completed_session()
	offline_session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	_expect(
		offline_session.qualification_unavailable(),
		"Unavailable qualification must resolve locally."
	)
	_expect(
		(
			offline_session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and offline_session.leaderboard().status() == Leaderboard.Status.OFFLINE
		),
		"Offline qualification must bypass name entry and preserve local results."
	)
	offline_session.free()


func _test_submission_branches() -> void:
	var session := _completed_session()
	session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	var qualification := LeaderboardQualification.new()
	qualification.qualified = true
	session.qualification_available(qualification)
	var accepted := LeaderboardSubmissionResult.new()
	accepted.rank = 2
	_expect(session.submission_succeeded(accepted), "Accepted submission must resolve once.")
	_expect(
		(
			session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and session.leaderboard().rank() == 2
		),
		"Accepted submission must expose its server rank in results."
	)
	session.free()

	var failed_session := _completed_session()
	failed_session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	failed_session.qualification_available(qualification)
	_expect(failed_session.submission_failed(), "A failed submission must resolve once.")
	_expect(
		(
			failed_session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and failed_session.leaderboard().status() == Leaderboard.Status.OFFLINE
		),
		"A failed submission must mark the leaderboard offline."
	)
	failed_session.free()

	var skipped_session := _completed_session()
	skipped_session.advance(GameSession.GAME_OVER_AUTO_ADVANCE_DELAY)
	skipped_session.qualification_available(qualification)
	_expect(skipped_session.name_entry_skipped(), "A player must be able to skip name entry.")
	_expect(
		(
			skipped_session.session_phase == RoundState.SessionPhase.ROUND_RESULTS
			and skipped_session.leaderboard().is_qualified()
			and skipped_session.leaderboard().rank() == null
		),
		"Skipping name entry must show round results with a skipped leaderboard state."
	)
	skipped_session.free()


func _test_name_entry_normalizes_and_confirms_once() -> void:
	var screen := PlayerNameEntryScreenScene.new()
	screen.confirmed.connect(_on_name_confirmed)
	get_root().add_child(screen)
	await process_frame
	screen._accept_character("!")
	screen._accept_character("z")
	_expect(
		screen._name.begins_with("Z"),
		"Name entry must accept only normalized supported characters."
	)
	screen._confirm()
	screen._confirm()
	_expect(_confirmed_names.size() == 1, "Confirm must emit one submission while it is in flight.")
	screen.free()


func _completed_session() -> GameSession:
	var session := GameSession.new()
	session.start_game(RiderKind.SKIER)
	for _jump in range(RoundState.MAX_JUMPS):
		session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
		session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
		session.step_run(RiderInputFrame.new(), 0.0)
		session.complete_tally()
	return session


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_name_confirmed(player_name: String) -> void:
	_confirmed_names.append(player_name)
