## Self-contained scrolling lift-status ticker for the marquee.
class_name MarqueeTicker
extends Control

const SPEED := 85.0
const TRACK_GAP := 72.0

var _elapsed := 0.0
var _ticker_width := 1.0
var _tracks: Array[HBoxContainer] = []
var _lifts: Array[LiftState] = []


func _status_text(status: LiftState.Status) -> String:
	match status:
		LiftState.Status.OPEN:
			return "OPEN"
		LiftState.Status.HOLD:
			return "WIND HOLD"
		LiftState.Status.CLOSED:
			return "CLOSED"
		LiftState.Status.SCHEDULED:
			return "SCHEDULED"
		_:
			return "UNKNOWN"


func _status_text_color(status: LiftState.Status) -> Color:
	match status:
		LiftState.Status.OPEN:
			return Color("bdf77d")
		LiftState.Status.HOLD:
			return Color("ffd166")
		LiftState.Status.CLOSED:
			return Color("d7e0e8")
		LiftState.Status.SCHEDULED:
			return Color("92c5ff")
		_:
			return Color("ffffff")


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_tracks()


func set_mountain_state(mountain_state: MountainState) -> void:
	_lifts = mountain_state.lifts
	if is_node_ready():
		# Preserve scrolling tracks so live updates do not visibly flash the ticker.
		_update_tracks()


func _rebuild_tracks() -> void:
	for child in get_children():
		child.queue_free()
	_tracks.clear()
	_ticker_width = 1.0
	for track_index in 2:
		var track := HBoxContainer.new()
		track.name = "TickerTrack%d" % (track_index + 1)
		track.add_theme_constant_override("separation", TRACK_GAP)
		add_child(track)
		_tracks.append(track)
	_update_tracks()


func _update_tracks() -> void:
	for track in _tracks:
		# Reconcile only changed item counts; existing labels update in place below.
		while track.get_child_count() > _lifts.size():
			var item := track.get_child(-1)
			track.remove_child(item)
			item.queue_free()
		while track.get_child_count() < _lifts.size():
			track.add_child(_build_lift_item())
		for index in _lifts.size():
			_apply_lift_item(track.get_child(index), _lifts[index])
	call_deferred("_finish_layout")


func _process(delta: float) -> void:
	_elapsed += delta
	if _tracks.size() != 2 or _ticker_width <= 1.0:
		return
	var ticker_x := -fposmod(_elapsed * SPEED, _ticker_width)
	_tracks[0].position.x = ticker_x
	_tracks[1].position.x = ticker_x + _ticker_width


func _build_lift_item() -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 18)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(620, 116)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	name_label.add_theme_color_override("font_color", Color("f5fbff"))
	name_label.add_theme_color_override("font_outline_color", Color("07182d"))
	name_label.add_theme_constant_override("outline_size", 8)
	name_label.add_theme_font_size_override("font_size", 52)
	_add_pixel_shadow(name_label, 6)
	item.add_child(name_label)
	var leader_label := Label.new()
	leader_label.text = "...."
	leader_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	leader_label.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	leader_label.add_theme_color_override("font_color", Color("ffd166"))
	leader_label.add_theme_color_override("font_outline_color", Color("07182d"))
	leader_label.add_theme_constant_override("outline_size", 5)
	leader_label.add_theme_font_size_override("font_size", 24)
	item.add_child(leader_label)
	var status_label := Label.new()
	status_label.custom_minimum_size = Vector2(0, 70)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	status_label.add_theme_font_size_override("font_size", 28)
	item.add_child(status_label)
	return item


func _apply_lift_item(item: Node, lift: LiftState) -> void:
	var name_label := item.get_child(0) as Label
	var status_label := item.get_child(2) as Label
	var status := _status_text(lift.status)
	name_label.text = lift.display_name.to_upper()
	status_label.text = "  %s  " % status
	status_label.add_theme_color_override("font_color", _status_text_color(lift.status))
	status_label.add_theme_stylebox_override("normal", _status_style(lift.status))


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


func _status_style(status: LiftState.Status) -> StyleBoxFlat:
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
