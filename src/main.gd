extends Node

const PRIMARY_SCREEN_WITH_MARQUEE := 1
const MARQUEE_SCREEN := 0
const PRIMARY_DESIGN_SIZE := Vector2i(1920, 1080)
const MARQUEE_DESIGN_SIZE := Vector2i(1920, 360)
const EXIT_HOLD_SECONDS := 2.0

var _exit_hold_time := 0.0
var _elapsed_time := 0.0
var _moving_bars: Array[Dictionary] = []


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().close_requested.connect(_quit)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	var screen_count := DisplayServer.get_screen_count()
	_log_displays(screen_count)
	_log_connected_controllers()

	var primary_screen := PRIMARY_SCREEN_WITH_MARQUEE if screen_count >= 2 else 0
	_configure_window(get_window(), primary_screen, PRIMARY_DESIGN_SIZE, "HEAVENLY - PRIMARY")
	add_child(_create_diagnostic_view(
		"PRIMARY",
		primary_screen,
		PRIMARY_DESIGN_SIZE,
		Color("071f4a"),
		Color("35a7ff"),
		false
	))

	if screen_count >= 2:
		_create_marquee(MARQUEE_SCREEN)


func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_motion()

	if Input.is_action_just_pressed(&"exit_escape"):
		_quit()
		return

	if Input.is_action_pressed(&"controller_start") and Input.is_action_pressed(&"controller_back"):
		_exit_hold_time += delta
		if _exit_hold_time >= EXIT_HOLD_SECONDS:
			_quit()
	else:
		_exit_hold_time = 0.0


func _create_marquee(screen_index: int) -> void:
	var marquee := Window.new()
	marquee.name = "MarqueeWindow"
	marquee.transient = false
	marquee.close_requested.connect(_quit)
	add_child(marquee)
	_configure_window(marquee, screen_index, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE")
	marquee.add_child(_create_diagnostic_view(
		"MARQUEE",
		screen_index,
		MARQUEE_DESIGN_SIZE,
		Color("3b2a04"),
		Color("ffc84a"),
		true
	))
	marquee.show()


func _configure_window(window: Window, screen_index: int, design_size: Vector2i, window_title: String) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	window.title = window_title
	window.mode = Window.MODE_WINDOWED
	window.current_screen = screen_index
	window.borderless = true
	window.unresizable = true
	window.content_scale_size = design_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.position = screen_position
	window.size = screen_size


func _create_diagnostic_view(
	window_name: String,
	screen_index: int,
	design_size: Vector2i,
	background_color: Color,
	accent_color: Color,
	reverse_motion: bool
) -> Control:
	var root := Control.new()
	root.name = "%sView" % window_name.capitalize()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = background_color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var title := Label.new()
	title.text = "HEAVENLY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f5f7ff"))
	title.add_theme_color_override("font_outline_color", accent_color.darkened(0.65))
	title.add_theme_constant_override("outline_size", 10 if window_name == "PRIMARY" else 7)
	title.add_theme_font_size_override("font_size", 132 if window_name == "PRIMARY" else 86)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 280.0 if window_name == "PRIMARY" else 65.0
	title.offset_bottom = title.offset_top + (190.0 if window_name == "PRIMARY" else 120.0)
	root.add_child(title)

	var identifier := Label.new()
	identifier.text = window_name
	identifier.position = Vector2(42, 28)
	identifier.add_theme_color_override("font_color", accent_color)
	identifier.add_theme_font_size_override("font_size", 30 if window_name == "PRIMARY" else 22)
	root.add_child(identifier)

	if window_name == "PRIMARY":
		var exit_button := Button.new()
		exit_button.text = "EXIT"
		exit_button.tooltip_text = "Exit HEAVENLY"
		exit_button.position = Vector2(design_size.x - 178, 28)
		exit_button.size = Vector2(136, 54)
		exit_button.add_theme_color_override("font_color", Color("f5f7ff"))
		exit_button.add_theme_font_size_override("font_size", 22)
		exit_button.pressed.connect(_quit)
		root.add_child(exit_button)

	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var diagnostics := Label.new()
	diagnostics.text = "Godot screen %d  |  %d x %d  |  position %d, %d" % [
		screen_index,
		screen_size.x,
		screen_size.y,
		screen_position.x,
		screen_position.y,
	]
	diagnostics.position = Vector2(42, design_size.y - (64 if window_name == "PRIMARY" else 40))
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	diagnostics.add_theme_font_size_override("font_size", 22 if window_name == "PRIMARY" else 16)
	root.add_child(diagnostics)

	var moving_bar := ColorRect.new()
	moving_bar.color = accent_color
	moving_bar.size = Vector2(260, 42) if window_name == "PRIMARY" else Vector2(360, 18)
	moving_bar.position.y = design_size.y * (0.72 if window_name == "PRIMARY" else 0.69)
	moving_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(moving_bar)
	_moving_bars.append({
		"node": moving_bar,
		"width": float(design_size.x),
		"reverse": reverse_motion,
	})

	return root


func _update_motion() -> void:
	var progress := (sin(_elapsed_time * 1.35) + 1.0) * 0.5
	for bar_data in _moving_bars:
		var bar: ColorRect = bar_data.node
		var travel: float = bar_data.width - bar.size.x
		var bar_progress: float = 1.0 - progress if bar_data.reverse else progress
		bar.position.x = bar_progress * travel


func _log_displays(screen_count: int) -> void:
	print("HEAVENLY detected %d screen(s)." % screen_count)
	for screen_index in screen_count:
		var position := DisplayServer.screen_get_position(screen_index)
		var size := DisplayServer.screen_get_size(screen_index)
		var refresh_rate := DisplayServer.screen_get_refresh_rate(screen_index)
		print("Screen %d: %d x %d at (%d, %d), %.2f Hz" % [
			screen_index,
			size.x,
			size.y,
			position.x,
			position.y,
			refresh_rate,
		])


func _log_connected_controllers() -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		print("No controller detected at startup.")
		return

	for device_id in joypads:
		print("Controller %d: %s" % [device_id, Input.get_joy_name(device_id)])


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		print("Controller %d connected: %s" % [device_id, Input.get_joy_name(device_id)])
	else:
		print("Controller %d disconnected." % device_id)


func _quit() -> void:
	get_tree().quit()
