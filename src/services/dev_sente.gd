## Dev-only window overrides for single-display testing (sizes, forced marquee,
## diagnostics, terrain editor). Example: launch with `--sente` for 1080p + marquee windows.
##
## Lives under `src/services/` for CLI access but is purely a development helper.
## Window configuration is owned by `WindowManager`; this only parses options.
class_name DevSente
extends RefCounted


# Dev overrides for testing Sente resolutions on a single display.
# Usage:
#   --sente                    primary 1920x1080 + marquee 1920x360 dev windows
#   --primary-size=WIDTHxHEIGHT override primary window size (e.g. 1280x720)
#   --marquee-size=WIDTHxHEIGHT override marquee size, forces marquee visible
#   --marquee                  force marquee visible at 1920x360
#   --designer-mode            show the debug terrain overlay in debug builds
# Without dev options the cabinet behavior is unchanged (borderless fullscreen-cover).
static func parse_options(primary_design: Vector2i, marquee_design: Vector2i) -> DevOptions:
	var options := DevOptions.new()
	for arg in OS.get_cmdline_user_args():
		if arg == "--sente":
			options.primary_size = primary_design
			options.marquee_size = marquee_design
			options.force_marquee = true
		elif arg.begins_with("--primary-size="):
			options.primary_size = parse_size_arg(arg.get_slice("=", 1))
		elif arg.begins_with("--marquee-size="):
			options.marquee_size = parse_size_arg(arg.get_slice("=", 1))
			options.force_marquee = true
		elif arg == "--marquee":
			options.force_marquee = true
		elif arg == "--diagnostics":
			options.show_diagnostics = true
		elif arg == "--designer-mode" and OS.is_debug_build():
			options.designer_mode = true
	if options.force_marquee and options.marquee_size.x < 0:
		options.marquee_size = marquee_design
	if options.primary_size.x > 0 or options.force_marquee:
		print(
			(
				"HEAVENLY dev windows: primary %s marquee %s"
				% [
					size_to_string(options.primary_size),
					size_to_string(options.marquee_size),
				]
			)
		)
	return options


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
