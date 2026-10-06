## Renders and navigates the character grid for player-name entry.
class_name QwertyKeyboard
extends Control

signal character_selected(character: String)

const KEY_ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM", "0123456789"]
const KEY_SIZE := Vector2(82, 58)
const KEY_GAP := 10.0
const ROW_GAP := 18.0
const NAVIGATION_REPEAT_DELAY := 0.35
const NAVIGATION_REPEAT_INTERVAL := 0.09

var input_router: InputRouter
var audio_manager: AudioManager
var interactive := true
var _selected_row := 0
var _selected_column := 0
var _held_navigation_action := &""
var _navigation_repeat_elapsed := 0.0


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	for row_index in KEY_ROWS.size():
		var row: String = KEY_ROWS[row_index]
		var row_width: float = row.length() * KEY_SIZE.x + (row.length() - 1) * KEY_GAP
		var start_x: float = (size.x - row_width) / 2.0
		for column_index in row.length():
			_add_key(row_index, column_index, row[column_index], start_x)


func _process(delta: float) -> void:
	_advance_navigation_repeat(delta)


func _unhandled_input(event: InputEvent) -> void:
	if (
		not interactive
		or input_router == null
		or not input_router.owns_event(event)
		or not event.is_pressed()
	):
		return
	var key_event := event as InputEventKey
	if event.is_action_pressed(&"move_left"):
		_begin_navigation(&"move_left", Vector2i.LEFT, key_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right"):
		_begin_navigation(&"move_right", Vector2i.RIGHT, key_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_up"):
		_begin_navigation(&"move_up", Vector2i.UP, key_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_down"):
		_begin_navigation(&"move_down", Vector2i.DOWN, key_event)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"action_a"):
		_select()
		get_viewport().set_input_as_handled()


func _move_horizontal(direction: int) -> void:
	var row: String = KEY_ROWS[_selected_row]
	_selected_column = posmod(_selected_column + direction, row.length())
	refresh()


func _move_vertical(direction: int) -> void:
	var selected_x := _key_center_x(_selected_row, _selected_column)
	_selected_row = posmod(_selected_row + direction, KEY_ROWS.size())
	_selected_column = _closest_column(_selected_row, selected_x)
	refresh()


func _select() -> void:
	character_selected.emit(KEY_ROWS[_selected_row][_selected_column])


func selection() -> Vector2i:
	return Vector2i(_selected_row, _selected_column)


func set_selection(value: Vector2i) -> void:
	_selected_row = clampi(value.x, 0, KEY_ROWS.size() - 1)
	_selected_column = clampi(value.y, 0, KEY_ROWS[_selected_row].length() - 1)


func _begin_navigation(action: StringName, direction: Vector2i, key_event: InputEventKey) -> void:
	if key_event and key_event.echo:
		return
	_held_navigation_action = action
	_navigation_repeat_elapsed = 0.0
	_move(direction)


func _advance_navigation_repeat(delta: float) -> void:
	if (
		not interactive
		or _held_navigation_action.is_empty()
		or input_router == null
		or not input_router.is_action_pressed(_held_navigation_action)
	):
		_held_navigation_action = &""
		_navigation_repeat_elapsed = 0.0
		return
	_navigation_repeat_elapsed += maxf(delta, 0.0)
	var repeat_delay := NAVIGATION_REPEAT_DELAY
	while _navigation_repeat_elapsed >= repeat_delay:
		_navigation_repeat_elapsed -= repeat_delay
		_move(_navigation_direction(_held_navigation_action))
		repeat_delay = NAVIGATION_REPEAT_INTERVAL


func _navigation_direction(action: StringName) -> Vector2i:
	match action:
		&"move_left":
			return Vector2i.LEFT
		&"move_right":
			return Vector2i.RIGHT
		&"move_up":
			return Vector2i.UP
		&"move_down":
			return Vector2i.DOWN
	return Vector2i.ZERO


func _move(direction: Vector2i) -> void:
	if direction.x:
		_move_horizontal(direction.x)
	elif direction.y:
		_move_vertical(direction.y)
	if audio_manager:
		audio_manager.play_event(AudioManager.Event.KEYBOARD_MOVE)


func _key_center_x(row_index: int, column_index: int) -> float:
	var row: String = KEY_ROWS[row_index]
	var row_width: float = row.length() * KEY_SIZE.x + (row.length() - 1) * KEY_GAP
	var start_x: float = (size.x - row_width) / 2.0
	return start_x + column_index * (KEY_SIZE.x + KEY_GAP) + KEY_SIZE.x / 2.0


func _closest_column(row_index: int, x: float) -> int:
	var row: String = KEY_ROWS[row_index]
	var closest_column := 0
	var closest_distance := INF
	for column_index in row.length():
		var distance := absf(_key_center_x(row_index, column_index) - x)
		if distance < closest_distance:
			closest_column = column_index
			closest_distance = distance
	return closest_column


func _add_key(row_index: int, column_index: int, character: String, start_x: float) -> void:
	var key := Panel.new()
	key.position = Vector2(
		start_x + column_index * (KEY_SIZE.x + KEY_GAP), row_index * (KEY_SIZE.y + ROW_GAP)
	)
	key.size = KEY_SIZE
	var selected := row_index == _selected_row and column_index == _selected_column
	key.add_theme_stylebox_override(
		"panel",
		ArcadeTheme.button_style(
			Color("16406b") if selected else Color("0b2545"),
			Color("fff16a") if selected else Color("238bd4"),
			5 if selected else 3,
			8 if selected else 4
		)
	)
	add_child(key)
	var label := ArcadeTheme.make_label(
		character, 24, Color("fff7cf") if selected else Color("e8f7ff")
	)
	label.position = Vector2.ZERO
	label.size = KEY_SIZE
	key.add_child(label)
