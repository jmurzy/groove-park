## Displays immutable local round results.
class_name RoundResultsScreen
extends Control

var _round_state: RoundState
var _result_rows := PackedStringArray()


func show_round(round_state: RoundState) -> void:
	_round_state = round_state
	_result_rows = _rows_for(round_state)
	if is_inside_tree():
		_build()


func result_rows() -> PackedStringArray:
	return _result_rows.duplicate()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _round_state:
		_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var panel := Panel.new()
	panel.position = Vector2(370, 135)
	panel.size = Vector2(1180, 810)
	panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(panel)
	_add_label(panel, "ROUND RESULTS", Vector2(0, 34), Vector2(1180, 64), 38, Color("fff16a"))
	_add_label(
		panel,
		(
			"%s  |  FINAL SCORE %d"
			% [String(_round_state.rider_kind()).to_upper(), _round_state.round_score()]
		),
		Vector2(0, 112),
		Vector2(1180, 40),
		20,
		Color("42eaff")
	)
	_add_label(
		panel,
		"\n".join(_result_rows),
		Vector2(160, 205),
		Vector2(860, 300),
		22,
		Color("e8f7ff"),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_add_label(
		panel,
		"PRESS START OR A FOR NEW ROUND",
		Vector2(0, 625),
		Vector2(1180, 36),
		17,
		Color("fff7cf")
	)
	_add_label(
		panel,
		"PRESS BACK OR B FOR ATTRACT",
		Vector2(0, 680),
		Vector2(1180, 30),
		15,
		Color("e8f7ff")
	)


func _add_label(
	parent: Control,
	text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	var label := ArcadeTheme.make_label(text, font_size, color)
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = alignment
	parent.add_child(label)


func _rows_for(round_state: RoundState) -> PackedStringArray:
	var rows := PackedStringArray()
	for result in round_state.jump_results():
		rows.append(
			(
				"JUMP %d    %-14s +%d"
				% [rows.size() + 1, JumpOutcome.label(result.outcome()), result.resolved_score()]
			)
		)
	return rows
