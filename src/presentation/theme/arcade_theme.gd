## Shared arcade styling helpers: pixel-font labels and chunky button panels.
## Example: `ArcadeTheme.make_label("READY", 42, Color("fff7cf"))`.
class_name ArcadeTheme
extends RefCounted

const ARCADE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")


static func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ARCADE_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("061020"))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_shadow_color", Color("02060fcc"))
	label.add_theme_constant_override("shadow_offset_x", 5)
	label.add_theme_constant_override("shadow_offset_y", 5)
	return label


static func button_style(
	background: Color, border: Color, border_width: int, shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color("b0000000")
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 9)
	return style
