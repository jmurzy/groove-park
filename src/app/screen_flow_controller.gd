## Swaps the primary window between attract and gameplay presentation.
class_name ScreenFlowController
extends Node

signal quit_requested

const PrimaryScreenScene := preload("res://src/presentation/attract/primary_screen.gd")
const GameplayScreenScene := preload("res://src/presentation/gameplay/gameplay_screen.gd")
const CrtTransitionScene := preload("res://src/presentation/effects/crt_transition.gd")
const PostRoundFlowControllerScene := preload("res://src/app/post_round_flow_controller.gd")

var _game_session: GameSession
var _input_router: InputRouter
var _audio_manager: AudioManager
var _liftie_state_service: LiftieStateService
var _leaderboard_repository: LeaderboardRepository
var _post_round_flow: PostRoundFlowController
var _primary_screen_index := 0
var _options: DevOptions
var _primary_view: PrimaryScreen
var _gameplay_screen: GameplayScreen
var _transitioning := false


func setup(
	game_session: GameSession,
	input_router: InputRouter,
	audio_manager: AudioManager,
	liftie_state_service: LiftieStateService,
	leaderboard_repository: LeaderboardRepository,
	primary_screen_index: int,
	options: DevOptions
) -> void:
	assert(
		leaderboard_repository != null, "ScreenFlowController requires a leaderboard repository."
	)
	_game_session = game_session
	_input_router = input_router
	_audio_manager = audio_manager
	_liftie_state_service = liftie_state_service
	_leaderboard_repository = leaderboard_repository
	_primary_screen_index = primary_screen_index
	_options = options
	_post_round_flow = PostRoundFlowControllerScene.new()
	_post_round_flow.setup(_game_session, _leaderboard_repository)
	_post_round_flow.submission_started.connect(_on_submission_started)
	add_child(_post_round_flow)
	_game_session.phase_changed.connect(_on_session_phase_changed)
	_game_session.jump_started.connect(_on_jump_started)
	_show_attract()


func handle_exit_input() -> bool:
	if _primary_view and _primary_view.handle_escape():
		return true
	if _gameplay_screen:
		if _gameplay_screen.is_exit_confirmation_open():
			_gameplay_screen.close_exit_confirmation()
		else:
			_gameplay_screen.request_exit_confirmation()
		return true
	return false


func _process(delta: float) -> void:
	_game_session.advance(delta)


func _start_game(rider_kind: StringName) -> void:
	if _transitioning or _primary_view == null:
		return
	_transitioning = true
	_audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	var transition := CrtTransitionScene.new()
	transition.midpoint_reached.connect(_show_gameplay.bind(rider_kind, transition))
	transition.finished.connect(_finish_transition.bind(transition))
	add_child(transition)


func _show_gameplay(rider_kind: StringName, transition: CrtTransition) -> void:
	_primary_view.queue_free()
	_primary_view = null
	_game_session.start_game(rider_kind)
	_gameplay_screen = GameplayScreenScene.new()
	_gameplay_screen.game_session = _game_session
	_gameplay_screen.input_router = _input_router
	_gameplay_screen.audio_manager = _audio_manager
	_gameplay_screen.designer_mode = _options.designer_mode
	_gameplay_screen.return_to_title_requested.connect(_return_to_attract)
	_gameplay_screen.new_round_requested.connect(_start_new_round)
	_gameplay_screen.player_name_submission_requested.connect(_post_round_flow.submit_player_name)
	add_child(_gameplay_screen)
	move_child(_gameplay_screen, transition.get_index())
	_audio_manager.stop_background_music()


func _finish_transition(transition: CrtTransition) -> void:
	transition.queue_free()
	_transitioning = false


func _return_to_attract() -> void:
	if _gameplay_screen == null:
		return
	get_tree().paused = false
	_post_round_flow.cancel()
	_gameplay_screen.set_process(false)
	_gameplay_screen.set_physics_process(false)
	_gameplay_screen.queue_free()
	_gameplay_screen = null
	_audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	_audio_manager.play_background_music()
	_game_session.return_to_attract()
	_input_router.release_owner()
	_show_attract()


func _start_new_round() -> void:
	_return_to_attract()
	if _primary_view:
		_primary_view.call_deferred("show_rider_select")


func _on_session_phase_changed(phase: int) -> void:
	if _gameplay_screen == null:
		return
	if phase == RoundState.SessionPhase.CRASH_RESCUE:
		_gameplay_screen.start_crash_rescue()
	elif phase == RoundState.SessionPhase.GAME_OVER:
		_audio_manager.duck_gameplay_sfx_for_post_round()
		_audio_manager.play_event(AudioManager.Event.GAME_OVER)
		_gameplay_screen.show_game_over()
	elif phase == RoundState.SessionPhase.QUALIFYING:
		_gameplay_screen.show_qualification_pending()
		_post_round_flow.check_qualification()
	elif phase == RoundState.SessionPhase.NAME_ENTRY:
		_audio_manager.play_event(AudioManager.Event.HIGH_SCORE)
		_gameplay_screen.show_name_entry()
	elif phase == RoundState.SessionPhase.ROUND_RESULTS:
		_audio_manager.play_event(AudioManager.Event.RESULTS_REVEAL)
		_gameplay_screen.show_round_results()
	elif phase == RoundState.SessionPhase.ATTRACT:
		_return_to_attract()


func _on_jump_started(_round_state: RoundState) -> void:
	_connect_run_audio(_game_session.run_manager)
	_audio_manager.play_event(AudioManager.Event.JUMP_START)


func _connect_run_audio(run_manager: RiderRunManager) -> void:
	run_manager.event_emitted.connect(_audio_manager.play_event)
	run_manager.loop_event_started.connect(_audio_manager.play_loop_event)
	run_manager.loop_event_updated.connect(_audio_manager.update_loop_event)
	run_manager.loop_event_stopped.connect(_audio_manager.stop_loop_event)


func _show_attract() -> void:
	_primary_view = PrimaryScreenScene.new()
	_primary_view.screen_index = _primary_screen_index
	_primary_view.liftie_state_service = _liftie_state_service
	_primary_view.input_router = _input_router
	_primary_view.audio_manager = _audio_manager
	_primary_view.show_diagnostics = _options.show_diagnostics
	_primary_view.start_game_requested.connect(_start_game)
	_primary_view.exit_requested.connect(quit_requested.emit)
	add_child(_primary_view)


func _on_submission_started() -> void:
	if _gameplay_screen:
		_gameplay_screen.set_name_submitting()
