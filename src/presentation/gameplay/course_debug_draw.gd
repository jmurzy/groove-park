## Debug-only course overlay: terrain profile, phase paths, and drag handles.
## Called from ParkWorldPresenter when the terrain editor is on.
class_name CourseDebugDraw
extends RefCounted

const SURFACE_GRID_SIZE := 120.0
const TERRAIN_HANDLE_RADIUS := 5.5


static func draw_course_debug(
	canvas: CanvasItem, projection: ParkProjection, background_size: Vector2
) -> void:
	var course := projection.course
	var world_bounds := Rect2(Vector2.ZERO, background_size)
	canvas.draw_rect(world_bounds, Color("010713dd"), false, 7.0)
	canvas.draw_rect(world_bounds, Color("ff5d52"), false, 3.0)
	_draw_terrain(canvas, course)
	_draw_phase_paths(canvas, course)
	_draw_grid(canvas, world_bounds)


static func draw_terrain_handles(canvas: CanvasItem, projection: ParkProjection) -> void:
	var course := projection.course
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


static func _draw_phase_paths(canvas: CanvasItem, course: ParkCourse) -> void:
	for phase_path in course.phase_paths:
		if phase_path.path_points.size() < 2:
			continue
		var color := _phase_color(phase_path.phase)
		canvas.draw_polyline(phase_path.path_points, Color("010713ee"), 7.0)
		canvas.draw_polyline(phase_path.path_points, color, 3.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			phase_path.path_points[0] + Vector2(0, -16),
			str(phase_path.id).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16.0,
			color
		)


static func _phase_color(phase: int) -> Color:
	match phase:
		ParkPhasePath.Phase.APPROACH:
			return Color("64ffb2")
		ParkPhasePath.Phase.COMPRESSION:
			return Color("ffe126")
		ParkPhasePath.Phase.TAKEOFF:
			return Color("68efff")
		ParkPhasePath.Phase.LANDING:
			return Color("73ff91")
		_:
			return Color("a9b7d0")


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
