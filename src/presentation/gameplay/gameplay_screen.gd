## Composes gameplay presentation and bridges session events to screen navigation.
class_name GameplayScreen
extends Control

signal return_to_title_requested
signal new_round_requested
signal player_name_submission_requested(player_name: String)

const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const GameplayRunPresenterScene := preload(
	"res://src/presentation/gameplay/gameplay_run_presenter.gd"
)
const PauseFlowControllerScene := preload(
	"res://src/presentation/gameplay/pause_flow_controller.gd"
)
const GameOverScreenScene := preload("res://src/presentation/results/game_over_screen.gd")
const RoundResultsScreenScene := preload("res://src/presentation/results/round_results_screen.gd")
const PlayerNameEntryScreenScene := preload(
	"res://src/presentation/results/player_name_entry_screen.gd"
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
var _game_over_screen: GameOverScreen
var _round_results_screen: RoundResultsScreen
var _player_name_entry_screen: PlayerNameEntryScreen


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
	_pause_flow.setup(self, game_session, _ui_layer, audio_manager)
	_pause_flow.abort_requested.connect(_confirm_return_to_title)
	audio_manager.play_gameplay_ambience()


func _process(delta: float) -> void:
	if _pause_flow.is_open():
		return
	_run_presenter.update(delta)
	if _player_name_entry_screen:
		_player_name_entry_screen.advance(delta)


func _physics_process(delta: float) -> void:
	if _pause_flow.is_open() or game_session.is_paused:
		return
	if (
		game_session.session_phase
		in [
			RoundState.SessionPhase.CRASH_RESCUE,
			RoundState.SessionPhase.GAME_OVER,
			RoundState.SessionPhase.QUALIFYING,
			RoundState.SessionPhase.NAME_ENTRY,
			RoundState.SessionPhase.ROUND_RESULTS,
		]
	):
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
		&"skip_crash_rescue":
			game_session.request_skip_crash_rescue()
			get_viewport().set_input_as_handled()
		&"advance_jump_tally":
			_run_presenter.continue_tally()
			get_viewport().set_input_as_handled()
		&"new_round":
			new_round_requested.emit()
			get_viewport().set_input_as_handled()
		&"return_to_attract":
			return_to_title_requested.emit()
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


func show_game_over() -> void:
	if _game_over_screen or game_session.round_state() == null:
		return
	_run_presenter.finish_crash_rescue()
	_game_over_screen = GameOverScreenScene.new()
	_game_over_screen.show_round(game_session.round_state())
	_ui_layer.add_child(_game_over_screen)


func show_qualification_pending() -> void:
	if _game_over_screen:
		_game_over_screen.set_leaderboard_message("CHECKING LEADERBOARD")


func start_crash_rescue() -> void:
	if _game_over_screen or game_session.session_phase != RoundState.SessionPhase.CRASH_RESCUE:
		return
	_run_presenter.start_crash_rescue()


func _exit_tree() -> void:
	if audio_manager:
		audio_manager.stop_helicopter_hover()
		audio_manager.stop_gameplay_ambience()


func show_round_results() -> void:
	if _round_results_screen or game_session.round_state() == null:
		return
	if _game_over_screen:
		_game_over_screen.queue_free()
		_game_over_screen = null
	if _player_name_entry_screen:
		_player_name_entry_screen.queue_free()
		_player_name_entry_screen = null
	_round_results_screen = RoundResultsScreenScene.new()
	_round_results_screen.show_round(game_session.round_state(), game_session.leaderboard())
	_ui_layer.add_child(_round_results_screen)


func show_name_entry() -> void:
	if _player_name_entry_screen:
		return
	_player_name_entry_screen = PlayerNameEntryScreenScene.new()
	_player_name_entry_screen.input_router = input_router
	_player_name_entry_screen.audio_manager = audio_manager
	_player_name_entry_screen.confirmed.connect(_on_player_name_confirmed)
	_player_name_entry_screen.skipped.connect(game_session.name_entry_skipped)
	_ui_layer.add_child(_player_name_entry_screen)


func set_name_submitting() -> void:
	if _player_name_entry_screen:
		_player_name_entry_screen.set_submitting()


func _on_player_name_confirmed(player_name: String) -> void:
	player_name_submission_requested.emit(player_name)


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
