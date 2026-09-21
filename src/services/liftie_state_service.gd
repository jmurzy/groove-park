## Polls liftie.info for Heavenly lift counts every minute and publishes a
## normalized `{status, open/hold/closed/total}` dict. Falls back to unknown offline.
class_name LiftieStateService
extends Node

signal state_changed(state: Dictionary)

const LIFTIE_URL := "https://liftie.info/api/resort/heavenly"
const LIFTIE_REFRESH_SECONDS := 60.0
const DEV_OPEN_LIFT_COUNT := 19
const DEV_HOLD_LIFT_COUNT := 2
const DEV_CLOSED_LIFT_COUNT := 8

const Config := preload("res://src/services/config.gd")

var state := {
	"status": "unknown",
	"open_count": 0,
	"hold_count": 0,
	"closed_count": 0,
	"total_count": 0,
}

var _http: HTTPRequest
var _refresh_timer: Timer


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = LIFTIE_REFRESH_SECONDS
	_refresh_timer.autostart = true
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(request_status)

	request_status()


func request_status() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var user_agent := Config.resolve_liftie_user_agent()
	if user_agent.is_empty():
		push_warning("Liftie user agent is not configured; using unknown lift state.")
		_publish_unknown()
		return
	var error := _http.request(LIFTIE_URL, PackedStringArray(["User-Agent: %s" % user_agent]))
	if error != OK:
		push_warning("Liftie status request failed to start: %s" % error_string(error))
		_publish_unknown()


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning(
			"Liftie status request failed with result %d and HTTP %d." % [result, response_code]
		)
		_publish_unknown()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Liftie status response was not a JSON object.")
		_publish_unknown()
		return
	var data: Dictionary = parsed
	var lifts: Dictionary = data.get("lifts", {})
	var stats: Dictionary = lifts.get("stats", {})
	var open_count := int(stats.get("open", 0))
	var hold_count := int(stats.get("hold", 0))
	var closed_count := int(stats.get("closed", 0))
	var scheduled_count := int(stats.get("scheduled", 0))
	var total_count := open_count + hold_count + closed_count + scheduled_count
	if OS.is_debug_build() and total_count == 0:
		# Liftie omits the lift inventory outside the operating season.
		open_count = DEV_OPEN_LIFT_COUNT
		hold_count = DEV_HOLD_LIFT_COUNT
		closed_count = DEV_CLOSED_LIFT_COUNT
		total_count = open_count + hold_count + closed_count
	var normalized_status := "unknown"
	if open_count > 0:
		normalized_status = "open"
	elif hold_count > 0:
		normalized_status = "hold"
	elif total_count > 0:
		normalized_status = "closed"
	state = {
		"status": normalized_status,
		"open_count": open_count,
		"hold_count": hold_count,
		"closed_count": closed_count,
		"total_count": total_count,
	}
	state_changed.emit(state)


func _publish_unknown() -> void:
	state = {
		"status": "unknown",
		"open_count": 0,
		"hold_count": 0,
		"closed_count": 0,
		"total_count": 0,
	}
	state_changed.emit(state)
