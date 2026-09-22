## Runs the park run: orchestrates RiderRunManager stepping, camera/HUD/audio,
## and the pause/exit flow. Run state lives in RiderRunManager, the exit dialog
## in PauseMenu. Course authoring lives in the Godot editor
## (park_course_editor.tscn); the in-game terrain overlay below is a
## read-only visualizer (`--show-terrain`).
class_name GameplayScreen
extends Control

signal return_to_title_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const HeavenlyLogomarkScene := preload("res://src/presentation/features/heavenly_logomark.gd")
const HeavenlyLogotypeScene := preload("res://src/presentation/features/heavenly_logotype.gd")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const SnowboarderViewScene := preload("res://src/presentation/gameplay/snowboarder_view.gd")
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")
const RiderEffectsScene := preload("res://src/presentation/gameplay/rider_effects.gd")
const RiderMarkerScene := preload("res://src/presentation/gameplay/rider_marker.gd")
const PauseMenuScene := preload("res://src/presentation/gameplay/pause_menu.gd")
const CourseDebugDrawScene := preload("res://src/presentation/gameplay/course_debug_draw.gd")

const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")
const CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 724.0, DESIGN_SIZE.y / 724.0)
const START_LOGOMARK_POSITION := Vector2(640, 390)
const MIDDLE_LOGOMARK_POSITION := Vector2(1572, 544)
const END_LOGOMARK_POSITION := Vector2(1922, 600)
const LOGOMARK_SCALE := 0.105
const LOGOTYPE_POSITION := Vector2(250, 260)
const LOGOTYPE_SCALE := 0.12096
const RIDER_MARKER_TOP_OFFSET := Vector2(0, -70)
var game_controller: GameController
var show_terrain := OS.is_debug_build()
var _ready_label: Label
var _action_label: Label
var _action_hint_time := 0.0
var _elapsed := 0.0
var _rider_tuning: RiderTuning = RIDER_TUNING_RESOURCE
var _snowboarder: SnowboarderView
var _skier: SkierView
var _rider_marker: RiderMarker
var _rider_effects: RiderEffects
var _hud: GameplayHud
var _pause_menu: PauseMenu
var _gameplay_music: AudioStreamPlayer
var _back_sound: AudioStreamPlayer
var _controls_screen: HowToPlayScreen
var _course: ParkCourse = PARK_COURSE_RESOURCE.duplicate()
var _world: Node2D
var _camera: Camera2D
var _ui_layer: CanvasLayer

var _run_manager: RiderRunManager:
	get:
		return game_controller.run_manager


func _ready() -> void:
	name = "GameplayScreen"
	# Stay responsive while the tree is paused for the exit dialog.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var course_errors := _course.validation_errors()
	if not course_errors.is_empty():
		push_error("Invalid ParkCourse:\n%s" % "\n".join(course_errors))
	if game_controller == null:
		push_error("GameplayScreen requires a GameController.")
		return
	game_controller.begin_run(_course)
	_build_world()
	_build_screen_ui()
	_build_snowboarder()
	_build_hud()
	game_controller.run_score_changed.connect(_on_run_score_changed)
	_hud.set_rider_text("P1" if game_controller.player_count == 1 else "P1 / P2")
	_on_run_score_changed(game_controller.run_score)
	_build_music()
	queue_redraw()


func _process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_elapsed += delta
	_ready_label.visible = (
		(not _run_manager.has_started_moving or _run_manager.is_crashed())
		and fmod(_elapsed, 0.8) < 0.56
	)
	if _action_hint_time > 0.0:
		_action_hint_time = maxf(_action_hint_time - delta, 0.0)
		_action_label.visible = true
	elif _action_label:
		_action_label.visible = false
	if show_terrain:
		queue_redraw()


func _draw() -> void:
	if not show_terrain:
		return
	_draw_course_debug()
	_draw_terrain_handles()


func _physics_process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_update_rider_state(delta)
	_update_snowboarder_view()


func _background_source_rect() -> Rect2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	var source_size := _background_source_size()
	var camera_x := clampf(
		_run_manager.rider_state.course_progress - source_size.x * 0.5,
		0.0,
		texture_size.x - source_size.x
	)
	return Rect2(Vector2(camera_x, 0), source_size)


func _background_source_size() -> Vector2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	return Vector2(texture_size.y * DESIGN_SIZE.x / DESIGN_SIZE.y, texture_size.y)


func _update_rider_state(delta: float) -> void:
	var input := RiderInputFrameScene.from_actions()
	game_controller.step_run(input, _course, _rider_tuning, delta)
	_ready_label.text = (
		"PRESS START OR R TO RESTART"
		if _run_manager.is_crashed()
		else (
			"%d PLAYER%s READY"
			% [
				game_controller.player_count,
				"" if game_controller.player_count == 1 else "S",
			]
		)
	)
	_hud.set_speed(_run_manager.rider_state.ground_velocity.length())
	_update_action_label(input)
	_update_camera()


func _update_action_label(input: RiderInputFrame) -> void:
	var action_message := "RIGHT / D: BUILD SPEED"
	if input.brake_pressed:
		action_message = "B  CHECKING SPEED"
	elif input.edge_pressed:
		action_message = "Y  STRONG EDGE"
	elif input.tuck_pressed:
		action_message = "A  TUCKING - LESS STEERING"
	if not action_message.is_empty():
		_action_label.text = action_message
		_action_hint_time = 1.5


func _on_run_score_changed(score: int) -> void:
	_hud.set_score("%04d" % score)


func _project_rider_position() -> Vector2:
	return Vector2(
		_run_manager.rider_state.course_progress,
		(
			_run_manager.rider_state.vertical_position
			+ _run_manager.rider_state.lane_position * GameConstants.LANE_PROJECTION_SCALE
		)
	)


func _build_snowboarder() -> void:
	_snowboarder = SnowboarderViewScene.new()
	_snowboarder.z_index = 2
	_snowboarder.set_show_source_bounds(show_terrain)
	_world.add_child(_snowboarder)
	_skier = SkierViewScene.new()
	_skier.z_index = 2
	_skier.set_show_source_bounds(show_terrain)
	_world.add_child(_skier)
	_rider_marker = RiderMarkerScene.new()
	_world.add_child(_rider_marker)
	_update_snowboarder_view()


func _update_snowboarder_view() -> void:
	var ground_rotation := _course.tangent_at(_run_manager.rider_state.course_progress).angle()
	_snowboarder.update_from_state(
		_run_manager.rider_state, _project_rider_position(), ground_rotation
	)
	var skier_rotation := _course.tangent_at(_run_manager.skier_state.course_progress).angle()
	_skier.update_from_state(
		_run_manager.skier_state,
		Vector2(
			_run_manager.skier_state.course_progress,
			(
				_run_manager.skier_state.vertical_position
				+ _run_manager.skier_state.lane_position * GameConstants.LANE_PROJECTION_SCALE
			)
		),
		skier_rotation
	)
	_update_rider_marker()
	_rider_effects.update_from_state(
		_run_manager.rider_state, _course, get_physics_process_delta_time()
	)


func _update_rider_marker() -> void:
	if _rider_marker == null:
		return
	var speed_mph := GameplayHud.speed_to_mph(_run_manager.rider_state.ground_velocity.length())
	if speed_mph == 0:
		_rider_marker.hide()
		return
	_rider_marker.update_from_rider(
		_project_rider_position() + RIDER_MARKER_TOP_OFFSET, "%d MPH" % speed_mph
	)
	_rider_marker.visible = not _rider_marker_overlaps_hud()


func _rider_marker_overlaps_hud() -> bool:
	if _hud == null:
		return false
	var marker_transform := _rider_marker.get_global_transform_with_canvas()
	var marker_bounds := _rider_marker.local_bounds()
	var marker_top_left := marker_transform * marker_bounds.position
	var marker_bottom_right := marker_transform * marker_bounds.end
	var marker_rect := Rect2(marker_top_left, marker_bottom_right - marker_top_left).abs()
	return _hud.is_occluded(marker_rect)


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "ParkWorld"
	# Keep the debug-only Control overlay above the camera-transformed world.
	_world.z_index = -1
	add_child(_world)
	var background := Sprite2D.new()
	background.name = "CourseBackground"
	background.texture = GAMEPLAY_BG
	background.centered = false
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(background)
	_world.add_child(_build_start_logotype())
	_world.add_child(_build_logomark("StartLogomark", START_LOGOMARK_POSITION))
	_world.add_child(_build_logomark("MiddleLogomark", MIDDLE_LOGOMARK_POSITION))
	_world.add_child(_build_logomark("LandingLogomark", END_LOGOMARK_POSITION))
	_rider_effects = RiderEffectsScene.new()
	_rider_effects.name = "RiderEffects"
	_rider_effects.z_index = 1
	_world.add_child(_rider_effects)
	_camera = Camera2D.new()
	_camera.name = "ParkCamera"
	_camera.zoom = CAMERA_ZOOM
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = GAMEPLAY_BG.get_width()
	_camera.limit_bottom = GAMEPLAY_BG.get_height()
	_world.add_child(_camera)
	_update_camera()


func _build_logomark(logomark_name: String, logomark_position: Vector2) -> AnimatedSprite2D:
	var logomark := HeavenlyLogomarkScene.create(LOGOMARK_SCALE)
	logomark.name = logomark_name
	logomark.position = logomark_position
	return logomark


func _build_start_logotype() -> AnimatedSprite2D:
	var logotype := HeavenlyLogotypeScene.create(LOGOTYPE_SCALE)
	logotype.name = "StartLogotype"
	logotype.position = LOGOTYPE_POSITION
	return logotype


func _build_screen_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ScreenUi"
	_ui_layer.layer = 1
	add_child(_ui_layer)
	var frame := TextureRect.new()
	frame.name = "FrameOverlay"
	frame.texture = FRAME_OVERLAY
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ui_layer.add_child(frame)


func _update_camera() -> void:
	if _camera == null:
		return
	var half_view_width := DESIGN_SIZE.x / CAMERA_ZOOM.x * 0.5
	var camera_min := half_view_width
	var camera_max := GAMEPLAY_BG.get_width() - half_view_width
	var target_x := clampf(_run_manager.rider_state.course_progress, camera_min, camera_max)
	_camera.position = Vector2(target_x, GAMEPLAY_BG.get_height() * 0.5)


func _draw_course_debug() -> void:
	CourseDebugDrawScene.draw_course_debug(self, _course, Vector2(GAMEPLAY_BG.get_size()), &"", -1)


func _draw_terrain_handles() -> void:
	CourseDebugDrawScene.draw_terrain_handles(self, _course)


func _build_hud() -> void:
	_hud = GameplayHudScene.new()
	_ui_layer.add_child(_hud)

	_ready_label = (
		ArcadeTheme
		.make_label(
			(
				"%d PLAYER%s READY"
				% [
					game_controller.player_count,
					"" if game_controller.player_count == 1 else "S",
				]
			),
			42,
			Color("fff7cf")
		)
	)
	_ready_label.position = Vector2(0, 430)
	_ready_label.size = Vector2(DESIGN_SIZE.x, 72)
	_ui_layer.add_child(_ready_label)

	_action_label = ArcadeTheme.make_label("", 30, Color("68efff"))
	_action_label.position = Vector2(0, 218)
	_action_label.size = Vector2(DESIGN_SIZE.x, 52)
	_action_label.hide()
	_ui_layer.add_child(_action_label)


func _build_music() -> void:
	var music_stream: AudioStreamMP3 = GAMEPLAY_MUSIC.duplicate()
	music_stream.loop = true
	_gameplay_music = AudioStreamPlayer.new()
	_gameplay_music.name = "GameplayMusic"
	_gameplay_music.stream = music_stream
	add_child(_gameplay_music)
	_gameplay_music.play()
	_back_sound = AudioStreamPlayer.new()
	_back_sound.name = "BackSound"
	_back_sound.stream = BACK_SOUND
	add_child(_back_sound)


func request_exit_confirmation() -> void:
	if _pause_menu:
		return
	game_controller.set_paused(true)
	get_tree().paused = true
	_pause_menu = PauseMenuScene.new()
	_pause_menu.resume_requested.connect(close_exit_confirmation)
	_pause_menu.controls_requested.connect(_open_controls)
	_pause_menu.abandon_requested.connect(_confirm_return_to_title)
	_ui_layer.add_child(_pause_menu)


func is_exit_confirmation_open() -> bool:
	return _pause_menu != null


func _unhandled_input(event: InputEvent) -> void:
	if _controls_screen:
		return
	if is_exit_confirmation_open():
		# PauseMenu owns dialog navigation input while open.
		return
	if (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).echo
		and (event as InputEventKey).keycode == KEY_R
	):
		_restart_run()
		get_viewport().set_input_as_handled()
		return
	if _run_manager.is_crashed() and event.is_action_pressed(&"controller_start"):
		_restart_run()
		get_viewport().set_input_as_handled()
		return
	# Cabinet: ▷ (Start) pauses, ≡ (Back) backs out, white EXIT opens the dialog.
	# Holding white EXIT quits to AGS via main._process. Esc is the Mac dev equivalent.
	if (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"controller_start")
		or event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"cabinet_exit")
	):
		request_exit_confirmation()
		get_viewport().set_input_as_handled()


func _restart_run() -> void:
	game_controller.restart_run(_course)
	_snowboarder.reset_presentation()
	_action_hint_time = 0.0
	_action_label.hide()
	_hud.set_speed(0.0)
	_update_snowboarder_view()


func _confirm_return_to_title() -> void:
	get_tree().paused = false
	game_controller.set_paused(false)
	return_to_title_requested.emit()


func close_exit_confirmation() -> void:
	if not _pause_menu:
		return
	get_tree().paused = false
	game_controller.set_paused(false)
	_pause_menu.queue_free()
	_pause_menu = null


func _open_controls() -> void:
	if _controls_screen:
		return
	_controls_screen = HowToPlayScreenScene.new()
	_controls_screen.closed.connect(_close_controls)
	_ui_layer.add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	if is_instance_valid(_back_sound):
		_back_sound.play()
	if is_instance_valid(_pause_menu):
		_pause_menu.focus_controls_button()
