## Wide 1920x360 cabinet topper: lift ticker, animated riders, logomark, and
## snowfall. Purely decorative; ignores mouse.
class_name MarqueeScreen
extends Control

const DESIGN_SIZE := Vector2(1920, 360)
const MARQUEE_BACKGROUND := preload("res://artwork/marquee/marquee_bg.png")
const SnowfallLayerScene := preload("res://src/presentation/effects/snowfall_layer.gd")
const MarqueeTickerScene := preload("res://src/presentation/marquee/marquee_ticker.gd")
const MarqueeRiderLoopScene := preload("res://src/presentation/marquee/marquee_rider_loop.gd")
const HeavenlyLogomarkScene := preload("res://src/presentation/features/heavenly_logomark.gd")
const LiveIndicatorScene := preload("res://src/presentation/marquee/live_indicator.gd")
const BORDER_WIDTH := 14.0
const SNOW_SAFE_INSET := 40.0
const LOGOMARK_SCALE := 0.15
const LOGOMARK_POSITION := Vector2(374.0, 308.0)
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
var _elapsed := 0.0
var _animated_separators: Array[Label] = []
var _logomark: AnimatedSprite2D
var _ticker: MarqueeTicker
var _session_phase := RoundState.SessionPhase.ATTRACT
var _round_state: RoundState
var _leaderboard: Leaderboard
var _mountain_state: MountainState
var _lift_summary_labels: Array[Label] = []


## Accepts gameplay state without making the marquee responsible for game flow.
func set_session_context(phase: int, round_state: RoundState, leaderboard: Leaderboard) -> void:
	_session_phase = phase
	_round_state = round_state
	_leaderboard = leaderboard


func set_mountain_state(mountain_state: MountainState) -> void:
	_mountain_state = mountain_state
	_update_lift_summary()
	if _ticker:
		_ticker.set_mountain_state(mountain_state)


func _ready() -> void:
	name = "MarqueeView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_header()
	_build_ticker()
	add_child(MarqueeRiderLoopScene.new())
	_build_logomark()
	# Keep snowfall behind the footer notice so its text stays readable.
	add_child(SnowfallLayerScene.create(DESIGN_SIZE, 28, SNOW_SAFE_INSET))
	_build_footer()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_separator_colors()


func _draw() -> void:
	draw_texture_rect(MARQUEE_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	var cell_size := 8
	for y in range(142, 264, cell_size):
		for x in range(int(BORDER_WIDTH), int(DESIGN_SIZE.x - BORDER_WIDTH), cell_size):
			if int(x / cell_size + y / cell_size) % 2 == 0:
				var cell_width: int = min(cell_size, int(DESIGN_SIZE.x - BORDER_WIDTH) - x)
				draw_rect(Rect2(x, y, cell_width, min(cell_size, 264 - y)), Color("02060cff"))


func _build_logomark() -> void:
	_logomark = HeavenlyLogomarkScene.create(LOGOMARK_SCALE)
	_logomark.position = LOGOMARK_POSITION
	add_child(_logomark)


func _build_header() -> void:
	var header := HBoxContainer.new()
	header.position = Vector2(0, 20)
	header.size = Vector2(DESIGN_SIZE.x, 52)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 28)
	add_child(header)

	var summary := _build_divided_line(
		["0 OPEN", "0 HOLD", "0 SCHEDULED", "0 CLOSED"],
		32,
		Color("ffffff"),
		52,
		6,
		true,
		_lift_summary_labels
	)
	header.add_child(LiveIndicatorScene.new())
	header.add_child(summary)
	_update_lift_summary()


func _update_lift_summary() -> void:
	if not _mountain_state or _lift_summary_labels.size() != 4:
		return
	var totals := [
		"%d OPEN" % _mountain_state.open,
		"%d HOLD" % _mountain_state.hold,
		"%d SCHEDULED" % _mountain_state.scheduled,
		"%d CLOSED" % _mountain_state.closed,
	]
	for index in totals.size():
		_lift_summary_labels[index].text = totals[index]


func _build_ticker() -> void:
	_ticker = MarqueeTickerScene.new()
	_ticker.position = Vector2(BORDER_WIDTH, 142)
	_ticker.size = Vector2(DESIGN_SIZE.x - BORDER_WIDTH * 2.0, 132)
	add_child(_ticker)
	if _mountain_state:
		_ticker.set_mountain_state(_mountain_state)


func _build_footer() -> void:
	var footer := _build_divided_line(
		["CONDITIONS CAN CHANGE", "OBSERVE ALL POSTED SIGNAGE"], 22, Color("d4efff"), 44, 6, true
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
	separator_top_margin: int,
	animate_separators: bool = false,
	labels: Array[Label] = []
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
			separator_padding.add_theme_constant_override("margin_top", separator_top_margin)
			var separator := Label.new()
			separator.text = "◆"
			separator.add_theme_font_override("font", ArcadeTheme.SYMBOL_FONT)
			separator.add_theme_color_override("font_color", Color("ffd166"))
			separator.add_theme_color_override("font_outline_color", Color("07182d"))
			separator.add_theme_constant_override("outline_size", 7)
			separator.add_theme_font_size_override("font_size", roundi(font_size * 0.8))
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
		label.add_theme_font_override("font", ArcadeTheme.AUDIOWIDE_FONT)
		label.add_theme_color_override("font_color", text_color)
		label.add_theme_color_override("font_outline_color", Color("07182d"))
		label.add_theme_constant_override("outline_size", 7)
		label.add_theme_font_size_override("font_size", font_size)
		_add_pixel_shadow(label, 4)
		labels.append(label)
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
