## Owns pause dialog and controls-overlay lifetime for gameplay.
class_name PauseFlowController
extends RefCounted

signal abandon_requested

const PauseMenuScene := preload("res://src/presentation/gameplay/pause_menu.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")

var _game_controller: GameController
var _owner: Node
var _ui_layer: CanvasLayer
var _pause_menu: PauseMenu
var _controls_screen: HowToPlayScreen
var _back_sound: AudioStreamPlayer


func setup(owner: Node, game_controller: GameController, ui_layer: CanvasLayer) -> void:
	_owner = owner
	_game_controller = game_controller
	_ui_layer = ui_layer
	_back_sound = AudioStreamPlayer.new()
	_back_sound.name = "BackSound"
	_back_sound.stream = BACK_SOUND
	owner.add_child(_back_sound)


func is_open() -> bool:
	return _pause_menu != null


func request_open(tree: SceneTree) -> void:
	if _pause_menu:
		return
	_game_controller.set_paused(true)
	tree.paused = true
	_pause_menu = PauseMenuScene.new()
	_pause_menu.resume_requested.connect(close)
	_pause_menu.controls_requested.connect(_open_controls)
	_pause_menu.abandon_requested.connect(abandon_requested.emit)
	_ui_layer.add_child(_pause_menu)


func close() -> void:
	if not _pause_menu:
		return
	_owner.get_tree().paused = false
	_game_controller.set_paused(false)
	_pause_menu.queue_free()
	_pause_menu = null


func close_for_navigation(tree: SceneTree) -> void:
	tree.paused = false
	_game_controller.set_paused(false)


func accepts_screen_input() -> bool:
	return _controls_screen == null and _pause_menu == null


func _open_controls() -> void:
	if _controls_screen:
		return
	_controls_screen = HowToPlayScreenScene.new()
	_controls_screen.closed.connect(_close_controls)
	_ui_layer.add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	if is_instance_valid(_back_sound):
		_back_sound.play()
	if is_instance_valid(_pause_menu):
		_pause_menu.focus_controls_button()
