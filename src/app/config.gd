## Reads deployment settings and persists app-owned user settings without logging values.
## Example: `Config.resolve_value("liftie_api", "user_agent")`.
class_name Config
extends RefCounted

# Generic runtime source for app settings, read from heavenly.cfg files only.
# Lookup order per value: exe directory first (cabinet: heavenly.cfg next
# to HEAVENLY.exe), then res:// (dev: repo root).
# Never log resolved values themselves.

const CONFIG_FILENAME := "heavenly.cfg"
const USER_SETTINGS_PATH := "user://leaderboard.cfg"


static func missing_required_values() -> PackedStringArray:
	var missing := PackedStringArray()
	if resolve_liftie_user_agent().is_empty():
		missing.append("liftie_api/user_agent")
	if resolve_leaderboard_api_base_url().is_empty():
		missing.append("leaderboard_api/base_url")
	return missing


static func resolve_liftie_user_agent() -> String:
	return resolve_value("liftie_api", "user_agent")


static func resolve_leaderboard_api_base_url() -> String:
	return resolve_value("leaderboard_api", "base_url")


static func resolve_value(section: String, key: String) -> String:
	# Cabinet deployment: file next to the exported exe. In the editor this
	# resolves to the editor binary dir and simply misses, falling through.
	var exe_dir := OS.get_executable_path().get_base_dir()
	if not exe_dir.is_empty():
		var exe_cfg := _read_from_config(exe_dir.path_join(CONFIG_FILENAME), section, key)
		if not exe_cfg.is_empty():
			return exe_cfg
	return _read_from_config("res://" + CONFIG_FILENAME, section, key)


static func _read_from_config(path: String, section: String, key: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	return str(cfg.get_value(section, key, "")).strip_edges()


static func resolve_installation_id() -> String:
	var settings := ConfigFile.new()
	if settings.load(USER_SETTINGS_PATH) == OK:
		var existing := str(settings.get_value("leaderboard", "installation_id", ""))
		if not existing.is_empty():
			return existing
	var generated := Id.generate_id()
	settings.set_value("leaderboard", "installation_id", generated)
	if settings.save(USER_SETTINGS_PATH) != OK:
		push_warning("Unable to persist leaderboard installation ID.")
	return generated
