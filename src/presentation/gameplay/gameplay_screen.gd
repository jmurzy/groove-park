class_name GameplayScreen
extends Control

signal return_to_title_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const PRIMARY_BACKGROUND := preload("res://artwork/primary_bg.png")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")

var player_count := 1
var _ready_label: Label
var _elapsed := 0.0
var _exit_confirmation: Control
var _return_button: Button
var _keep_playing_button: Button
var _switch_sound: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _focused_dialog_button: Button


func _ready() -> void:
	name = "GameplayScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_hud()
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(PRIMARY_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	for y in range(0, int(DESIGN_SIZE.y), 6):
		draw_line(Vector2(0, y), Vector2(DESIGN_SIZE.x, y), Color(0.0, 0.08, 0.16, 0.18), 1.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_ready_label.visible = fmod(_elapsed, 0.8) < 0.56


func _build_hud() -> void:
	add_child(GameplayHudScene.new())

	_ready_label = ArcadeTheme.make_label(
		"%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"], 42, Color("fff7cf")
	)
	_ready_label.position = Vector2(0, 430)
	_ready_label.size = Vector2(DESIGN_SIZE.x, 72)
	add_child(_ready_label)


func request_exit_confirmation() -> void:
	if _exit_confirmation:
		return
	_exit_confirmation = Control.new()
	_exit_confirmation.name = "ExitConfirmation"
	_exit_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_exit_confirmation)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fd9")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_confirmation.add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(472, 342)
	panel.size = Vector2(976, 396)
	panel.add_theme_stylebox_override(
		"panel", ArcadeTheme.button_style(Color("071b39"), Color("fff16a"), 8, 12)
	)
	_exit_confirmation.add_child(panel)

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
	_exit_confirmation.add_child(_switch_sound)
	if _confirmation_sound == null:
		_confirmation_sound = AudioStreamPlayer.new()
		_confirmation_sound.stream = CONFIRMATION_SOUND
		add_child(_confirmation_sound)
	_focused_dialog_button = null

	_keep_playing_button = _build_confirmation_button(
		"KEEP PLAYING", Vector2(88, 252), Color("d92c0ba6"), Color("ffb000")
	)
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	panel.add_child(_keep_playing_button)

	_return_button = _build_confirmation_button(
		"RETURN TO MAIN MENU", Vector2(510, 252), Color("b000d4a6"), Color("43f4ff")
	)
	_return_button.pressed.connect(_confirm_return_to_title)
	panel.add_child(_return_button)
	_wire_dialog_button_focus()
	_keep_playing_button.call_deferred("grab_focus")


func is_exit_confirmation_open() -> bool:
	return _exit_confirmation != null


func _build_confirmation_button(
	text: String, button_position: Vector2, fill: Color, border: Color
) -> Button:
	var button := Button.new()
	button.text = text
	button.position = button_position
	button.size = Vector2(378, 78)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("fff7cf"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff19a"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("260700"))
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_stylebox_override("normal", ArcadeTheme.button_style(fill, border, 6, 8))
	button.add_theme_stylebox_override(
		"hover", ArcadeTheme.button_style(fill.lightened(0.14), Color("fff16a"), 8, 10)
	)
	button.add_theme_stylebox_override(
		"pressed", ArcadeTheme.button_style(fill.darkened(0.2), border, 6, 4)
	)
	button.add_theme_stylebox_override(
		"focus", ArcadeTheme.button_style(fill.lightened(0.1), Color("fff16a"), 8, 10)
	)
	button.focus_entered.connect(_on_dialog_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _wire_dialog_button_focus() -> void:
	_keep_playing_button.focus_neighbor_left = NodePath(".")
	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_return_button)
	_return_button.focus_neighbor_left = _return_button.get_path_to(_keep_playing_button)
	_return_button.focus_neighbor_right = NodePath(".")


func _on_dialog_button_focused(button: Button) -> void:
	if _focused_dialog_button == button:
		return
	var is_first_focus := _focused_dialog_button == null
	_focused_dialog_button = button
	if not is_first_focus and is_instance_valid(_switch_sound):
		_switch_sound.play()


func _unhandled_input(event: InputEvent) -> void:
	if not _exit_confirmation:
		if event.is_action_pressed(&"exit_escape") or event.is_action_pressed(&"controller_back"):
			request_exit_confirmation()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		if _return_button.has_focus():
			_keep_playing_button.grab_focus()
		else:
			_return_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"controller_start"):
		if _return_button.has_focus():
			_confirm_return_to_title()
		else:
			_on_keep_playing_pressed()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"controller_back")
	):
		close_exit_confirmation()
		get_viewport().set_input_as_handled()


func _confirm_return_to_title() -> void:
	return_to_title_requested.emit()


func _on_keep_playing_pressed() -> void:
	if is_instance_valid(_confirmation_sound):
		_confirmation_sound.play()
	close_exit_confirmation()


func close_exit_confirmation() -> void:
	if not _exit_confirmation:
		return
	_exit_confirmation.queue_free()
	_exit_confirmation = null
	_return_button = null
	_keep_playing_button = null
	_switch_sound = null
	_focused_dialog_button = null
