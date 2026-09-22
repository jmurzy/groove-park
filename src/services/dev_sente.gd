## Dev-only window overrides for single-display testing (sizes, forced marquee,
## diagnostics, terrain editor). Example: launch with `--sente` for 1080p + marquee windows.
##
## Lives under `src/services/` for CLI access but is purely a development helper.
## Window configuration is owned by `WindowManager`; this only parses overrides.
class_name DevSente
extends RefCounted


# Dev overrides for testing Sente resolutions on a single display.
# Usage:
#   --sente                    primary 1920x1080 + marquee 1920x360 dev windows
#   --primary-size=WIDTHxHEIGHT override primary window size (e.g. 1280x720)
#   --marquee-size=WIDTHxHEIGHT override marquee size, forces marquee visible
#   --marquee                  force marquee visible at 1920x360
#   --show-terrain             show the debug terrain overlay in debug builds
# Without overrides the cabinet behavior is unchanged (borderless fullscreen-cover).
static func parse_overrides(primary_design: Vector2i, marquee_design: Vector2i) -> Dictionary:
	var overrides := {
		"primary_size": Vector2i(-1, -1),
		"marquee_size": Vector2i(-1, -1),
		"force_marquee": false,
		"show_diagnostics": false,
		"show_terrain": false,
	}
	for arg in OS.get_cmdline_user_args():
		if arg == "--sente":
			overrides.primary_size = primary_design
			overrides.marquee_size = marquee_design
			overrides.force_marquee = true
		elif arg.begins_with("--primary-size="):
			overrides.primary_size = parse_size_arg(arg.get_slice("=", 1))
		elif arg.begins_with("--marquee-size="):
			overrides.marquee_size = parse_size_arg(arg.get_slice("=", 1))
			overrides.force_marquee = true
		elif arg == "--marquee":
			overrides.force_marquee = true
		elif arg == "--diagnostics":
			overrides.show_diagnostics = true
		elif arg == "--show-terrain" and OS.is_debug_build():
			overrides.show_terrain = true
	if overrides.force_marquee and overrides.marquee_size.x < 0:
		overrides.marquee_size = marquee_design
	if overrides.primary_size.x > 0 or overrides.force_marquee:
		print(
			(
				"HEAVENLY dev windows: primary %s marquee %s"
				% [
					size_to_string(overrides.primary_size),
					size_to_string(overrides.marquee_size),
				]
			)
		)
	return overrides


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
