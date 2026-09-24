## Debug-only course overlay: approach/landing routes, abandon zones, and drag handles.
## Called from ParkWorldPresenter when the terrain editor is on.
class_name CourseDebugDraw
extends RefCounted

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 5.5
const APPROACH_PATH_COLORS := [Color("48b3ffff"), Color("ff3bd4ff"), Color("ffba33ff")]
const APPROACH_PATH_NAMES := ["UPPER APPROACH", "CENTER APPROACH", "LOWER APPROACH"]
const LANDING_PATH_NAMES := ["UPPER LANDING", "CENTER LANDING", "LOWER RUNOUT"]
const MISS_ZONE_FILL := Color("ff304580")
const MISS_ZONE_LINE := Color("ff5d52dd")
const ABANDON_FLOOR_LINE := Color("fff16add")
const ABANDON_TRIGGER_LINE := Color("ffffffff")
const COMPRESSION_FILL_ALPHA := 0.28
const COMPRESSION_ACTIVE_ALPHA := 0.72


static func draw_course_debug(
	canvas: CanvasItem,
	projection: ParkProjection,
	background_size: Vector2,
	active_route_index: int,
	compression_window_distance: float
) -> void:
	var course := projection.course
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	_draw_grid(canvas, world_bounds)
	_draw_abandon_zone(canvas, course, world_bounds, active_route_index)
	_draw_paths(canvas, course.approach_paths, APPROACH_PATH_NAMES, 6.0)
	_draw_compression_windows(canvas, course, active_route_index, compression_window_distance)
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
		if course.route_kinds[route_index] == ParkCourse.RouteKind.FLIGHT:
			continue
		canvas.draw_string(
			ThemeDB.fallback_font,
			(approach_end + landing_start) * 0.5 + Vector2(0, -18),
			"GROUND JOIN",
			HORIZONTAL_ALIGNMENT_CENTER,
			-1.0,
			14.0,
			color
		)


static func _draw_compression_windows(
	canvas: CanvasItem, course: ParkCourse, active_route_index: int, window_distance: float
) -> void:
	if window_distance <= 0.0:
		return
	for route_index in course.approach_paths.size():
		var path := course.approach_paths[route_index]
		if path.size() < 2:
			continue
		var lip := path[-1]
		var start_x := maxf(path[0].x, lip.x - window_distance)
		var start := Vector2(start_x, course.route_surface_y_at(start_x, float(route_index)))
		var points := PackedVector2Array([start])
		for point in path:
			if point.x > start_x:
				points.append(point)
		var color: Color = APPROACH_PATH_COLORS[route_index % APPROACH_PATH_COLORS.size()]
		var is_active := route_index == active_route_index
		color.a = COMPRESSION_ACTIVE_ALPHA if is_active else COMPRESSION_FILL_ALPHA
		canvas.draw_polyline(points, color, 18.0 if is_active else 12.0)
		canvas.draw_dashed_line(start + Vector2(0, -28), start + Vector2(0, 28), color, 3.0, 7.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			start + Vector2(10, -24),
			"COMPRESSION",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14.0,
			color
		)


static func _draw_abandon_zone(
	canvas: CanvasItem, course: ParkCourse, _world_bounds: Rect2, route_index: int
) -> void:
	var route_count := mini(
		mini(course.approach_paths.size(), course.landing_paths.size()), course.route_kinds.size()
	)
	if (
		route_index < 0
		or route_index >= route_count
		or course.route_kinds[route_index] != ParkCourse.RouteKind.FLIGHT
	):
		return
	var boundary := course.flight_miss_boundary_points(route_index)
	if boundary.size() < 2:
		return
	var abandon_floor := course.flight_abandon_floor_points(route_index)
	var abandon_trigger := PackedVector2Array()
	for point in abandon_floor:
		abandon_trigger.append(
			Vector2(point.x, course.flight_abandon_trigger_y_at(point.x, route_index))
		)
	var abandon_zone := boundary.duplicate()
	for point_index in range(abandon_floor.size() - 1, -1, -1):
		abandon_zone.append(abandon_floor[point_index])
	canvas.draw_colored_polygon(abandon_zone, MISS_ZONE_FILL)
	for point_index in range(boundary.size() - 1):
		canvas.draw_dashed_line(
			boundary[point_index], boundary[point_index + 1], MISS_ZONE_LINE, 3.0, 12.0
		)
	for point_index in range(abandon_floor.size() - 1):
		canvas.draw_dashed_line(
			abandon_floor[point_index],
			abandon_floor[point_index + 1],
			ABANDON_FLOOR_LINE,
			3.0,
			12.0
		)
		canvas.draw_dashed_line(
			abandon_trigger[point_index],
			abandon_trigger[point_index + 1],
			ABANDON_TRIGGER_LINE,
			2.0,
			8.0
		)
	var zone_label_position := (boundary[0] + boundary[1]) * 0.5
	canvas.draw_string(
		ThemeDB.fallback_font,
		zone_label_position + Vector2(0, 28),
		"ABANDON ZONE",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14.0,
		MISS_ZONE_LINE
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		abandon_floor[floori(abandon_floor.size() * 0.5)] + Vector2(0, -10.0),
		"ABANDON FLOOR",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14.0,
		ABANDON_FLOOR_LINE
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		abandon_trigger[floori(abandon_trigger.size() * 0.5)] + Vector2(0, -10.0),
		"ABANDON LINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14.0,
		ABANDON_TRIGGER_LINE
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
