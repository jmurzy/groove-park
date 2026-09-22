## Pause/exit dialog: "ABANDON THIS RUN?" with KEEP PLAYING / HOW TO PLAY /
## ABANDON RUN. Owns its panel styling, focus wiring, and switch/confirm SFX.
## Emits intent signals; PauseFlowController pauses the tree, frees this control
## on close, and hosts the HowToPlay overlay + return-to-title flow.
class_name PauseMenu
extends Control

signal resume_requested
signal controls_requested
signal abandon_requested

const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")

var _return_button: Button
var _keep_playing_button: Button
var _controls_button: Button
var _switch_sound: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _focused_dialog_button: Button


func _ready() -> void:
	name = "ExitConfirmation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_dialog()
	_confirmation_sound.play()
	_keep_playing_button.call_deferred("grab_focus")


func focus_default() -> void:
	if is_instance_valid(_keep_playing_button):
		_keep_playing_button.grab_focus()


func focus_controls_button() -> void:
	if is_instance_valid(_controls_button):
		_controls_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
		or event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"ui_down")
	):
		_cycle_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"controller_start") or event.is_action_pressed(&"ui_accept"):
		_confirm_focused()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"cabinet_exit")
	):
		_play_confirmation()
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _build_dialog() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fd9")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(300, 342)
	panel.size = Vector2(1320, 396)
	panel.add_theme_stylebox_override("panel", _dialog_style())
	add_child(panel)

	var title := ArcadeTheme.make_label("ABANDON THIS RUN?", 36, Color("fff16a"))
	title.position = Vector2(0, 55)
	title.size = Vector2(panel.size.x, 58)
	panel.add_child(title)

	var warning := ArcadeTheme.make_label("YOUR CURRENT SCORE WILL VANISH", 20, Color("fff7cf"))
	warning.position = Vector2(0, 145)
	warning.size = Vector2(panel.size.x, 38)
	panel.add_child(warning)

	_switch_sound = AudioStreamPlayer.new()
	_switch_sound.stream = SWITCH_SOUND
	add_child(_switch_sound)
	_confirmation_sound = AudioStreamPlayer.new()
	_confirmation_sound.stream = CONFIRMATION_SOUND
	add_child(_confirmation_sound)
	_focused_dialog_button = null

	_keep_playing_button = _build_button("KEEP PLAYING", Vector2(460, 248))
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	panel.add_child(_keep_playing_button)

	_controls_button = _build_button("HOW TO PLAY", Vector2(60, 248))
	_controls_button.pressed.connect(_on_controls_pressed)
	panel.add_child(_controls_button)

	_return_button = _build_button("ABANDON RUN", Vector2(860, 248))
	_return_button.pressed.connect(_on_abandon_pressed)
	panel.add_child(_return_button)
	_wire_button_focus()


func _build_button(text: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = button_position
	button.size = Vector2(400, 86)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("e8f7ff"))
	button.add_theme_color_override("font_hover_color", Color("fff7cf"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("fff16a"))
	button.add_theme_color_override("font_outline_color", Color("010713"))
	button.add_theme_constant_override("outline_size", 7)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _selected_style())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", _selected_style())
	var left_marker := ArcadeTheme.make_label(">", 24, Color("fff16a"))
	left_marker.name = "SelectionLeft"
	left_marker.position = Vector2(14, 0)
	left_marker.size = Vector2(30, button.size.y)
	left_marker.hide()
	button.add_child(left_marker)
	var right_marker := ArcadeTheme.make_label("<", 24, Color("fff16a"))
	right_marker.name = "SelectionRight"
	right_marker.position = Vector2(button.size.x - 44, 0)
	right_marker.size = Vector2(30, button.size.y)
	right_marker.hide()
	button.add_child(right_marker)
	button.focus_entered.connect(_on_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("03162be0")
	style.border_color = Color("fff16a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color("01040ae6")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style


func _dialog_style() -> StyleBoxFlat:
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


func _wire_button_focus() -> void:
	_controls_button.focus_neighbor_left = NodePath(".")
	_controls_button.focus_neighbor_right = _controls_button.get_path_to(_keep_playing_button)
	_keep_playing_button.focus_neighbor_left = _keep_playing_button.get_path_to(_controls_button)
	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_return_button)
	_return_button.focus_neighbor_left = _return_button.get_path_to(_keep_playing_button)
	_return_button.focus_neighbor_right = NodePath(".")


func _on_button_focused(button: Button) -> void:
	if _focused_dialog_button == button:
		return
	var is_first_focus := _focused_dialog_button == null
	if _focused_dialog_button:
		_set_selection(_focused_dialog_button, false)
	_focused_dialog_button = button
	_set_selection(button, true)
	if not is_first_focus and is_instance_valid(_switch_sound):
		_switch_sound.play()


func _set_selection(button: Button, selected: bool) -> void:
	var left_marker := button.get_node("SelectionLeft") as Label
	var right_marker := button.get_node("SelectionRight") as Label
	left_marker.visible = selected
	right_marker.visible = selected


func _cycle_focus() -> void:
	if _keep_playing_button.has_focus():
		_controls_button.grab_focus()
	elif _controls_button.has_focus():
		_return_button.grab_focus()
	else:
		_keep_playing_button.grab_focus()


func _confirm_focused() -> void:
	if _return_button.has_focus():
		_on_abandon_pressed()
	elif _controls_button.has_focus():
		_on_controls_pressed()
	else:
		_on_keep_playing_pressed()


func _on_keep_playing_pressed() -> void:
	_play_confirmation()
	resume_requested.emit()


func _on_controls_pressed() -> void:
	_play_confirmation()
	controls_requested.emit()


func _on_abandon_pressed() -> void:
	abandon_requested.emit()


func _play_confirmation() -> void:
	if is_instance_valid(_confirmation_sound):
		_confirmation_sound.play()
