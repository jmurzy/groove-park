class_name GameplayHud
extends Control

const HEAVENLY_LOGO := preload("res://artwork/heavenly_logo.png")
const AnimatedTimeLabelScene := preload("res://src/presentation/gameplay/animated_time_label.gd")
const HUD_RECT := Rect2(60, 24, 1800, 146)
const HUD_INSET := 11.0
const HUD_LOGO_SIZE := Vector2(380, 122)
const HUD_SEPARATORS := [490.0, 860.0, 1200.0, 1540.0]


func _ready() -> void:
	name = "GameplayHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position.y = 30.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_metrics()
	queue_redraw()


func _draw() -> void:
	var outer := HUD_RECT
	var inner := outer.grow(-HUD_INSET)
	var shadow := outer.grow(8)
	draw_colored_polygon(_beveled_rect_points(shadow, 30), Color("010711cc"))
	draw_colored_polygon(_beveled_rect_points(outer, 24), Color("0647bd"))
	draw_colored_polygon(_beveled_rect_points(outer.grow(-5), 19), Color("031643"))
	draw_colored_polygon(_beveled_rect_points(inner, 15), Color("071c42f5"))
	draw_polyline(_closed_points(_beveled_rect_points(inner, 15)), Color("18dffa"), 3.0)
	for separator_x: float in HUD_SEPARATORS:
		draw_line(Vector2(separator_x, 44), Vector2(separator_x, 150), Color("24ddf6"), 3.0)
	draw_texture_rect(HEAVENLY_LOGO, _logo_rect(), false)


func _logo_rect() -> Rect2:
	var first_box_width: float = HUD_SEPARATORS[0] - HUD_RECT.position.x
	var logo_x := HUD_RECT.position.x + (first_box_width - HUD_LOGO_SIZE.x) / 2.0 + 4.0
	var logo_y := HUD_RECT.position.y + (HUD_RECT.size.y - HUD_LOGO_SIZE.y) / 2.0
	return Rect2(Vector2(logo_x, logo_y), HUD_LOGO_SIZE)


func _beveled_rect_points(rect: Rect2, corner_size: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(rect.position.x + corner_size, rect.position.y),
			Vector2(rect.end.x - corner_size, rect.position.y),
			Vector2(rect.end.x, rect.position.y + corner_size),
			Vector2(rect.end.x, rect.end.y - corner_size),
			Vector2(rect.end.x - corner_size, rect.end.y),
			Vector2(rect.position.x + corner_size, rect.end.y),
			Vector2(rect.position.x, rect.end.y - corner_size),
			Vector2(rect.position.x, rect.position.y + corner_size),
		]
	)


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	return closed_points


func _build_metrics() -> void:
	_add_metric("GUNBARREL 25", "LAP 07 / 25", 506, Color("ffe126"), Color("f3f6ff"))
	_add_animated_time_metric("TOTAL TIME", 278.72, 876)
	_add_animated_time_metric("LAP TIME", 28.14, 1216)
	_add_metric("BEST LAP", "00:38.09", 1549, Color("42eaff"), Color("ffe126"))


func _add_metric(
	title: String, value: String, x_position: float, title_color: Color, value_color: Color
) -> void:
	_add_metric_title(title, x_position, title_color)

	var value_label := ArcadeTheme.make_label(value, 29, value_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.position = Vector2(x_position, 84)
	value_label.size = Vector2(300, 46)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_constant_override("shadow_offset_x", 3)
	value_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(value_label)


func _add_metric_title(title: String, x_position: float, title_color: Color) -> void:
	var title_label := ArcadeTheme.make_label(title, 25, title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.position = Vector2(x_position, 43)
	title_label.size = Vector2(300, 38)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title_label)


func _add_animated_time_metric(title: String, start_seconds: float, x_position: float) -> void:
	_add_metric_title(title, x_position, Color("42eaff"))

	var animated_value := AnimatedTimeLabelScene.new(start_seconds)
	animated_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	animated_value.position = Vector2(x_position, 84)
	animated_value.size = Vector2(300, 46)
	animated_value.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	animated_value.add_theme_font_size_override("font_size", 29)
	animated_value.add_theme_color_override("font_color", Color("f3f6ff"))
	animated_value.add_theme_color_override("font_outline_color", Color("260700"))
	animated_value.add_theme_constant_override("outline_size", 4)
	animated_value.add_theme_constant_override("shadow_offset_x", 3)
	animated_value.add_theme_constant_override("shadow_offset_y", 3)
	add_child(animated_value)
