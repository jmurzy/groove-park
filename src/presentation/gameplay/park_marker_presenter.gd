## Updates rider markers, feedback, and HUD occlusion in world-space presentation.
class_name ParkMarkerPresenter
extends RefCounted

const INFO_OFFSET := Vector2(0, -70)
const PERFORMANCE_OFFSET := Vector2(0, 30)
const FULL_SPIN_PANEL_COLOR := Color("42eaff")
const FULL_SPIN_LABEL_COLOR := Color("0047b8")

var _info_marker: InfoMarker
var _performance_marker: PerformanceMarker
var _rider_kind: StringName
var _observed_compression_release_progress := -1.0
var _observed_spin_half_turns := 0


func _init(
	info_marker: InfoMarker, performance_marker: PerformanceMarker, rider_kind: StringName
) -> void:
	_info_marker = info_marker
	_performance_marker = performance_marker
	_rider_kind = rider_kind


func reset() -> void:
	_performance_marker.reset_feedback()
	_observed_compression_release_progress = -1.0
	_observed_spin_half_turns = 0


func update(
	state: RiderState, projection: ParkProjection, hud_occlusion: Callable, delta: float
) -> void:
	_show_new_compression_feedback(state)
	_show_new_spin_feedback(state)
	var rider_position := projection.project_rider(state)
	_performance_marker.update_from_rider(rider_position + PERFORMANCE_OFFSET, delta)
	if _performance_marker.is_feedback_active():
		_performance_marker.visible = not hud_occlusion.call(
			_screen_rect(_performance_marker, _performance_marker.local_bounds())
		)
	var speed_mph := GameplayHud.speed_to_mph(state.movement_velocity().length())
	if speed_mph == 0:
		_info_marker.hide()
		return
	_info_marker.update_from_rider(rider_position + INFO_OFFSET, "%d MPH" % speed_mph)
	_info_marker.visible = not hud_occlusion.call(
		_screen_rect(_info_marker, _info_marker.local_bounds())
	)


func _show_new_compression_feedback(state: RiderState) -> void:
	if state.jump.compression_release_progress < 0.0:
		_observed_compression_release_progress = -1.0
		return
	if is_equal_approx(
		state.jump.compression_release_progress, _observed_compression_release_progress
	):
		return
	_observed_compression_release_progress = state.jump.compression_release_progress
	if is_zero_approx(state.jump.compression_amount):
		return
	if state.jump.compression_auto_released:
		_performance_marker.show_feedback("AUTO POP")
	elif state.jump.compression_release_quality >= 0.9:
		_performance_marker.show_feedback("PERFECT POP!")
	elif state.jump.compression_release_quality >= 0.5:
		_performance_marker.show_feedback("GOOD POP")
	else:
		_performance_marker.show_feedback("EARLY POP")


func _show_new_spin_feedback(state: RiderState) -> void:
	if state.run.run_phase != RiderRunState.RunPhase.FLIGHT or state.jump.spin_direction == 0:
		_observed_spin_half_turns = 0
		return
	var spin_half_turns := spin_half_turns(state.jump.spin_progress)
	if spin_half_turns == 0:
		_observed_spin_half_turns = 0
		return
	if spin_half_turns <= _observed_spin_half_turns:
		return
	_observed_spin_half_turns = spin_half_turns
	var degrees := spin_half_turns * 180
	if degrees % 360 == 0:
		_performance_marker.show_feedback(
			spin_feedback_text(state.jump.spin_direction, degrees, _rider_kind),
			FULL_SPIN_PANEL_COLOR,
			FULL_SPIN_LABEL_COLOR
		)
		return
	_performance_marker.show_feedback(
		spin_feedback_text(state.jump.spin_direction, degrees, _rider_kind)
	)


static func spin_half_turns(spin_progress: float) -> int:
	return floori(spin_progress / PI)


static func spin_feedback_text(
	spin_direction: int, degrees: int, rider_kind: StringName = GameSession.RIDER_SNOWBOARDER
) -> String:
	var direction := "BACKSIDE" if spin_direction < 0 else "FRONTSIDE"
	if rider_kind == GameSession.RIDER_SKIER:
		direction = "LEFT" if spin_direction < 0 else "RIGHT"
	return "%s %d" % [direction, degrees]


func _screen_rect(marker: Control, bounds: Rect2) -> Rect2:
	var transform := marker.get_global_transform_with_canvas()
	return (
		Rect2(transform * bounds.position, transform * bounds.end - transform * bounds.position)
		. abs()
	)
