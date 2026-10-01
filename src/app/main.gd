## Application composition root. Runtime screen flow and window ownership live in
## ScreenFlowController and WindowCoordinator respectively.
extends Node

const PRIMARY_DESIGN_SIZE := Vector2i(1920, 1080)
const MARQUEE_DESIGN_SIZE := Vector2i(1920, 360)
const DevSente := preload("res://src/services/dev_sente.gd")
const AudioManagerScript := preload("res://src/app/audio_manager.gd")
const CabinetExitHandlerScript := preload("res://src/app/cabinet_exit_handler.gd")
const WindowCoordinatorScene := preload("res://src/app/window_coordinator.gd")
const ScreenFlowControllerScene := preload("res://src/app/screen_flow_controller.gd")
const GameSessionScene := preload("res://src/game/game_session.gd")
const MockMountainStateSourceScene := preload("res://src/game/world/mock_mountain_state_source.gd")
const LiftieStateServiceScene := preload("res://src/services/liftie_state_service.gd")
const BackgroundMusic := preload("res://assets/audio/slimeyfox-gameotoon.mp3")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")

var _audio_manager: AudioManager
var _cabinet_exit_handler := CabinetExitHandlerScript.new()
var _game_session: GameSession
var _mountain_state_source: MountainStateSource
var _liftie_state_service: LiftieStateService
var _window_coordinator: WindowCoordinator
var _screen_flow: ScreenFlowController


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Load rider animation textures before a gameplay transition needs to build their views.
	RiderVisualDefinition.warm()
	_setup_audio()
	_log_displays(DisplayServer.get_screen_count())
	_log_connected_controllers()

	var overrides := DevSente.parse_overrides(PRIMARY_DESIGN_SIZE, MARQUEE_DESIGN_SIZE)
	_setup_game_services()
	_window_coordinator = WindowCoordinatorScene.new()
	_window_coordinator.close_requested.connect(_quit)
	add_child(_window_coordinator)
	_window_coordinator.setup(
		get_window(), overrides, _liftie_state_service, overrides.show_diagnostics
	)
	_screen_flow = ScreenFlowControllerScene.new()
	_screen_flow.quit_requested.connect(_quit)
	add_child(_screen_flow)
	_screen_flow.setup(
		_game_session,
		_audio_manager,
		_liftie_state_service,
		_window_coordinator.primary_screen_index(),
		overrides.show_terrain,
		overrides.show_diagnostics
	)


func _process(delta: float) -> void:
	if _cabinet_exit_handler.update(delta):
		_quit()


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
	if _screen_flow.handle_exit_input():
		get_viewport().set_input_as_handled()
		return
	# Attract has no Esc-to-quit; cabinet exit requires the hold handled in _process.
	get_viewport().set_input_as_handled()


func _setup_audio() -> void:
	_audio_manager = AudioManagerScript.new()
	add_child(_audio_manager)
	_audio_manager.configure(BackgroundMusic.duplicate(), CONFIRMATION_SOUND)
	_audio_manager.play_background_music()


func _setup_game_services() -> void:
	# Mountain conditions outlive individual rounds and are shared by app-level views.
	_mountain_state_source = MockMountainStateSourceScene.new()
	add_child(_mountain_state_source)
	_game_session = GameSessionScene.new()
	add_child(_game_session)
	_liftie_state_service = LiftieStateServiceScene.new()
	add_child(_liftie_state_service)


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
	if is_instance_valid(_audio_manager):
		_audio_manager.shutdown()
	get_tree().quit()
