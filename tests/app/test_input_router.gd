## Headless checks for logical keyboard and per-gamepad round ownership.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_test_keyboard_and_gamepad_claims()
	_test_claim_excludes_other_sources_and_releases_at_attract()
	_test_cabinet_policy_rejects_keyboard_claiming()
	if _failures.is_empty():
		print("Input-router checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_keyboard_and_gamepad_claims() -> void:
	var keyboard_router := InputRouter.new()
	keyboard_router.configure(true)
	var keyboard_event := _key_event(KEY_J)
	_expect(
		keyboard_router.claim_from_rider_select(keyboard_event),
		"Keyboard must be claimable when the policy permits it."
	)
	_expect(
		keyboard_router.owns_keyboard(), "Keyboard claims must retain the logical keyboard owner."
	)
	_expect(
		keyboard_router.is_action_pressed(&"action_a"),
		"Owned keyboard events must populate gameplay action state."
	)

	var gamepad_router := InputRouter.new()
	gamepad_router.configure(true)
	var gamepad_event := _button_event(3, JOY_BUTTON_A)
	_expect(
		gamepad_router.claim_from_rider_select(gamepad_event),
		"A specific gamepad must be claimable."
	)
	_expect(gamepad_router.claimed_gamepad_id() == 3, "The claimed gamepad ID must be retained.")
	_expect(
		gamepad_router.is_action_pressed(&"action_a"),
		"Owned gamepad events must populate gameplay action state."
	)


func _test_claim_excludes_other_sources_and_releases_at_attract() -> void:
	var router := InputRouter.new()
	router.configure(true)
	var owner_event := _button_event(2, JOY_BUTTON_A)
	var other_gamepad_event := _button_event(4, JOY_BUTTON_A)
	var keyboard_event := _key_event(KEY_J)
	router.claim_from_rider_select(owner_event)
	_expect(
		not router.claim_from_rider_select(other_gamepad_event), "Other gamepads must be excluded."
	)
	_expect(
		not router.claim_from_rider_select(keyboard_event),
		"Keyboard must be excluded by a gamepad claim."
	)
	_expect(
		not router.owns_event(other_gamepad_event), "Unowned gamepad events must not be accepted."
	)
	_expect(not router.owns_event(keyboard_event), "Unowned keyboard events must not be accepted.")
	var other_move_event := _button_event(4, JOY_BUTTON_DPAD_RIGHT)
	router.observe_event(other_move_event)
	_expect(
		not router.is_action_pressed(&"move_right"),
		"Unowned input must not populate the gameplay frame."
	)
	router.observe_event(_button_event(2, JOY_BUTTON_DPAD_RIGHT))
	_expect(
		router.is_action_pressed(&"move_right"), "Owned input must populate the gameplay frame."
	)
	router.finish_physics_frame()
	_expect(
		not router.is_action_just_pressed(&"action_a"),
		"Restarting an unrecorded jump can clear edge state without releasing ownership."
	)
	_expect(router.has_owner(), "Input ownership must survive a current-jump restart.")
	router.release_owner()
	_expect(not router.has_owner(), "Returning to attract must release input ownership.")
	_expect(
		router.claim_from_rider_select(keyboard_event),
		"A released round must allow a new source to claim the next round."
	)


func _test_cabinet_policy_rejects_keyboard_claiming() -> void:
	var router := InputRouter.new()
	router.configure(false)
	_expect(
		not router.claim_from_rider_select(_key_event(KEY_J)),
		"Cabinet production policy must reject keyboard claims."
	)
	_expect(
		router.claim_from_rider_select(_button_event(1, JOY_BUTTON_A)),
		"Cabinet production policy must still accept a gamepad claim."
	)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _button_event(device: int, button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
