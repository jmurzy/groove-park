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
const CourseDebugDrawScene := preload("res://src/presentation/gameplay/course_debug_draw.gd")
const ParkProjectionScene := preload("res://src/presentation/gameplay/park_projection.gd")
const CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 724.0, DESIGN_SIZE.y / 724.0)
const RIDER_MARKER_TOP_OFFSET := Vector2(0, -70)

var course: ParkCourse
var show_terrain := false
var _snowboarder: SnowboarderView
var _skier: SkierView
var _rider_marker: RiderMarker
var _rider_effects: RiderEffects
var _camera: Camera2D
var _projection: ParkProjection


func setup(next_course: ParkCourse, next_show_terrain: bool) -> void:
	name = "ParkWorld"
	z_index = -1
	course = next_course
	_projection = ParkProjectionScene.new(course)
	show_terrain = next_show_terrain
	_build_world()


func update_from_run(run_manager: RiderRunManager, delta: float, hud_occlusion: Callable) -> void:
	_update_rider_views(run_manager)
	_update_rider_marker(run_manager, hud_occlusion)
	_rider_effects.update_from_state(run_manager.rider_state, _projection, delta)
	_update_camera(run_manager)
	if show_terrain:
		queue_redraw()


func reset_presentation(run_manager: RiderRunManager, hud_occlusion: Callable) -> void:
	_snowboarder.reset_presentation()
	update_from_run(run_manager, 0.0, hud_occlusion)


func _draw() -> void:
	if not show_terrain:
		return
	CourseDebugDrawScene.draw_course_debug(
		self, _projection, Vector2(GAMEPLAY_BG.get_size()), &"", -1
	)
	CourseDebugDrawScene.draw_terrain_handles(self, _projection)


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
	view.update_from_state(
		state, _projection.project_rider(state), course.tangent_at(state.course_progress).angle()
	)


func _update_rider_marker(run_manager: RiderRunManager, hud_occlusion: Callable) -> void:
	var speed_mph := GameplayHud.speed_to_mph(run_manager.rider_state.ground_velocity.length())
	if speed_mph == 0:
		_rider_marker.hide()
		return
	_rider_marker.update_from_rider(
		_projection.project_rider(run_manager.rider_state) + RIDER_MARKER_TOP_OFFSET,
		"%d MPH" % speed_mph
	)
	var marker_transform := _rider_marker.get_global_transform_with_canvas()
	var marker_bounds := _rider_marker.local_bounds()
	var marker_rect := (
		Rect2(
			marker_transform * marker_bounds.position,
			marker_transform * marker_bounds.end - marker_transform * marker_bounds.position
		)
		. abs()
	)
	_rider_marker.visible = not hud_occlusion.call(marker_rect)


func _update_camera(run_manager: RiderRunManager) -> void:
	var half_view_width := DESIGN_SIZE.x / CAMERA_ZOOM.x * 0.5
	var target_x := clampf(
		run_manager.rider_state.course_progress,
		half_view_width,
		GAMEPLAY_BG.get_width() - half_view_width
	)
	_camera.position = Vector2(target_x, GAMEPLAY_BG.get_height() * 0.5)
