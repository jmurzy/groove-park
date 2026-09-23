## One physics tick of phase-neutral player intent (stick heading, tuck/brake/edge,
## pop, grab/tweak, landing prep). Example: `RiderInputFrame.from_actions()`.
class_name RiderInputFrame
extends RefCounted

# One fixed physics tick of phase-neutral player intent.
var heading := Vector2.ZERO
var tuck_pressed := false
var brake_pressed := false
var pop_pressed := false
var pop_just_pressed := false
var pop_just_released := false
var edge_pressed := false
var grab_pressed := false
var grab_just_pressed := false
var tweak_pressed := false
var tweak_just_pressed := false
var landing_prep_pressed := false
var approach_path_change := 0


static func from_actions() -> RiderInputFrame:
	var frame := RiderInputFrame.new()
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
	frame.edge_pressed = Input.is_action_pressed(&"action_y")
	frame.tweak_pressed = Input.is_action_pressed(&"action_x")
	frame.tweak_just_pressed = Input.is_action_just_pressed(&"action_x")
	frame.landing_prep_pressed = Input.is_action_pressed(&"action_b")
	return frame
