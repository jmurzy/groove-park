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

var _session: GameSession
var _course: ParkCourse
var _tuning: RiderTuning
var _input: GameplayInputController
var _hud: GameplayHudPresenter
var _world: ParkWorldPresenter


func setup(
	owner: Node,
	ui_layer: CanvasLayer,
	session: GameSession,
	course: ParkCourse,
	tuning: RiderTuning,
	show_terrain: bool
) -> void:
	_session = session
	_course = course
	_tuning = tuning
	_input = GameplayInputControllerScene.new()
	_hud = GameplayHudPresenterScene.new()
	_hud.build(ui_layer, session.rider_kind)
	_world = ParkWorldPresenterScene.new()
	owner.add_child(_world)
	_world.setup(course, show_terrain, tuning, session.rider_kind)
	_world.update_from_run(_session.run_manager, 0.0, _hud.is_occluded)
	_update_hud_occlusion()
	_session.run_score_changed.connect(_hud.set_score)
	_hud.set_score(_session.run_score)


func update(delta: float) -> void:
	_hud.update(delta, _session.run_manager, _session.rider_kind, _input.sample_frame())


func physics_update(delta: float) -> void:
	_session.step_run(_input.sample_frame(), _course, _tuning, delta)
	_world.update_from_run(_session.run_manager, delta, _hud.is_occluded)
	_update_hud_occlusion()


func screen_command(event: InputEvent) -> StringName:
	return _input.screen_command(event, _session.run_manager)


func restart() -> void:
	_session.restart_run(_course)
	_hud.reset(_session.rider_kind)
	_world.reset_presentation(_session.run_manager, _hud.is_occluded)
	_update_hud_occlusion()


func _update_hud_occlusion() -> void:
	_hud.update_rider_occlusion(_world.primary_rider_screen_bounds())
