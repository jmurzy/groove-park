class_name MarqueeScreen
extends Control

const DESIGN_SIZE := Vector2(1920, 360)
const MARQUEE_BACKGROUND := preload("res://artwork/marquee/marquee_bg.png")
const SnowfallLayerScene := preload("res://src/presentation/effects/snowfall_layer.gd")
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SNOWBOARDER_SHEET := preload("res://artwork/marquee/snowboarder_sprite.png")
const MARQUEE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LiveIndicatorScene := preload("res://src/presentation/marquee/live_indicator.gd")
const TICKER_SPEED := 85.0
const BORDER_WIDTH := 14.0
const SKIER_FRAME_COUNT := 8
const SKIER_FRAME_RATE := 10.0
const SKIER_SPEED := 150.0
const SKIER_SCALE := 0.34
const SKIER_OFFSCREEN_MARGIN := 160.0
const SNOWBOARDER_LEAD_DISTANCE := 280.0
const SEPARATOR_COLOR_STEP_DURATION := 0.4
const SEPARATOR_COLORS: Array[Color] = [
	Color("ffd166"),
	Color("ff8c42"),
	Color("ff5d8f"),
	Color("c77dff"),
	Color("5c7cfa"),
	Color("5ce1e6"),
	Color("80ed99"),
	Color("ff4d4d"),
]
const LIFTS: Array[Dictionary] = [
	{"name": "HEAVENLY GONDOLA", "status": "OPEN"},
	{"name": "GUNBARREL EXPRESS", "status": "HOLD"},
	{"name": "POWDERBOWL EXPRESS", "status": "OPEN"},
	{"name": "SKY EXPRESS", "status": "WIND HOLD"},
	{"name": "DIPPER EXPRESS", "status": "CLOSED"},
]

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service: LiftieStateService

var _elapsed := 0.0
var _ticker_width := 1.0
var _ticker_tracks: Array[HBoxContainer] = []
var _animated_separators: Array[Label] = []
var _skier: AnimatedSprite2D
var _snowboarder: AnimatedSprite2D


func _ready() -> void:
	name = "MarqueeView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(SnowfallLayerScene.create(DESIGN_SIZE, 28))
	_build_header()
	_build_ticker()
	_build_skier()
	_build_footer()
	if show_diagnostics:
		add_child(_build_diagnostics())
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_skier()
	_update_separator_colors()
	if _ticker_tracks.size() != 2 or _ticker_width <= 1.0:
		return
	var ticker_x := -fposmod(_elapsed * TICKER_SPEED, _ticker_width)
	_ticker_tracks[0].position.x = ticker_x
	_ticker_tracks[1].position.x = ticker_x + _ticker_width


func _draw() -> void:
	draw_texture_rect(MARQUEE_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	var cell_size := 8
	for y in range(142, 264, cell_size):
		for x in range(int(BORDER_WIDTH), int(DESIGN_SIZE.x - BORDER_WIDTH), cell_size):
			if int(x / cell_size + y / cell_size) % 2 == 0:
				var cell_width: int = min(cell_size, int(DESIGN_SIZE.x - BORDER_WIDTH) - x)
				draw_rect(Rect2(x, y, cell_width, min(cell_size, 264 - y)), Color("02060cff"))


func _build_skier() -> void:
	_skier = _build_rider("Skier", SKIER_SHEET)
	add_child(_skier)
	_skier.play()

	_snowboarder = _build_rider("Snowboarder", SNOWBOARDER_SHEET)
	add_child(_snowboarder)
	_snowboarder.play()


func _build_rider(rider_name: String, sprite_sheet: Texture2D) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("ski")
	frames.set_animation_loop("ski", true)
	frames.set_animation_speed("ski", SKIER_FRAME_RATE)
	var sheet_width := sprite_sheet.get_width()
	var sheet_height := sprite_sheet.get_height()
	for frame_index in SKIER_FRAME_COUNT:
		var frame_start := roundi(float(frame_index) * sheet_width / SKIER_FRAME_COUNT)
		var frame_end := roundi(float(frame_index + 1) * sheet_width / SKIER_FRAME_COUNT)
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2(frame_start, 0, frame_end - frame_start, sheet_height)
		frames.add_frame("ski", frame)

	var rider := AnimatedSprite2D.new()
	rider.name = rider_name
	rider.sprite_frames = frames
	rider.animation = "ski"
	rider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rider.scale = Vector2.ONE * SKIER_SCALE
	rider.position.y = 131
	return rider


func _update_skier() -> void:
	if not _skier:
		return
	var travel_width := DESIGN_SIZE.x + SKIER_OFFSCREEN_MARGIN * 2.0
	_skier.position.x = -SKIER_OFFSCREEN_MARGIN + fposmod(_elapsed * SKIER_SPEED, travel_width)
	_snowboarder.position.x = (
		-SKIER_OFFSCREEN_MARGIN
		+ fposmod(_elapsed * SKIER_SPEED + SNOWBOARDER_LEAD_DISTANCE, travel_width)
	)


func _build_header() -> void:
	var header := HBoxContainer.new()
	header.position = Vector2(0, 20)
	header.size = Vector2(DESIGN_SIZE.x, 52)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 28)
	add_child(header)

	var summary := _build_divided_line(
		["14 OPEN", "2 HOLD", "1 CLOSED"], 34, Color("ffffff"), 52, 6, true
	)
	header.add_child(LiveIndicatorScene.new())
	header.add_child(summary)


func _build_ticker() -> void:
	var ticker_window := Control.new()
	ticker_window.position = Vector2(BORDER_WIDTH, 142)
	ticker_window.size = Vector2(DESIGN_SIZE.x - BORDER_WIDTH * 2.0, 132)
	ticker_window.clip_contents = true
	ticker_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticker_window)

	for track_index in 2:
		var track := HBoxContainer.new()
		track.name = "TickerTrack%d" % (track_index + 1)
		track.add_theme_constant_override("separation", 72)
		for lift in LIFTS:
			track.add_child(_build_lift_item(lift.name, lift.status))
		ticker_window.add_child(track)
		_ticker_tracks.append(track)
	call_deferred("_finish_ticker_layout")


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


func _finish_ticker_layout() -> void:
	if _ticker_tracks.size() != 2:
		return
	for track in _ticker_tracks:
		track.reset_size()
	_ticker_width = _ticker_tracks[0].size.x + 72.0
	_ticker_tracks[0].position = Vector2(0, 5)
	_ticker_tracks[1].position = Vector2(_ticker_width, 5)


func _build_footer() -> void:
	var footer := _build_divided_line(
		["CONDITIONS CAN CHANGE", "OBSERVE ALL POSTED SIGNAGE"], 26, Color("d4efff"), 44, 4, true
	)
	footer.position = Vector2(58, 284)
	footer.size = Vector2(1804, 44)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(footer)


func _build_divided_line(
	parts: Array,
	font_size: int,
	text_color: Color,
	line_height: int,
	separator_offset: int,
	animate_separators: bool = false
) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = line_height
	line.add_theme_constant_override("separation", 22)
	for index in parts.size():
		if index > 0:
			var separator_container := CenterContainer.new()
			separator_container.custom_minimum_size.y = line_height
			separator_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var separator_padding := MarginContainer.new()
			separator_padding.add_theme_constant_override("margin_bottom", separator_offset * 2)
			var separator := Label.new()
			separator.text = "◆"
			separator.add_theme_color_override("font_color", Color("ffd166"))
			separator.add_theme_color_override("font_outline_color", Color("07182d"))
			separator.add_theme_constant_override("outline_size", 7)
			separator.add_theme_font_size_override("font_size", roundi(font_size * 1.5))
			_add_pixel_shadow(separator, 4)
			if animate_separators:
				_animated_separators.append(separator)
			separator_padding.add_child(separator)
			separator_container.add_child(separator_padding)
			line.add_child(separator_container)

		var label_container := CenterContainer.new()
		label_container.custom_minimum_size.y = line_height
		label_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = parts[index]
		label.add_theme_color_override("font_color", text_color)
		label.add_theme_color_override("font_outline_color", Color("07182d"))
		label.add_theme_constant_override("outline_size", 7)
		label.add_theme_font_size_override("font_size", font_size)
		_add_pixel_shadow(label, 4)
		label_container.add_child(label)
		line.add_child(label_container)
	return line


func _update_separator_colors() -> void:
	if _animated_separators.is_empty():
		return
	var color_step := _elapsed / SEPARATOR_COLOR_STEP_DURATION
	var step_index := floori(color_step)
	var blend := smoothstep(0.0, 1.0, color_step - step_index)

	for index in _animated_separators.size():
		var current_index := posmod(step_index - index, SEPARATOR_COLORS.size())
		var next_index := posmod(step_index + 1 - index, SEPARATOR_COLORS.size())
		var current_color: Color = SEPARATOR_COLORS[current_index]
		var next_color: Color = SEPARATOR_COLORS[next_index]
		var color := current_color.lerp(next_color, blend)
		_animated_separators[index].add_theme_color_override("font_color", color)


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


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  /  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(1510, 326)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 14)
	return diagnostics
