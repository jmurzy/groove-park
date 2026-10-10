## Pause/exit dialog: "ABORT THIS RUN?" with KEEP PLAYING / HOW TO PLAY /
## ABORT RUN. Owns its panel styling and focus wiring.
## Emits intent signals; PauseFlowController pauses the tree, frees this control
## on close, and hosts the HowToPlay overlay + return-to-title flow.
class_name PauseMenu
extends Control

signal resume_requested
signal controls_requested
signal abort_requested

var audio_manager: AudioManager
var _return_button: ArcadeMenuButton
var _keep_playing_button: ArcadeMenuButton
var _controls_button: ArcadeMenuButton
var _has_menu_focus := false


func _ready() -> void:
	name = "ExitConfirmation"
	# This menu must handle resume input after its flow pauses the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_dialog()
	audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
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
		audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
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
	panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(panel)

	var title := ArcadeTheme.make_label("ABORT THIS RUN?", 36, Color("fff16a"))
	title.position = Vector2(0, 55)
	title.size = Vector2(panel.size.x, 58)
	panel.add_child(title)

	var warning := ArcadeTheme.make_label("YOUR CURRENT SCORE WILL VANISH", 20, Color("fff7cf"))
	warning.position = Vector2(0, 145)
	warning.size = Vector2(panel.size.x, 38)
	panel.add_child(warning)

	_keep_playing_button = _build_button("KEEP PLAYING", Vector2(460, 248))
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	panel.add_child(_keep_playing_button)

	_controls_button = _build_button("HOW TO PLAY", Vector2(60, 248))
	_controls_button.pressed.connect(_on_controls_pressed)
	panel.add_child(_controls_button)

	_return_button = _build_button("ABORT RUN", Vector2(860, 248))
	_return_button.pressed.connect(_on_abort_pressed)
	panel.add_child(_return_button)
	_wire_button_focus()


func _build_button(text: String, button_position: Vector2) -> ArcadeMenuButton:
	var button := ArcadeMenuButton.new()
	button.position = button_position
	button.size = Vector2(400, 86)
	button.configure(text, 18)
	button.selection_focused.connect(_on_button_focused)
	return button


func _wire_button_focus() -> void:
	_controls_button.focus_neighbor_left = NodePath(".")
	_controls_button.focus_neighbor_right = _controls_button.get_path_to(_keep_playing_button)
	_keep_playing_button.focus_neighbor_left = _keep_playing_button.get_path_to(_controls_button)
	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_return_button)
	_return_button.focus_neighbor_left = _return_button.get_path_to(_keep_playing_button)
	_return_button.focus_neighbor_right = NodePath(".")


func _on_button_focused() -> void:
	if _has_menu_focus:
		audio_manager.play_event(AudioManager.Event.UI_MOVE)
	_has_menu_focus = true


func _cycle_focus() -> void:
	if _keep_playing_button.has_focus():
		_controls_button.grab_focus()
	elif _controls_button.has_focus():
		_return_button.grab_focus()
	else:
		_keep_playing_button.grab_focus()


func _confirm_focused() -> void:
	if _return_button.has_focus():
		_on_abort_pressed()
	elif _controls_button.has_focus():
		_on_controls_pressed()
	else:
		_on_keep_playing_pressed()


func _on_keep_playing_pressed() -> void:
	audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	resume_requested.emit()


func _on_controls_pressed() -> void:
	audio_manager.play_event(AudioManager.Event.UI_CONFIRM)
	controls_requested.emit()


func _on_abort_pressed() -> void:
	abort_requested.emit()
