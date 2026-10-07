## Coordinates primary-menu overlays and translates their actions into app navigation.
class_name PrimaryScreen
extends Control

signal start_game_requested(rider_kind: StringName)
signal exit_requested

const AttractBackdropScene := preload("res://src/presentation/attract/attract_backdrop.gd")
const AttractMenuScene := preload("res://src/presentation/attract/attract_menu.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const AttractIdleFlowControllerScene := preload("res://src/app/attract_idle_flow_controller.gd")

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service: LiftieStateService
var input_router: InputRouter
var audio_manager: AudioManager
var leaderboard_repository: LeaderboardRepository
var _idle_flow: AttractIdleFlowController
var _menu: AttractMenu
var _player_select: PlayerSelectScreen
var _controls_screen: HowToPlayScreen


func _ready() -> void:
	name = "PrimaryView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := AttractBackdropScene.new()
	backdrop.screen_index = screen_index
	backdrop.show_diagnostics = show_diagnostics
	add_child(backdrop)
	_menu = AttractMenuScene.new()
	_menu.audio_manager = audio_manager
	_menu.start_requested.connect(show_rider_select)
	_menu.controls_requested.connect(_open_controls)
	_menu.exit_requested.connect(exit_requested.emit)
	add_child(_menu)
	_idle_flow = AttractIdleFlowControllerScene.new()
	_idle_flow.name = "AttractIdleFlow"
	_idle_flow.setup(self, leaderboard_repository)
	_idle_flow.overlay_started.connect(_hide_menu_for_idle)
	_idle_flow.overlay_dismissed.connect(_restore_menu_after_idle)
	add_child(_idle_flow)
	_idle_flow.start_waiting()


func handle_escape() -> bool:
	if _controls_screen:
		_close_controls()
		return true
	if _player_select:
		_close_player_select()
		return true
	return false


func show_rider_select() -> void:
	if _player_select or _controls_screen:
		return
	_idle_flow.suspend()
	audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	_menu.hide()
	_player_select = PlayerSelectScreen.new()
	_player_select.input_router = input_router
	_player_select.audio_manager = audio_manager
	_player_select.confirmed.connect(_on_player_select_confirmed)
	_player_select.cancelled.connect(_close_player_select)
	add_child(_player_select)
	_player_select.focus_default()


func _close_player_select() -> void:
	if not _player_select:
		return
	_player_select.queue_free()
	_player_select = null
	input_router.release_owner()
	_menu.show()
	_menu.focus_default()
	_idle_flow.start_waiting()


func _open_controls() -> void:
	if _controls_screen or _player_select:
		return
	_idle_flow.suspend()
	audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	_controls_screen = HowToPlayScreenScene.new()
	_controls_screen.audio_manager = audio_manager
	_controls_screen.closed.connect(_close_controls)
	add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	audio_manager.play_event(AudioManager.Event.UI_BACK)
	_menu.focus_controls()
	_idle_flow.start_waiting()


func _on_player_select_confirmed(rider_kind: StringName) -> void:
	if not _player_select:
		return
	_player_select = null
	start_game_requested.emit(rider_kind)


func _unhandled_input(event: InputEvent) -> void:
	if _player_select or _controls_screen:
		return
	if event.is_action_pressed(&"controller_start"):
		show_rider_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"action_y"):
		_open_controls()
		get_viewport().set_input_as_handled()


func _restore_menu_after_idle() -> void:
	_menu.show()
	_menu.focus_default()


func _hide_menu_for_idle() -> void:
	_menu.hide()
