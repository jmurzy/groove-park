## Flashing world-space performance feedback below the primary rider.
class_name PerformanceMarker
extends RiderMarker

const CALLOUT_DURATION := 1.0
const FLASH_INTERVAL := 0.12
const DEFAULT_PANEL_COLOR := Color("f51e16")
const DEFAULT_LABEL_COLOR := Color("ffe126")

var _time_remaining := 0.0
var _elapsed := 0.0


func _ready() -> void:
	_build_callout(&"PerformanceMarker", DEFAULT_LABEL_COLOR, DEFAULT_PANEL_COLOR)
	hide()


func show_feedback(
	callout_text: String, panel_color := DEFAULT_PANEL_COLOR, label_color := DEFAULT_LABEL_COLOR
) -> void:
	set_callout_text(callout_text)
	set_callout_colors(panel_color, label_color)
	_time_remaining = CALLOUT_DURATION
	_elapsed = 0.0
	show()


func reset_feedback() -> void:
	_time_remaining = 0.0
	_elapsed = 0.0
	hide()


func update_from_rider(world_position: Vector2, delta: float) -> void:
	if _time_remaining <= 0.0:
		hide()
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_elapsed += delta
	_refresh_callout_size()
	_place_below(world_position)
	_update_arrow_below()
	var flash_on := fposmod(_elapsed, FLASH_INTERVAL * 2.0) < FLASH_INTERVAL
	modulate = Color(1.0, 1.0, 1.0, 1.0 if flash_on else 0.35)


func is_feedback_active() -> bool:
	return _time_remaining > 0.0


func local_bounds() -> Rect2:
	return callout_bounds_below()
