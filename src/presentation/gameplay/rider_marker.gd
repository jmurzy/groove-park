## Shared world-space callout marker: panel, label, and direction arrow.
## Subclasses choose above/below placement; this owns sizing, styling, label
## setup, arrow geometry, and bounds math.
class_name RiderMarker
extends Panel

const CONTENT_PADDING := 4.0
const ARROW_GAP := 2.0
const ARROW_HEIGHT := 19.0
const RIDER_GAP := 8.0
const ARROW_HALF_WIDTH := 16.0
const LABEL_FONT_SIZE := 16

var _label: Label
var _arrow: Polygon2D


func _build_callout(node_name: StringName, label_color: Color, panel_color: Color) -> void:
	name = node_name
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	add_theme_stylebox_override("panel", callout_style(panel_color))
	_arrow = Polygon2D.new()
	_arrow.color = panel_color
	add_child(_arrow)
	_label = ArcadeTheme.make_label("", LABEL_FONT_SIZE, label_color)
	_label.name = "Label"
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_label)


func set_callout_text(callout_text: String) -> void:
	_label.text = callout_text


func set_callout_colors(panel_color: Color, label_color: Color) -> void:
	add_theme_stylebox_override("panel", callout_style(panel_color))
	_arrow.color = panel_color
	_label.add_theme_color_override("font_color", label_color)


func callout_style(panel_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	return style


func _refresh_callout_size() -> void:
	size = _label.get_combined_minimum_size() + Vector2.ONE * CONTENT_PADDING * 2.0


func _place_above(world_position: Vector2) -> void:
	position = (
		world_position + Vector2(-size.x * 0.5, -size.y - ARROW_GAP - ARROW_HEIGHT - RIDER_GAP)
	)


func _place_below(world_position: Vector2) -> void:
	position = world_position + Vector2(-size.x * 0.5, ARROW_HEIGHT + ARROW_GAP + RIDER_GAP)


func _update_arrow_above() -> void:
	var center_x := size.x * 0.5
	var arrow_top := size.y + ARROW_GAP
	_arrow.polygon = PackedVector2Array(
		[
			Vector2(center_x - ARROW_HALF_WIDTH, arrow_top),
			Vector2(center_x + ARROW_HALF_WIDTH, arrow_top),
			Vector2(center_x, arrow_top + ARROW_HEIGHT),
		]
	)


func _update_arrow_below() -> void:
	var center_x := size.x * 0.5
	var arrow_bottom := -ARROW_GAP
	_arrow.polygon = PackedVector2Array(
		[
			Vector2(center_x, arrow_bottom - ARROW_HEIGHT),
			Vector2(center_x - ARROW_HALF_WIDTH, arrow_bottom),
			Vector2(center_x + ARROW_HALF_WIDTH, arrow_bottom),
		]
	)


func callout_bounds_above() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.y + ARROW_GAP + ARROW_HEIGHT))


func callout_bounds_below() -> Rect2:
	return Rect2(
		Vector2(0.0, -ARROW_HEIGHT - ARROW_GAP), Vector2(size.x, size.y + ARROW_HEIGHT + ARROW_GAP)
	)
