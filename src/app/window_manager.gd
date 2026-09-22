## Configures cabinet-cover and resizable development windows at a design resolution.
class_name WindowManager
extends RefCounted


static func configure_cabinet_window(
	window: Window, screen_index: int, design_size: Vector2i, window_title: String
) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	_configure_base(window, screen_index, design_size, window_title)
	window.borderless = true
	window.unresizable = true
	window.position = screen_position
	window.size = screen_size


static func configure_dev_window(
	window: Window,
	screen_index: int,
	design_size: Vector2i,
	window_title: String,
	window_size: Vector2i,
	offset: Vector2i
) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	_configure_base(window, screen_index, design_size, window_title)
	window.borderless = false
	window.unresizable = false
	window.size = window_size
	var centered := screen_position + (screen_size - window_size) / 2 + offset
	centered.x = maxf(float(screen_position.x), centered.x)
	centered.y = maxf(float(screen_position.y), centered.y)
	window.position = centered


static func _configure_base(
	window: Window, screen_index: int, design_size: Vector2i, window_title: String
) -> void:
	window.title = window_title
	window.mode = Window.MODE_WINDOWED
	window.current_screen = screen_index
	window.content_scale_size = design_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
