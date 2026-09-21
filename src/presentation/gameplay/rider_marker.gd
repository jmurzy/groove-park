## World-space label marker that stays upright above a rider.
class_name RiderMarker
extends Panel

const CONTENT_PADDING := 4.0
const ARROW_GAP := 2.0
const ARROW_HEIGHT := 19.0
const RIDER_GAP := 8.0

var _label: Label
var _arrow: Polygon2D


func _ready() -> void:
	name = "RiderMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1.0, 1.0, 1.0, 0.8)
	z_index = 3
	add_theme_stylebox_override("panel", _marker_style())
	_add_arrow()
	_label = ArcadeTheme.make_label("", 16, Color.WHITE)
	_label.name = "Label"
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_label)


func update_from_rider(world_position: Vector2, label_text: String) -> void:
	_label.text = label_text
	size = _label.get_combined_minimum_size() + Vector2.ONE * CONTENT_PADDING * 2.0
	position = (
		world_position + Vector2(-size.x * 0.5, -size.y - ARROW_GAP - ARROW_HEIGHT - RIDER_GAP)
	)
	_update_arrow_geometry()


func local_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.y + ARROW_GAP + ARROW_HEIGHT))


func _marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f51e16")
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	return style


func _add_arrow() -> void:
	_arrow = Polygon2D.new()
	_arrow.color = Color("f51e16")
	add_child(_arrow)


func _update_arrow_geometry() -> void:
	var center_x := size.x * 0.5
	var arrow_top := size.y + ARROW_GAP
	_arrow.polygon = PackedVector2Array(
		[
			Vector2(center_x - 16.0, arrow_top),
			Vector2(center_x + 16.0, arrow_top),
			Vector2(center_x, arrow_top + ARROW_HEIGHT),
		]
	)
