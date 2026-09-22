## Samples gameplay intent and translates unhandled events into screen commands.
class_name GameplayInputController
extends RefCounted

const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")


func sample_frame() -> RiderInputFrame:
	return RiderInputFrameScene.from_actions()


func screen_command(event: InputEvent, run_manager: RiderRunManager) -> StringName:
	if (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).echo
		and (event as InputEventKey).keycode == KEY_R
	):
		return &"restart"
	if run_manager.is_crashed() and event.is_action_pressed(&"controller_start"):
		return &"restart"
	if (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"controller_start")
		or event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"cabinet_exit")
	):
		return &"pause"
	return &""
