## Configures the primary cabinet window and owns the optional marquee window.
class_name WindowCoordinator
extends Node

signal close_requested

const PRIMARY_SCREEN_WITH_MARQUEE := 1
const MARQUEE_SCREEN := 0
const PRIMARY_DESIGN_SIZE := Vector2i(1920, 1080)
const MARQUEE_DESIGN_SIZE := Vector2i(1920, 360)
const MarqueeScreenScene := preload("res://src/presentation/marquee/marquee_screen.gd")

var _primary_screen_index := 0


func setup(
	primary_window: Window, options: DevOptions, liftie_state_service: LiftieStateService
) -> void:
	primary_window.close_requested.connect(close_requested.emit)
	var screen_count := DisplayServer.get_screen_count()
	_primary_screen_index = PRIMARY_SCREEN_WITH_MARQUEE if screen_count >= 2 else 0
	_configure_primary_window(primary_window, options)
	if screen_count >= 2 or options.force_marquee:
		_create_marquee(options, liftie_state_service, screen_count)


func primary_screen_index() -> int:
	return _primary_screen_index


func _configure_primary_window(primary_window: Window, options: DevOptions) -> void:
	if options.primary_size.x > 0:
		WindowManager.configure_dev_window(
			primary_window,
			_primary_screen_index,
			PRIMARY_DESIGN_SIZE,
			"HEAVENLY - PRIMARY",
			options.primary_size,
			Vector2i.ZERO
		)
		return
	WindowManager.configure_cabinet_window(
		primary_window, _primary_screen_index, PRIMARY_DESIGN_SIZE, "HEAVENLY - PRIMARY"
	)


func _create_marquee(
	options: DevOptions, liftie_state_service: LiftieStateService, screen_count: int
) -> void:
	var marquee := Window.new()
	marquee.name = "MarqueeWindow"
	marquee.transient = false
	marquee.close_requested.connect(close_requested.emit)
	add_child(marquee)
	var marquee_screen := MARQUEE_SCREEN if screen_count >= 2 else _primary_screen_index
	var marquee_size: Vector2i = (
		options.marquee_size if options.marquee_size.x > 0 else MARQUEE_DESIGN_SIZE
	)
	var marquee_offset := Vector2i.ZERO
	if options.primary_size.x > 0 or options.marquee_size.x > 0:
		# Stack the dev marquee below the dev primary so both are visible on one screen.
		var primary_height: int = options.primary_size.y if options.primary_size.x > 0 else 0
		marquee_offset = Vector2i(0, primary_height + 28)
	if marquee_size.x > 0:
		WindowManager.configure_dev_window(
			marquee,
			marquee_screen,
			MARQUEE_DESIGN_SIZE,
			"HEAVENLY - MARQUEE",
			marquee_size,
			marquee_offset
		)
	else:
		WindowManager.configure_cabinet_window(
			marquee, marquee_screen, MARQUEE_DESIGN_SIZE, "HEAVENLY - MARQUEE"
		)
	var marquee_view := MarqueeScreenScene.new()
	marquee_view.screen_index = marquee_screen
	marquee_view.liftie_state_service = liftie_state_service
	marquee_view.show_diagnostics = options.show_diagnostics
	marquee.add_child(marquee_view)
	marquee.show()
