## Composes gameplay presentation and bridges session events to screen navigation.
class_name GameplayScreen
extends Control

signal return_to_title_requested

const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")
const GameplayInputControllerScene := preload(
	"res://src/presentation/gameplay/gameplay_input_controller.gd"
)
const GameplayHudPresenterScene := preload(
	"res://src/presentation/gameplay/gameplay_hud_presenter.gd"
)
const ParkWorldPresenterScene := preload("res://src/presentation/gameplay/park_world_presenter.gd")
const PauseFlowControllerScene := preload(
	"res://src/presentation/gameplay/pause_flow_controller.gd"
)

var game_session: GameSession
var show_terrain := OS.is_debug_build()
var _course: ParkCourse = PARK_COURSE_RESOURCE.duplicate()
var _input_controller: GameplayInputController
var _hud_presenter: GameplayHudPresenter
var _world_presenter: ParkWorldPresenter
var _pause_flow: PauseFlowController
var _rider_tuning: RiderTuning = RIDER_TUNING_RESOURCE
var _ui_layer: CanvasLayer
var _gameplay_music: AudioStreamPlayer

var _run_manager: RiderRunManager:
	get:
		return game_session.run_manager


func _ready() -> void:
	name = "GameplayScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if game_session == null:
		push_error("GameplayScreen requires a GameSession.")
		return
	var course_errors := _course.validation_errors()
	if not course_errors.is_empty():
		push_error("Invalid ParkCourse:\n%s" % "\n".join(course_errors))
	game_session.begin_run(_course)
	_build_ui_layer()
	_input_controller = GameplayInputControllerScene.new()
	_hud_presenter = GameplayHudPresenterScene.new()
	_hud_presenter.build(_ui_layer, game_session.player_count)
	_world_presenter = ParkWorldPresenterScene.new()
	add_child(_world_presenter)
	_world_presenter.setup(_course, show_terrain)
	_world_presenter.update_from_run(_run_manager, 0.0, _hud_presenter.is_occluded)
	_pause_flow = PauseFlowControllerScene.new()
	_pause_flow.setup(self, game_session, _ui_layer)
	_pause_flow.abandon_requested.connect(_confirm_return_to_title)
	game_session.run_score_changed.connect(_hud_presenter.set_score)
	_hud_presenter.set_score(game_session.run_score)
	_build_music()


func _process(delta: float) -> void:
	if _pause_flow.is_open():
		return
	_hud_presenter.update(
		delta, _run_manager, game_session.player_count, _input_controller.sample_frame()
	)


func _physics_process(delta: float) -> void:
	if _pause_flow.is_open():
		return
	var input := _input_controller.sample_frame()
	game_session.step_run(input, _course, _rider_tuning, delta)
	_world_presenter.update_from_run(_run_manager, delta, _hud_presenter.is_occluded)


func request_exit_confirmation() -> void:
	_pause_flow.request_open(get_tree())


func is_exit_confirmation_open() -> bool:
	return _pause_flow != null and _pause_flow.is_open()


func close_exit_confirmation() -> void:
	_pause_flow.close()


func _unhandled_input(event: InputEvent) -> void:
	if not _pause_flow.accepts_screen_input():
		return
	match _input_controller.screen_command(event, _run_manager):
		&"restart":
			_restart_run()
			get_viewport().set_input_as_handled()
		&"pause":
			request_exit_confirmation()
			get_viewport().set_input_as_handled()


func _restart_run() -> void:
	game_session.restart_run(_course)
	_hud_presenter.reset(game_session.player_count)
	_world_presenter.reset_presentation(_run_manager, _hud_presenter.is_occluded)


func _confirm_return_to_title() -> void:
	_pause_flow.close_for_navigation(get_tree())
	return_to_title_requested.emit()


func _build_ui_layer() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ScreenUi"
	_ui_layer.layer = 1
	add_child(_ui_layer)
	var frame := TextureRect.new()
	frame.name = "FrameOverlay"
	frame.texture = FRAME_OVERLAY
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ui_layer.add_child(frame)


func _build_music() -> void:
	var music_stream: AudioStreamMP3 = GAMEPLAY_MUSIC.duplicate()
	music_stream.loop = true
	_gameplay_music = AudioStreamPlayer.new()
	_gameplay_music.name = "GameplayMusic"
	_gameplay_music.stream = music_stream
	add_child(_gameplay_music)
	_gameplay_music.play()
