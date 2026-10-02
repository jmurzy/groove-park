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

var input: GameplayInputController

var _session: GameSession
var _input_router: InputRouter
var _course: ParkCourse
var _tuning: RiderTuning
var _hud: GameplayHudPresenter
var _world: ParkWorldPresenter


func setup(
	owner: Node,
	ui_layer: CanvasLayer,
	session: GameSession,
	input_router: InputRouter,
	course: ParkCourse,
	tuning: RiderTuning,
	designer_mode: bool
) -> void:
	_session = session
	_input_router = input_router
	_course = course
	_tuning = tuning
	input = GameplayInputControllerScene.new()
	input.configure(designer_mode and OS.is_debug_build())
	_hud = GameplayHudPresenterScene.new()
	_hud.build(ui_layer, session.rider_kind)
	_world = ParkWorldPresenterScene.new()
	owner.add_child(_world)
	_world.setup(course, designer_mode, tuning, session.rider_kind)
	_session.jump_started.connect(_on_jump_started)
	_world.update_from_run(_session.run_manager, 0.0, _hud.is_occluded)
	_update_hud_occlusion()


func update(delta: float) -> void:
	_hud.update(delta, _session, input.sample_frame(_input_router))


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
	_session.complete_tally()


func _on_jump_started(_round_state: RoundState) -> void:
	_hud.reset(_session.rider_kind)
	_world.reset_presentation(_session.run_manager, _hud.is_occluded)
	_update_hud_occlusion()


func _update_hud_occlusion() -> void:
	_hud.update_rider_occlusion(_world.primary_rider_screen_bounds())
