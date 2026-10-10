## Configures the primary cabinet window and owns the optional marquee window.
class_name WindowCoordinator
extends Node

signal close_requested

const GameArgsScene := preload("res://src/app/game_args.gd")

const SCREEN_ONE := 1
const SCREEN_ZERO := 0

var _primary_subviewport: SubViewport
var _marquee_subviewport: SubViewport
var _marquee_window: Window


func _primary_screen_index_for() -> int:
	var screen_count := DisplayServer.get_screen_count()
	return SCREEN_ONE if screen_count >= 2 else SCREEN_ZERO


func _marquee_screen_index_for() -> int:
	return SCREEN_ZERO


func setup(options: GameArgsScene.GameOptions) -> void:
	var primary_window := get_window()
	primary_window.close_requested.connect(close_requested.emit)

	if OS.has_feature("web"):
		WindowManager.make_composite_window(primary_window, options.composite_size, "Marquee+Game")
		_setup_composite_viewports(options)
	else:
		var primary_screen_index := _primary_screen_index_for()
		if OS.is_debug_build():
			(
				WindowManager
				. make_dev_window(
					primary_window,
					primary_screen_index,
					options.primary_size,
					"Game",
				)
			)
		else:
			WindowManager.make_fullscreen_window(
				primary_window, primary_screen_index, options.primary_size, "Game"
			)
		var screen_count := DisplayServer.get_screen_count()
		if screen_count >= 2:
			_create_marquee_window(options)


func primary_content_parent() -> Node:
	if _primary_subviewport:
		return _primary_subviewport
	return get_parent()


func marquee_content_parent() -> Node:
	if _marquee_subviewport:
		return _marquee_subviewport
	return _marquee_window


func _create_marquee_window(options: GameArgsScene.GameOptions) -> void:
	_marquee_window = Window.new()
	_marquee_window.name = "MarqueeWindow"
	_marquee_window.transient = false
	_marquee_window.close_requested.connect(close_requested.emit)
	add_child(_marquee_window)

	var marquee_screen_index := _marquee_screen_index_for()
	if OS.is_debug_build():
		WindowManager.make_dev_window(
			_marquee_window, marquee_screen_index, options.marquee_size, "Marquee"
		)
	else:
		WindowManager.make_fullscreen_window(
			_marquee_window, marquee_screen_index, options.marquee_size, "Marquee"
		)
	_marquee_window.show()


func _setup_composite_viewports(options: GameArgsScene.GameOptions) -> void:
	var primary_container := SubViewportContainer.new()
	primary_container.position = Vector2(0, options.marquee_size.y)
	primary_container.size = options.primary_size
	primary_container.stretch = true
	add_child(primary_container)

	_primary_subviewport = SubViewport.new()
	_primary_subviewport.size = options.primary_size
	_primary_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	primary_container.add_child(_primary_subviewport)

	var marquee_container := SubViewportContainer.new()
	marquee_container.position = Vector2.ZERO
	marquee_container.size = options.marquee_size
	marquee_container.stretch = true
	add_child(marquee_container)

	_marquee_subviewport = SubViewport.new()
	_marquee_subviewport.size = options.marquee_size
	_marquee_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	marquee_container.add_child(_marquee_subviewport)
