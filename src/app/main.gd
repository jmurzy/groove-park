## Application entry point: builds the primary + marquee windows, wires services,
## and swaps between attract and gameplay. Runs automatically as the main scene.
extends Node

const PRIMARY_SCREEN_WITH_MARQUEE := 1
const MARQUEE_SCREEN := 0
const PRIMARY_DESIGN_SIZE := Vector2i(1920, 1080)
const MARQUEE_DESIGN_SIZE := Vector2i(1920, 360)
const EXIT_HOLD_SECONDS := 2.0

const PrimaryScreenScene := preload("res://src/presentation/attract/primary_screen.gd")
const GameplayScreenScene := preload("res://src/presentation/gameplay/gameplay_screen.gd")
const MarqueeScreenScene := preload("res://src/presentation/marquee/marquee_screen.gd")
const CrtTransitionScene := preload("res://src/presentation/effects/crt_transition.gd")
const DevSente := preload("res://src/services/dev_sente.gd")
const GameControllerScene := preload("res://src/game/game_controller.gd")
const MockMountainStateSourceScene := preload("res://src/game/world/mock_mountain_state_source.gd")
const LiftieStateServiceScene := preload("res://src/services/liftie_state_service.gd")
const BackgroundMusic := preload("res://assets/audio/slimeyfox-gameotoon.mp3")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")

var _exit_hold_time := 0.0
var _background_music: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _game_controller: GameController
var _liftie_state_service: LiftieStateService
var _primary_view: PrimaryScreen
var _gameplay_screen: GameplayScreen
var _transitioning := false
var _terrain_editor_enabled := false


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().close_requested.connect(_quit)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	var background_music_stream: AudioStreamMP3 = BackgroundMusic.duplicate()
	background_music_stream.loop = true
	_background_music = AudioStreamPlayer.new()
	_background_music.name = "BackgroundMusic"
	_background_music.stream = background_music_stream
	add_child(_background_music)
	_background_music.play()
	_confirmation_sound = AudioStreamPlayer.new()
	_confirmation_sound.stream = CONFIRMATION_SOUND
	add_child(_confirmation_sound)

	var screen_count := DisplayServer.get_screen_count()
	_log_displays(screen_count)
	_log_connected_controllers()

	var overrides := DevSente.parse_overrides(PRIMARY_DESIGN_SIZE, MARQUEE_DESIGN_SIZE)
	_terrain_editor_enabled = overrides.terrain_editor_enabled
	_game_controller = GameControllerScene.new()
	_game_controller.set_mountain_state_source(MockMountainStateSourceScene.new())
	add_child(_game_controller)
	_liftie_state_service = LiftieStateServiceScene.new()
	add_child(_liftie_state_service)

	var primary_screen := PRIMARY_SCREEN_WITH_MARQUEE if screen_count >= 2 else 0
	if overrides.primary_size.x > 0:
		DevSente.configure(
			get_window(),
			primary_screen,
			PRIMARY_DESIGN_SIZE,
			"HEAVENLY - PRIMARY",
			overrides.primary_size,
			Vector2i(0, 0)
		)
	else:
		_configure_window(get_window(), primary_screen, PRIMARY_DESIGN_SIZE, "HEAVENLY - PRIMARY")

	_show_attract(primary_screen, overrides.show_diagnostics)

	var show_marquee: bool = screen_count >= 2 or overrides.force_marquee
	if show_marquee:
		var marquee_screen := MARQUEE_SCREEN if screen_count >= 2 else primary_screen
		var marquee_size: Vector2i = (
			overrides.marquee_size if overrides.marquee_size.x > 0 else MARQUEE_DESIGN_SIZE
		)
		var marquee_offset := Vector2i(0, 0)
		if overrides.primary_size.x > 0 or overrides.marquee_size.x > 0:
			# Stack the dev marquee below the dev primary so both are visible on one screen.
			var primary_height: int = (
				overrides.primary_size.y if overrides.primary_size.x > 0 else 0
			)
			marquee_offset = Vector2i(0, primary_height + 28)
		_create_marquee(marquee_screen, marquee_size, marquee_offset, overrides.show_diagnostics)


func _process(delta: float) -> void:
	# Cabinet hard exit: hold white EXIT (cabinet_exit) alone, or legacy Start + Back.
	# Keep the combo so existing cabinets/frontends still quit to AGS.
	var hold_exit: bool = (
		Input.is_action_pressed(&"cabinet_exit")
		or (
			Input.is_action_pressed(&"controller_start")
			and Input.is_action_pressed(&"controller_back")
		)
	)
	if hold_exit:
		_exit_hold_time += delta
		if _exit_hold_time >= EXIT_HOLD_SECONDS:
			_quit()
	else:
		_exit_hold_time = 0.0


func _start_game(player_count: int) -> void:
	if _transitioning or _primary_view == null:
		return
	_transitioning = true
	_confirmation_sound.play()
	var transition := CrtTransitionScene.new()
	transition.midpoint_reached.connect(_show_gameplay.bind(player_count, transition))
	transition.finished.connect(_finish_transition.bind(transition))
	add_child(transition)


func _show_gameplay(player_count: int, transition: CrtTransition) -> void:
	_primary_view.queue_free()
	_primary_view = null
	_gameplay_screen = GameplayScreenScene.new()
	_gameplay_screen.player_count = player_count
	_gameplay_screen.terrain_editor_enabled = _terrain_editor_enabled
	_gameplay_screen.return_to_title_requested.connect(_return_to_attract)
	add_child(_gameplay_screen)
	move_child(_gameplay_screen, transition.get_index())
	_background_music.stop()
	_game_controller.start_game(player_count)


func _finish_transition(transition: CrtTransition) -> void:
	transition.queue_free()
	_transitioning = false


func _return_to_attract() -> void:
	if _gameplay_screen == null:
		return
	get_tree().paused = false
	_gameplay_screen.queue_free()
	_gameplay_screen = null
	_confirmation_sound.play()
	_background_music.play()
	_game_controller.return_to_attract()
	_show_attract(_primary_screen_index(), _show_diagnostics())


func _unhandled_input(event: InputEvent) -> void:
	_log_unhandled_joy_button(event)
	# Cabinet: ▷ (Start) pauses/opens dialog, ≡ (Back) backs out, white EXIT opens
	# dialog (hold quits via _process).
	if (
		not event.is_action_pressed(&"exit_escape")
		and not event.is_action_pressed(&"controller_start")
		and not event.is_action_pressed(&"controller_back")
		and not event.is_action_pressed(&"cabinet_exit")
	):
		return
	if _primary_view and _primary_view.handle_escape():
		get_viewport().set_input_as_handled()
		return
	if _gameplay_screen:
		if _gameplay_screen.is_exit_confirmation_open():
			_gameplay_screen.close_exit_confirmation()
		else:
			_gameplay_screen.request_exit_confirmation()
		get_viewport().set_input_as_handled()
		return
	# Attract has no Esc-to-quit; cabinet exit requires the hold handled in _process.
	get_viewport().set_input_as_handled()


func _create_marquee(
	screen_index: int,
	window_size: Vector2i = Vector2i(-1, -1),
	offset: Vector2i = Vector2i(0, 0),
	show_diagnostics: bool = false
) -> void:
	var marquee := Window.new()
	marquee.name = "MarqueeWindow"
	marquee.transient = false
	marquee.close_requested.connect(_quit)
	add_child(marquee)
	if window_size.x > 0:
		DevSente.configure(
			marquee, screen_index, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE", window_size, offset
		)
	else:
		_configure_window(marquee, screen_index, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE")

	var marquee_view := MarqueeScreenScene.new()
	marquee_view.screen_index = screen_index
	marquee_view.liftie_state_service = _liftie_state_service
	marquee_view.show_diagnostics = show_diagnostics
	marquee.add_child(marquee_view)
	marquee.show()


func _show_attract(screen_index: int, show_diagnostics: bool) -> void:
	_primary_view = PrimaryScreenScene.new()
	_primary_view.screen_index = screen_index
	_primary_view.liftie_state_service = _liftie_state_service
	_primary_view.show_diagnostics = show_diagnostics
	_primary_view.start_game_requested.connect(_start_game)
	_primary_view.exit_requested.connect(_quit)
	add_child(_primary_view)


func _primary_screen_index() -> int:
	return PRIMARY_SCREEN_WITH_MARQUEE if DisplayServer.get_screen_count() >= 2 else 0


func _show_diagnostics() -> bool:
	return DevSente.parse_overrides(PRIMARY_DESIGN_SIZE, MARQUEE_DESIGN_SIZE).show_diagnostics


func _configure_window(
	window: Window, screen_index: int, design_size: Vector2i, window_title: String
) -> void:
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
		print(
			(
				"Screen %d: %d x %d at (%d, %d), %.2f Hz"
				% [
					screen_index,
					size.x,
					size.y,
					position.x,
					position.y,
					refresh_rate,
				]
			)
		)


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


func _log_unhandled_joy_button(event: InputEvent) -> void:
	var joy_event := event as InputEventJoypadButton
	if joy_event == null or not joy_event.pressed:
		return
	print(
		(
			"HEAVENLY unhandled joy button %d on device %d (%s)."
			% [joy_event.button_index, joy_event.device, Input.get_joy_name(joy_event.device)]
		)
	)


func _quit() -> void:
	if is_instance_valid(_background_music):
		_background_music.stop()
		_background_music.stream = null
	get_tree().quit()
