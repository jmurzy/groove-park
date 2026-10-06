## Cabinet-friendly player-name editor. Submission remains owned by screen flow.
class_name PlayerNameEntryScreen
extends Control

signal confirmed(player_name: String)
signal skipped

const TIMEOUT_SECONDS := 120.0
const MAX_NAME_LENGTH := 12
const PANEL_WIDTH := 1342.0
var input_router: InputRouter
var audio_manager: AudioManager
var _name := ""
var _elapsed := 0.0
var _submitting := false
var _status := "ENTER YOUR NAME"
var _countdown_label: Label
var _keyboard: QwertyKeyboard


func _ready() -> void:
	# This screen must not receive navigation input behind the pause dialog.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func advance(delta: float) -> void:
	if _submitting:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= TIMEOUT_SECONDS:
		if _name.is_empty():
			_skip_name_entry()
		else:
			_confirm()
	elif _countdown_label:
		_countdown_label.text = _countdown_text()


func _delete_selected() -> void:
	if _submitting or _name.is_empty():
		return
	_name = _name.left(_name.length() - 1)
	_build()
	if audio_manager:
		audio_manager.play_event(AudioManager.Event.KEYBOARD_INTERACTION)


func _accept_character(character: String) -> void:
	if _submitting or _name.length() >= MAX_NAME_LENGTH or character.length() != 1:
		return
	var normalized := character.to_upper()
	if not _is_allowed_character(normalized):
		return
	_name += normalized
	_build()
	if audio_manager:
		audio_manager.play_event(AudioManager.Event.KEYBOARD_INTERACTION)


func set_submitting() -> void:
	_submitting = true
	_status = "SUBMITTING SCORE"
	_build()


func _skip_name_entry() -> void:
	if _submitting:
		return
	if audio_manager:
		audio_manager.play_event(AudioManager.Event.NAME_SKIP)
	_submitting = true
	_status = "SKIPPING SCORE"
	_build()
	skipped.emit()


func _unhandled_input(event: InputEvent) -> void:
	if input_router == null or not input_router.owns_event(event) or not event.is_pressed():
		return
	var key_event := event as InputEventKey
	if event.is_action_pressed(&"action_b") or (key_event and key_event.keycode == KEY_BACKSPACE):
		_delete_selected()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"controller_start")
		or (key_event and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER))
	):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"action_x"):
		_skip_name_entry()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var keyboard_selection := (
		_keyboard.selection() if is_instance_valid(_keyboard) else Vector2i.ZERO
	)
	for child in get_children():
		child.queue_free()
	var panel := Panel.new()
	panel.position = Vector2(289, 130)
	panel.size = Vector2(PANEL_WIDTH, 820)
	panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(panel)
	_add_label(panel, "HIGH SCORE", Vector2(0, 42), Vector2(PANEL_WIDTH, 70), 46, Color("fff16a"))
	_add_label(panel, _status, Vector2(0, 125), Vector2(PANEL_WIDTH, 38), 20, Color("42eaff"))
	_add_label(
		panel,
		"NAME  %d / %d" % [_name.length(), MAX_NAME_LENGTH],
		Vector2(0, 188),
		Vector2(PANEL_WIDTH, 30),
		16,
		Color("fff7cf")
	)
	_add_name_display(panel)
	_keyboard = _create_keyboard(keyboard_selection)
	panel.add_child(_keyboard)
	_keyboard.refresh()
	_add_label(
		panel,
		"UP / DOWN / LEFT / RIGHT NAVIGATE   A SELECT   B DELETE   X SKIP   START SUBMIT",
		Vector2(0, 690),
		Vector2(PANEL_WIDTH, 32),
		15,
		Color("fff7cf")
	)
	_countdown_label = ArcadeTheme.make_label(_countdown_text(), 16, Color("e8f7ff"))
	_countdown_label.position = Vector2(0, 750)
	_countdown_label.size = Vector2(PANEL_WIDTH, 30)
	panel.add_child(_countdown_label)


func _create_keyboard(keyboard_selection: Vector2i) -> QwertyKeyboard:
	var keyboard := QwertyKeyboard.new()
	keyboard.position = Vector2(0, 330)
	keyboard.size = Vector2(PANEL_WIDTH, 286)
	keyboard.input_router = input_router
	keyboard.audio_manager = audio_manager
	keyboard.interactive = not _submitting
	keyboard.set_selection(keyboard_selection)
	keyboard.character_selected.connect(_accept_character)
	return keyboard


func _add_name_display(parent: Control) -> void:
	var slots := ""
	for index in MAX_NAME_LENGTH:
		slots += _name[index] if index < _name.length() else "_"
		if index < MAX_NAME_LENGTH - 1:
			slots += " "
	_add_label(
		parent, slots, Vector2(80, 225), Vector2(PANEL_WIDTH - 160.0, 72), 30, Color("e8f7ff")
	)


func _countdown_text() -> String:
	var seconds_remaining := ceili(maxf(0.0, TIMEOUT_SECONDS - _elapsed))
	if _name.is_empty():
		return "SKIP IN %d" % seconds_remaining
	return "AUTO SUBMIT IN %d" % seconds_remaining


func _is_allowed_character(character: String) -> bool:
	return (
		character.length() == 1
		and ((character >= "A" and character <= "Z") or (character >= "0" and character <= "9"))
	)


func _confirm() -> void:
	if _submitting or _name.is_empty():
		return
	if audio_manager:
		audio_manager.play_event(AudioManager.Event.NAME_CONFIRM)
	set_submitting()
	confirmed.emit(_name)


func _add_label(
	parent: Control,
	text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> void:
	var label := ArcadeTheme.make_label(text, font_size, color)
	label.position = position_value
	label.size = size_value
	parent.add_child(label)
