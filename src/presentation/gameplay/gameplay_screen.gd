## Composes gameplay presentation and bridges session events to screen navigation.
class_name GameplayScreen
extends Control

signal return_to_title_requested

const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const GameplayRunPresenterScene := preload(
	"res://src/presentation/gameplay/gameplay_run_presenter.gd"
)
const PauseFlowControllerScene := preload(
	"res://src/presentation/gameplay/pause_flow_controller.gd"
)

var game_session: GameSession
var input_router: InputRouter
var audio_manager: AudioManager
var designer_mode := OS.is_debug_build()
var _course: ParkCourse
var _run_presenter: GameplayRunPresenter
var _pause_flow: PauseFlowController
var _rider_tuning: RiderTuning
var _ui_layer: CanvasLayer
var _gameplay_music: AudioStreamPlayer


func _ready() -> void:
	name = "GameplayScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if game_session == null or input_router == null or audio_manager == null:
		push_error("GameplayScreen requires a GameSession, InputRouter, and AudioManager.")
		return
	_course = game_session.course()
	_rider_tuning = game_session.tuning()
	var course_errors := _course.validation_errors()
	if not course_errors.is_empty():
		push_error("Invalid ParkCourse:\n%s" % "\n".join(course_errors))
	_build_ui_layer()
	_run_presenter = GameplayRunPresenterScene.new()
	_run_presenter.setup(
		self,
		_ui_layer,
		game_session,
		input_router,
		audio_manager,
		_course,
		_rider_tuning,
		designer_mode
	)
	_pause_flow = PauseFlowControllerScene.new()
	_pause_flow.setup(self, game_session, _ui_layer)
	_pause_flow.abort_requested.connect(_confirm_return_to_title)
	_build_music()


func _process(delta: float) -> void:
	if _pause_flow.is_open():
		return
	_run_presenter.update(delta)


func _physics_process(delta: float) -> void:
	if _pause_flow.is_open():
		return
	_run_presenter.physics_update(delta)


func request_exit_confirmation() -> void:
	_pause_flow.request_open(get_tree())


func is_exit_confirmation_open() -> bool:
	return _pause_flow != null and _pause_flow.is_open()


func close_exit_confirmation() -> void:
	_pause_flow.close()


func _unhandled_input(event: InputEvent) -> void:
	if not _pause_flow.accepts_screen_input():
		return
	match _run_presenter.input.screen_command(event, game_session, input_router):
		&"continue":
			_run_presenter.continue_tally()
			get_viewport().set_input_as_handled()
		&"restart":
			_restart_run()
			get_viewport().set_input_as_handled()
		&"pause":
			request_exit_confirmation()
			get_viewport().set_input_as_handled()


func _restart_run() -> void:
	_run_presenter.restart()


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
