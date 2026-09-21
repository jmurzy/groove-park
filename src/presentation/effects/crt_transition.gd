## CRT power-off/on wipe between attract and gameplay. Emits `midpoint_reached`
## to swap screens, then `finished` to free itself.
class_name CrtTransition
extends Control

signal midpoint_reached
signal finished

const DESIGN_SIZE := Vector2(1920, 1080)

var _flash: ColorRect


func _ready() -> void:
	name = "CrtTransition"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pivot_offset = DESIGN_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color("d9ffff00")
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	queue_redraw()
	_run()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("02060f"))
	for y in range(0, int(DESIGN_SIZE.y), 5):
		draw_line(Vector2(0, y), Vector2(DESIGN_SIZE.x, y), Color("17446b"), 1.0)


func _run() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale:y", 0.012, 0.20)
	tween.parallel().tween_property(self, "modulate:a", 0.88, 0.20)
	tween.tween_callback(midpoint_reached.emit)
	tween.tween_property(_flash, "color:a", 1.0, 0.06)
	tween.tween_property(_flash, "color:a", 0.0, 0.18)
	tween.tween_property(self, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(finished.emit)
