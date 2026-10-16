extends SceneTree

const FORBIDDEN_PATHS := [
	"res://game.cfg",
	"res://game.cfg.example",
	"res://export_presets.cfg",
	"res://release_config.tpl",
	"res://src/services/leaderboard/leaderboard_repository_fake.gdc",
]
const FORBIDDEN_PREFIXES := [
	"res://tests/",
	"res://workers/",
	"res://build/",
	"res://tools/",
	"res://src/game/park/park_course_editor.",
	"res://src/game/park/park_course_path.",
]
const SECRET_PATTERN := (
	"(?i)(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|"
	+ "(?:ghp_|gho_|ghu_|ghs_|github_pat_)[A-Za-z0-9_]{20,}|"
	+ "sk_(?:live|test)_[A-Za-z0-9]{16,}|"
	+ "(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\\s*[=:]\\s*"
	+ "[\\\"']?[A-Za-z0-9_./+-]{16,}|"
	+ "https?://(?:localhost|127\\.0\\.0\\.1|10\\.[0-9.]+|"
	+ "172\\.(?:1[6-9]|2[0-9]|3[01])\\.[0-9.]+|192\\.168\\.[0-9.]+))"
)


func _initialize() -> void:
	if not FileAccess.file_exists("res://project.binary"):
		push_error("PCK not mounted (missing project.binary)")
		quit(1)
		return
	var secrets := RegEx.new()
	if secrets.compile(SECRET_PATTERN) != OK:
		push_error("PCK audit pattern is invalid")
		quit(1)
		return
	var violations: Array[String] = []
	var count := 0
	var directories: Array[String] = ["res://"]
	while not directories.is_empty():
		var directory: String = directories.pop_back()
		for name in DirAccess.get_directories_at(directory):
			directories.append(directory.path_join(name))
		for name in DirAccess.get_files_at(directory):
			var path := directory.path_join(name)
			count += 1
			if _is_forbidden(path):
				violations.append("Unexpected file: " + path)
			var bytes := FileAccess.get_file_as_bytes(path)
			if FileAccess.get_open_error() != OK:
				violations.append("Unreadable file: " + path)
			elif secrets.search(bytes.get_string_from_ascii()) != null:
				violations.append("Credential or private endpoint marker: " + path)
	for violation in violations:
		printerr(violation)
	print("Audited %d PCK files; %d finding(s)." % [count, violations.size()])
	quit(1 if not violations.is_empty() else 0)


func _is_forbidden(path: String) -> bool:
	if path in FORBIDDEN_PATHS:
		return true
	for i in FORBIDDEN_PREFIXES.size():
		var prefix: String = FORBIDDEN_PREFIXES[i]
		if path.begins_with(prefix):
			return true
	var name := path.get_file().to_lower()
	return (
		name.begins_with(".env")
		or name.ends_with(".pem")
		or name.ends_with(".key")
		or name.ends_with(".p12")
		or name.ends_with(".pfx")
		or name.ends_with(".keystore")
		or name.ends_with(".jks")
	)
