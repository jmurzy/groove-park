## Screen-space gameplay HUD, ready prompt, and contextual control hint.
class_name GameplayHudPresenter
extends RefCounted

const DESIGN_SIZE := Vector2(1920, 1080)
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")

var _hud: GameplayHud
var _cta_label: Label
var _status_label: Label
var _action_hint_time := 0.0
var _elapsed := 0.0


func build(ui_layer: CanvasLayer, rider_kind: StringName) -> void:
	_hud = GameplayHudScene.new()
	ui_layer.add_child(_hud)
	_cta_label = _build_cta_label(rider_kind)
	ui_layer.add_child(_cta_label)
	_status_label = _build_status_label()
	ui_layer.add_child(_status_label)


func _build_cta_label(rider_kind: StringName) -> Label:
	var label := ArcadeTheme.make_label(_ready_text(rider_kind), 42, Color("fff7cf"))
	label.position = Vector2(0, 430)
	label.size = Vector2(DESIGN_SIZE.x, 72)
	return label


func _build_status_label() -> Label:
	var label := ArcadeTheme.make_label("", 30, Color("68efff"))
	label.position = Vector2(0, 218)
	label.size = Vector2(DESIGN_SIZE.x, 52)
	label.hide()
	return label


func update(delta: float, session: GameSession, input: RiderInputFrame) -> void:
	var run_manager := session.run_manager
	_elapsed += delta
	_cta_label.visible = (
		(
			not run_manager.has_started_moving
			or session.session_phase == RoundState.SessionPhase.JUMP_TALLY
			or session.session_phase == RoundState.SessionPhase.GAME_OVER
		)
		and fmod(_elapsed, 0.8) < 0.56
	)
	if session.session_phase == RoundState.SessionPhase.GAME_OVER:
		_cta_label.text = "GAME OVER"
	elif session.session_phase == RoundState.SessionPhase.JUMP_TALLY:
		var current_jump_number := session.round_state().current_jump_number()
		_cta_label.text = (
			"PRESS START OR A TO CONTINUE"
			if current_jump_number == RoundState.MAX_JUMPS
			else "JUMP %d NEXT! PRESS START OR A TO BEGIN" % (current_jump_number + 1)
		)
	else:
		_cta_label.text = _ready_text(session.rider_kind)
	_hud.set_speed(run_manager.rider_state.movement_velocity().length())
	_update_rotation(run_manager.rider_state)
	_update_action_hint(delta, input, run_manager.rider_state)


func reset(rider_kind: StringName) -> void:
	_action_hint_time = 0.0
	_status_label.hide()
	_hud.show()
	_hud.set_speed(0.0)
	_hud.set_rotation_text("+0°")
	_hud.set_rotation_quota_text("--")
	_cta_label.text = _ready_text(rider_kind)


func show_round_state(round_state: RoundState) -> void:
	if round_state == null:
		return
	_hud.set_round_score(round_state.round_score())
	_hud.set_jump_number(round_state.current_jump_number())


func is_occluded(rect: Rect2) -> bool:
	return _hud.is_occluded(rect)


func update_rider_occlusion(rider_rect: Rect2) -> void:
	_hud.visible = not _hud.is_occluded(rider_rect)


func _ready_text(rider_kind: StringName) -> String:
	return "%s READY" % rider_kind.to_upper()


func _update_rotation(state: RiderState) -> void:
	var rotation_degrees := roundi(rad_to_deg(state.jump.trick_tracker.cumulative_rotation))
	var sign_prefix := "+" if rotation_degrees >= 0 else ""
	_hud.set_rotation_text("%s%d°" % [sign_prefix, rotation_degrees])
	if state.run.run_phase == RiderRunState.RunPhase.APPROACH:
		_hud.set_rotation_quota_text("--")
		return
	_hud.set_rotation_quota_text(
		"%d / %d" % [state.jump.completed_rotations, state.jump.required_rotations]
	)


func _update_action_hint(delta: float, input: RiderInputFrame, state: RiderState) -> void:
	var action_message := ""
	if state.run.jump_outcome == JumpOutcome.Value.SKETCHY:
		action_message = "SKETCHY RECOVERY"
	elif state.run.jump_outcome == JumpOutcome.Value.CRASH:
		action_message = "CRASH"
	elif state.run.jump_outcome == JumpOutcome.Value.BAIL:
		action_message = "BAIL"
	elif state.run.jump_outcome == JumpOutcome.Value.LOW_MOMENTUM:
		action_message = "LOW MOMENTUM"
	elif state.run.jump_outcome == JumpOutcome.Value.CLEAN:
		action_message = "CLEAN LANDING"
	elif state.run.run_phase == RiderRunState.RunPhase.APPROACH:
		action_message = "RIGHT / D: BUILD SPEED"
		if state.jump.compression_active:
			action_message = "X  COMPRESSING"
		elif input.brake_pressed:
			action_message = "B  CHECKING SPEED"
		elif input.tuck_pressed:
			action_message = "A  TUCKING"
	elif state.run.run_phase == RiderRunState.RunPhase.FLIGHT:
		if state.jump.landing_prep_active:
			action_message = "X  HOLD TO LAND"
		elif state.jump.tweak_active:
			action_message = "B  TWEAK GRAB"
		elif state.jump.trick_tracker.grab_active:
			action_message = "A  STANDARD GRAB"
		else:
			action_message = "A  HOLD GRAB  /  B  HOLD TWEAK GRAB"
	_status_label.text = action_message
	_action_hint_time = maxf(_action_hint_time - delta, 0.0) if _action_hint_time > 0.0 else 1.5
	_status_label.visible = not action_message.is_empty() and _action_hint_time > 0.0
