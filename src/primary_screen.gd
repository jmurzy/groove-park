class_name PrimaryScreen
extends Control

const DESIGN_SIZE := Vector2i(1920, 1080)

const LiftStatusPanelScene := preload("res://src/lift_status.gd")

@export var screen_index: int = 0
@export var background_color: Color = Color("071f4a")
@export var accent_color: Color = Color("35a7ff")

var _elapsed_time := 0.0
var _bar: ColorRect
var _bar_width := float(DESIGN_SIZE.x)


func _ready() -> void:
	name = "PrimaryView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = background_color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "HEAVENLY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f5f7ff"))
	title.add_theme_color_override("font_outline_color", accent_color.darkened(0.65))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_font_size_override("font_size", 132)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 280.0
	title.offset_bottom = title.offset_top + 190.0
	add_child(title)

	var identifier := Label.new()
	identifier.text = "PRIMARY"
	identifier.position = Vector2(42, 28)
	identifier.add_theme_color_override("font_color", accent_color)
	identifier.add_theme_font_size_override("font_size", 30)
	add_child(identifier)

	var exit_button := Button.new()
	exit_button.text = "EXIT"
	exit_button.tooltip_text = "Exit HEAVENLY"
	exit_button.position = Vector2(DESIGN_SIZE.x - 178, 28)
	exit_button.size = Vector2(136, 54)
	exit_button.add_theme_color_override("font_color", Color("f5f7ff"))
	exit_button.add_theme_font_size_override("font_size", 22)
	exit_button.pressed.connect(_on_exit_pressed)
	add_child(exit_button)

	add_child(_build_diagnostics())
	_build_moving_bar()

	var lift_panel := LiftStatusPanelScene.new()
	lift_panel.accent_color = accent_color
	lift_panel.design_width = float(DESIGN_SIZE.x)
	add_child(lift_panel)

	add_child(_build_resolution_border(6))


func _process(delta: float) -> void:
	_elapsed_time += delta
	if is_instance_valid(_bar):
		var progress := (sin(_elapsed_time * 1.35) + 1.0) * 0.5
		_bar.position.x = progress * (_bar_width - _bar.size.x)


func _build_diagnostics() -> Label:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var diagnostics := Label.new()
	diagnostics.text = "Godot screen %d  |  %d x %d  |  position %d, %d" % [
		screen_index,
		screen_size.x,
		screen_size.y,
		screen_position.x,
		screen_position.y,
	]
	diagnostics.position = Vector2(42, DESIGN_SIZE.y - 64)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	diagnostics.add_theme_font_size_override("font_size", 22)
	return diagnostics


func _build_moving_bar() -> void:
	_bar = ColorRect.new()
	_bar.color = accent_color
	_bar.size = Vector2(260, 42)
	_bar.position.y = DESIGN_SIZE.y * 0.72
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)


func _build_resolution_border(width: int) -> Panel:
	var border := Panel.new()
	border.name = "ResolutionBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(width)
	style.border_color = accent_color
	border.add_theme_stylebox_override("panel", style)
	return border


func _on_exit_pressed() -> void:
	get_tree().quit()
