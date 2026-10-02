## Claims one logical keyboard or gamepad for a solo round.
##
## Godot's Input singleton merges matching actions from every connected device. That is useful
## for general UI, but not for a cabinet round: after a player chooses a rider, another player
## must not be able to steer, pause, navigate a focused control, or advance a tally. This node
## receives raw input events, records state only for the claimed source, and consumes matching
## events from every other source before GUI focus handling can act on them.
class_name InputRouter
extends Node

# Keyboard events are treated as one logical device even though Godot does not give each physical
# keyboard a useful player identity. Gamepad events retain their Godot device ID instead.
const KEYBOARD_DEVICE := -1

# These actions form a RiderInputFrame. The router maintains pressed and edge-triggered state for
# them because gameplay samples input during physics ticks rather than directly from raw events.
const _TRACKED_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"action_a",
	&"action_b",
	&"action_x",
	&"action_lt",
	&"action_rt",
]
# This broader set includes tracked gameplay actions plus every action that can move focused UI,
# accept/cancel a dialog, pause, exit, or restart. Unowned events matching one of these actions
# are marked handled in _input so Godot's wildcard GUI navigation cannot bypass ownership.
const _FILTERED_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"action_a",
	&"action_b",
	&"action_x",
	&"action_lt",
	&"action_rt",
	&"controller_start",
	&"controller_back",
	&"cabinet_exit",
	&"exit_escape",
	&"ui_accept",
	&"ui_cancel",
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
	&"debug_restart",
]

# Configured at app composition time. Release cabinets reject a keyboard claim; Web and debug
# builds can use the keyboard as the logical round owner.
var _keyboard_claiming_allowed := true
# The current gamepad device ID, or KEYBOARD_DEVICE when the logical keyboard owns the round.
var _claimed_device := KEYBOARD_DEVICE
# No owner exists at attract mode or before a rider-select action claims one.
var _has_owner := false
# Current held state and one-physics-tick edges for _TRACKED_ACTIONS. Dictionaries avoid coupling
# this routing layer to RiderInputFrame while keeping action names typed at the call boundary.
var _pressed: Dictionary = {}
var _just_pressed: Dictionary = {}
var _just_released: Dictionary = {}


# Sets the platform policy without changing a current claim. This is called once during startup.
func configure(keyboard_claiming_allowed: bool) -> void:
	_keyboard_claiming_allowed = keyboard_claiming_allowed


# Lets screen flow distinguish attract/rider-select from an active owned round.
func has_owner() -> bool:
	return _has_owner


# True only when the logical keyboard, rather than a gamepad, owns the current round.
func owns_keyboard() -> bool:
	return _has_owner and _claimed_device == KEYBOARD_DEVICE


# Returns -1 for no owner or keyboard ownership so callers never mistake a keyboard for gamepad 0.
func claimed_gamepad_id() -> int:
	return _claimed_device if _has_owner and _claimed_device != KEYBOARD_DEVICE else -1


# Claims the first valid raw source used to choose a rider.
#
# Once owned, this is also the rider-select gate: repeat input from the owner is accepted and
# updates its action state, while another source is rejected. Callers invoke this only for rider
# selection actions, not arbitrary key presses, so unrelated input cannot claim a round.
func claim_from_rider_select(event: InputEvent) -> bool:
	if _has_owner:
		if not owns_event(event):
			return false
		observe_event(event)
		return true
	var device: Variant = _device_for(event)
	if device == null or (device == KEYBOARD_DEVICE and not _keyboard_claiming_allowed):
		return false
	_claimed_device = device
	_has_owner = true
	observe_event(event)
	return true


# Releases ownership on return to attract and clears held/edge state so a newly claimed round
# cannot inherit a stuck button from the previous player.
func release_owner() -> void:
	_has_owner = false
	_claimed_device = KEYBOARD_DEVICE
	_pressed.clear()
	_just_pressed.clear()
	_just_released.clear()


# Checks whether an event originated from the current logical keyboard or exact claimed gamepad.
# Events that are not keyboard or joypad input deliberately have no owner.
func owns_event(event: InputEvent) -> bool:
	if not _has_owner:
		return false
	var device: Variant = _device_for(event)
	return device != null and device == _claimed_device


# The following accessors are consumed by GameplayInputController when it builds a physics frame.
func is_action_pressed(action: StringName) -> bool:
	return _pressed.get(action, false)


func is_action_just_pressed(action: StringName) -> bool:
	return _just_pressed.get(action, false)


func is_action_just_released(action: StringName) -> bool:
	return _just_released.get(action, false)


# Called once after gameplay physics samples input. Edge state lasts through the matching render
# update and physics step, but held state remains until an owner release event arrives.
func finish_physics_frame() -> void:
	_just_pressed.clear()
	_just_released.clear()


# Records an owned raw event against every gameplay action it matches. A single event can update
# both held and edge state; release events clear held state and expose a one-tick release edge.
# Calling this for an unowned event is harmless and intentionally does nothing.
func observe_event(event: InputEvent) -> void:
	if not owns_event(event):
		return
	for action in _TRACKED_ACTIONS:
		if event.is_action_pressed(action):
			_pressed[action] = true
			_just_pressed[action] = true
		elif event.is_action_released(action):
			_pressed[action] = false
			_just_released[action] = true


# Runs before GUI and _unhandled_input dispatch. Owner events feed the gameplay state buffer.
# Matching input from another device is consumed here, preventing focused Buttons, pause menus,
# and other wildcard action listeners from responding to a player who does not own the round.
func _input(event: InputEvent) -> void:
	if not _has_owner:
		return
	if owns_event(event):
		observe_event(event)
		return
	if _is_filtered_unowned_event(event):
		get_viewport().set_input_as_handled()


# Identifies actions that would have an observable game or UI effect if an unowned source reached
# the rest of Godot's input pipeline. debug_restart remains terrain-debug gated by the gameplay
# input controller, but unowned sources must still be prevented from reaching that controller.
func _is_filtered_unowned_event(event: InputEvent) -> bool:
	for action in _FILTERED_ACTIONS:
		if event.is_action_pressed(action) or event.is_action_released(action):
			return true
	return false


# Converts supported raw event families into this router's source identity. Keyboard keys share
# one logical source; joypad buttons and axes use their actual device ID; mouse/touch/other events
# are not ownership candidates for this controller-first release.
func _device_for(event: InputEvent) -> Variant:
	if event is InputEventKey:
		return KEYBOARD_DEVICE
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device
	return null
