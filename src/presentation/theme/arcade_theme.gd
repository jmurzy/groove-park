## Shared arcade styling helpers: pixel-font labels and chunky button panels.
## Example: `ArcadeTheme.make_label("READY", 42, Color("fff7cf"))`.
class_name ArcadeTheme
extends RefCounted

const ARCADE_FONT := preload("res://assets/fonts/PressStart2P/PressStart2P-Regular.ttf")
const AUDIOWIDE_FONT := preload("res://assets/fonts/Audiowide/Audiowide-Regular.ttf")
const SYMBOL_FONT := preload("res://assets/fonts/NotoSansSymbols2/NotoSansSymbols2-Regular.ttf")


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


static func apply_menu_button_style(button: Button, font_size: int, shadow_color: Color) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("e8f7ff"))
	button.add_theme_color_override("font_hover_color", Color("fff7cf"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("fff16a"))
	button.add_theme_color_override("font_outline_color", Color("010713"))
	button.add_theme_constant_override("outline_size", 8)
	button.add_theme_color_override("font_shadow_color", Color("01040aff"))
	button.add_theme_constant_override("shadow_offset_x", 4)
	button.add_theme_constant_override("shadow_offset_y", 4)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", menu_selection_style(shadow_color))
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", menu_selection_style(shadow_color))


static func menu_selection_style(shadow_color: Color = Color("01040add")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("03162be0")
	style.border_color = Color("fff16a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = shadow_color
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style


static func dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("071b39")
	style.border_color = Color("fff16a")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color("01040add")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style
