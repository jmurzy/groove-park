## Presents one already-recorded jump result without owning round state or navigation.
class_name ScoreTallyPresenter
extends RefCounted

const DESIGN_SIZE := Vector2(1920, 1080)
const MINIMUM_DISPLAY_TIME := 1.0
const COUNT_UP_START := 1.5
const COUNT_UP_DURATION := 1.2
const AUTO_COMPLETE_TIME := 10.0
const ACCELERATED_RATE := 6.0

var _panel: Panel
var _outcome_label: Label
var _trick_label: Label
var _rows_label: Label
var _multiplier_label: Label
var _jump_total_label: Label
var _round_total_label: Label
var _completion_label: Label
var _footer_label: Label
var _result: JumpResult
var _previous_round_score := 0
var _current_jump_number := 1
var _elapsed := 0.0
var _accelerated := false
var _complete := false


func build(ui_layer: CanvasLayer) -> void:
	_panel = Panel.new()
	_panel.name = "ScoreTally"
	_panel.position = Vector2(450, 170)
	_panel.size = Vector2(1020, 750)
	_panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	_panel.hide()
	ui_layer.add_child(_panel)
	_outcome_label = _add_label(Vector2(0, 34), Vector2(1020, 68), 42, Color("fff16a"))
	_trick_label = _add_label(Vector2(0, 104), Vector2(1020, 42), 22, Color("e8f7ff"))
	_rows_label = _add_label(
		Vector2(90, 168), Vector2(840, 242), 20, Color("68efff"), HORIZONTAL_ALIGNMENT_LEFT
	)
	_multiplier_label = _add_label(Vector2(0, 430), Vector2(1020, 42), 22, Color("e8f7ff"))
	_jump_total_label = _add_label(Vector2(0, 492), Vector2(1020, 48), 30, Color("fff16a"))
	_round_total_label = _add_label(Vector2(0, 548), Vector2(1020, 48), 30, Color("42eaff"))
	_completion_label = _add_label(Vector2(0, 616), Vector2(1020, 40), 22, Color("fff7cf"))
	_footer_label = _add_label(Vector2(0, 668), Vector2(1020, 40), 18, Color("e8f7ff"))


func start(round_state: RoundState, result: JumpResult) -> void:
	_result = result
	_previous_round_score = max(round_state.round_score() - result.resolved_score(), 0)
	_current_jump_number = round_state.current_jump_number()
	_elapsed = 0.0
	_accelerated = false
	_complete = false
	if _panel != null:
		_panel.show()
		_outcome_label.text = JumpOutcome.label(result.outcome())
		_trick_label.text = result.trick_summary()
		_rows_label.text = _component_rows(result.score())
		_multiplier_label.text = (
			"LANDING x%.1f" % (float(result.score().landing_multiplier_milli()) / 1000.0)
		)
		_jump_total_label.text = "JUMP SCORE +0"
		_round_total_label.text = "ROUND SCORE %5d" % _previous_round_score
		_completion_label.hide()
		_footer_label.text = "TALLYING..."


func update(delta: float) -> bool:
	if _result == null or _complete:
		return false
	_elapsed += maxf(delta, 0.0) * (ACCELERATED_RATE if _accelerated else 1.0)
	_update_labels()
	if _elapsed < AUTO_COMPLETE_TIME:
		return false
	_complete = true
	if _panel != null:
		_panel.hide()
	return true


func request_continue() -> bool:
	if _result == null or _complete or _elapsed < MINIMUM_DISPLAY_TIME:
		return false
	_accelerated = true
	return true


func displayed_jump_score() -> int:
	return _counted_score(_result.resolved_score()) if _result != null else 0


func displayed_round_score() -> int:
	return _previous_round_score + displayed_jump_score()


func is_visible() -> bool:
	return _result != null and not _complete


func completion_text() -> String:
	return "JUMP %d COMPLETE" % _current_jump_number


func _update_labels() -> void:
	if _panel == null:
		return
	var revealed := _elapsed >= COUNT_UP_START
	_jump_total_label.text = "JUMP SCORE +%5d" % displayed_jump_score()
	_round_total_label.text = "ROUND SCORE %5d" % displayed_round_score()
	_footer_label.text = _next_action_text() if _elapsed >= MINIMUM_DISPLAY_TIME else "TALLYING..."
	if not revealed:
		_jump_total_label.text = "JUMP SCORE"
		_round_total_label.text = "ROUND SCORE %5d" % _previous_round_score
	_completion_label.visible = _elapsed >= COUNT_UP_START + COUNT_UP_DURATION
	_completion_label.text = completion_text()


func _next_action_text() -> String:
	if _current_jump_number >= RoundState.MAX_JUMPS:
		return "FINAL TALLY. PRESS START OR A TO HURRY"
	return "JUMP %d NEXT! PRESS START OR A TO HURRY" % (_current_jump_number + 1)


func _counted_score(score: int) -> int:
	var progress := clampf((_elapsed - COUNT_UP_START) / COUNT_UP_DURATION, 0.0, 1.0)
	return roundi(float(score) * progress)


func _component_rows(score: JumpScore) -> String:
	return (
		"\n"
		.join(
			[
				"APPROACH      +%d" % score.approach_points(),
				"TAKEOFF       +%d" % score.takeoff_points(),
				"AIRTIME       +%d" % score.airtime_points(),
				"ROTATION      +%d" % score.rotation_points(),
				"GRAB          +%d" % score.grab_points(),
				"STYLE BONUS   +%d" % score.style_bonus_points(),
			]
		)
	)


func _add_label(
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_CENTER
) -> Label:
	var label := ArcadeTheme.make_label("", font_size, color)
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = alignment
	label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(label)
	return label
