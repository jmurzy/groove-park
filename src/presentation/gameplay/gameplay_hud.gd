## In-run HUD data: rider, speed, jump, score, and rotation metric labels.
## Background frame rendering lives in `HudFrame`; this node owns the values so
## score/jump/rotation can go live without touching the painter.
## Example: `hud.set_speed(state.ground_velocity.length())`.
class_name GameplayHud
extends Control

const KMH_TO_MPH := 0.621371
const WORLD_TO_DISPLAY_SCALE := 0.12

var _frame: HudFrame
var _rider_value: Label
var _speed_value: Label
var _jump_value: Label
var _score_value: Label
var _rotation_value: Label


static func speed_to_mph(world_speed: float) -> int:
	return roundi(maxf(world_speed, 0.0) * WORLD_TO_DISPLAY_SCALE * KMH_TO_MPH)


func is_occluded(rect: Rect2) -> bool:
	return _frame.is_occluded(rect)


func _ready() -> void:
	name = "GameplayHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position.y = 30.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame = HudFrame.new()
	add_child(_frame)
	_build_metrics()
	_frame.queue_redraw()


func set_rider_text(rider_text: String) -> void:
	_rider_value.text = rider_text


func set_speed(world_speed: float) -> void:
	_speed_value.text = "%d MPH" % speed_to_mph(world_speed)


func set_jump(jump_text: String) -> void:
	_jump_value.text = jump_text


func set_score(score_text: String) -> void:
	_score_value.text = score_text


func set_rotation_text(rotation_text: String) -> void:
	_rotation_value.text = rotation_text


func _build_metrics() -> void:
	_rider_value = _add_metric("P1  SKIER", "READY", 506, Color("ffe126"), Color("f3f6ff"))
	_speed_value = _add_metric("SPEED", "0 MPH", 780, Color("42eaff"), Color("f3f6ff"))
	_jump_value = _add_metric("JUMP", "01 / 01", 1054, Color("42eaff"), Color("f3f6ff"))
	_score_value = _add_metric("SCORE", "0000", 1328, Color("42eaff"), Color("ffe126"))
	_rotation_value = _add_metric("ROTATION", "0", 1602, Color("42eaff"), Color("f3f6ff"))


func _add_metric(
	title: String, value: String, x_position: float, title_color: Color, value_color: Color
) -> Label:
	_add_metric_title(title, x_position, title_color)

	var value_label := ArcadeTheme.make_label(value, 29, value_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.position = Vector2(x_position, 84)
	value_label.size = Vector2(250, 46)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_constant_override("shadow_offset_x", 3)
	value_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(value_label)
	return value_label


func _add_metric_title(title: String, x_position: float, title_color: Color) -> void:
	var title_label := ArcadeTheme.make_label(title, 25, title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.position = Vector2(x_position, 43)
	title_label.size = Vector2(250, 38)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title_label)
