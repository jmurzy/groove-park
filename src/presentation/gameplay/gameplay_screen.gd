class_name GameplayScreen
extends Control

signal return_to_title_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")

const PARK_COURSE_RESOURCE := preload("res://src/game/park/park_course.tres")
const RiderStateScene := preload("res://src/game/park/rider_state.gd")
const RiderInputFrameScene := preload("res://src/game/park/rider_input_frame.gd")
const RiderSimulationScene := preload("res://src/game/park/rider_simulation.gd")
const RIDER_TUNING_RESOURCE := preload("res://src/game/park/rider_tuning.tres")
const SURFACE_GRID_SIZE := 120.0
const LANE_PROJECTION_SCALE := 0.18
var player_count := 1
var _ready_label: Label
var _action_label: Label
var _action_hint_time := 0.0
var _elapsed := 0.0
var _has_started_moving := false
var _rider_state: RiderState = RiderStateScene.new()
var _rider_simulation: RiderSimulation = RiderSimulationScene.new()
var _rider_tuning: RiderTuning = RIDER_TUNING_RESOURCE
var _skier: SkierView
var _hud: GameplayHud
var _exit_confirmation: Control
var _return_button: Button
var _keep_playing_button: Button
var _controls_button: Button
var _switch_sound: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _gameplay_music: AudioStreamPlayer
var _back_sound: AudioStreamPlayer
var _focused_dialog_button: Button
var _controls_screen: HowToPlayScreen
var _course: ParkCourse = PARK_COURSE_RESOURCE


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
	_build_skier()
	_build_hud()
	_build_music()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color.BLACK)
	var source_rect := _background_source_rect()
	draw_texture_rect_region(GAMEPLAY_BG, Rect2(Vector2.ZERO, DESIGN_SIZE), source_rect)
	if OS.is_debug_build():
		_draw_course_debug(source_rect)
	_draw_skier_debug_marker(source_rect)
	draw_texture_rect(FRAME_OVERLAY, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	for y in range(0, int(DESIGN_SIZE.y), 6):
		draw_line(Vector2(0, y), Vector2(DESIGN_SIZE.x, y), Color(0.0, 0.08, 0.16, 0.18), 1.0)


func _process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_elapsed += delta
	_ready_label.visible = not _has_started_moving and fmod(_elapsed, 0.8) < 0.56
	if _action_hint_time > 0.0:
		_action_hint_time = maxf(_action_hint_time - delta, 0.0)
		_action_label.visible = true
	elif _action_label:
		_action_label.visible = false


func _physics_process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_update_rider_state(delta)
	_update_skier_view()
	queue_redraw()


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
	_hud.set_speed(_rider_state.ground_velocity.length())
	_update_action_label(input)


func _update_action_label(input: RiderInputFrame) -> void:
	var action_message := ""
	if _rider_state.phase == RiderState.Phase.AIRBORNE:
		action_message = (
			"TAKEOFF %.0f  VY %.0f"
			% [_rider_state.takeoff_course_speed, _rider_state.takeoff_vertical_speed]
		)
	elif _rider_state.compression_active:
		action_message = "BLUE X  COMPRESSING %.0f%%" % (_rider_state.compression_amount * 100.0)
	elif input.brake_pressed:
		action_message = "B  CHECKING SPEED"
	elif input.edge_pressed:
		action_message = "Y  STRONG EDGE"
	elif input.tuck_pressed:
		action_message = "A  TUCKING - LESS STEERING"
	elif input.pop_pressed:
		action_message = "BLUE X  POP AVAILABLE AT THE LIP"
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
	add_child(_skier)
	_update_skier_view()


func _update_skier_view() -> void:
	var source_rect := _background_source_rect()
	var screen_scale := DESIGN_SIZE / source_rect.size
	var screen_position := (_project_rider_position() - source_rect.position) * screen_scale
	_skier.update_from_state(
		_rider_state, screen_position, _course.tangent_at(_rider_state.course_progress).angle()
	)


func _draw_course_debug(source_rect: Rect2) -> void:
	var world_bounds := Rect2(Vector2.ZERO, Vector2(GAMEPLAY_BG.get_size()))
	var visible_bounds := world_bounds.intersection(source_rect)
	var scale := DESIGN_SIZE / source_rect.size
	var screen_bounds := Rect2(
		(visible_bounds.position - source_rect.position) * scale, visible_bounds.size * scale
	)
	draw_rect(screen_bounds, Color("010713dd"), false, 7.0)
	draw_rect(screen_bounds, Color("ff5d52"), false, 3.0)
	for point_index in range(_course.terrain_points.size() - 1):
		var slope_start := (_course.terrain_points[point_index] - source_rect.position) * scale
		var slope_end := (_course.terrain_points[point_index + 1] - source_rect.position) * scale
		draw_line(slope_start, slope_end, Color("010713ee"), 10.0)
		draw_line(slope_start, slope_end, Color("ff5d52"), 5.0)
	_draw_lane_guide(source_rect, _course.lane_min, Color("64ffb2"))
	_draw_lane_guide(source_rect, _course.lane_max, Color("64ffb2"))
	_draw_course_marker(source_rect, _course.compression_start, "COMPRESS", Color("fff16a"))
	_draw_course_marker(source_rect, _course.compression_end, "RELEASE", Color("fff16a"))
	_draw_course_marker(source_rect, _course.lip_progress, "LIP", Color("68efff"))
	_draw_course_marker(source_rect, _course.landing_start, "LAND", Color("73ff91"))
	_draw_course_marker(source_rect, _course.landing_end, "RUNOUT", Color("73ff91"))
	_draw_predicted_takeoff_trajectory(source_rect)

	var first_grid_x := floorf(visible_bounds.position.x / SURFACE_GRID_SIZE) * SURFACE_GRID_SIZE
	for x in range(int(first_grid_x), int(visible_bounds.end.x) + 1, int(SURFACE_GRID_SIZE)):
		var screen_x := (x - source_rect.position.x) * scale.x
		draw_line(
			Vector2(screen_x, screen_bounds.position.y),
			Vector2(screen_x, screen_bounds.end.y),
			Color("071326bb"),
			3.0
		)
		draw_line(
			Vector2(screen_x, screen_bounds.position.y),
			Vector2(screen_x, screen_bounds.end.y),
			Color("68efff88"),
			1.0
		)

	var first_grid_y := floorf(visible_bounds.position.y / SURFACE_GRID_SIZE) * SURFACE_GRID_SIZE
	for y in range(int(first_grid_y), int(visible_bounds.end.y) + 1, int(SURFACE_GRID_SIZE)):
		var screen_y := (y - source_rect.position.y) * scale.y
		draw_line(
			Vector2(screen_bounds.position.x, screen_y),
			Vector2(screen_bounds.end.x, screen_y),
			Color("071326bb"),
			3.0
		)
		draw_line(
			Vector2(screen_bounds.position.x, screen_y),
			Vector2(screen_bounds.end.x, screen_y),
			Color("68efff88"),
			1.0
		)


func _draw_lane_guide(source_rect: Rect2, lane_position: float, color: Color) -> void:
	var scale := DESIGN_SIZE / source_rect.size
	var projected_offset := Vector2(0, lane_position * LANE_PROJECTION_SCALE)
	for point_index in range(_course.terrain_points.size() - 1):
		var guide_start := (
			(_course.terrain_points[point_index] + projected_offset - source_rect.position) * scale
		)
		var guide_end := (
			(_course.terrain_points[point_index + 1] + projected_offset - source_rect.position)
			* scale
		)
		draw_line(guide_start, guide_end, Color("010713ee"), 7.0)
		draw_line(guide_start, guide_end, color, 3.0)


func _draw_course_marker(
	source_rect: Rect2, course_progress: float, marker_name: String, color: Color
) -> void:
	if course_progress < source_rect.position.x or course_progress > source_rect.end.x:
		return
	var scale := DESIGN_SIZE / source_rect.size
	var surface_position := _course.surface_position_at(course_progress)
	var screen_position := (surface_position - source_rect.position) * scale
	draw_line(
		Vector2(screen_position.x, 0),
		Vector2(screen_position.x, DESIGN_SIZE.y),
		Color("010713ee"),
		7.0
	)
	draw_line(Vector2(screen_position.x, 0), Vector2(screen_position.x, DESIGN_SIZE.y), color, 3.0)
	draw_circle(screen_position, 15.0, Color("010713ee"))
	draw_circle(screen_position, 10.0, color)
	var label_size := ThemeDB.fallback_font.get_string_size(
		marker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18
	)
	var label_rect := Rect2(screen_position + Vector2(8, -38), label_size + Vector2(16, 20))
	draw_rect(label_rect, Color("010713dd"))
	draw_rect(label_rect, color, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		screen_position + Vector2(16, -22),
		marker_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18.0,
		color
	)


func _draw_skier_debug_marker(source_rect: Rect2) -> void:
	var scale := DESIGN_SIZE / source_rect.size
	var screen_position := (_project_rider_position() - source_rect.position) * scale
	draw_circle(screen_position, 56, Color("010713ee"), false, 8.0)
	draw_circle(screen_position, 52, Color("fff16a"), false, 3.0)


func _draw_predicted_takeoff_trajectory(source_rect: Rect2) -> void:
	if _rider_state.phase != RiderState.Phase.AIRBORNE:
		return
	var scale := DESIGN_SIZE / source_rect.size
	var start := (_project_rider_position() - source_rect.position) * scale
	var velocity := Vector2(_rider_state.course_speed, _rider_state.vertical_speed) * 0.28
	draw_line(start, start + velocity, Color("68efff"), 3.0)
	draw_circle(start + velocity, 6.0, Color("68efff"))


func _build_hud() -> void:
	_hud = GameplayHudScene.new()
	add_child(_hud)

	_ready_label = ArcadeTheme.make_label(
		"%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"], 42, Color("fff7cf")
	)
	_ready_label.position = Vector2(0, 430)
	_ready_label.size = Vector2(DESIGN_SIZE.x, 72)
	add_child(_ready_label)

	_action_label = ArcadeTheme.make_label("", 30, Color("68efff"))
	_action_label.position = Vector2(0, 218)
	_action_label.size = Vector2(DESIGN_SIZE.x, 52)
	_action_label.hide()
	add_child(_action_label)


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
	if _exit_confirmation:
		return
	get_tree().paused = true
	_exit_confirmation = Control.new()
	_exit_confirmation.name = "ExitConfirmation"
	_exit_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_exit_confirmation)

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


func _unhandled_input(event: InputEvent) -> void:
	if _controls_screen:
		return
	if not _exit_confirmation:
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
	add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	if is_instance_valid(_back_sound):
		_back_sound.play()
	_controls_button.call_deferred("grab_focus")
