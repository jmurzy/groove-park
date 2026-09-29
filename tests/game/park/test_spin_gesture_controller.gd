## Headless checks for the shared two-press spin gesture state machine.
extends SceneTree

const SpinGestureControllerScene := preload("res://src/game/park/spin_gesture_controller.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_requires_release_and_matching_second_press()
	_test_completion_preserves_full_turn()
	_test_stop_preserves_incomplete_progress()
	if _failures.is_empty():
		print("Spin gesture controller checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_requires_release_and_matching_second_press() -> void:
	var gesture := SpinGestureControllerScene.new()
	_expect(
		gesture.update_input(true, false, true, false, true, false, 0.5, 1.0),
		"First press must start."
	)
	gesture.advance(1.0, 1.0)
	_expect(
		gesture.phase == SpinGestureController.Phase.WAITING_SECOND_PRESS,
		"First half must stop at 180."
	)
	_expect(
		not gesture.update_input(true, false, true, false, true, false, 0.5, 1.0),
		"Held trigger must not repeat."
	)
	gesture.update_input(false, false, false, false, true, false, 0.5, 1.0)
	_expect(
		not gesture.update_input(false, true, false, true, true, false, 0.5, 1.0),
		"Opposite trigger must not complete."
	)
	_expect(
		gesture.update_input(true, false, true, false, true, false, 0.5, 1.0),
		"Re-armed matching trigger must complete."
	)


func _test_completion_preserves_full_turn() -> void:
	var gesture := SpinGestureControllerScene.new()
	gesture.update_input(false, true, false, true, true, true, PI, TAU)
	gesture.advance(1.0, TAU)
	gesture.update_input(false, false, false, false, true, true, PI, TAU)
	gesture.update_input(false, true, false, true, true, true, PI, TAU)
	_expect(gesture.advance(1.0, TAU), "Second half must report completion.")
	_expect(is_equal_approx(gesture.progress, TAU), "Completion must retain full-turn progress.")
	_expect(gesture.direction == 1 and gesture.tweak, "Completion must retain style and direction.")


func _test_stop_preserves_incomplete_progress() -> void:
	var gesture := SpinGestureControllerScene.new()
	gesture.update_input(true, false, true, false, true, false, PI, TAU)
	gesture.advance(0.25, PI)
	var progress_before_stop := gesture.progress
	gesture.update_input(true, false, false, false, false, false, PI, TAU)
	_expect(
		is_equal_approx(gesture.progress, progress_before_stop),
		"Stopping must preserve partial progress."
	)
	_expect(not gesture.is_advancing(), "Stopping must end rotation.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
