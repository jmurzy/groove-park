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
	var mountain_state_source := MountainStateSource.new()
	var flow := MarqueeFlowControllerScene.new()
	get_root().add_child(session)
	get_root().add_child(mountain_state_source)
	get_root().add_child(flow)
	flow.setup(session, mountain_state_source)
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
	var mountain_state := MountainState.create(
		[LiftState.create("Sky Express", LiftState.Status.HOLD)]
	)
	mountain_state_source._refresh_mountain_state(mountain_state)
	_expect(
		flow._marquee_view._ticker._lifts == mountain_state.lifts,
		"The marquee must receive mountain-state updates."
	)
	_expect(
		flow._marquee_view._ticker._status_text(LiftState.Status.HOLD) == "WIND HOLD",
		"Held lifts must display as wind holds in the marquee."
	)
	_expect(
		flow._marquee_view._ticker._status_text(LiftState.Status.SCHEDULED) == "SCHEDULED",
		"Scheduled lifts must display as scheduled in the marquee."
	)
	var first_item := flow._marquee_view._ticker._tracks[0].get_child(0)
	var status_label := first_item.get_child(2) as Label
	(
		mountain_state_source
		. _refresh_mountain_state(
			(
				MountainState
				. create(
					[
						LiftState.create("Sky Express", LiftState.Status.CLOSED),
						LiftState.create("Heavenly Gondola", LiftState.Status.OPEN),
					]
				)
			)
		)
	)
	_expect(
		(
			flow._marquee_view._ticker._tracks[0].get_child_count() == 2
			and flow._marquee_view._ticker._tracks[0].get_child(0) == first_item
			and status_label.text == "  CLOSED  "
		),
		"Lift updates must preserve existing ticker items when the count changes."
	)
	flow.free()
	mountain_state_source.free()
	session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
