## Coordinates primary-menu overlays and translates their actions into app navigation.
class_name PrimaryScreen
extends Control

signal start_game_requested(rider_kind: StringName)
signal exit_requested

const AttractBackdropScene := preload("res://src/presentation/attract/attract_backdrop.gd")
const AttractMenuScene := preload("res://src/presentation/attract/attract_menu.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service: LiftieStateService
var _menu: AttractMenu
var _player_select: PlayerSelectScreen
var _controls_screen: HowToPlayScreen
var _back_sound: AudioStreamPlayer


func _ready() -> void:
	name = "PrimaryView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := AttractBackdropScene.new()
	backdrop.screen_index = screen_index
	backdrop.show_diagnostics = show_diagnostics
	add_child(backdrop)
	_menu = AttractMenuScene.new()
	_menu.start_requested.connect(_open_player_select)
	_menu.controls_requested.connect(_open_controls)
	_menu.exit_requested.connect(exit_requested.emit)
	add_child(_menu)
	_back_sound = AudioStreamPlayer.new()
	_back_sound.name = "BackSound"
	_back_sound.stream = BACK_SOUND
	add_child(_back_sound)


func handle_escape() -> bool:
	if _controls_screen:
		_close_controls()
		return true
	if _player_select:
		_close_player_select()
		return true
	return false


func _open_player_select() -> void:
	if _player_select or _controls_screen:
		return
	_menu.play_confirmation()
	_menu.hide()
	_player_select = PlayerSelectScreen.new()
	_player_select.confirmed.connect(_on_player_select_confirmed)
	_player_select.cancelled.connect(_close_player_select)
	add_child(_player_select)
	_player_select.focus_default()


func _close_player_select() -> void:
	if not _player_select:
		return
	_player_select.queue_free()
	_player_select = null
	_menu.show()
	_menu.focus_default()


func _open_controls() -> void:
	if _controls_screen or _player_select:
		return
	_menu.play_confirmation()
	_controls_screen = HowToPlayScreenScene.new()
	_controls_screen.closed.connect(_close_controls)
	add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	_back_sound.play()
	_menu.focus_controls()


func _on_player_select_confirmed(rider_kind: StringName) -> void:
	if not _player_select:
		return
	_player_select = null
	start_game_requested.emit(rider_kind)


func _unhandled_input(event: InputEvent) -> void:
	if _player_select or _controls_screen:
		return
	if event.is_action_pressed(&"controller_start"):
		_open_player_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"action_y"):
		_open_controls()
		get_viewport().set_input_as_handled()
