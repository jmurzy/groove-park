## Blinking "LIVE / MOUNTAIN OPS" badge used in the marquee header.
class_name LiveIndicator
extends Control

const ARCADE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BLINK_DURATION := 0.7

var _elapsed := 0.0
var _status_light: PanelContainer


func _ready() -> void:
	name = "LiveIndicator"
	custom_minimum_size = Vector2(410, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 4
	content.offset_bottom = 4
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	add_child(content)

	_status_light = PanelContainer.new()
	_status_light.name = "LiveLight"
	_status_light.custom_minimum_size = Vector2(24, 14)
	_status_light.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status_light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_light.add_theme_stylebox_override("panel", _light_style())
	content.add_child(_status_light)

	var live_tag := PanelContainer.new()
	live_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live_tag.add_theme_stylebox_override("panel", _tag_style())
	content.add_child(live_tag)

	var live_label := Label.new()
	live_label.text = "LIVE"
	live_label.add_theme_font_override("font", ARCADE_FONT)
	live_label.add_theme_font_size_override("font_size", 24)
	live_label.add_theme_color_override("font_color", Color("fff1f1"))
	live_label.add_theme_color_override("font_outline_color", Color("641010"))
	live_label.add_theme_constant_override("outline_size", 3)
	live_tag.add_child(live_label)

	var source_label := Label.new()
	source_label.text = "MOUNTAIN OPS"
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_label.add_theme_font_override("font", ARCADE_FONT)
	source_label.add_theme_font_size_override("font_size", 20)
	source_label.add_theme_color_override("font_color", Color("d4efff"))
	source_label.add_theme_color_override("font_outline_color", Color("07182d"))
	source_label.add_theme_constant_override("outline_size", 4)
	_add_pixel_shadow(source_label)
	content.add_child(source_label)


func _process(delta: float) -> void:
	_elapsed += delta
	var blink: float = 0.45 + 0.55 * abs(sin(_elapsed * PI / BLINK_DURATION))
	_status_light.modulate.a = blink


func _light_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ff5d5d")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("7a1010")
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color("260304")
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 2)
	return style


func _tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("b72b2bf2")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("ff6868")
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _add_pixel_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("02060fe6"))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 2)
