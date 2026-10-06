## Synchronizes one run's simulation input with its world and HUD presentation.
class_name GameplayRunPresenter
extends RefCounted

const GameplayInputControllerScene := preload(
	"res://src/presentation/gameplay/gameplay_input_controller.gd"
)
const GameplayHudPresenterScene := preload(
	"res://src/presentation/gameplay/gameplay_hud_presenter.gd"
)
const ParkWorldPresenterScene := preload("res://src/presentation/gameplay/park_world_presenter.gd")
const ScoreTallyPresenterScene := preload(
	"res://src/presentation/gameplay/score_tally_presenter.gd"
)
const CrashRescuePresenterScene := preload(
	"res://src/presentation/gameplay/crash_rescue_presenter.gd"
)

var input: GameplayInputController

var _session: GameSession
var _input_router: InputRouter
var _course: ParkCourse
var _tuning: RiderTuning
var _audio_manager: AudioManager
var _hud: GameplayHudPresenter
var _world: ParkWorldPresenter
var _tally: ScoreTallyPresenter
var _crash_rescue: CrashRescuePresenter


func setup(
	owner: Node,
	ui_layer: CanvasLayer,
	session: GameSession,
	input_router: InputRouter,
	audio_manager: AudioManager,
	course: ParkCourse,
	tuning: RiderTuning,
	designer_mode: bool
) -> void:
	_session = session
	_input_router = input_router
	_course = course
	_tuning = tuning
	_audio_manager = audio_manager
	input = GameplayInputControllerScene.new()
	input.configure(designer_mode and OS.is_debug_build())
	_hud = GameplayHudPresenterScene.new()
	_hud.build(ui_layer, session.rider_kind)
	_hud.show_round_state(session.round_state())
	_tally = ScoreTallyPresenterScene.new()
	_tally.build(ui_layer)
	_tally.score_tick_requested.connect(
		audio_manager.play_event.bind(AudioManager.Event.SCORE_TICK)
	)
	_world = ParkWorldPresenterScene.new()
	owner.add_child(_world)
	_world.setup(course, designer_mode, tuning, session.rider_kind)
	_crash_rescue = CrashRescuePresenterScene.new()
	_crash_rescue.configure(designer_mode)
	_world.add_child(_crash_rescue)
	_crash_rescue.crash_rescue_started.connect(_on_crash_rescue_started)
	_crash_rescue.crash_rescue_progress_changed.connect(_on_crash_rescue_progress_changed)
	_session.jump_started.connect(_on_jump_started)
	_session.jump_result_recorded.connect(_on_jump_result_recorded)
	_world.update_from_run(_session.run_manager, 0.0, _hud.is_occluded)
	_update_hud_occlusion()


func update(delta: float) -> void:
	_hud.update(delta, _session, input.sample_frame(_input_router))
	_crash_rescue.advance(delta)
	if _tally.update(delta):
		_session.complete_tally()


func physics_update(delta: float) -> void:
	_session.step_run(input.sample_frame(_input_router), delta)
	_input_router.finish_physics_frame()
	_world.update_from_run(_session.run_manager, delta, _hud.is_occluded)
	_update_hud_occlusion()


func restart() -> void:
	_session.restart_run()
	_hud.reset(_session.rider_kind)
	_world.reset_presentation(_session.run_manager, _hud.is_occluded)
	_update_hud_occlusion()


func continue_tally() -> void:
	_tally.request_continue()


func start_crash_rescue() -> bool:
	if _session.run_manager == null:
		return false
	return _crash_rescue.start(_world.crash_site_position(_session.run_manager))


func finish_crash_rescue() -> void:
	_crash_rescue.finish()


func _on_jump_started(round_state: RoundState) -> void:
	_hud.reset(_session.rider_kind)
	_hud.show_round_state(round_state)
	_world.reset_presentation(_session.run_manager, _hud.is_occluded)
	_update_hud_occlusion()


func _on_jump_result_recorded(round_state: RoundState, _jump_result: JumpResult) -> void:
	_hud.show_round_state(round_state)
	if round_state.session_phase() == RoundState.SessionPhase.JUMP_TALLY:
		_tally.start(round_state, _jump_result)


func _on_crash_rescue_started() -> void:
	_audio_manager.duck_gameplay_ambience_for_rescue()
	_audio_manager.start_helicopter_hover()


func _on_crash_rescue_progress_changed(progress: float) -> void:
	_audio_manager.set_helicopter_hover_progress(progress)


func _update_hud_occlusion() -> void:
	_hud.update_rider_occlusion(_world.primary_rider_screen_bounds())
