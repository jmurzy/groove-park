## Owns pause dialog and controls-overlay lifetime for gameplay.
class_name PauseFlowController
extends RefCounted

signal abort_requested

const PauseMenuScene := preload("res://src/presentation/gameplay/pause_menu.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")

var _game_session: GameSession
var _owner: Node
var _ui_layer: CanvasLayer
var _pause_menu: PauseMenu
var _controls_screen: HowToPlayScreen
var _audio_manager: AudioManager


func setup(
	owner: Node, game_session: GameSession, ui_layer: CanvasLayer, audio_manager: AudioManager
) -> void:
	_owner = owner
	_game_session = game_session
	_ui_layer = ui_layer
	_audio_manager = audio_manager


func is_open() -> bool:
	return _pause_menu != null


func request_open(tree: SceneTree) -> void:
	if _pause_menu:
		return
	_game_session.set_paused(true)
	tree.paused = true
	_pause_menu = PauseMenuScene.new()
	_pause_menu.audio_manager = _audio_manager
	_pause_menu.resume_requested.connect(close)
	_pause_menu.controls_requested.connect(_open_controls)
	_pause_menu.abort_requested.connect(abort_requested.emit)
	_ui_layer.add_child(_pause_menu)


func close() -> void:
	if not _pause_menu:
		return
	_owner.get_tree().paused = false
	_game_session.set_paused(false)
	_pause_menu.queue_free()
	_pause_menu = null


func close_for_navigation(tree: SceneTree) -> void:
	tree.paused = false
	_game_session.set_paused(false)


func accepts_screen_input() -> bool:
	return _controls_screen == null and _pause_menu == null


func _open_controls() -> void:
	if _controls_screen:
		return
	# Process mode does not release focused GUI buttons, which consume directional
	# input ahead of How to Play overlay.
	_pause_menu.get_viewport().gui_release_focus()
	# This prevents the pause menu's _unhandled_input() from receiving actions
	# that How To Play does not consume.
	_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	_controls_screen = HowToPlayScreenScene.new()
	_controls_screen.audio_manager = _audio_manager
	_controls_screen.closed.connect(_close_controls)
	_ui_layer.add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	_audio_manager.play_back()
	if is_instance_valid(_pause_menu):
		_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		_pause_menu.show()
		_pause_menu.focus_controls_button()
