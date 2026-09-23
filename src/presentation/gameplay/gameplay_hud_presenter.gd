## Screen-space gameplay HUD, ready prompt, and contextual control hint.
class_name GameplayHudPresenter
extends RefCounted

const DESIGN_SIZE := Vector2(1920, 1080)
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")

var _hud: GameplayHud
var _ready_label: Label
var _action_label: Label
var _action_hint_time := 0.0
var _elapsed := 0.0


func build(ui_layer: CanvasLayer, player_count: int) -> void:
	_hud = GameplayHudScene.new()
	ui_layer.add_child(_hud)
	_hud.set_rider_text("P1" if player_count == 1 else "P1 / P2")
	_ready_label = ArcadeTheme.make_label(_ready_text(player_count), 42, Color("fff7cf"))
	_ready_label.position = Vector2(0, 430)
	_ready_label.size = Vector2(DESIGN_SIZE.x, 72)
	ui_layer.add_child(_ready_label)
	_action_label = ArcadeTheme.make_label("", 30, Color("68efff"))
	_action_label.position = Vector2(0, 218)
	_action_label.size = Vector2(DESIGN_SIZE.x, 52)
	_action_label.hide()
	ui_layer.add_child(_action_label)


func update(
	delta: float, run_manager: RiderRunManager, player_count: int, input: RiderInputFrame
) -> void:
	_elapsed += delta
	_ready_label.visible = (
		(not run_manager.has_started_moving or run_manager.is_crashed())
		and fmod(_elapsed, 0.8) < 0.56
	)
	_ready_label.text = (
		"PRESS START OR R TO RESTART" if run_manager.is_crashed() else _ready_text(player_count)
	)
	_hud.set_speed(run_manager.rider_state.movement_velocity().length())
	_update_action_hint(delta, input)


func set_score(score: int) -> void:
	_hud.set_score("%04d" % score)


func reset(player_count: int) -> void:
	_action_hint_time = 0.0
	_action_label.hide()
	_hud.show()
	_hud.set_speed(0.0)
	_ready_label.text = _ready_text(player_count)


func is_occluded(rect: Rect2) -> bool:
	return _hud.is_occluded(rect)


func update_rider_occlusion(rider_rect: Rect2) -> void:
	_hud.visible = not _hud.is_occluded(rider_rect)


func _ready_text(player_count: int) -> String:
	return "%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"]


func _update_action_hint(delta: float, input: RiderInputFrame) -> void:
	var action_message := "RIGHT / D: BUILD SPEED"
	if input.brake_pressed:
		action_message = "B  CHECKING SPEED"
	elif input.tuck_pressed:
		action_message = "A  TUCKING - LESS STEERING"
	_action_label.text = action_message
	_action_hint_time = maxf(_action_hint_time - delta, 0.0) if _action_hint_time > 0.0 else 1.5
	_action_label.visible = _action_hint_time > 0.0
