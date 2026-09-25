## World-space park presentation: background, camera, riders, marker, effects, and debug terrain.
class_name ParkWorldPresenter
extends Node2D

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const HeavenlyLogomarkScene := preload("res://src/presentation/features/heavenly_logomark.gd")
const HeavenlyLogotypeScene := preload("res://src/presentation/features/heavenly_logotype.gd")
const SnowboarderViewScene := preload("res://src/presentation/gameplay/snowboarder_view.gd")
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")
const RiderEffectsScene := preload("res://src/presentation/gameplay/rider_effects.gd")
const RiderMarkerScene := preload("res://src/presentation/gameplay/rider_marker.gd")
const PerformanceMarkerScene := preload("res://src/presentation/gameplay/performance_marker.gd")
const ParkProjectionScene := preload("res://src/presentation/gameplay/park_projection.gd")
const ParkDebugOverlayScene := preload("res://src/presentation/gameplay/park_debug_overlay.gd")
const CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 724.0, DESIGN_SIZE.y / 724.0)
const FLIGHT_CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 640.0, DESIGN_SIZE.y / 640.0)
const CAMERA_ZOOM_RESPONSE := 3.5
const RIDER_MARKER_TOP_OFFSET := Vector2(0, -70)
const PERFORMANCE_MARKER_BOTTOM_OFFSET := Vector2(0, 30)
const FULL_SPIN_PANEL_COLOR := Color("42eaff")
const FULL_SPIN_LABEL_COLOR := Color("0047b8")

var course: ParkCourse
var show_terrain := false
var compression_window_distance := 0.0
var _snowboarder: SnowboarderView
var _skier: SkierView
var _rider_marker: RiderMarker
var _performance_marker: PerformanceMarker
var _rider_effects: RiderEffects
var _camera: Camera2D
var _projection: ParkProjection
var _debug_overlay: ParkDebugOverlay
var _observed_compression_release_progress := -1.0
var _observed_spin_half_turns := 0


func setup(
	next_course: ParkCourse, next_show_terrain: bool, next_compression_window_distance: float
) -> void:
	name = "ParkWorld"
	z_index = -1
	course = next_course
	_projection = ParkProjectionScene.new(course)
	show_terrain = next_show_terrain
	compression_window_distance = next_compression_window_distance
	_build_world()


func update_from_run(run_manager: RiderRunManager, delta: float, hud_occlusion: Callable) -> void:
	_update_rider_views(run_manager)
	_update_rider_marker(run_manager, hud_occlusion, delta)
	_rider_effects.update_from_state(run_manager.rider_state, _projection, delta)
	_update_debug_overlay(run_manager.rider_state)
	_update_camera(run_manager, delta)


func reset_presentation(run_manager: RiderRunManager, hud_occlusion: Callable) -> void:
	_snowboarder.reset_presentation()
	_performance_marker.reset_feedback()
	_observed_compression_release_progress = -1.0
	_observed_spin_half_turns = 0
	_camera.zoom = CAMERA_ZOOM
	update_from_run(run_manager, 0.0, hud_occlusion)


func primary_rider_screen_bounds() -> Rect2:
	return _snowboarder.screen_bounds()


func _build_world() -> void:
	var background := Sprite2D.new()
	background.name = "CourseBackground"
	background.texture = GAMEPLAY_BG
	background.centered = false
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(background)
	add_child(_build_logotype())
	add_child(_build_logomark("StartLogomark", Vector2(640, 390)))
	add_child(_build_logomark("MiddleLogomark", Vector2(1572, 544)))
	add_child(_build_logomark("LandingLogomark", Vector2(1922, 600)))
	_rider_effects = RiderEffectsScene.new()
	_rider_effects.name = "RiderEffects"
	_rider_effects.z_index = 1
	add_child(_rider_effects)
	_snowboarder = SnowboarderViewScene.new()
	_snowboarder.z_index = 2
	_snowboarder.set_show_source_bounds(show_terrain)
	add_child(_snowboarder)
	_skier = SkierViewScene.new()
	_skier.z_index = 2
	_skier.set_show_source_bounds(show_terrain)
	add_child(_skier)
	_rider_marker = RiderMarkerScene.new()
	add_child(_rider_marker)
	_performance_marker = PerformanceMarkerScene.new()
	add_child(_performance_marker)
	_camera = Camera2D.new()
	_camera.name = "ParkCamera"
	_camera.zoom = CAMERA_ZOOM
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = GAMEPLAY_BG.get_width()
	_camera.limit_bottom = GAMEPLAY_BG.get_height()
	add_child(_camera)
	if show_terrain:
		_debug_overlay = ParkDebugOverlayScene.new()
		_debug_overlay.name = "ParkDebugOverlay"
		_debug_overlay.z_index = 3
		_debug_overlay.setup(_projection, compression_window_distance)
		add_child(_debug_overlay)
		_debug_overlay.refresh()


func _build_logomark(logomark_name: String, position: Vector2) -> AnimatedSprite2D:
	var logomark := HeavenlyLogomarkScene.create(0.105)
	logomark.name = logomark_name
	logomark.position = position
	return logomark


func _build_logotype() -> AnimatedSprite2D:
	var logotype := HeavenlyLogotypeScene.create(0.12096)
	logotype.name = "StartLogotype"
	logotype.position = Vector2(250, 260)
	return logotype


func _update_rider_views(run_manager: RiderRunManager) -> void:
	_update_rider_view(_snowboarder, run_manager.rider_state)
	_update_rider_view(_skier, run_manager.skier_state)


func _update_rider_view(view: RiderViewBase, state: RiderState) -> void:
	var ground_rotation := (
		course.route_tangent_at(state.course_progress, state.approach_path_position).angle()
	)
	if state.active_route_index >= 0 and state.run_phase != RiderState.RunPhase.APPROACH:
		ground_rotation = (
			course.landing_tangent_at(state.course_progress, state.active_route_index).angle()
		)
	view.update_from_state(state, _projection.project_rider(state), ground_rotation)


func _update_rider_marker(
	run_manager: RiderRunManager, hud_occlusion: Callable, delta: float
) -> void:
	var state := run_manager.rider_state
	_show_new_compression_feedback(state)
	_show_new_spin_feedback(state)
	var rider_position := _projection.project_rider(state)
	_update_performance_marker(rider_position, hud_occlusion, delta)
	var speed_mph := GameplayHud.speed_to_mph(state.movement_velocity().length())
	if speed_mph == 0:
		_rider_marker.hide()
		return
	_rider_marker.update_from_rider(rider_position + RIDER_MARKER_TOP_OFFSET, "%d MPH" % speed_mph)
	_rider_marker.visible = not hud_occlusion.call(
		_marker_screen_rect(_rider_marker, _rider_marker.local_bounds())
	)


func _update_performance_marker(
	rider_position: Vector2, hud_occlusion: Callable, delta: float
) -> void:
	_performance_marker.update_from_rider(rider_position + PERFORMANCE_MARKER_BOTTOM_OFFSET, delta)
	if _performance_marker.is_feedback_active():
		_performance_marker.visible = not hud_occlusion.call(
			_marker_screen_rect(_performance_marker, _performance_marker.local_bounds())
		)


func _marker_screen_rect(marker: Control, marker_bounds: Rect2) -> Rect2:
	var marker_transform := marker.get_global_transform_with_canvas()
	return (
		Rect2(
			marker_transform * marker_bounds.position,
			marker_transform * marker_bounds.end - marker_transform * marker_bounds.position
		)
		. abs()
	)


func _show_new_compression_feedback(state: RiderState) -> void:
	if state.compression_release_progress < 0.0:
		_observed_compression_release_progress = -1.0
		return
	if is_equal_approx(state.compression_release_progress, _observed_compression_release_progress):
		return
	_observed_compression_release_progress = state.compression_release_progress
	if is_zero_approx(state.compression_amount):
		return
	if state.compression_auto_released:
		_performance_marker.show_feedback("AUTO POP")
	elif state.compression_release_quality >= 0.9:
		_performance_marker.show_feedback("PERFECT POP!")
	elif state.compression_release_quality >= 0.5:
		_performance_marker.show_feedback("GOOD POP")
	else:
		_performance_marker.show_feedback("EARLY POP")


func _show_new_spin_feedback(state: RiderState) -> void:
	if state.run_phase != RiderState.RunPhase.FLIGHT or state.spin_direction == 0:
		_observed_spin_half_turns = 0
		return
	var spin_half_turns := _spin_half_turns(state.spin_progress)
	if spin_half_turns == 0:
		_observed_spin_half_turns = 0
		return
	if spin_half_turns <= _observed_spin_half_turns:
		return
	_observed_spin_half_turns = spin_half_turns
	var degrees := spin_half_turns * 180
	if degrees % 360 == 0:
		_performance_marker.show_feedback(
			_spin_feedback_text(state.spin_direction, degrees),
			FULL_SPIN_PANEL_COLOR,
			FULL_SPIN_LABEL_COLOR
		)
		return
	_performance_marker.show_feedback(_spin_feedback_text(state.spin_direction, degrees))


static func _spin_half_turns(spin_progress: float) -> int:
	return floori(spin_progress / PI)


static func _spin_feedback_text(spin_direction: int, degrees: int) -> String:
	var direction := "BACKSIDE" if spin_direction < 0 else "FRONTSIDE"
	return "%s %d" % [direction, degrees]


func _update_debug_overlay(state: RiderState) -> void:
	if _debug_overlay == null:
		return
	var route_index := state.active_route_index
	if route_index < 0:
		route_index = state.approach_path_target
	_debug_overlay.set_active_route_index(route_index)


func _update_camera(run_manager: RiderRunManager, delta: float) -> void:
	var state := run_manager.rider_state
	var is_flying := state.run_phase == RiderState.RunPhase.FLIGHT
	var target_zoom := FLIGHT_CAMERA_ZOOM if is_flying else CAMERA_ZOOM
	_camera.zoom = _camera.zoom.lerp(target_zoom, clampf(CAMERA_ZOOM_RESPONSE * delta, 0.0, 1.0))
	var half_view_size := DESIGN_SIZE / _camera.zoom * 0.5
	var target_x := clampf(
		state.course_progress, half_view_size.x, GAMEPLAY_BG.get_width() - half_view_size.x
	)
	var target_y := GAMEPLAY_BG.get_height() * 0.5
	if is_flying:
		var rider_y := _projection.project_rider(state).y
		var landing_y := _projection.project_rider_ground(state).y
		target_y = (rider_y + landing_y) * 0.5
	target_y = clampf(target_y, half_view_size.y, GAMEPLAY_BG.get_height() - half_view_size.y)
	_camera.position = Vector2(target_x, target_y)
