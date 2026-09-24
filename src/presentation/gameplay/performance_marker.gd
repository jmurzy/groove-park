## Flashing world-space performance feedback below the primary rider.
class_name PerformanceMarker
extends Panel

const CONTENT_PADDING := 4.0
const ARROW_GAP := 2.0
const ARROW_HEIGHT := 19.0
const RIDER_GAP := 8.0
const CALLOUT_DURATION := 1.0
const FLASH_INTERVAL := 0.12

var _label: Label
var _arrow: Polygon2D
var _time_remaining := 0.0
var _elapsed := 0.0


func _ready() -> void:
	name = "PerformanceMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	add_theme_stylebox_override("panel", _marker_style())
	_arrow = Polygon2D.new()
	_arrow.color = Color("f51e16")
	add_child(_arrow)
	_label = ArcadeTheme.make_label("", 16, Color("ffe126"))
	_label.name = "Label"
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_label)
	hide()


func show_feedback(callout_text: String) -> void:
	_label.text = callout_text
	_time_remaining = CALLOUT_DURATION
	_elapsed = 0.0
	show()


func reset_feedback() -> void:
	_time_remaining = 0.0
	_elapsed = 0.0
	hide()


func update_from_rider(world_position: Vector2, delta: float) -> void:
	if _time_remaining <= 0.0:
		hide()
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_elapsed += delta
	size = _label.get_combined_minimum_size() + Vector2.ONE * CONTENT_PADDING * 2.0
	position = world_position + Vector2(-size.x * 0.5, ARROW_HEIGHT + ARROW_GAP + RIDER_GAP)
	_update_arrow_geometry()
	var flash_on := fposmod(_elapsed, FLASH_INTERVAL * 2.0) < FLASH_INTERVAL
	modulate = Color(1.0, 1.0, 1.0, 1.0 if flash_on else 0.35)


func is_feedback_active() -> bool:
	return _time_remaining > 0.0


func local_bounds() -> Rect2:
	return Rect2(
		Vector2(0.0, -ARROW_HEIGHT - ARROW_GAP), Vector2(size.x, size.y + ARROW_HEIGHT + ARROW_GAP)
	)


func _marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f51e16")
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	return style


func _update_arrow_geometry() -> void:
	var center_x := size.x * 0.5
	var arrow_bottom := -ARROW_GAP
	_arrow.polygon = PackedVector2Array(
		[
			Vector2(center_x, arrow_bottom - ARROW_HEIGHT),
			Vector2(center_x - 16.0, arrow_bottom),
			Vector2(center_x + 16.0, arrow_bottom),
		]
	)
