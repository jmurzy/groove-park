## In-run HUD frame: speed, jump count, score, rotation, and the transient
## post-landing breakdown line. Updated via `set_*()` / `show_result()`.
class_name GameplayHud
extends Control

const HEAVENLY_LOGO := preload("res://artwork/gameplay/heavenly_logo.png")
const HUD_RECT := Rect2(60, 24, 1800, 126)
const HUD_INSET := 11.0
const HUD_LOGO_SIZE := Vector2(280, 90)
const HUD_SEPARATORS := [490.0, 764.0, 1038.0, 1312.0, 1586.0]
const KMH_TO_MPH := 0.621371

var _speed_value: Label
var _jump_value: Label
var _score_value: Label
var _rotation_value: Label
var _result_value: Label


func _ready() -> void:
	name = "GameplayHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position.y = 30.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_metrics()
	queue_redraw()


func _draw() -> void:
	var divider_x: float = HUD_SEPARATORS[0]
	var outer := HUD_RECT
	var inner := outer.grow(-HUD_INSET)
	var mid := outer.grow(-5)
	var shadow := outer.grow(8)
	var inner_left := _split_rect_left(inner, divider_x)
	var inner_right := _split_rect_right(inner, divider_x)
	var mid_right := _split_rect_right(mid, divider_x)
	var outer_right := _split_rect_right(outer, divider_x)
	var shadow_right := _split_rect_right(shadow, divider_x)
	var shadow_left := _split_rect_left(shadow, divider_x)
	var outer_left := _split_rect_left(outer, divider_x)
	var mid_left := _split_rect_left(mid, divider_x)
	# Right side: opaque beveled rims so the frame stays continuous,
	# background fill at 80% opacity so the bg faintly shows through.
	draw_colored_polygon(
		_beveled_frame_u_right(shadow_right, outer_right, 30, 24), Color("010711cc")
	)
	draw_colored_polygon(_beveled_frame_u_right(outer_right, mid_right, 24, 19), Color("0647bd"))
	draw_colored_polygon(_beveled_frame_u_right(mid_right, inner_right, 19, 15), Color("031643"))
	draw_colored_polygon(_partial_beveled_points(inner_right, 15, false, true), Color("071c42cc"))
	# First (logo) box: opaque beveled rims so the frame stays continuous,
	# interior left unpainted except for a translucent fill so the bg shows through.
	draw_colored_polygon(_beveled_frame_u(shadow_left, outer_left, 30, 24), Color("010711cc"))
	draw_colored_polygon(_beveled_frame_u(outer_left, mid_left, 24, 19), Color("0647bd"))
	draw_colored_polygon(_beveled_frame_u(mid_left, inner_left, 19, 15), Color("031643"))
	draw_colored_polygon(
		_partial_beveled_points(inner_left, 15, true, false), Color(0.03, 0.11, 0.26, 0.45)
	)
	draw_polyline(_closed_points(_beveled_rect_points(inner, 15)), Color("18dffa"), 3.0)
	for separator_x: float in HUD_SEPARATORS:
		draw_line(Vector2(separator_x, 44), Vector2(separator_x, 130), Color("24ddf6"), 3.0)
	draw_texture_rect(HEAVENLY_LOGO, _logo_rect(), false)


func _split_rect_left(rect: Rect2, divider_x: float) -> Rect2:
	return Rect2(rect.position, Vector2(divider_x - rect.position.x, rect.size.y))


func _split_rect_right(rect: Rect2, divider_x: float) -> Rect2:
	return Rect2(Vector2(divider_x, rect.position.y), Vector2(rect.end.x - divider_x, rect.size.y))


func _partial_beveled_points(
	rect: Rect2, corner_size: float, bevel_left: bool, bevel_right: bool
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if bevel_left:
		points.append(Vector2(rect.position.x + corner_size, rect.position.y))
	else:
		points.append(Vector2(rect.position.x, rect.position.y))
	if bevel_right:
		points.append(Vector2(rect.end.x - corner_size, rect.position.y))
		points.append(Vector2(rect.end.x, rect.position.y + corner_size))
	else:
		points.append(Vector2(rect.end.x, rect.position.y))
	if bevel_right:
		points.append(Vector2(rect.end.x, rect.end.y - corner_size))
		points.append(Vector2(rect.end.x - corner_size, rect.end.y))
	else:
		points.append(Vector2(rect.end.x, rect.end.y))
	if bevel_left:
		points.append(Vector2(rect.position.x + corner_size, rect.end.y))
		points.append(Vector2(rect.position.x, rect.end.y - corner_size))
		points.append(Vector2(rect.position.x, rect.position.y + corner_size))
	else:
		points.append(Vector2(rect.position.x, rect.end.y))
	return points


func _beveled_rect_points(rect: Rect2, corner_size: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(rect.position.x + corner_size, rect.position.y),
			Vector2(rect.end.x - corner_size, rect.position.y),
			Vector2(rect.end.x, rect.position.y + corner_size),
			Vector2(rect.end.x, rect.end.y - corner_size),
			Vector2(rect.end.x - corner_size, rect.end.y),
			Vector2(rect.position.x + corner_size, rect.end.y),
			Vector2(rect.position.x, rect.end.y - corner_size),
			Vector2(rect.position.x, rect.position.y + corner_size),
		]
	)


func _logo_rect() -> Rect2:
	var first_box_width: float = HUD_SEPARATORS[0] - HUD_RECT.position.x
	var logo_x := HUD_RECT.position.x + (first_box_width - HUD_LOGO_SIZE.x) / 2.0 + 4.0
	var logo_y := HUD_RECT.position.y + (HUD_RECT.size.y - HUD_LOGO_SIZE.y) / 2.0
	return Rect2(Vector2(logo_x, logo_y), HUD_LOGO_SIZE)


func _beveled_frame_u(
	outer_rect: Rect2, inner_rect: Rect2, outer_corner: float, inner_corner: float
) -> PackedVector2Array:
	# U-shaped frame between two left-beveled rects sharing a right (divider) edge:
	# opaque rims (top/bottom/left) with the interior left open.
	var ox := outer_rect.position.x
	var oy := outer_rect.position.y
	var oex := outer_rect.end.x
	var oey := outer_rect.end.y
	var ix := inner_rect.position.x
	var iy := inner_rect.position.y
	var iex := inner_rect.end.x
	var iey := inner_rect.end.y
	return PackedVector2Array(
		[
			Vector2(ox + outer_corner, oy),
			Vector2(oex, oy),
			Vector2(iex, iy),
			Vector2(ix + inner_corner, iy),
			Vector2(ix, iy + inner_corner),
			Vector2(ix, iey - inner_corner),
			Vector2(ix + inner_corner, iey),
			Vector2(iex, iey),
			Vector2(oex, oey),
			Vector2(ox + outer_corner, oey),
			Vector2(ox, oey - outer_corner),
			Vector2(ox, oy + outer_corner),
		]
	)


func _beveled_frame_u_right(
	outer_rect: Rect2, inner_rect: Rect2, outer_corner: float, inner_corner: float
) -> PackedVector2Array:
	# Mirrored U-shaped frame: right side beveled, left (divider) edge open.
	var ox := outer_rect.position.x
	var oy := outer_rect.position.y
	var oex := outer_rect.end.x
	var oey := outer_rect.end.y
	var ix := inner_rect.position.x
	var iy := inner_rect.position.y
	var iex := inner_rect.end.x
	var iey := inner_rect.end.y
	return PackedVector2Array(
		[
			Vector2(ox, oy),
			Vector2(oex - outer_corner, oy),
			Vector2(oex, oy + outer_corner),
			Vector2(oex, oey - outer_corner),
			Vector2(oex - outer_corner, oey),
			Vector2(ox, oey),
			Vector2(ix, iey),
			Vector2(iex - inner_corner, iey),
			Vector2(iex, iey - inner_corner),
			Vector2(iex, iy + inner_corner),
			Vector2(iex - inner_corner, iy),
			Vector2(ix, iy),
		]
	)


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	return closed_points


func _build_metrics() -> void:
	_add_metric("P1  SKIER", "READY", 506, Color("ffe126"), Color("f3f6ff"))
	_speed_value = _add_metric("SPEED", "0 MPH", 780, Color("42eaff"), Color("f3f6ff"))
	_jump_value = _add_metric("JUMP", "01 / 01", 1054, Color("42eaff"), Color("f3f6ff"))
	_score_value = _add_metric("SCORE", "0000", 1328, Color("42eaff"), Color("ffe126"))
	_rotation_value = _add_metric("ROTATION", "0", 1602, Color("42eaff"), Color("f3f6ff"))
	_result_value = ArcadeTheme.make_label("", 20, Color("fff7cf"))
	_result_value.position = Vector2(0, 164)
	_result_value.size = Vector2(1920, 36)
	_result_value.hide()
	add_child(_result_value)


func set_speed(world_speed: float) -> void:
	_speed_value.text = "%d MPH" % roundi(maxf(world_speed, 0.0) * 0.12 * KMH_TO_MPH)


func set_jump(jump_number: int, jump_count: int) -> void:
	_jump_value.text = "%02d / %02d" % [jump_number, jump_count]


func set_score(score: int) -> void:
	_score_value.text = "%04d" % max(score, 0)


func set_rotation_value(rotation_radians: float) -> void:
	_rotation_value.text = "%+.0f" % rad_to_deg(rotation_radians)


func show_result(label: String, breakdown: Dictionary) -> void:
	if breakdown.is_empty():
		_result_value.hide()
		return
	_result_value.text = (
		"%s  +%d  A%d T%d F%d R%d G%d W%d  x%.2f"
		% [
			label,
			int(breakdown["total"]),
			int(breakdown["approach"]),
			int(breakdown["takeoff"]),
			int(breakdown["airtime"]),
			int(breakdown["rotation"]),
			int(breakdown["grab"]),
			int(breakdown["tweak"]),
			float(breakdown["landing_multiplier"]),
		]
	)
	_result_value.show()


func clear_result() -> void:
	_result_value.hide()


func _add_metric(
	title: String, value: String, x_position: float, title_color: Color, value_color: Color
) -> Label:
	_add_metric_title(title, x_position, title_color)

	var value_label := ArcadeTheme.make_label(value, 29, value_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.position = Vector2(x_position, 84)
	value_label.size = Vector2(250, 46)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_constant_override("shadow_offset_x", 3)
	value_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(value_label)
	return value_label


func _add_metric_title(title: String, x_position: float, title_color: Color) -> void:
	var title_label := ArcadeTheme.make_label(title, 25, title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.position = Vector2(x_position, 43)
	title_label.size = Vector2(250, 38)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title_label)
