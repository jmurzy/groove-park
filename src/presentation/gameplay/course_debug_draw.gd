## Debug-only course overlay: approach path, surface fills, and drag handles.
## Called from GameplayScreen when the terrain editor is on.
class_name CourseDebugDraw
extends RefCounted

const ParkSurfaceScene := preload("res://src/game/park/park_surface.gd")

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 5.5


static func draw_course_debug(
	canvas: CanvasItem,
	course: ParkCourse,
	background_size: Vector2,
	surface_drag_id: StringName,
	surface_drag_vertex: int
) -> void:
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	_draw_terrain(canvas, course)
	_draw_surface_areas(canvas, course)
	_draw_surface_footprint_handles(canvas, course, surface_drag_id, surface_drag_vertex)
	_draw_control_zones(canvas, course)
	_draw_grid(canvas, world_bounds)


static func draw_terrain_handles(canvas: CanvasItem, course: ParkCourse) -> void:
	for point_index in course.approach_rider_path.size():
		var screen_point := course.approach_rider_path[point_index]
		var color := Color("ff5d52")
		canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color.WHITE)
		canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS - 1.0, color)
		canvas.draw_string(
			ThemeDB.fallback_font,
			screen_point + Vector2(18, 6),
			"POINT %d" % point_index,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14.0,
			color
		)


static func _draw_terrain(canvas: CanvasItem, course: ParkCourse) -> void:
	for point_index in range(course.approach_rider_path.size() - 1):
		var slope_start := course.approach_rider_path[point_index]
		var slope_end := course.approach_rider_path[point_index + 1]
		canvas.draw_line(slope_start, slope_end, Color("ff5d52"), 6.0)


static func _draw_control_zones(canvas: CanvasItem, course: ParkCourse) -> void:
	for zone in course.control_zones:
		_draw_control_zone(canvas, course, zone.footprint, Color("64ffb2"), str(zone.id).to_upper())


static func _draw_control_zone(
	canvas: CanvasItem,
	course: ParkCourse,
	footprint: PackedVector2Array,
	color: Color,
	label: String
) -> void:
	var screen_footprint := PackedVector2Array()
	for point in footprint:
		screen_footprint.append(ground_to_screen(course, point))
	if screen_footprint.size() >= 3:
		var fill := color
		fill.a = 0.18
		canvas.draw_colored_polygon(screen_footprint, fill)
	for point_index in screen_footprint.size():
		var point := screen_footprint[point_index]
		canvas.draw_circle(point, TERRAIN_HANDLE_RADIUS, Color("010713ee"))
		canvas.draw_circle(point, TERRAIN_HANDLE_RADIUS - 3.0, color)
		if point_index > 0:
			canvas.draw_line(screen_footprint[point_index - 1], point, color, 3.0)
	if screen_footprint.size() >= 3:
		canvas.draw_line(screen_footprint[-1], screen_footprint[0], color, 3.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			_polygon_center(screen_footprint) + Vector2(0, -16),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16.0,
			color
		)


static func ground_to_screen(course: ParkCourse, ground_position: Vector2) -> Vector2:
	return (
		course.surface_position_at(ground_position.x)
		+ Vector2(0, ground_position.y * GameConstants.LANE_PROJECTION_SCALE)
	)


static func screen_to_ground(course: ParkCourse, screen_position: Vector2) -> Vector2:
	return Vector2(
		screen_position.x,
		(
			(screen_position.y - course.surface_y_at(screen_position.x))
			/ GameConstants.LANE_PROJECTION_SCALE
		)
	)


static func surface_screen_footprint(
	course: ParkCourse, surface: ParkSurface
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for ground_point in surface.footprint:
		points.append(ground_to_screen(course, ground_point))
	return points


static func surface_debug_color(role: int) -> Color:
	match role:
		ParkSurfaceScene.Role.APPROACH:
			return Color("64ffb2")
		ParkSurfaceScene.Role.TAKEOFF:
			return Color("68efff")
		ParkSurfaceScene.Role.LANDING:
			return Color("73ff91")
		_:
			return Color("a9b7d0")


static func _draw_surface_areas(canvas: CanvasItem, course: ParkCourse) -> void:
	for surface in course.surfaces:
		var color := surface_debug_color(surface.role)
		var footprint := surface_screen_footprint(course, surface)
		if footprint.size() < 3:
			continue
		var fill := color
		fill.a = 0.22
		canvas.draw_colored_polygon(footprint, fill)
		_draw_surface_edge(canvas, footprint, color)
		var label_position := _polygon_center(footprint) + Vector2(0, -16.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			label_position,
			str(surface.id).to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16.0,
			color
		)


static func _draw_surface_edge(
	canvas: CanvasItem, points: PackedVector2Array, color: Color
) -> void:
	for point_index in points.size():
		var edge_start := points[point_index]
		var edge_end := points[(point_index + 1) % points.size()]
		canvas.draw_line(edge_start, edge_end, Color("010713ee"), 7.0)
		canvas.draw_line(edge_start, edge_end, color, 3.0)


static func _draw_surface_footprint_handles(
	canvas: CanvasItem, course: ParkCourse, surface_drag_id: StringName, surface_drag_vertex: int
) -> void:
	for surface in course.surfaces:
		var color := surface_debug_color(surface.role)
		for point_index in surface.footprint.size():
			var is_dragged := surface.id == surface_drag_id and point_index == surface_drag_vertex
			var screen_point := ground_to_screen(course, surface.footprint[point_index])
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color("010713ee"))
			var handle_color := Color.WHITE if is_dragged else color
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS - 3.0, handle_color)


static func _draw_grid(canvas: CanvasItem, world_bounds: Rect2) -> void:
	for x in range(0, int(world_bounds.end.x) + 1, int(SURFACE_GRID_SIZE)):
		canvas.draw_line(
			Vector2(x, world_bounds.position.y),
			Vector2(x, world_bounds.end.y),
			Color("071326bb"),
			3.0
		)
		canvas.draw_line(
			Vector2(x, world_bounds.position.y),
			Vector2(x, world_bounds.end.y),
			Color("68efff88"),
			1.0
		)
	for y in range(0, int(world_bounds.end.y) + 1, int(SURFACE_GRID_SIZE)):
		canvas.draw_line(
			Vector2(world_bounds.position.x, y),
			Vector2(world_bounds.end.x, y),
			Color("071326bb"),
			3.0
		)
		canvas.draw_line(
			Vector2(world_bounds.position.x, y),
			Vector2(world_bounds.end.x, y),
			Color("68efff88"),
			1.0
		)


static func _polygon_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / points.size()
