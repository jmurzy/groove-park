## Application composition root. Runtime display flow and window ownership live in
## the screen/marquee controllers and WindowCoordinator respectively.
extends Node

const GameArgsScene := preload("res://src/app/game_args.gd")
const AudioManagerScript := preload("res://src/app/audio_manager.gd")
const CabinetExitHandlerScript := preload("res://src/app/cabinet_exit_handler.gd")
const InputRouterScene := preload("res://src/app/input_router.gd")
const WindowCoordinatorScene := preload("res://src/app/window_coordinator.gd")
const ScreenFlowControllerScene := preload("res://src/app/screen_flow_controller.gd")
const MarqueeFlowControllerScene := preload("res://src/app/marquee_flow_controller.gd")
const GameSessionScene := preload("res://src/game/game_session.gd")
const MockMountainStateSourceScene := preload("res://src/game/world/mock_mountain_state_source.gd")
const LiftieStateServiceScene := preload("res://src/services/liftie/liftie_state_service.gd")
const RemoteLeaderboardRepositoryScene := preload(
	"res://src/services/leaderboard/leaderboard_repository_remote.gd"
)

var _audio_manager: AudioManager
var _cabinet_exit_handler := CabinetExitHandlerScript.new()
var _input_router: InputRouter
var _game_session: GameSession
var _mountain_state_source: MountainStateSource
var _liftie_state_service: LiftieStateService
var _leaderboard_repository: RemoteLeaderboardRepository
var _window_coordinator: WindowCoordinator
var _screen_flow: ScreenFlowController
var _marquee_flow: MarqueeFlowController


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var missing_config_values := Config.missing_required_values()
	if not missing_config_values.is_empty():
		push_error("Missing required configuration: %s." % ", ".join(missing_config_values))
		get_tree().quit()
		return
	var leaderboard_api_base_url := Config.resolve_leaderboard_api_base_url()
	# Load rider animation textures before a gameplay transition needs to build their views.
	RiderVisualDefinition.warm()
	_setup_audio()
	_input_router = InputRouterScene.new()
	# Production cabinets reserve the keyboard for maintenance; Web and debug builds support it.
	_input_router.configure(OS.is_debug_build() or OS.has_feature("web"))
	add_child(_input_router)

	var options := GameArgsScene.parse_options()
	_setup_game_services(leaderboard_api_base_url)
	_window_coordinator = WindowCoordinatorScene.new()
	_window_coordinator.close_requested.connect(_quit)
	add_child(_window_coordinator)
	_window_coordinator.setup(options)

	var marquee_parent := _window_coordinator.marquee_content_parent()
	if marquee_parent:
		_marquee_flow = MarqueeFlowControllerScene.new()
		marquee_parent.add_child(_marquee_flow)
		_marquee_flow.setup(_game_session, _liftie_state_service)

	var primary_parent := _window_coordinator.primary_content_parent()
	if primary_parent:
		_screen_flow = ScreenFlowControllerScene.new()
		_screen_flow.quit_requested.connect(_quit)
		primary_parent.add_child(_screen_flow)
		_screen_flow.setup(
			_game_session,
			_input_router,
			_audio_manager,
			_liftie_state_service,
			_leaderboard_repository,
			options
		)


func _process(delta: float) -> void:
	if not OS.has_feature("web") and _cabinet_exit_handler.update(delta):
		_quit()


func _unhandled_input(event: InputEvent) -> void:
	_log_unhandled_joy_button(event)


func _setup_audio() -> void:
	_audio_manager = AudioManagerScript.new()
	add_child(_audio_manager)
	_audio_manager.configure()
	_audio_manager.play_background_music()


func _setup_game_services(leaderboard_api_base_url: String) -> void:
	# Mountain conditions outlive individual rounds and are shared by app-level views.
	_mountain_state_source = MockMountainStateSourceScene.new()
	add_child(_mountain_state_source)
	_game_session = GameSessionScene.new()
	add_child(_game_session)
	_liftie_state_service = LiftieStateServiceScene.new()
	add_child(_liftie_state_service)
	_setup_leaderboard_repository(leaderboard_api_base_url)


func _setup_leaderboard_repository(leaderboard_api_base_url: String) -> void:
	_leaderboard_repository = RemoteLeaderboardRepositoryScene.new()
	_leaderboard_repository.installation_id = Config.resolve_installation_id()
	_leaderboard_repository.setup(leaderboard_api_base_url)
	add_child(_leaderboard_repository)


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
