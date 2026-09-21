class_name CourseDebugDraw
extends RefCounted

const ParkSurfaceScene := preload("res://src/game/park/park_surface.gd")

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 14.0
const LANE_PROJECTION_SCALE := 0.18


static func draw_course_debug(
	canvas: CanvasItem,
	course: ParkCourse,
	background_size: Vector2,
	surface_drag_id: StringName,
	surface_drag_vertex: int,
	rider_state: RiderState
) -> void:
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	for point_index in range(course.terrain_points.size() - 1):
		var slope_start := course.terrain_points[point_index]
		var slope_end := course.terrain_points[point_index + 1]
		canvas.draw_line(slope_start, slope_end, Color("010713ee"), 10.0)
		canvas.draw_line(slope_start, slope_end, Color("ff5d52"), 5.0)
	_draw_surface_areas(canvas, course)
	_draw_surface_footprint_handles(canvas, course, surface_drag_id, surface_drag_vertex)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(28, 48),
		"DRAG VERTEX  |  SHIFT+CLICK EDGE: ADD  |  RIGHT-CLICK VERTEX: REMOVE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16.0,
		Color("fff16a")
	)
	_draw_predicted_trajectory(canvas, course, rider_state)
	_draw_grid(canvas, world_bounds)


static func draw_terrain_handles(
	canvas: CanvasItem, course: ParkCourse, terrain_drag_point: int
) -> void:
	for point_index in course.terrain_points.size():
		var screen_point := course.terrain_points[point_index]
		var color := Color("fff16a") if point_index == terrain_drag_point else Color("ff5d52")
		canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color("010713ee"))
		canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS - 3.0, color)
		canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color("010713"), false, 2.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			screen_point + Vector2(18, 6),
			"POINT %d" % point_index,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14.0,
			color
		)


static func ground_to_screen(course: ParkCourse, ground_position: Vector2) -> Vector2:
	return (
		course.surface_position_at(ground_position.x)
		+ Vector2(0, ground_position.y * LANE_PROJECTION_SCALE)
	)


static func screen_to_ground(course: ParkCourse, screen_position: Vector2) -> Vector2:
	return Vector2(
		screen_position.x,
		(screen_position.y - course.surface_y_at(screen_position.x)) / LANE_PROJECTION_SCALE
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


static func _draw_predicted_trajectory(
	canvas: CanvasItem, _course: ParkCourse, rider_state: RiderState
) -> void:
	if rider_state.phase != RiderState.Phase.AIRBORNE:
		return
	var start := Vector2(
		rider_state.course_progress,
		rider_state.vertical_position + rider_state.lane_position * LANE_PROJECTION_SCALE
	)
	var velocity := Vector2(rider_state.course_speed, rider_state.vertical_speed) * 0.28
	canvas.draw_line(start, start + velocity, Color("68efff"), 3.0)
	canvas.draw_circle(start + velocity, 6.0, Color("68efff"))


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
