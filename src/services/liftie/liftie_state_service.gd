## Liftie API service for Heavenly lift data.
class_name LiftieStateService
extends Node

const RESORT_PATH := "/api/liftie/resort/sierra"

signal state_received(state: LiftieResortResponse)

var _http: HTTPRequest
var state: LiftieResortResponse


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func request_lift_data() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var endpoint := Config.resolve_game_api_base_url().trim_suffix("/") + RESORT_PATH
	var installation_id := Config.resolve_installation_id()
	var headers := PackedStringArray(["Accept: application/json", "X-Installation-Id: %s" % installation_id])
	var error := _http.request(endpoint, headers)
	if error != OK:
		push_warning("Liftie status request failed to start: %s" % error_string(error))


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning(
			"Liftie status request failed with result %d and HTTP %d." % [result, response_code]
		)
		return
	var response := _parse_response(body)
	if response == null:
		push_warning("Liftie status request returned malformed JSON.")
		return
	state = response
	state_received.emit(state)


func _parse_response(body: PackedByteArray) -> LiftieResortResponse:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var payload: Dictionary = json.data
	var id: Variant = payload.get("id")
	var is_open: Variant = payload.get("open")
	var coordinates: Variant = payload.get("ll")
	var timestamp_data: Variant = payload.get("timestamp")
	var lifts_data: Variant = payload.get("lifts")
	if (
		typeof(id) != TYPE_STRING
		or typeof(is_open) != TYPE_BOOL
		or typeof(coordinates) != TYPE_ARRAY
		or typeof(timestamp_data) != TYPE_DICTIONARY
		or typeof(lifts_data) != TYPE_DICTIONARY
	):
		return null
	var coordinate_values := Array(coordinates)
	if (
		coordinate_values.size() != 2
		or not _is_finite_number(coordinate_values[0])
		or not _is_finite_number(coordinate_values[1])
	):
		return null

	var timestamp := _parse_timestamp(Dictionary(timestamp_data))
	var lifts := _parse_lifts(Dictionary(lifts_data))
	if timestamp == null or lifts == null:
		return null

	var response := LiftieResortResponse.new()
	response.id = String(id)
	response.open = bool(is_open)
	response.ll = Vector2(float(coordinate_values[0]), float(coordinate_values[1]))
	response.timestamp = timestamp
	response.lifts = lifts
	return response


func _parse_timestamp(data: Dictionary) -> LiftieResortResponse.Timestamp:
	var lifts: Variant = data.get("lifts")
	var opening: Variant = data.get("opening")
	if not _is_non_negative_integer(lifts) or not _is_non_negative_integer(opening):
		return null
	var timestamp := LiftieResortResponse.Timestamp.new()
	timestamp.lifts = int(lifts)
	timestamp.opening = int(opening)
	return timestamp


func _parse_lifts(data: Dictionary) -> LiftieResortResponse.Lifts:
	var status_data: Variant = data.get("status")
	var stats_data: Variant = data.get("stats")
	if typeof(status_data) != TYPE_DICTIONARY or typeof(stats_data) != TYPE_DICTIONARY:
		return null
	var status_dictionary := Dictionary(status_data)
	var statuses: Dictionary[String, String] = {}
	for lift_id: Variant in status_dictionary:
		var lift_status: Variant = status_dictionary[lift_id]
		if typeof(lift_id) != TYPE_STRING or not _is_lift_status(lift_status):
			return null
		statuses[String(lift_id)] = String(lift_status)
	var stats := _parse_stats(Dictionary(stats_data))
	if stats == null:
		return null
	var lifts := LiftieResortResponse.Lifts.new()
	lifts.status = statuses
	lifts.stats = stats
	return lifts


func _parse_stats(data: Dictionary) -> LiftieResortResponse.LiftStats:
	var open: Variant = data.get("open")
	var hold: Variant = data.get("hold")
	var scheduled: Variant = data.get("scheduled")
	var closed: Variant = data.get("closed")
	var percentage_data: Variant = data.get("percentage")
	if (
		not _is_non_negative_integer(open)
		or not _is_non_negative_integer(hold)
		or not _is_non_negative_integer(scheduled)
		or not _is_non_negative_integer(closed)
		or typeof(percentage_data) != TYPE_DICTIONARY
	):
		return null
	var percentage := _parse_percentage(Dictionary(percentage_data))
	if percentage == null:
		return null
	var stats := LiftieResortResponse.LiftStats.new()
	stats.open = int(open)
	stats.hold = int(hold)
	stats.scheduled = int(scheduled)
	stats.closed = int(closed)
	stats.percentage = percentage
	return stats


func _parse_percentage(data: Dictionary) -> LiftieResortResponse.LiftPercentage:
	var open: Variant = data.get("open")
	var hold: Variant = data.get("hold")
	var scheduled: Variant = data.get("scheduled")
	var closed: Variant = data.get("closed")
	if (
		not _is_finite_number(open)
		or not _is_finite_number(hold)
		or not _is_finite_number(scheduled)
		or not _is_finite_number(closed)
	):
		return null
	var percentage := LiftieResortResponse.LiftPercentage.new()
	percentage.open = float(open)
	percentage.hold = float(hold)
	percentage.scheduled = float(scheduled)
	percentage.closed = float(closed)
	return percentage


func _is_non_negative_integer(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0 and float(value) == floor(float(value))


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _is_lift_status(value: Variant) -> bool:
	return value == "open" or value == "hold" or value == "scheduled" or value == "closed"
