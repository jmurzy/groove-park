class_name GameplayScreen
extends Control

signal return_to_title_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const FRAME_OVERLAY := preload("res://artwork/gameplay/frame_overlay.png")
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const GameplayHudScene := preload("res://src/presentation/gameplay/gameplay_hud.gd")
const ControlsScreenScene := preload("res://src/presentation/attract/controls_screen.gd")
const SLOPE_PATH_RESOURCE := preload("res://src/game/slope_path.tres")
const SLOPE_PATH_RESOURCE_PATH := "res://src/game/slope_path.tres"
const SKIER_SPEED := 520.0
const SKIER_FRAME_COUNT := 8
const SKIER_FRAME_RATE := 10.0
const SKIER_SCALE := 0.34
const SKIER_FLIP_DURATION := 0.35
const SURFACE_GRID_SIZE := 120.0
const SURFACE_MARGIN := 20.0
const SLOPE_HANDLE_RADIUS := 14.0
const SLOPE_HANDLE_HIT_RADIUS := 28.0
var player_count := 1
var _ready_label: Label
var _elapsed := 0.0
var _has_started_moving := false
var _skier_world_position := Vector2.ZERO
var _skier: AnimatedSprite2D
var _skier_flip_rotation := 0.0
var _skier_flip_tween: Tween
var _exit_confirmation: Control
var _return_button: Button
var _keep_playing_button: Button
var _controls_button: Button
var _switch_sound: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _focused_dialog_button: Button
var _controls_screen: ControlsScreen
var _slope_path_resource: SlopePath = SLOPE_PATH_RESOURCE.duplicate()
var _slope_path := _slope_path_resource.points
var _slope_drag_point := -1
var _slope_editor_enabled := OS.is_debug_build()


func _ready() -> void:
	name = "GameplayScreen"
	# Stay responsive while the tree is paused for the exit dialog.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skier_world_position = _slope_position(SURFACE_MARGIN)
	_build_skier()
	_build_hud()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color.BLACK)
	var source_rect := _background_source_rect()
	draw_texture_rect_region(GAMEPLAY_BG, Rect2(Vector2.ZERO, DESIGN_SIZE), source_rect)
	_draw_development_surface(source_rect)
	if _slope_editor_enabled:
		_draw_slope_handles(source_rect)
	_draw_skier(source_rect)
	draw_texture_rect(FRAME_OVERLAY, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	for y in range(0, int(DESIGN_SIZE.y), 6):
		draw_line(Vector2(0, y), Vector2(DESIGN_SIZE.x, y), Color(0.0, 0.08, 0.16, 0.18), 1.0)


func _process(delta: float) -> void:
	if is_exit_confirmation_open():
		return
	_elapsed += delta
	_update_skier_position(delta)
	_update_skier_sprite()
	_ready_label.visible = not _has_started_moving and fmod(_elapsed, 0.8) < 0.56
	queue_redraw()


func _background_source_rect() -> Rect2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	var source_size := _background_source_size()
	var camera_x := clampf(
		_skier_world_position.x - source_size.x * 0.5, 0.0, texture_size.x - source_size.x
	)
	return Rect2(Vector2(camera_x, 0), source_size)


func _background_source_size() -> Vector2:
	var texture_size := Vector2(GAMEPLAY_BG.get_size())
	return Vector2(texture_size.y * DESIGN_SIZE.x / DESIGN_SIZE.y, texture_size.y)


func _update_skier_position(delta: float) -> void:
	var steering := Input.get_axis(&"ui_left", &"ui_right")
	if is_zero_approx(steering):
		return
	if not _has_started_moving:
		_has_started_moving = true
		_skier.play()
	var texture_width := float(GAMEPLAY_BG.get_width())
	var skier_x := clampf(
		_skier_world_position.x + steering * SKIER_SPEED * delta,
		SURFACE_MARGIN,
		texture_width - SURFACE_MARGIN
	)
	_skier_world_position = _slope_position(skier_x)


func _slope_position(world_x: float) -> Vector2:
	if world_x <= _slope_path[0].x:
		return _slope_path[0]
	for point_index in range(_slope_path.size() - 1):
		var start := _slope_path[point_index]
		var end := _slope_path[point_index + 1]
		if world_x <= end.x:
			return start.lerp(end, inverse_lerp(start.x, end.x, world_x))
	return _slope_path[_slope_path.size() - 1]


func _build_skier() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("sprint")
	frames.set_animation_loop("sprint", true)
	frames.set_animation_speed("sprint", SKIER_FRAME_RATE)
	var sheet_width := SKIER_SHEET.get_width()
	var sheet_height := SKIER_SHEET.get_height()
	for frame_index in SKIER_FRAME_COUNT:
		var frame_start := roundi(float(frame_index) * sheet_width / SKIER_FRAME_COUNT)
		var frame_end := roundi(float(frame_index + 1) * sheet_width / SKIER_FRAME_COUNT)
		var frame := AtlasTexture.new()
		frame.atlas = SKIER_SHEET
		frame.region = Rect2(frame_start, 0, frame_end - frame_start, sheet_height)
		frames.add_frame("sprint", frame)

	_skier = AnimatedSprite2D.new()
	_skier.name = "Skier"
	_skier.sprite_frames = frames
	_skier.animation = "sprint"
	_skier.scale = Vector2.ONE * SKIER_SCALE
	_skier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_skier)
	_update_skier_sprite()


func _update_skier_sprite() -> void:
	var source_rect := _background_source_rect()
	var scale := DESIGN_SIZE / source_rect.size
	_skier.position = (_skier_world_position - source_rect.position) * scale
	var next_x := minf(_skier_world_position.x + 8.0, _slope_path[_slope_path.size() - 1].x)
	var previous_x := maxf(_skier_world_position.x - 8.0, _slope_path[0].x)
	_skier.rotation = (
		(_slope_position(next_x) - _slope_position(previous_x)).angle() + _skier_flip_rotation
	)


func _flip_skier() -> void:
	if is_instance_valid(_skier_flip_tween):
		_skier_flip_tween.kill()
	_skier_flip_tween = create_tween()
	_skier_flip_tween.tween_property(self, "_skier_flip_rotation", TAU, SKIER_FLIP_DURATION).from(
		0.0
	)
	_skier_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_skier_flip_tween.tween_callback(func() -> void: _skier_flip_rotation = 0.0)


func _draw_development_surface(source_rect: Rect2) -> void:
	var world_bounds := Rect2(Vector2.ZERO, Vector2(GAMEPLAY_BG.get_size()))
	var visible_bounds := world_bounds.intersection(source_rect)
	var scale := DESIGN_SIZE / source_rect.size
	var screen_bounds := Rect2(
		(visible_bounds.position - source_rect.position) * scale, visible_bounds.size * scale
	)
	draw_rect(screen_bounds, Color("ff3b3088"), false, 3.0)
	for point_index in range(_slope_path.size() - 1):
		var slope_start := (_slope_path[point_index] - source_rect.position) * scale
		var slope_end := (_slope_path[point_index + 1] - source_rect.position) * scale
		draw_line(slope_start, slope_end, Color("ff3b30bb"), 4.0)

	var first_grid_x := floorf(visible_bounds.position.x / SURFACE_GRID_SIZE) * SURFACE_GRID_SIZE
	for x in range(int(first_grid_x), int(visible_bounds.end.x) + 1, int(SURFACE_GRID_SIZE)):
		var screen_x := (x - source_rect.position.x) * scale.x
		draw_line(
			Vector2(screen_x, screen_bounds.position.y),
			Vector2(screen_x, screen_bounds.end.y),
			Color("ff3b3044"),
			1.0
		)

	var first_grid_y := floorf(visible_bounds.position.y / SURFACE_GRID_SIZE) * SURFACE_GRID_SIZE
	for y in range(int(first_grid_y), int(visible_bounds.end.y) + 1, int(SURFACE_GRID_SIZE)):
		var screen_y := (y - source_rect.position.y) * scale.y
		draw_line(
			Vector2(screen_bounds.position.x, screen_y),
			Vector2(screen_bounds.end.x, screen_y),
			Color("ff3b3044"),
			1.0
		)


func _draw_slope_handles(source_rect: Rect2) -> void:
	var scale := DESIGN_SIZE / source_rect.size
	for point_index in _slope_path.size():
		var screen_point := (_slope_path[point_index] - source_rect.position) * scale
		var color := Color("fff16a") if point_index == _slope_drag_point else Color("ff3b30")
		draw_circle(screen_point, SLOPE_HANDLE_RADIUS, color)
		draw_circle(screen_point, SLOPE_HANDLE_RADIUS, Color("180400"), false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if not _slope_editor_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_slope_drag_point = _slope_point_at(mouse_event.position, _background_source_rect())
		else:
			_save_slope_path()
			_slope_drag_point = -1
		queue_redraw()
		return
	if event is InputEventMouseMotion and _slope_drag_point >= 0:
		var motion_event := event as InputEventMouseMotion
		var source_rect := _background_source_rect()
		var scale := DESIGN_SIZE / source_rect.size
		_slope_path[_slope_drag_point] = motion_event.position / scale + source_rect.position
		_skier_world_position = _slope_position(_skier_world_position.x)
		queue_redraw()


func _slope_point_at(screen_position: Vector2, source_rect: Rect2) -> int:
	var scale := DESIGN_SIZE / source_rect.size
	var closest_point := -1
	var closest_distance := SLOPE_HANDLE_HIT_RADIUS
	for point_index in _slope_path.size():
		var point_position := (_slope_path[point_index] - source_rect.position) * scale
		var distance := screen_position.distance_to(point_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_point = point_index
	return closest_point


func _save_slope_path() -> void:
	if _slope_drag_point < 0:
		return
	_slope_path_resource.points = _slope_path
	var error := ResourceSaver.save(_slope_path_resource, SLOPE_PATH_RESOURCE_PATH)
	if error != OK:
		push_error("Could not save slope path: %s" % error_string(error))


func _draw_skier(source_rect: Rect2) -> void:
	var scale := DESIGN_SIZE / source_rect.size
	var screen_position := (_skier_world_position - source_rect.position) * scale
	draw_circle(screen_position, 52, Color("ff3b30aa"), false, 3.0)


func _build_hud() -> void:
	add_child(GameplayHudScene.new())

	_ready_label = ArcadeTheme.make_label(
		"%d PLAYER%s READY" % [player_count, "" if player_count == 1 else "S"], 42, Color("fff7cf")
	)
	_ready_label.position = Vector2(0, 430)
	_ready_label.size = Vector2(DESIGN_SIZE.x, 72)
	add_child(_ready_label)


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
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if (
				key_event.keycode == KEY_SPACE
				and key_event.is_pressed()
				and not key_event.is_echo()
			):
				_flip_skier()
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
	_controls_screen = ControlsScreenScene.new()
	_controls_screen.closed.connect(_close_controls)
	add_child(_controls_screen)


func _close_controls() -> void:
	if not _controls_screen:
		return
	_controls_screen.queue_free()
	_controls_screen = null
	_controls_button.call_deferred("grab_focus")
