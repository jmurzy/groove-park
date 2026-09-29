## Reusable arcade menu button with pixel styling and focus-driven selection cues.
class_name ArcadeMenuButton
extends Button

signal selection_focused

const LEFT_MARKER_NAME := "SelectionLeft"
const RIGHT_MARKER_NAME := "SelectionRight"

var _base_text := ""
var _uses_text_selection := false


func _ready() -> void:
	focus_entered.connect(_select)
	focus_exited.connect(_deselect)
	mouse_entered.connect(grab_focus)


func configure(
	button_text: String,
	font_size: int,
	uses_text_selection: bool = false,
	selection_shadow_color: Color = Color("01040add")
) -> void:
	_base_text = button_text
	_uses_text_selection = uses_text_selection
	ArcadeTheme.apply_menu_button_style(self, font_size, selection_shadow_color)
	text = button_text
	if not _uses_text_selection:
		_add_selection_markers()


func _select() -> void:
	if _uses_text_selection:
		text = ">  %s  <" % _base_text
	else:
		_set_marker_visibility(true)
	selection_focused.emit()


func _deselect() -> void:
	if _uses_text_selection:
		text = _base_text
	else:
		_set_marker_visibility(false)


func _add_selection_markers() -> void:
	var left_marker := ArcadeTheme.make_label(">", 24, Color("fff16a"))
	left_marker.name = LEFT_MARKER_NAME
	left_marker.position = Vector2(14, 0)
	left_marker.size = Vector2(30, size.y)
	left_marker.hide()
	add_child(left_marker)
	var right_marker := ArcadeTheme.make_label("<", 24, Color("fff16a"))
	right_marker.name = RIGHT_MARKER_NAME
	right_marker.position = Vector2(size.x - 44, 0)
	right_marker.size = Vector2(30, size.y)
	right_marker.hide()
	add_child(right_marker)


func _set_marker_visibility(selected: bool) -> void:
	var left_marker := get_node(NodePath(LEFT_MARKER_NAME)) as Label
	var right_marker := get_node(NodePath(RIGHT_MARKER_NAME)) as Label
	left_marker.visible = selected
	right_marker.visible = selected
