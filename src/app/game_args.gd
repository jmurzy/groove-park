## Parses startup arguments and owns the cabinet display design dimensions.
## Supports dev window overrides and the debug-only terrain editor.
##
## Window configuration is owned by `WindowCoordinator`; this only parses arguments.
class_name GameArgs
extends RefCounted


## Typed startup options parsed from command-line arguments.
class GameOptions:
	extends RefCounted

	var primary_size := Vector2i(1920, 1080)
	var marquee_size := Vector2i(1920, 360)
	var composite_size := Vector2i(primary_size.x, primary_size.y + marquee_size.y)
	var designer_mode := false


# Window overrides for testing Sente resolutions.
# Usage:
#   --primary-size=WIDTHxHEIGHT 	override primary window size (e.g. 1280x720)
#   --marquee-size=WIDTHxHEIGHT 	override marquee window size
#   --designer-mode            		show the debug terrain overlay in debug builds
# Without window overrides, cabinet behavior is unchanged (borderless fullscreen-cover).
static func parse_options() -> GameOptions:
	var options := GameOptions.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--primary-size="):
			options.primary_size = parse_size_arg(arg.get_slice("=", 1))
		elif arg.begins_with("--marquee-size="):
			options.marquee_size = parse_size_arg(arg.get_slice("=", 1))
		elif arg == "--designer-mode" and OS.is_debug_build():
			options.designer_mode = true

	print("User data: %s" % OS.get_user_data_dir())
	_log_connected_controllers()
	_log_displays(DisplayServer.get_screen_count(), options)
	return options


static func _log_displays(screen_count: int, options: GameOptions) -> void:
	print("Detected %d screen(s)." % screen_count)
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
	print(
		(
			"Game windows: primary %s, marquee %s"
			% [
				size_to_string(options.primary_size),
				size_to_string(options.marquee_size),
			]
		)
	)


static func _log_connected_controllers() -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		print("No controller detected at startup.")
		return
	for device_id in joypads:
		print("Controller %d: %s" % [device_id, Input.get_joy_name(device_id)])


static func parse_size_arg(text: String) -> Vector2i:
	var parts := text.to_lower().split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("Ignoring invalid size '%s', expected WIDTHxHEIGHT." % text)
		return Vector2i(-1, -1)
	var size := Vector2i(int(parts[0]), int(parts[1]))
	if size.x <= 0 or size.y <= 0:
		push_warning("Ignoring invalid size '%s', expected WIDTHxHEIGHT." % text)
		return Vector2i(-1, -1)
	return size


static func size_to_string(size: Vector2i) -> String:
	if size.x < 0:
		return "cabinet"
	return "%dx%d" % [size.x, size.y]
