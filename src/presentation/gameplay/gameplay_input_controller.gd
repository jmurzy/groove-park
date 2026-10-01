## Samples gameplay intent and translates unhandled events into screen commands.
class_name GameplayInputController
extends RefCounted

const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")


func sample_frame() -> RiderInputFrame:
	var frame := RiderInputFrameScene.new()
	frame.heading = Vector2(
		Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_up", &"move_down")
	)
	if not frame.heading.is_zero_approx():
		# The cabinet stick is digital. Normalizing makes every diagonal one of eight headings.
		frame.heading = frame.heading.normalized()
	# W/S choose the neighboring authored approach path once per press.
	frame.approach_path_change = (
		int(Input.is_action_just_pressed(&"move_down"))
		- int(Input.is_action_just_pressed(&"move_up"))
	)
	frame.tuck_pressed = Input.is_action_pressed(&"action_a")
	frame.grab_pressed = frame.tuck_pressed
	frame.grab_just_pressed = Input.is_action_just_pressed(&"action_a")
	frame.brake_pressed = Input.is_action_pressed(&"action_b")
	frame.pop_pressed = Input.is_action_pressed(&"action_x")
	frame.pop_just_pressed = Input.is_action_just_pressed(&"action_x")
	frame.pop_just_released = Input.is_action_just_released(&"action_x")
	frame.tweak_pressed = frame.brake_pressed
	frame.tweak_just_pressed = Input.is_action_just_pressed(&"action_b")
	frame.spin_lt_pressed = Input.is_action_pressed(&"action_lt")
	frame.spin_lt_just_pressed = Input.is_action_just_pressed(&"action_lt")
	frame.spin_rt_pressed = Input.is_action_pressed(&"action_rt")
	frame.spin_rt_just_pressed = Input.is_action_just_pressed(&"action_rt")
	frame.landing_prep_pressed = Input.is_action_pressed(&"action_x")
	return frame


func screen_command(event: InputEvent, run_manager: RiderRunManager) -> StringName:
	if (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).echo
		and (event as InputEventKey).keycode == KEY_R
	):
		return &"restart"
	if (
		(run_manager.is_crashed() or run_manager.is_bailed() or run_manager.is_complete())
		and event.is_action_pressed(&"controller_start")
	):
		return &"restart"
	if (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"controller_start")
		or event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"cabinet_exit")
	):
		return &"pause"
	return &""
