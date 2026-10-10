## Headless checks for marquee lifecycle ownership and gameplay context updates.
extends SceneTree

const MarqueeFlowControllerScene := preload("res://src/app/marquee_flow_controller.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_marquee_receives_initial_and_gameplay_context()
	if _failures.is_empty():
		print("Marquee-flow controller checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_marquee_receives_initial_and_gameplay_context() -> void:
	var session := GameSession.new()
	var flow := MarqueeFlowControllerScene.new()
	get_root().add_child(session)
	get_root().add_child(flow)
	flow.setup(session, LiftieStateService.new())
	_expect(
		flow._marquee_view._session_phase == RoundState.SessionPhase.ATTRACT,
		"The marquee must start with the session's attract context."
	)
	session.start_game(RiderKind.SKIER)
	_expect(
		(
			flow._marquee_view._session_phase == RoundState.SessionPhase.JUMP_ACTIVE
			and flow._marquee_view._round_state == session.round_state()
		),
		"Starting a round must refresh the marquee with the active jump context."
	)
	flow.free()
	session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
