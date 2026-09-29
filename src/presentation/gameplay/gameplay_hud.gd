## In-run HUD data: speed, jump, score, rotation, and rotation quota labels.
## Background frame rendering lives in `HudFrame`; this node owns the values so
## metrics can go live without touching the painter.
## Example: `hud.set_speed(state.kinematics.ground_velocity.length())`.
class_name GameplayHud
extends Control

var _frame: HudFrame
var _speed_value: Label
var _jump_value: Label
var _score_value: Label
var _rotation_value: Label
var _rotation_quota_value: Label


static func speed_to_mph(world_speed: float) -> int:
	return GameConstants.speed_to_mph(world_speed)


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


func set_speed(world_speed: float) -> void:
	_speed_value.text = "%d MPH" % speed_to_mph(world_speed)


func set_jump(jump_text: String) -> void:
	_jump_value.text = jump_text


func set_score(score_text: String) -> void:
	_score_value.text = score_text


func set_rotation_text(rotation_text: String) -> void:
	_rotation_value.text = rotation_text


func set_rotation_quota_text(rotation_quota_text: String) -> void:
	_rotation_quota_value.text = rotation_quota_text


func _build_metrics() -> void:
	_score_value = _add_metric("SCORE", "0000", 506, Color("42eaff"), Color("ffe126"))
	_jump_value = _add_metric("JUMP", "01 / 01", 780, Color("42eaff"), Color("f3f6ff"))
	_speed_value = _add_metric("SPEED", "0 MPH", 1054, Color("42eaff"), Color("f3f6ff"))
	_rotation_value = _add_metric("ROTATION", "+0°", 1328, Color("42eaff"), Color("f3f6ff"))
	_rotation_quota_value = _add_metric("SPINS", "--", 1602, Color("42eaff"), Color("f3f6ff"))


func _add_metric(
	title: String, value: String, x_position: float, title_color: Color, value_color: Color
) -> Label:
	_add_metric_title(title, x_position, title_color)
	return _add_metric_value(value, x_position, value_color)


func _add_metric_value(value: String, x_position: float, value_color: Color) -> Label:
	var value_label := ArcadeTheme.make_label(value, 29, value_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.position = Vector2(x_position, 84)
	value_label.size = Vector2(250, 46)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_constant_override("shadow_offset_x", 3)
	value_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(value_label)
	return value_label


func _add_metric_title(title: String, x_position: float, title_color: Color) -> Label:
	var title_label := ArcadeTheme.make_label(title, 25, title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.position = Vector2(x_position, 43)
	title_label.size = Vector2(250, 38)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title_label)
	return title_label
