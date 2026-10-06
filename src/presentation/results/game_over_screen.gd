## Presents the immutable game-over state while GameSession owns its transition timing.
class_name GameOverScreen
extends Control

var _round_state: RoundState
var _leaderboard_message := "PREPARING ROUND RESULTS"


func show_round(round_state: RoundState) -> void:
	_round_state = round_state
	if is_inside_tree():
		_build()


func set_leaderboard_message(message: String) -> void:
	_leaderboard_message = message
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
	var panel := Panel.new()
	panel.position = Vector2(510, 325)
	panel.size = Vector2(900, 430)
	panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(panel)
	_add_label(panel, "GAME OVER", Vector2(0, 70), Vector2(900, 90), 54, Color("fff16a"))
	_add_label(
		panel,
		"FINAL SCORE %d" % _round_state.round_score(),
		Vector2(0, 185),
		Vector2(900, 60),
		30,
		Color("42eaff")
	)
	_add_label(panel, _leaderboard_message, Vector2(0, 292), Vector2(900, 40), 18, Color("e8f7ff"))


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
