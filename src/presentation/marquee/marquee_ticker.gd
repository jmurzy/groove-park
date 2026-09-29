## Self-contained scrolling lift-status ticker for the marquee.
class_name MarqueeTicker
extends Control

const MARQUEE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPEED := 85.0
const TRACK_GAP := 72.0

const LIFTS: Array[Dictionary] = [
	{"name": "HEAVENLY GONDOLA", "status": "OPEN"},
	{"name": "GUNBARREL EXPRESS", "status": "HOLD"},
	{"name": "POWDERBOWL EXPRESS", "status": "OPEN"},
	{"name": "SKY EXPRESS", "status": "WIND HOLD"},
	{"name": "DIPPER EXPRESS", "status": "CLOSED"},
]

var _elapsed := 0.0
var _ticker_width := 1.0
var _tracks: Array[HBoxContainer] = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for track_index in 2:
		var track := HBoxContainer.new()
		track.name = "TickerTrack%d" % (track_index + 1)
		track.add_theme_constant_override("separation", TRACK_GAP)
		for lift in LIFTS:
			track.add_child(_build_lift_item(lift.name, lift.status))
		add_child(track)
		_tracks.append(track)
	call_deferred("_finish_layout")


func _process(delta: float) -> void:
	_elapsed += delta
	if _tracks.size() != 2 or _ticker_width <= 1.0:
		return
	var ticker_x := -fposmod(_elapsed * SPEED, _ticker_width)
	_tracks[0].position.x = ticker_x
	_tracks[1].position.x = ticker_x + _ticker_width


func _build_lift_item(lift_name: String, status: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 18)
	var name_label := Label.new()
	name_label.text = lift_name
	name_label.custom_minimum_size = Vector2(620, 116)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MARQUEE_FONT)
	name_label.add_theme_color_override("font_color", Color("f5fbff"))
	name_label.add_theme_color_override("font_outline_color", Color("07182d"))
	name_label.add_theme_constant_override("outline_size", 8)
	name_label.add_theme_font_size_override("font_size", 52)
	_add_pixel_shadow(name_label, 6)
	item.add_child(name_label)
	var leader_label := Label.new()
	leader_label.text = "...."
	leader_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	leader_label.add_theme_font_override("font", MARQUEE_FONT)
	leader_label.add_theme_color_override("font_color", Color("ffd166"))
	leader_label.add_theme_color_override("font_outline_color", Color("07182d"))
	leader_label.add_theme_constant_override("outline_size", 5)
	leader_label.add_theme_font_size_override("font_size", 24)
	item.add_child(leader_label)
	var status_label := Label.new()
	status_label.text = "  %s  " % status
	status_label.custom_minimum_size = Vector2(0, 70)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", MARQUEE_FONT)
	status_label.add_theme_color_override("font_color", _status_text_color(status))
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_stylebox_override("normal", _status_style(status))
	item.add_child(status_label)
	return item


func _finish_layout() -> void:
	if _tracks.size() != 2:
		return
	for track in _tracks:
		track.reset_size()
	_ticker_width = _tracks[0].size.x + TRACK_GAP
	_tracks[0].position = Vector2(0, 5)
	_tracks[1].position = Vector2(_ticker_width, 5)


func _add_pixel_shadow(label: Label, offset: int) -> void:
	label.add_theme_color_override("font_shadow_color", Color("02060fe6"))
	label.add_theme_constant_override("shadow_offset_x", offset)
	label.add_theme_constant_override("shadow_offset_y", offset)
	label.add_theme_constant_override("shadow_outline_size", 2)


func _status_style(status: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("05070af0")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = _status_text_color(status)
	style.shadow_color = Color("02060fcc")
	style.shadow_size = 5
	style.shadow_offset = Vector2(5, 5)
	return style


func _status_text_color(status: String) -> Color:
	match status:
		"OPEN":
			return Color("bdf77d")
		"HOLD", "WIND HOLD":
			return Color("ffd166")
		"CLOSED":
			return Color("d7e0e8")
		_:
			return Color("ffffff")
