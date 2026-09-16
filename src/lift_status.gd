class_name LiftStatusPanel
extends CenterContainer

const LIFT_URL := "https://liftie.info/api/resort/heavenly"
const LIFT_REFRESH_SECONDS := 60.0
const MAX_LIFTS_SHOWN := 10

const Config := preload("res://src/config.gd")

@export var accent_color: Color = Color("35a7ff")
@export var design_width: float = 1920.0
@export var compact: bool = false

var _http: HTTPRequest
var _timer: Timer
var _seconds_until_refresh := LIFT_REFRESH_SECONDS
var _user_agent: String = ""
var _warned_missing_user_agent := false
var _summary: Label
var _detail: Label
var _countdown: Label


func _ready() -> void:
	name = "LiftCenter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if compact:
		offset_top = 180.0
		offset_bottom = -45.0
	else:
		offset_top = 470.0
		offset_bottom = -140.0

	_build_ui()

	_user_agent = Config.resolve_liftie_user_agent()

	_http = HTTPRequest.new()
	_http.name = "LiftStatusRequest"
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_timer = Timer.new()
	_timer.name = "LiftRefreshTimer"
	_timer.wait_time = LIFT_REFRESH_SECONDS
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_on_refresh_timeout)

	request_status()


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.name = "LiftBox"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4 if compact else 10)
	add_child(box)

	var header := Label.new()
	header.text = "LIFT STATUS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", accent_color)
	header.add_theme_font_size_override("font_size", 22 if compact else 44)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	_summary = Label.new()
	_summary.text = "Loading lift status…"
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", Color("f5f7ff"))
	_summary.add_theme_font_size_override("font_size", 28 if compact else 40)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_summary)

	if compact:
		_detail = null
	else:
		_detail = Label.new()
		_detail.text = ""
		_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.custom_minimum_size = Vector2(minf(1100.0, design_width - 200.0), 0.0)
		_detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
		_detail.add_theme_font_size_override("font_size", 26)
		_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_detail)

	_countdown = Label.new()
	_countdown.text = "Refreshing in %ds" % int(LIFT_REFRESH_SECONDS)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_countdown.add_theme_font_size_override("font_size", 18 if compact else 24)
	_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_countdown)


func _process(delta: float) -> void:
	_seconds_until_refresh = maxf(0.0, _seconds_until_refresh - delta)
	_countdown.text = "Refreshing in %ds" % int(ceil(_seconds_until_refresh))


func request_status() -> void:
	# Re-resolve every time so a dropped-in heavenly.cfg / env change
	# recovers on the next refresh without a restart.
	_user_agent = Config.resolve_liftie_user_agent()
	if _user_agent.is_empty():
		if not _warned_missing_user_agent:
			_warned_missing_user_agent = true
			push_warning("Lift user agent is not configured; showing missing-config error (heavenly.cfg).")
		_set_missing_config_error()
		return
	_warned_missing_user_agent = false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var headers := PackedStringArray(["User-Agent: %s" % _user_agent])
	var error := _http.request(LIFT_URL, headers)
	if error != OK:
		push_warning("Lift status request failed to start: %s" % error_string(error))
		_set_error("Could not fetch Heavenly lift status.")


func refresh_now() -> void:
	_seconds_until_refresh = LIFT_REFRESH_SECONDS
	request_status()


func _on_refresh_timeout() -> void:
	_seconds_until_refresh = LIFT_REFRESH_SECONDS
	request_status()


func _on_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_seconds_until_refresh = LIFT_REFRESH_SECONDS
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Lift status request failed with result %d." % result)
		_set_error("Could not fetch Heavenly lift status.")
		return
	_parse_body(body.get_string_from_utf8())


func _parse_body(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_set_error("Could not fetch Heavenly lift status.")
		return
	var data: Dictionary = parsed
	var lifts: Dictionary = data.get("lifts", {})
	var stats: Dictionary = lifts.get("stats", {})
	var status_map: Dictionary = lifts.get("status", {})
	var open_count := int(stats.get("open", 0))
	var hold_count := int(stats.get("hold", 0))
	var scheduled_count := int(stats.get("scheduled", 0))
	var closed_count := int(stats.get("closed", 0))

	_summary.text = "Open %d  •  Hold %d  •  Scheduled %d  •  Closed %d" % [
		open_count, hold_count, scheduled_count, closed_count
	]

	if _detail == null:
		return

	if status_map.is_empty():
		_detail.text = "Live lift list unavailable right now."
		return

	var names: Array = status_map.keys()
	names.sort()
	var lines: PackedStringArray = []
	for lift_name in names:
		var lift_status := str(status_map[lift_name]).to_upper()
		lines.append("%s — %s" % [str(lift_name), lift_status])
		if lines.size() >= MAX_LIFTS_SHOWN:
			break
	if names.size() > lines.size():
		lines.append("+ %d more" % (names.size() - lines.size()))
	_detail.text = "\n".join(lines)


func _set_missing_config_error() -> void:
	_summary.text = "Lift status unavailable: missing user agent."
	if _detail != null:
		_detail.text = "Copy heavenly.cfg next to the app (see heavenly.cfg.example)."


func _set_error(message: String) -> void:
	_summary.text = message
	if _detail != null:
		_detail.text = ""
