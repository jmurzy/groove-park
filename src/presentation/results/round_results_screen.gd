## Displays immutable local round results.
class_name RoundResultsScreen
extends Control

const CENTERED_PANEL_POSITION := Vector2(370, 135)
const LEADERBOARD_PANEL_POSITION := Vector2(90, 135)
const LEADERBOARD_REVEAL_DURATION := 0.35

var _round_state: RoundState
var _result_rows := PackedStringArray()
var _leaderboard := Leaderboard.new()
var _panel: Panel
var _leaderboard_overlay: LeaderboardOverlay
var _leaderboard_status: Label


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
	if not is_inside_tree():
		return
	if _panel == null:
		_build()
		return
	_update_leaderboard_status()
	var leaderboard_entries := _leaderboard.top_entries()
	if leaderboard_entries.is_empty():
		return
	if _leaderboard_overlay:
		_leaderboard_overlay.queue_free()
		_add_leaderboard_overlay(_panel, leaderboard_entries)
		return
	_add_leaderboard_overlay(_panel, leaderboard_entries, true)
	_animate_leaderboard_reveal()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _round_state:
		_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_panel = null
	_leaderboard_overlay = null
	_leaderboard_status = null
	var leaderboard_entries := _leaderboard.top_entries()
	_panel = Panel.new()
	_panel.position = (
		LEADERBOARD_PANEL_POSITION
		if not leaderboard_entries.is_empty()
		else CENTERED_PANEL_POSITION
	)
	_panel.size = Vector2(1180, 810)
	_panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(_panel)
	_add_label(_panel, "ROUND RESULTS", Vector2(0, 34), Vector2(1180, 64), 38, Color("fff16a"))
	_add_label(
		_panel,
		(
			"%s  |  FINAL SCORE %d"
			% [String(_round_state.rider_kind()).to_upper(), _round_state.round_score()]
		),
		Vector2(0, 112),
		Vector2(1180, 40),
		20,
		Color("42eaff")
	)
	_update_leaderboard_status()
	_add_label(
		_panel,
		"\n".join(_result_rows),
		Vector2(160, 205),
		Vector2(860, 300),
		22,
		Color("e8f7ff"),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_add_leaderboard_overlay(_panel, leaderboard_entries)
	_add_label(
		_panel,
		"PRESS START OR A FOR NEW ROUND",
		Vector2(0, 625),
		Vector2(1180, 36),
		17,
		Color("fff7cf")
	)
	_add_label(
		_panel,
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
) -> Label:
	var label := ArcadeTheme.make_label(text, font_size, color)
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label


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


func _update_leaderboard_status() -> void:
	var status_text := _leaderboard_status_text()
	if _leaderboard_status:
		if status_text.is_empty():
			_leaderboard_status.queue_free()
			_leaderboard_status = null
		else:
			_leaderboard_status.text = status_text
	elif not status_text.is_empty():
		_leaderboard_status = _add_label(
			_panel, status_text, Vector2(0, 160), Vector2(1180, 30), 16, Color("fff7cf")
		)


func _add_leaderboard_overlay(
	panel: Control, leaderboard_entries: Array[LeaderboardEntry], reveal := false
) -> void:
	if leaderboard_entries.is_empty():
		return
	_leaderboard_overlay = LeaderboardOverlay.new()
	_leaderboard_overlay.position = Vector2(1060, 36)
	_leaderboard_overlay.show_entries(
		leaderboard_entries, _leaderboard.rank(), _round_state.rider_kind()
	)
	if reveal:
		_leaderboard_overlay.modulate.a = 0.0
	panel.add_child(_leaderboard_overlay)


func _animate_leaderboard_reveal() -> void:
	var tween := create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_panel, "position", LEADERBOARD_PANEL_POSITION, LEADERBOARD_REVEAL_DURATION
	)
	tween.tween_property(_leaderboard_overlay, "modulate:a", 1.0, LEADERBOARD_REVEAL_DURATION)
