extends Node

const PRIMARY_SCREEN_WITH_MARQUEE := 1
const MARQUEE_SCREEN := 0
const PRIMARY_DESIGN_SIZE := Vector2i(1920, 1080)
const MARQUEE_DESIGN_SIZE := Vector2i(1920, 360)
const EXIT_HOLD_SECONDS := 2.0

const PrimaryScreenScene := preload("res://src/primary_screen.gd")
const MarqueeScreenScene := preload("res://src/marquee_screen.gd")
const DevSente := preload("res://src/dev_sente.gd")
const LiftieStateServiceScene := preload("res://src/liftie_state_service.gd")
const BackgroundMusic := preload("res://assets/fonts/slimeyfox-gameotoon.mp3")

var _exit_hold_time := 0.0
var _liftie_state_service


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().close_requested.connect(_quit)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	var background_music_stream: AudioStreamMP3 = BackgroundMusic.duplicate()
	background_music_stream.loop = true
	var background_music := AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	background_music.stream = background_music_stream
	add_child(background_music)
	background_music.play()

	var screen_count := DisplayServer.get_screen_count()
	_log_displays(screen_count)
	_log_connected_controllers()

	var overrides := DevSente.parse_overrides(PRIMARY_DESIGN_SIZE, MARQUEE_DESIGN_SIZE)
	_liftie_state_service = LiftieStateServiceScene.new()
	add_child(_liftie_state_service)

	var primary_screen := PRIMARY_SCREEN_WITH_MARQUEE if screen_count >= 2 else 0
	if overrides.primary_size.x > 0:
		DevSente.configure(get_window(), primary_screen, PRIMARY_DESIGN_SIZE, "HEAVENLY - PRIMARY", overrides.primary_size, Vector2i(0, 0))
	else:
		_configure_window(get_window(), primary_screen, PRIMARY_DESIGN_SIZE, "HEAVENLY - PRIMARY")

	var primary_view := PrimaryScreenScene.new()
	primary_view.screen_index = primary_screen
	primary_view.liftie_state_service = _liftie_state_service
	primary_view.show_diagnostics = overrides.show_diagnostics
	primary_view.exit_requested.connect(_quit)
	add_child(primary_view)

	var show_marquee: bool = screen_count >= 2 or overrides.force_marquee
	if show_marquee:
		var marquee_screen := MARQUEE_SCREEN if screen_count >= 2 else primary_screen
		var marquee_size: Vector2i = overrides.marquee_size if overrides.marquee_size.x > 0 else MARQUEE_DESIGN_SIZE
		var marquee_offset := Vector2i(0, 0)
		if overrides.primary_size.x > 0 or overrides.marquee_size.x > 0:
			# Stack the dev marquee below the dev primary so both are visible on one screen.
			var primary_height: int = overrides.primary_size.y if overrides.primary_size.x > 0 else 0
			marquee_offset = Vector2i(0, primary_height + 28)
		_create_marquee(marquee_screen, marquee_size, marquee_offset, overrides.show_diagnostics)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"exit_escape"):
		_quit()
		return

	if Input.is_action_pressed(&"controller_start") and Input.is_action_pressed(&"controller_back"):
		_exit_hold_time += delta
		if _exit_hold_time >= EXIT_HOLD_SECONDS:
			_quit()
	else:
		_exit_hold_time = 0.0


func _create_marquee(screen_index: int, window_size: Vector2i = Vector2i(-1, -1), offset: Vector2i = Vector2i(0, 0), show_diagnostics: bool = false) -> void:
	var marquee := Window.new()
	marquee.name = "MarqueeWindow"
	marquee.transient = false
	marquee.close_requested.connect(_quit)
	add_child(marquee)
	if window_size.x > 0:
		DevSente.configure(marquee, screen_index, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE", window_size, offset)
	else:
		_configure_window(marquee, screen_index, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE")

	var marquee_view := MarqueeScreenScene.new()
	marquee_view.screen_index = screen_index
	marquee_view.liftie_state_service = _liftie_state_service
	marquee_view.show_diagnostics = show_diagnostics
	marquee.add_child(marquee_view)
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
