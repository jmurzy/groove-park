## Displays immutable local round results.
class_name RoundResultsScreen
extends Control

var _round_state: RoundState
var _result_rows := PackedStringArray()
var _leaderboard := Leaderboard.new()


func show_round(round_state: RoundState, leaderboard: Leaderboard) -> void:
	_round_state = round_state
	_result_rows = _rows_for(round_state)
	_leaderboard = leaderboard
	if is_inside_tree():
		_build()


func result_rows() -> PackedStringArray:
	return _result_rows.duplicate()


func refresh_leaderboard(leaderboard: Leaderboard) -> void:
	_leaderboard = leaderboard
	if is_inside_tree():
		_build()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _round_state:
		_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var leaderboard_entries := _leaderboard.top_entries()
	var panel := Panel.new()
	panel.position = Vector2(90, 135) if not leaderboard_entries.is_empty() else Vector2(370, 135)
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
	var leaderboard_status := _leaderboard_status_text()
	if not leaderboard_status.is_empty():
		_add_label(
			panel, leaderboard_status, Vector2(0, 160), Vector2(1180, 30), 16, Color("fff7cf")
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
	_add_leaderboard_overlay(panel, leaderboard_entries)
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


func _leaderboard_status_text() -> String:
	if _leaderboard.status() == Leaderboard.Status.OFFLINE:
		return "LEADERBOARD OFFLINE"
	if not _leaderboard.is_qualified():
		return "NOT ON LEADERBOARD"
	if _leaderboard.is_qualified() and _leaderboard.rank() == null:
		return "LEADERBOARD SKIPPED"
	if _leaderboard.rank() is int:
		return "GLOBAL RANK %d" % _leaderboard.rank()
	return ""


func _add_leaderboard_overlay(panel: Control, leaderboard_entries: Array[LeaderboardEntry]) -> void:
	if leaderboard_entries.is_empty():
		return
	var leaderboard_overlay := LeaderboardOverlay.new()
	leaderboard_overlay.position = Vector2(1060, 36)
	leaderboard_overlay.show_entries(
		leaderboard_entries, _leaderboard.rank(), _round_state.rider_kind()
	)
	panel.add_child(leaderboard_overlay)
