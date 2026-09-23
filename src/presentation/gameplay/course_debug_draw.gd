## Debug-only course overlay: approach/landing routes, gaps, and drag handles.
## Called from ParkWorldPresenter when the terrain editor is on.
class_name CourseDebugDraw
extends RefCounted

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 5.5
const APPROACH_PATH_COLORS := [Color("48b3ffff"), Color("ff3bd4ff"), Color("ffba33ff")]
const APPROACH_PATH_NAMES := ["UPPER APPROACH", "CENTER APPROACH", "LOWER APPROACH"]
const LANDING_PATH_NAMES := ["UPPER LANDING", "CENTER LANDING", "LOWER RUNOUT"]


static func draw_course_debug(
	canvas: CanvasItem, projection: ParkProjection, background_size: Vector2
) -> void:
	var course := projection.course
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	_draw_grid(canvas, world_bounds)
	_draw_paths(canvas, course.approach_paths, APPROACH_PATH_NAMES, 6.0)
	_draw_paths(canvas, course.landing_paths, LANDING_PATH_NAMES, 5.0)
	_draw_route_transitions(canvas, course)


static func draw_terrain_handles(canvas: CanvasItem, projection: ParkProjection) -> void:
	var course := projection.course
	_draw_path_handles(canvas, course.approach_paths, "A")
	_draw_path_handles(canvas, course.landing_paths, "L")


static func _draw_path_handles(
	canvas: CanvasItem, paths: Array[PackedVector2Array], point_prefix: String
) -> void:
	for path_index in paths.size():
		var path: PackedVector2Array = paths[path_index]
		var color: Color = APPROACH_PATH_COLORS[path_index % APPROACH_PATH_COLORS.size()]
		for point_index in path.size():
			var screen_point := path[point_index]
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color.WHITE)
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS - 1.0, color)
			canvas.draw_string(
				ThemeDB.fallback_font,
				screen_point + Vector2(18, 6),
				"%s%d" % [point_prefix, point_index],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14.0,
				color
			)


static func _draw_paths(
	canvas: CanvasItem, paths: Array[PackedVector2Array], path_names: Array, width: float
) -> void:
	for path_index in paths.size():
		var path: PackedVector2Array = paths[path_index]
		var color: Color = APPROACH_PATH_COLORS[path_index % APPROACH_PATH_COLORS.size()]
		for point_index in range(path.size() - 1):
			canvas.draw_line(path[point_index], path[point_index + 1], color, width)
		if not path.is_empty():
			canvas.draw_string(
				ThemeDB.fallback_font,
				path[0] + Vector2(0, -16),
				(
					path_names[path_index]
					if path_index < path_names.size()
					else "PATH %d" % path_index
				),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16.0,
				color
			)


static func _draw_route_transitions(canvas: CanvasItem, course: ParkCourse) -> void:
	var route_count := mini(
		mini(course.approach_paths.size(), course.landing_paths.size()), course.route_kinds.size()
	)
	for route_index in route_count:
		var approach := course.approach_paths[route_index]
		var landing := course.landing_paths[route_index]
		if approach.is_empty() or landing.is_empty():
			continue
		var color: Color = APPROACH_PATH_COLORS[route_index % APPROACH_PATH_COLORS.size()]
		var approach_end := approach[-1]
		var landing_start := landing[0]
		canvas.draw_circle(approach_end, 9.0, color, false, 3.0)
		canvas.draw_circle(landing_start, 9.0, color, false, 3.0)
		var label := "GROUND JOIN"
		if course.route_kinds[route_index] == ParkCourse.RouteKind.FLIGHT:
			label = "AIR GAP"
		canvas.draw_string(
			ThemeDB.fallback_font,
			(approach_end + landing_start) * 0.5 + Vector2(0, -18),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14.0,
			color
		)


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
