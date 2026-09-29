## Swaps the primary window between attract and gameplay presentation.
class_name ScreenFlowController
extends Node

signal quit_requested

const PrimaryScreenScene := preload("res://src/presentation/attract/primary_screen.gd")
const GameplayScreenScene := preload("res://src/presentation/gameplay/gameplay_screen.gd")
const CrtTransitionScene := preload("res://src/presentation/effects/crt_transition.gd")

var _game_session: GameSession
var _audio_manager: AudioManager
var _liftie_state_service: LiftieStateService
var _primary_screen_index := 0
var _show_terrain := false
var _show_diagnostics := false
var _primary_view: PrimaryScreen
var _gameplay_screen: GameplayScreen
var _transitioning := false


func setup(
	game_session: GameSession,
	audio_manager: AudioManager,
	liftie_state_service: LiftieStateService,
	primary_screen_index: int,
	show_terrain: bool,
	show_diagnostics: bool
) -> void:
	_game_session = game_session
	_audio_manager = audio_manager
	_liftie_state_service = liftie_state_service
	_primary_screen_index = primary_screen_index
	_show_terrain = show_terrain
	_show_diagnostics = show_diagnostics
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


func _start_game(rider_kind: StringName) -> void:
	if _transitioning or _primary_view == null:
		return
	_transitioning = true
	_audio_manager.play_confirmation()
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
	_gameplay_screen.show_terrain = _show_terrain
	_gameplay_screen.return_to_title_requested.connect(_return_to_attract)
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
	_gameplay_screen.queue_free()
	_gameplay_screen = null
	_audio_manager.play_confirmation()
	_audio_manager.play_background_music()
	_game_session.return_to_attract()
	_show_attract()


func _show_attract() -> void:
	_primary_view = PrimaryScreenScene.new()
	_primary_view.screen_index = _primary_screen_index
	_primary_view.liftie_state_service = _liftie_state_service
	_primary_view.show_diagnostics = _show_diagnostics
	_primary_view.start_game_requested.connect(_start_game)
	_primary_view.exit_requested.connect(quit_requested.emit)
	add_child(_primary_view)
