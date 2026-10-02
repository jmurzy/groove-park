## Debug-only course overlay: approach/landing routes, bail zones, and drag handles.
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
const BAIL_FLOOR_LINE := Color("fff16add")
const BAIL_TRIGGER_LINE := Color("ffffffff")
const COMPRESSION_FILL_ALPHA := 0.28
const COMPRESSION_ACTIVE_ALPHA := 0.72
const FLIGHT_DEBUG_COLOR := Color("68efff")
const CONTACT_DEBUG_COLOR := Color("ff75e1")
const LOW_MOMENTUM_DEBUG_COLOR := Color("ffb347")
const FLIGHT_PREDICTION_DURATION := 1.2


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
	_draw_bail_zone(canvas, course, world_bounds, active_route_index)
	_draw_paths(canvas, course, true, APPROACH_PATH_NAMES, 6.0)
	_draw_compression_windows(canvas, course, active_route_index, compression_window_distance)
	_draw_paths(canvas, course, false, LANDING_PATH_NAMES, 5.0)
	_draw_route_transitions(canvas, course)


static func draw_terrain_handles(canvas: CanvasItem, projection: ParkProjection) -> void:
	var course := projection.course
	_draw_path_handles(canvas, course, true, "A")
	_draw_path_handles(canvas, course, false, "L")


static func _draw_path_handles(
	canvas: CanvasItem, course: ParkCourse, use_approach: bool, point_prefix: String
) -> void:
	for path_index in course.routes.size():
		var route := course.route_at(path_index)
		var path: PackedVector2Array = route.approach_path if use_approach else route.landing_path
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
	canvas: CanvasItem, course: ParkCourse, use_approach: bool, path_names: Array, width: float
) -> void:
	for path_index in course.routes.size():
		var route := course.route_at(path_index)
		var path: PackedVector2Array = route.approach_path if use_approach else route.landing_path
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
	for route_index in course.routes.size():
		var route := course.route_at(route_index)
		var approach := route.approach_path
		var landing := route.landing_path
		if approach.is_empty() or landing.is_empty():
			continue
		var color: Color = APPROACH_PATH_COLORS[route_index % APPROACH_PATH_COLORS.size()]
		var approach_end := approach[-1]
		var landing_start := landing[0]
		canvas.draw_circle(approach_end, 9.0, color, false, 3.0)
		canvas.draw_circle(landing_start, 9.0, color, false, 3.0)
		if route.kind == ParkRoute.Kind.FLIGHT:
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
	for route_index in course.routes.size():
		var path := course.route_at(route_index).approach_path
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


static func _draw_bail_zone(
	canvas: CanvasItem, course: ParkCourse, _world_bounds: Rect2, route_index: int
) -> void:
	if (
		route_index < 0
		or route_index >= course.routes.size()
		or course.route_at(route_index).kind != ParkRoute.Kind.FLIGHT
	):
		return
	var boundary := course.flight_miss_boundary_points(route_index)
	if boundary.size() < 2:
		return
	var bail_floor := course.flight_bail_floor_points(route_index)
	var bail_trigger := PackedVector2Array()
	for point in bail_floor:
		bail_trigger.append(Vector2(point.x, course.flight_bail_trigger_y_at(point.x, route_index)))
	var bail_zone := boundary.duplicate()
	for point_index in range(bail_floor.size() - 1, -1, -1):
		bail_zone.append(bail_floor[point_index])
	canvas.draw_colored_polygon(bail_zone, MISS_ZONE_FILL)
	for point_index in range(boundary.size() - 1):
		canvas.draw_dashed_line(
			boundary[point_index], boundary[point_index + 1], MISS_ZONE_LINE, 3.0, 12.0
		)
	for point_index in range(bail_floor.size() - 1):
		canvas.draw_dashed_line(
			bail_floor[point_index], bail_floor[point_index + 1], BAIL_FLOOR_LINE, 3.0, 12.0
		)
		canvas.draw_dashed_line(
			bail_trigger[point_index], bail_trigger[point_index + 1], BAIL_TRIGGER_LINE, 2.0, 8.0
		)
	var zone_label_position := (boundary[0] + boundary[1]) * 0.5
	canvas.draw_string(
		ThemeDB.fallback_font,
		zone_label_position + Vector2(0, 28),
		"BAIL ZONE",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14.0,
		MISS_ZONE_LINE
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		bail_floor[floori(bail_floor.size() * 0.5)] + Vector2(0, -10.0),
		"BAIL FLOOR",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14.0,
		BAIL_FLOOR_LINE
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		bail_trigger[floori(bail_trigger.size() * 0.5)] + Vector2(0, -10.0),
		"BAIL LINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14.0,
		BAIL_TRIGGER_LINE
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


static func draw_flight_debug(canvas: CanvasItem, state: RiderState, tuning: RiderTuning) -> void:
	if state.run.run_phase != RiderRunState.RunPhase.FLIGHT:
		if state.jump.landing_resolved:
			canvas.draw_circle(state.jump.landing_position, 12.0, CONTACT_DEBUG_COLOR, false, 3.0)
			canvas.draw_string(
				ThemeDB.fallback_font,
				state.jump.landing_position + Vector2(16, -14),
				"FIRST CONTACT",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				14.0,
				CONTACT_DEBUG_COLOR
			)
		return
	var position := Vector2(state.kinematics.course_progress, state.kinematics.vertical_position)
	var velocity := Vector2(state.kinematics.course_speed, state.kinematics.vertical_speed)
	canvas.draw_line(position, position + velocity * 0.25, FLIGHT_DEBUG_COLOR, 3.0)
	var previous_position := position
	var physics_delta := 1.0 / float(maxi(1, Engine.physics_ticks_per_second))
	var prediction_steps := ceili(FLIGHT_PREDICTION_DURATION / physics_delta)
	for _step in prediction_steps:
		velocity = FlightIntegrator.integrated_velocity(velocity, tuning, physics_delta)
		position += velocity * FlightIntegrator.scaled_delta(tuning, physics_delta)
		canvas.draw_dashed_line(previous_position, position, FLIGHT_DEBUG_COLOR, 2.0, 6.0)
		previous_position = position
	canvas.draw_dashed_line(
		Vector2(state.kinematics.course_progress - 220.0, state.jump.release_deadline_y),
		Vector2(state.kinematics.course_progress + 220.0, state.jump.release_deadline_y),
		Color("ffe126"),
		2.0,
		8.0
	)


static func draw_low_momentum_debug(
	canvas: CanvasItem, state: RiderState, tuning: RiderTuning
) -> void:
	if not state.run.low_momentum_detector_armed:
		return
	var position := Vector2(state.kinematics.course_progress, state.kinematics.vertical_position)
	var timer_text := (
		"%.2f / %.2f"
		% [
			state.run.low_momentum_no_progress_time,
			tuning.low_momentum_detection_duration,
		]
	)
	var lines := [
		"LOW MOMENTUM ARMED",
		"TIMER %s" % timer_text,
		"RECOVERABLE ACCEL %.1f" % state.run.low_momentum_recoverable_acceleration,
		"REASON %s" % state.run.low_momentum_detector_reason.to_upper(),
	]
	for line_index in lines.size():
		canvas.draw_string(
			ThemeDB.fallback_font,
			position + Vector2(20.0, -62.0 + line_index * 18.0),
			lines[line_index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14.0,
			LOW_MOMENTUM_DEBUG_COLOR
		)
