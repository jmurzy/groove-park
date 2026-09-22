## Debug-only course overlay: approach line, phase paths, and drag handles.
## Called from ParkWorldPresenter when the terrain editor is on.
class_name CourseDebugDraw
extends RefCounted

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 5.5
const APPROACH_PATH_COLORS := [Color("48b3ffff"), Color("ff3bd4ff"), Color("ffba33ff")]
const APPROACH_PATH_NAMES := ["UPPER APPROACH", "CENTER APPROACH", "LOWER APPROACH"]


static func draw_course_debug(
	canvas: CanvasItem, projection: ParkProjection, background_size: Vector2
) -> void:
	var course := projection.course
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	_draw_approach_line(canvas, course)
	_draw_grid(canvas, world_bounds)


static func draw_terrain_handles(canvas: CanvasItem, projection: ParkProjection) -> void:
	var course := projection.course
	var paths := course.approach_paths
	for path_index in paths.size():
		var path: PackedVector2Array = paths[path_index]
		var color: Color = APPROACH_PATH_COLORS[path_index]
		for point_index in path.size():
			var screen_point := path[point_index]
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS, Color.WHITE)
			canvas.draw_circle(screen_point, TERRAIN_HANDLE_RADIUS - 1.0, color)
			canvas.draw_string(
				ThemeDB.fallback_font,
				screen_point + Vector2(18, 6),
				"%d" % point_index,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14.0,
				color
			)


static func _draw_approach_line(canvas: CanvasItem, course: ParkCourse) -> void:
	var paths := course.approach_paths
	for path_index in paths.size():
		var path: PackedVector2Array = paths[path_index]
		var color: Color = APPROACH_PATH_COLORS[path_index]
		for point_index in range(path.size() - 1):
			canvas.draw_line(path[point_index], path[point_index + 1], color, 6.0)
		if not path.is_empty():
			canvas.draw_string(
				ThemeDB.fallback_font,
				path[0] + Vector2(0, -16),
				APPROACH_PATH_NAMES[path_index],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16.0,
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
