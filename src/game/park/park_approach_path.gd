@tool
## Editable, visible centerline for the approach zone.
class_name ParkApproachPath
extends Path2D

@export var preview_color := Color("ff3bd4"):
	set(value):
		preview_color = value
		queue_redraw()
@export_range(1.0, 24.0, 1.0) var preview_width := 8.0:
	set(value):
		preview_width = value
		queue_redraw()


func _ready() -> void:
	refresh_preview()


func refresh_preview() -> void:
	if curve != null and not curve.changed.is_connected(queue_redraw):
		curve.changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if curve == null or curve.point_count < 2:
		return
	var points := PackedVector2Array()
	for point_index in curve.point_count:
		points.append(curve.get_point_position(point_index))
	draw_polyline(points, preview_color, preview_width, true)
