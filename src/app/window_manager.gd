## Configures cabinet-cover and resizable development windows at a design resolution.
class_name WindowManager
extends RefCounted


static func make_fullscreen_window(
	window: Window, screen_index: int, window_size: Vector2i, window_title: String
) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	_make_base_window(window, screen_index, window_size, window_title)
	window.borderless = true
	window.unresizable = true
	window.size = screen_size
	window.position = screen_position


static func make_dev_window(
	window: Window, screen_index: int, window_size: Vector2i, window_title: String
) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)

	_make_base_window(window, screen_index, window_size, window_title)
	window.borderless = false
	window.unresizable = false
	window.size = window_size
	window.position = _centered_window_position(screen_position, screen_size, window_size)


# The browser owns the actual window. Keep the composite canvas letterboxed while it resizes.
static func make_composite_window(
	window: Window, window_size: Vector2i, window_title: String
) -> void:
	_make_base_window(window, 0, window_size, window_title)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


static func _make_base_window(
	window: Window, screen_index: int, window_size: Vector2i, window_title: String
) -> void:
	window.title = window_title
	window.mode = Window.MODE_WINDOWED
	window.current_screen = screen_index
	window.content_scale_size = window_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


static func _centered_window_position(
	screen_position: Vector2i, screen_size: Vector2i, window_size: Vector2i
) -> Vector2i:
	var centered := screen_position + (screen_size - window_size) / 2
	var max_x := maxi(screen_position.x, screen_position.x + screen_size.x - window_size.x)
	var max_y := maxi(screen_position.y, screen_position.y + screen_size.y - window_size.y)
	return Vector2i(
		clampi(centered.x, screen_position.x, max_x), clampi(centered.y, screen_position.y, max_y)
	)
