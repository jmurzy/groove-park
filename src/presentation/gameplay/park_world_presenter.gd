## World-space park presentation: background, camera, riders, marker, effects, and debug terrain.
class_name ParkWorldPresenter
extends Node2D

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const HeavenlyLogomarkScene := preload("res://src/presentation/features/heavenly_logomark.gd")
const HeavenlyLogotypeScene := preload("res://src/presentation/features/heavenly_logotype.gd")
const RiderEffectsScene := preload("res://src/presentation/gameplay/rider_effects.gd")
const InfoMarkerScene := preload("res://src/presentation/gameplay/info_marker.gd")
const PerformanceMarkerScene := preload("res://src/presentation/gameplay/performance_marker.gd")
const ParkProjectionScene := preload("res://src/presentation/gameplay/park_projection.gd")
const ParkDebugOverlayScene := preload("res://src/presentation/gameplay/park_debug_overlay.gd")
const ReleaseDeadlineWarningScene := preload(
	"res://src/presentation/gameplay/release_deadline_warning.gd"
)

var course: ParkCourse
var show_terrain := false
var compression_window_distance := 0.0
var rider_kind: StringName = GameSession.RIDER_SNOWBOARDER
var _rider: RiderView
var _info_marker: InfoMarker
var _performance_marker: PerformanceMarker
var _rider_effects: RiderEffects
var _camera: Camera2D
var _projection: ParkProjection
var _debug_overlay: ParkDebugOverlay
var _release_deadline_warning: ReleaseDeadlineWarning
var _camera_controller := ParkCameraController.new()
var _marker_presenter: ParkMarkerPresenter


func setup(
	next_course: ParkCourse,
	next_show_terrain: bool,
	next_compression_window_distance: float,
	next_rider_kind: StringName
) -> void:
	name = "ParkWorld"
	z_index = -1
	course = next_course
	_projection = ParkProjectionScene.new(course)
	show_terrain = next_show_terrain
	compression_window_distance = next_compression_window_distance
	rider_kind = next_rider_kind
	_build_world()


func update_from_run(run_manager: RiderRunManager, delta: float, hud_occlusion: Callable) -> void:
	_update_rider_views(run_manager)
	_release_deadline_warning.update_from_state(run_manager.rider_state)
	_marker_presenter.update(run_manager.rider_state, _projection, hud_occlusion, delta)
	_rider_effects.update_from_state(run_manager.rider_state, _projection, delta)
	_update_debug_overlay(run_manager.rider_state)
	_camera_controller.update(
		_camera, run_manager.rider_state, _projection, GAMEPLAY_BG.get_size(), delta
	)


func reset_presentation(run_manager: RiderRunManager, hud_occlusion: Callable) -> void:
	_rider.reset_presentation()
	_performance_marker.reset_feedback()
	_marker_presenter.reset()
	_camera.zoom = ParkCameraController.CAMERA_ZOOM
	update_from_run(run_manager, 0.0, hud_occlusion)


func primary_rider_screen_bounds() -> Rect2:
	return _rider.screen_bounds()


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
	var rider_definition := (
		RiderVisualDefinition.skier()
		if rider_kind == GameSession.RIDER_SKIER
		else RiderVisualDefinition.snowboarder()
	)
	_rider = RiderView.new(rider_definition)
	_rider.z_index = 2
	_rider.set_show_source_bounds(show_terrain)
	add_child(_rider)
	_release_deadline_warning = ReleaseDeadlineWarningScene.new()
	_release_deadline_warning.name = "ReleaseDeadlineWarning"
	_release_deadline_warning.z_index = 1
	add_child(_release_deadline_warning)
	_info_marker = InfoMarkerScene.new()
	add_child(_info_marker)
	_performance_marker = PerformanceMarkerScene.new()
	add_child(_performance_marker)
	_marker_presenter = ParkMarkerPresenter.new(_info_marker, _performance_marker)
	_camera = Camera2D.new()
	_camera.name = "ParkCamera"
	_camera.zoom = ParkCameraController.CAMERA_ZOOM
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
	_update_rider_view(_rider, run_manager.rider_state)


func _update_rider_view(view: RiderViewBase, state: RiderState) -> void:
	var ground_rotation := (
		course
		. route_tangent_at(
			state.kinematics.course_progress, state.kinematics.approach_path_position
		)
		. angle()
	)
	if (
		state.kinematics.active_route_index >= 0
		and state.run.run_phase != RiderRunState.RunPhase.APPROACH
	):
		ground_rotation = (
			course
			. landing_tangent_at(
				state.kinematics.course_progress, state.kinematics.active_route_index
			)
			. angle()
		)
	view.update_from_state(state, _projection.project_rider(state), ground_rotation)


static func _spin_half_turns(spin_progress: float) -> int:
	return ParkMarkerPresenter.spin_half_turns(spin_progress)


static func _spin_feedback_text(spin_direction: int, degrees: int) -> String:
	return ParkMarkerPresenter.spin_feedback_text(spin_direction, degrees)


func _update_debug_overlay(state: RiderState) -> void:
	if _debug_overlay == null:
		return
	var route_index := state.kinematics.active_route_index
	if route_index < 0:
		route_index = state.kinematics.approach_path_target
	_debug_overlay.set_active_route_index(route_index)
