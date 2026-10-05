## Samples gameplay intent and translates unhandled events into screen commands.
class_name GameplayInputController
extends RefCounted

const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")

# R restart is only available when the gameplay presenter was created with terrain diagnostics.
var _debug_restart_enabled := false


# Receives the terrain-debug policy once when a gameplay run is constructed.
func configure(debug_restart_enabled: bool) -> void:
	_debug_restart_enabled = debug_restart_enabled


# Builds one immutable-in-practice input snapshot for the next fixed simulation step. InputRouter
# has already excluded every unowned source, so these values belong to the round owner only.
func sample_frame(input_router: InputRouter) -> RiderInputFrame:
	var frame := RiderInputFrameScene.new()
	frame.heading = Vector2(
		(
			int(input_router.is_action_pressed(&"move_right"))
			- int(input_router.is_action_pressed(&"move_left"))
		),
		(
			int(input_router.is_action_pressed(&"move_down"))
			- int(input_router.is_action_pressed(&"move_up"))
		)
	)
	if not frame.heading.is_zero_approx():
		# The cabinet stick is digital. Normalizing makes every diagonal one of eight headings.
		frame.heading = frame.heading.normalized()
	# W/S choose the neighboring authored approach path once per press.
	frame.approach_path_change = (
		int(input_router.is_action_just_pressed(&"move_down"))
		- int(input_router.is_action_just_pressed(&"move_up"))
	)
	frame.tuck_pressed = input_router.is_action_pressed(&"action_a")
	# A tucks during approach and holds a grab during flight; phase-specific simulation decides.
	frame.grab_pressed = frame.tuck_pressed
	frame.grab_just_pressed = input_router.is_action_just_pressed(&"action_a")
	frame.brake_pressed = input_router.is_action_pressed(&"action_b")
	frame.pop_pressed = input_router.is_action_pressed(&"action_x")
	frame.pop_just_pressed = input_router.is_action_just_pressed(&"action_x")
	frame.pop_just_released = input_router.is_action_just_released(&"action_x")
	# B brakes during approach and tweaks an active grab during flight; phase-specific simulation
	# decides.
	frame.tweak_pressed = frame.brake_pressed
	frame.tweak_just_pressed = input_router.is_action_just_pressed(&"action_b")
	frame.spin_lt_pressed = input_router.is_action_pressed(&"action_lt")
	frame.spin_lt_just_pressed = input_router.is_action_just_pressed(&"action_lt")
	frame.spin_rt_pressed = input_router.is_action_pressed(&"action_rt")
	frame.spin_rt_just_pressed = input_router.is_action_just_pressed(&"action_rt")
	frame.landing_prep_pressed = input_router.is_action_pressed(&"action_x")
	return frame


# Converts owner-only UI events into semantic screen commands. The screen performs the resulting
# action, keeping this controller independent of pause menus, scene lifetime, and navigation.
# gdlint: disable=max-returns
func screen_command(
	event: InputEvent, session: GameSession, input_router: InputRouter
) -> StringName:
	if not input_router.owns_event(event):
		return &""
	if (
		session.session_phase == RoundState.SessionPhase.CRASH_RESCUE
		and (event.is_action_pressed(&"controller_start") or event.is_action_pressed(&"action_a"))
	):
		return &"skip_crash_rescue"
	if (
		session.session_phase == RoundState.SessionPhase.JUMP_TALLY
		and (event.is_action_pressed(&"controller_start") or event.is_action_pressed(&"action_a"))
	):
		return &"advance_jump_tally"
	if session.session_phase == RoundState.SessionPhase.ROUND_RESULTS:
		if event.is_action_pressed(&"controller_start") or event.is_action_pressed(&"action_a"):
			return &"new_round"
		if event.is_action_pressed(&"controller_back") or event.is_action_pressed(&"action_b"):
			return &"return_to_attract"
	if (
		_debug_restart_enabled
		and session.session_phase == RoundState.SessionPhase.JUMP_ACTIVE
		and event.is_action_pressed(&"debug_restart")
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
# gdlint: enable=max-returns
