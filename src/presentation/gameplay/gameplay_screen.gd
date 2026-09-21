## Runs the park run: steps RiderSimulation, drives camera/HUD/audio, handles
## pause/exit dialogs, and hosts the debug terrain editor.
class_name GameplayScreen
extends Control

signal return_to_title_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const HEAVENLY_LOGOTYPE_SPRITE := preload("res://artwork/features/heavenly_logotype_sprite.png")
const HeavenlyLogomarkScene := preload("res://src/presentation/features/heavenly_logomark.gd")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")
const ParkRiderEffectsScene := preload("res://src/presentation/gameplay/park_rider_effects.gd")

const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const PARK_COURSE_RESOURCE_PATH := "res://src/game/park/park_course.tres"
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const CourseDebugDrawScene := preload("res://src/presentation/gameplay/course_debug_draw.gd")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")
const TERRAIN_HANDLE_HIT_RADIUS := 28.0
const RIDER_DRAG_HIT_RADIUS := 56.0
const LANE_PROJECTION_SCALE := 0.18
const CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 724.0, DESIGN_SIZE.y / 724.0)
const START_LOGOMARK_POSITION := Vector2(640, 390)
const MIDDLE_LOGOMARK_POSITION := Vector2(1572, 544)
const END_LOGOMARK_POSITION := Vector2(1922, 600)
const LOGOMARK_SCALE := 0.105
const LOGOTYPE_FRAME_COLUMNS := 2
const LOGOTYPE_FRAME_ROWS := 2
const LOGOTYPE_FRAME_RATE := 2.5
const LOGOTYPE_TOP_ROW_OFFSET := 27.0
const LOGOTYPE_POSITION := Vector2(250, 260)
const LOGOTYPE_SCALE := 0.12096
var player_count := 1
var terrain_editor_enabled := OS.is_debug_build()
var _ready_label: Label
var _action_label: Label
var _action_hint_time := 0.0
var _elapsed := 0.0
var _has_started_moving := false
var _rider_state: RiderState = RiderStateScene.new()
var _rider_simulation: RiderSimulation = RiderSimulationScene.new()
var _rider_tuning: RiderTuning = RIDER_TUNING_RESOURCE
var _skier: SkierView
var _rider_effects: ParkRiderEffects
var _hud: GameplayHud
var _exit_confirmation: Control
var _return_button: Button
var _keep_playing_button: Button
var _controls_button: Button
var _switch_sound: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _gameplay_music: AudioStreamPlayer
var _back_sound: AudioStreamPlayer
var _launch_sound: AudioStreamPlayer
var _landing_sound: AudioStreamPlayer
var _focused_dialog_button: Button
var _controls_screen: HowToPlayScreen
var _course: ParkCourse = PARK_COURSE_RESOURCE.duplicate()
var _world: Node2D
var _camera: Camera2D
var _ui_layer: CanvasLayer
var _previous_phase := RiderState.Phase.GROUNDED
var _terrain_drag_point := -1
var _surface_drag_id: StringName
var _surface_drag_vertex := -1
var _rider_dragging := false


func _ready() -> void:
	name = "GameplayScreen"
	# Stay responsive while the tree is paused for the exit dialog.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var course_errors := _course.validation_errors()
	if not course_errors.is_empty():
		push_error("Invalid ParkCourse:\n%s" % "\n".join(course_errors))
	_rider_state.course_progress = _course.start_progress
	_rider_state.ground_position = Vector2(_rider_state.course_progress, _rider_state.lane_position)
	_rider_state.vertical_position = _course.surface_y_at(_rider_state.course_progress)
	_build_world()
	_build_screen_ui()
	_build_skier()
	_build_hud()
	_build_music()
	queue_redraw()


func _process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_elapsed += delta
	_ready_label.visible = (
		(not _has_started_moving or _rider_state.phase == RiderState.Phase.CRASHED)
		and fmod(_elapsed, 0.8) < 0.56
	)
	if _action_hint_time > 0.0:
		_action_hint_time = maxf(_action_hint_time - delta, 0.0)
		_action_label.visible = true
	elif _action_label:
		_action_label.visible = false
	if terrain_editor_enabled:
		queue_redraw()


func _draw() -> void:
	if not terrain_editor_enabled:
		return
	_draw_course_debug()
	_draw_terrain_handles()


func _physics_process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	if _rider_dragging:
		return
	_update_rider_state(delta)
	_update_skier_view()


func _background_source_rect() -> Rect2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	var source_size := _background_source_size()
	var camera_x := clampf(
		_rider_state.course_progress - source_size.x * 0.5, 0.0, texture_size.x - source_size.x
	)
	return Rect2(Vector2(camera_x, 0), source_size)


func _background_source_size() -> Vector2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	return Vector2(texture_size.y * DESIGN_SIZE.x / DESIGN_SIZE.y, texture_size.y)


func _update_rider_state(delta: float) -> void:
	var input := RiderInputFrameScene.from_actions()
	_rider_simulation.step(_rider_state, input, _course, _rider_tuning, delta)
	if not _has_started_moving and _rider_state.ground_velocity.length() > 1.0:
		_has_started_moving = true
	_ready_label.text = (
		"PRESS START OR R TO RESTART"
		if _rider_state.phase == RiderState.Phase.CRASHED
		else "%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"]
	)
	_hud.set_speed(_rider_state.ground_velocity.length())
	_hud.set_jump(1, 1)
	_hud.set_score(_rider_state.jump_score)
	_hud.set_rotation_value(_rider_state.trick_tracker.cumulative_rotation)
	if _rider_state.landing_resolved:
		_hud.show_result(_rider_state.landing_label, _rider_state.score_breakdown)
	_update_action_label(input)
	_update_camera()
	_update_presentation_cues()


func _update_action_label(input: RiderInputFrame) -> void:
	var action_message := ""
	if _rider_state.phase == RiderState.Phase.CRASHED:
		action_message = (
			"CRASH  ANGLE %.0f  IMPACT %.0f  SPIN %.1f"
			% [
				_rider_state.landing_angle_error_degrees,
				_rider_state.landing_normal_impact,
				_rider_state.landing_angular_speed,
			]
		)
	elif (
		_rider_state.phase == RiderState.Phase.LANDED
		or _rider_state.phase == RiderState.Phase.RECOVERING
	):
		action_message = (
			"%s  %s  %.0f%%  ANGLE %.0f  ALIGN %.0f%%  IMPACT %.0f  SPIN %.1f"
			% [
				_rider_state.landing_label,
				_rider_state.trick_call,
				_rider_state.landing_quality * 100.0,
				_rider_state.landing_angle_error_degrees,
				_rider_state.landing_velocity_alignment * 100.0,
				_rider_state.landing_normal_impact,
				_rider_state.landing_angular_speed,
			]
		)
	elif _rider_state.phase == RiderState.Phase.AIRBORNE:
		if _rider_state.airtime < 0.32:
			action_message = "ROTATE NOW: RIGHT / D, THEN HOLD B TO LAND"
		elif _rider_state.trick_tracker.grab_active:
			action_message = "RELEASE GRAB, THEN HOLD B TO SPOT LANDING"
		else:
			action_message = "SPOT LANDING: HOLD B / K"
	elif _rider_state.compression_active:
		action_message = "BLUE X  COMPRESSING %.0f%%" % (_rider_state.compression_amount * 100.0)
	elif (
		_rider_state.course_progress >= _course.compression_start
		and _rider_state.course_progress <= _course.lip_progress
	):
		action_message = "HOLD BLUE X, RELEASE AT THE LIP"
	elif _rider_state.course_progress >= _course.compression_start - 300.0:
		action_message = "GET READY: PRESS BLUE X AT THE RAMP"
	elif input.brake_pressed:
		action_message = "B  CHECKING SPEED"
	elif input.edge_pressed:
		action_message = "Y  STRONG EDGE"
	elif input.tuck_pressed:
		action_message = "A  TUCKING - LESS STEERING"
	elif input.pop_pressed:
		action_message = "BLUE X  POP AVAILABLE AT THE LIP"
	elif _rider_state.phase == RiderState.Phase.GROUNDED:
		action_message = "RIGHT / D: BUILD SPEED"
	elif Input.is_action_pressed(&"action_lb") or Input.is_action_pressed(&"action_rb"):
		action_message = "SHOULDER GRABS COMING SOON"
	elif Input.is_action_pressed(&"action_lt") or Input.is_action_pressed(&"action_rt"):
		action_message = "TRIGGER TRICKS COMING SOON"
	if not action_message.is_empty():
		_action_label.text = action_message
		_action_hint_time = 1.5


func _project_rider_position() -> Vector2:
	return Vector2(
		_rider_state.course_progress,
		_rider_state.vertical_position + _rider_state.lane_position * LANE_PROJECTION_SCALE
	)


func _build_skier() -> void:
	_skier = SkierViewScene.new()
	_skier.z_index = 2
	_world.add_child(_skier)
	_update_skier_view()


func _update_skier_view() -> void:
	var ground_rotation := _course.tangent_at(_rider_state.course_progress).angle()
	_skier.update_from_state(_rider_state, _project_rider_position(), ground_rotation)
	_rider_effects.update_from_state(_rider_state, _course, get_physics_process_delta_time())


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
	_rider_effects = ParkRiderEffectsScene.new()
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
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("wave")
	frames.set_animation_loop("wave", true)
	frames.set_animation_speed("wave", LOGOTYPE_FRAME_RATE)
	var frame_size := Vector2(
		HEAVENLY_LOGOTYPE_SPRITE.get_width() / float(LOGOTYPE_FRAME_COLUMNS),
		HEAVENLY_LOGOTYPE_SPRITE.get_height() / float(LOGOTYPE_FRAME_ROWS)
	)
	for row in LOGOTYPE_FRAME_ROWS:
		for column in LOGOTYPE_FRAME_COLUMNS:
			var frame := AtlasTexture.new()
			frame.atlas = HEAVENLY_LOGOTYPE_SPRITE
			frame.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			var frame_offset := Vector2.ZERO
			if row == 0:
				frame_offset.y = -LOGOTYPE_TOP_ROW_OFFSET
			frame.margin = Rect2(frame_offset, Vector2.ZERO)
			frames.add_frame("wave", frame)

	var logotype := AnimatedSprite2D.new()
	logotype.name = "StartLogotype"
	logotype.sprite_frames = frames
	logotype.animation = "wave"
	logotype.position = LOGOTYPE_POSITION
	logotype.scale = Vector2.ONE * LOGOTYPE_SCALE
	logotype.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logotype.play()
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
	var target_x := clampf(_rider_state.course_progress, camera_min, camera_max)
	_camera.position = Vector2(target_x, GAMEPLAY_BG.get_height() * 0.5)


func _update_presentation_cues() -> void:
	if _previous_phase == _rider_state.phase:
		return
	if _rider_state.phase == RiderState.Phase.AIRBORNE:
		_launch_sound.play()
	elif _rider_state.landing_resolved:
		_landing_sound.play()
	_previous_phase = _rider_state.phase


func _draw_course_debug() -> void:
	CourseDebugDrawScene.draw_course_debug(
		self,
		_course,
		Vector2(GAMEPLAY_BG.get_size()),
		_surface_drag_id,
		_surface_drag_vertex,
		_rider_state
	)


func _draw_terrain_handles() -> void:
	CourseDebugDrawScene.draw_terrain_handles(self, _course, _terrain_drag_point)


func _ground_to_screen(ground_position: Vector2) -> Vector2:
	return CourseDebugDrawScene.ground_to_screen(_course, ground_position)


func _screen_to_ground(screen_position: Vector2) -> Vector2:
	return CourseDebugDrawScene.screen_to_ground(_course, screen_position)


func _build_hud() -> void:
	_hud = GameplayHudScene.new()
	_ui_layer.add_child(_hud)

	_ready_label = ArcadeTheme.make_label(
		"%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"], 42, Color("fff7cf")
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
	_launch_sound = AudioStreamPlayer.new()
	_launch_sound.name = "LaunchSound"
	_launch_sound.stream = SWITCH_SOUND
	add_child(_launch_sound)
	_landing_sound = AudioStreamPlayer.new()
	_landing_sound.name = "LandingSound"
	_landing_sound.stream = CONFIRMATION_SOUND
	add_child(_landing_sound)


func request_exit_confirmation() -> void:
	if _exit_confirmation:
		return
	get_tree().paused = true
	_exit_confirmation = Control.new()
	_exit_confirmation.name = "ExitConfirmation"
	_exit_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(_exit_confirmation)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fd9")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_confirmation.add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(300, 342)
	panel.size = Vector2(1320, 396)
	panel.add_theme_stylebox_override("panel", _pause_dialog_style())
	_exit_confirmation.add_child(panel)

	var title := ArcadeTheme.make_label("ABANDON THIS RUN?", 36, Color("fff16a"))
	title.position = Vector2(0, 55)
	title.size = Vector2(panel.size.x, 58)
	panel.add_child(title)

	var warning := ArcadeTheme.make_label("YOUR CURRENT SCORE WILL VANISH", 20, Color("fff7cf"))
	warning.position = Vector2(0, 145)
	warning.size = Vector2(panel.size.x, 38)
	panel.add_child(warning)

	_switch_sound = AudioStreamPlayer.new()
	_switch_sound.stream = SWITCH_SOUND
	_exit_confirmation.add_child(_switch_sound)
	if _confirmation_sound == null:
		_confirmation_sound = AudioStreamPlayer.new()
		_confirmation_sound.stream = CONFIRMATION_SOUND
		add_child(_confirmation_sound)
	_focused_dialog_button = null

	_keep_playing_button = _build_confirmation_button("KEEP PLAYING", Vector2(460, 248))
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	panel.add_child(_keep_playing_button)

	_controls_button = _build_confirmation_button("HOW TO PLAY", Vector2(60, 248))
	_controls_button.pressed.connect(_open_controls)
	panel.add_child(_controls_button)

	_return_button = _build_confirmation_button("ABANDON RUN", Vector2(860, 248))
	_return_button.pressed.connect(_confirm_return_to_title)
	panel.add_child(_return_button)
	_wire_dialog_button_focus()
	_confirmation_sound.play()
	_keep_playing_button.call_deferred("grab_focus")


func is_exit_confirmation_open() -> bool:
	return _exit_confirmation != null


func _build_confirmation_button(text: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = button_position
	button.size = Vector2(400, 86)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("e8f7ff"))
	button.add_theme_color_override("font_hover_color", Color("fff7cf"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("fff16a"))
	button.add_theme_color_override("font_outline_color", Color("010713"))
	button.add_theme_constant_override("outline_size", 7)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _pause_selected_style())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", _pause_selected_style())
	var left_marker := ArcadeTheme.make_label(">", 24, Color("fff16a"))
	left_marker.name = "SelectionLeft"
	left_marker.position = Vector2(14, 0)
	left_marker.size = Vector2(30, button.size.y)
	left_marker.hide()
	button.add_child(left_marker)
	var right_marker := ArcadeTheme.make_label("<", 24, Color("fff16a"))
	right_marker.name = "SelectionRight"
	right_marker.position = Vector2(button.size.x - 44, 0)
	right_marker.size = Vector2(30, button.size.y)
	right_marker.hide()
	button.add_child(right_marker)
	button.focus_entered.connect(_on_dialog_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _pause_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("03162be0")
	style.border_color = Color("fff16a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color("01040ae6")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style


func _pause_dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("071b39")
	style.border_color = Color("fff16a")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color("01040add")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style


func _wire_dialog_button_focus() -> void:
	_controls_button.focus_neighbor_left = NodePath(".")
	_controls_button.focus_neighbor_right = _controls_button.get_path_to(_keep_playing_button)
	_keep_playing_button.focus_neighbor_left = _keep_playing_button.get_path_to(_controls_button)
	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_return_button)
	_return_button.focus_neighbor_left = _return_button.get_path_to(_keep_playing_button)
	_return_button.focus_neighbor_right = NodePath(".")


func _on_dialog_button_focused(button: Button) -> void:
	if _focused_dialog_button == button:
		return
	var is_first_focus := _focused_dialog_button == null
	if _focused_dialog_button:
		_set_dialog_selection(_focused_dialog_button, false)
	_focused_dialog_button = button
	_set_dialog_selection(button, true)
	if not is_first_focus and is_instance_valid(_switch_sound):
		_switch_sound.play()


func _set_dialog_selection(button: Button, selected: bool) -> void:
	var left_marker := button.get_node("SelectionLeft") as Label
	var right_marker := button.get_node("SelectionRight") as Label
	left_marker.visible = selected
	right_marker.visible = selected


func _input(event: InputEvent) -> void:
	if not terrain_editor_enabled or is_exit_confirmation_open():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if _remove_surface_vertex(_screen_to_world(mouse_event.global_position)):
				_save_terrain_points()
				get_viewport().set_input_as_handled()
				queue_redraw()
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			var world_position := _screen_to_world(mouse_event.global_position)
			if _rider_at(world_position):
				_begin_rider_drag(world_position)
			elif mouse_event.shift_pressed and _insert_surface_vertex(world_position):
				_surface_drag_id = StringName()
				_surface_drag_vertex = -1
				_save_terrain_points()
				get_viewport().set_input_as_handled()
			else:
				var surface_vertex := _surface_vertex_at(world_position)
				if surface_vertex.is_empty():
					_terrain_drag_point = _terrain_point_at(world_position)
				else:
					_surface_drag_id = surface_vertex["surface_id"]
					_surface_drag_vertex = surface_vertex["vertex_index"]
		elif _rider_dragging:
			_rider_dragging = false
			get_viewport().set_input_as_handled()
		elif _terrain_drag_point >= 0 or _surface_drag_vertex >= 0:
			_save_terrain_points()
			_terrain_drag_point = -1
			_surface_drag_id = StringName()
			_surface_drag_vertex = -1
		if _rider_dragging or _terrain_drag_point >= 0 or _surface_drag_vertex >= 0:
			get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if event is InputEventMouseMotion and _rider_dragging:
		var motion_event := event as InputEventMouseMotion
		_place_rider_on_course(_screen_to_world(motion_event.global_position).x)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _surface_drag_vertex >= 0:
		var motion_event := event as InputEventMouseMotion
		_move_surface_vertex(_screen_to_world(motion_event.global_position))
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if event is InputEventMouseMotion and _terrain_drag_point >= 0:
		var motion_event := event as InputEventMouseMotion
		_move_terrain_point(_terrain_drag_point, _screen_to_world(motion_event.global_position))
		get_viewport().set_input_as_handled()
		queue_redraw()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return _world.get_global_transform_with_canvas().affine_inverse() * screen_position


func _rider_at(world_position: Vector2) -> bool:
	return world_position.distance_to(_project_rider_position()) <= RIDER_DRAG_HIT_RADIUS


func _surface_vertex_at(world_position: Vector2) -> Dictionary:
	for surface in _course.surfaces:
		for point_index in surface.footprint.size():
			if (
				world_position.distance_to(_ground_to_screen(surface.footprint[point_index]))
				<= TERRAIN_HANDLE_HIT_RADIUS
			):
				return {"surface_id": surface.id, "vertex_index": point_index}
	return {}


func _move_surface_vertex(world_position: Vector2) -> void:
	for surface in _course.surfaces:
		if surface.id != _surface_drag_id:
			continue
		var ground_position := _screen_to_ground(world_position)
		ground_position.x = clampf(
			ground_position.x, _course.terrain_points[0].x, _course.terrain_points[-1].x
		)
		ground_position.y = clampf(ground_position.y, -900.0, 900.0)
		surface.footprint[_surface_drag_vertex] = ground_position
		return


func _insert_surface_vertex(world_position: Vector2) -> bool:
	var edge := _surface_edge_at(world_position)
	if edge.is_empty():
		return false
	var surface_id: StringName = edge["surface_id"]
	var edge_index: int = edge["edge_index"]
	for surface in _course.surfaces:
		if surface.id != surface_id:
			continue
		if edge_index == surface.launch_edge_index:
			return false
		surface.footprint.insert(edge_index + 1, _screen_to_ground(world_position))
		if edge_index < surface.launch_edge_index:
			surface.launch_edge_index += 1
		return true
	return false


func _remove_surface_vertex(world_position: Vector2) -> bool:
	var vertex := _surface_vertex_at(world_position)
	if vertex.is_empty():
		return false
	var surface_id: StringName = vertex["surface_id"]
	var vertex_index: int = vertex["vertex_index"]
	for surface in _course.surfaces:
		if surface.id != surface_id or surface.footprint.size() <= 3:
			continue
		var launch_edge_end := (surface.launch_edge_index + 1) % surface.footprint.size()
		if vertex_index == surface.launch_edge_index or vertex_index == launch_edge_end:
			return false
		surface.footprint.remove_at(vertex_index)
		if vertex_index < surface.launch_edge_index:
			surface.launch_edge_index -= 1
		return true
	return false


func _surface_edge_at(world_position: Vector2) -> Dictionary:
	var closest_edge := {}
	var closest_distance := TERRAIN_HANDLE_HIT_RADIUS
	for surface in _course.surfaces:
		var footprint := CourseDebugDrawScene.surface_screen_footprint(_course, surface)
		for point_index in footprint.size():
			var edge_start := footprint[point_index]
			var edge_end := footprint[(point_index + 1) % footprint.size()]
			var distance := (
				Geometry2D
				. get_closest_point_to_segment(world_position, edge_start, edge_end)
				. distance_to(world_position)
			)
			if distance <= closest_distance:
				closest_distance = distance
				closest_edge = {"surface_id": surface.id, "edge_index": point_index}
	return closest_edge


func _begin_rider_drag(world_position: Vector2) -> void:
	_rider_dragging = true
	_rider_state = RiderStateScene.new()
	_skier.reset_presentation()
	_has_started_moving = false
	_action_hint_time = 0.0
	_action_label.hide()
	_hud.set_speed(0.0)
	_hud.set_score(0)
	_hud.set_rotation_value(0.0)
	_hud.clear_result()
	_previous_phase = RiderState.Phase.GROUNDED
	_place_rider_on_course(world_position.x)


func _place_rider_on_course(world_x: float) -> void:
	_rider_state.course_progress = clampf(
		world_x, _course.terrain_points[0].x, _course.terrain_points[-1].x
	)
	_rider_state.lane_position = 0.0
	_rider_state.vertical_position = _course.surface_y_at(_rider_state.course_progress)
	_rider_state.ground_position = Vector2(_rider_state.course_progress, _rider_state.lane_position)
	_update_camera()
	_update_skier_view()


func _terrain_point_at(world_position: Vector2) -> int:
	var closest_point := -1
	var closest_distance := TERRAIN_HANDLE_HIT_RADIUS
	for point_index in _course.terrain_points.size():
		var distance := world_position.distance_to(_course.terrain_points[point_index])
		if distance <= closest_distance:
			closest_distance = distance
			closest_point = point_index
	return closest_point


func _move_terrain_point(point_index: int, world_position: Vector2) -> void:
	var point := world_position
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	var minimum_x := 0.0 if point_index == 0 else _course.terrain_points[point_index - 1].x + 1.0
	var maximum_x := (
		_course.terrain_points[point_index + 1].x - 1.0
		if point_index < _course.terrain_points.size() - 1
		else texture_size.x
	)
	if point_index == 0:
		maximum_x = minf(maximum_x, _course.camera_start)
	else:
		minimum_x = maxf(minimum_x, 0.0)
	if point_index == _course.terrain_points.size() - 1:
		minimum_x = maxf(minimum_x, _course.landing_end + 1.0)
	point.x = clampf(point.x, minimum_x, maximum_x)
	point.y = clampf(point.y, 0.0, texture_size.y)
	_course.terrain_points[point_index] = point
	if point_index == _course.terrain_points.size() - 1:
		# The final terrain point defines the end of the camera and recovery runout.
		_course.recovery_progress = point.x
		_course.camera_end = point.x
	_rider_state.vertical_position = _course.surface_y_at(_rider_state.course_progress)


func _save_terrain_points() -> void:
	var errors := _course.validation_errors()
	if not errors.is_empty():
		push_error("Terrain points not saved:\n%s" % "\n".join(errors))
		return
	var error := ResourceSaver.save(_course, PARK_COURSE_RESOURCE_PATH)
	if error != OK:
		push_error("Could not save terrain points: %s" % error_string(error))


func _unhandled_input(event: InputEvent) -> void:
	if _controls_screen:
		return
	if not _exit_confirmation:
		if (
			_rider_state.phase == RiderState.Phase.CRASHED
			and (
				event.is_action_pressed(&"controller_start")
				or (
					event is InputEventKey
					and (event as InputEventKey).pressed
					and (event as InputEventKey).keycode == KEY_R
				)
			)
		):
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
		return

	if (
		event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
		or event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"ui_down")
	):
		if _keep_playing_button.has_focus():
			_controls_button.grab_focus()
		elif _controls_button.has_focus():
			_return_button.grab_focus()
		else:
			_keep_playing_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"controller_start") or event.is_action_pressed(&"ui_accept"):
		if _return_button.has_focus():
			_confirm_return_to_title()
		elif _controls_button.has_focus():
			_open_controls()
		else:
			_on_keep_playing_pressed()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"exit_escape")
		or event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"cabinet_exit")
	):
		close_exit_confirmation()
		get_viewport().set_input_as_handled()


func _restart_run() -> void:
	_rider_state = RiderStateScene.new()
	_skier.reset_presentation()
	_rider_state.course_progress = _course.start_progress
	_rider_state.ground_position = Vector2(_rider_state.course_progress, _rider_state.lane_position)
	_rider_state.vertical_position = _course.surface_y_at(_rider_state.course_progress)
	_has_started_moving = false
	_action_hint_time = 0.0
	_action_label.hide()
	_hud.set_speed(0.0)
	_hud.set_score(0)
	_hud.set_rotation_value(0.0)
	_hud.clear_result()
	_previous_phase = RiderState.Phase.GROUNDED
	_update_skier_view()


func _confirm_return_to_title() -> void:
	get_tree().paused = false
	return_to_title_requested.emit()


func _on_keep_playing_pressed() -> void:
	if is_instance_valid(_confirmation_sound):
		_confirmation_sound.play()
	close_exit_confirmation()


func close_exit_confirmation() -> void:
	if not _exit_confirmation:
		return
	get_tree().paused = false
	_exit_confirmation.queue_free()
	_exit_confirmation = null
	_return_button = null
	_keep_playing_button = null
	_controls_button = null
	_switch_sound = null
	_focused_dialog_button = null


func _open_controls() -> void:
	if _controls_screen:
		return
	if is_instance_valid(_confirmation_sound):
		_confirmation_sound.play()
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
	_controls_button.call_deferred("grab_focus")
