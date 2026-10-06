## Displays leaderboard entries above another results view.
class_name LeaderboardOverlay
extends Control

const OVERLAY_SIZE := Vector2(680, 810)
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SNOWBOARDER_SHEET := preload("res://artwork/marquee/snowboarder_sprite.png")
const TOP_RIDERS_TITLE := preload("res://artwork/leaderboard/top_riders.png")
const GOLD_MEDAL := preload("res://artwork/leaderboard/gold.png")
const SILVER_MEDAL := preload("res://artwork/leaderboard/silver.png")
const BRONZE_MEDAL := preload("res://artwork/leaderboard/bronze.png")
const ROW_START_Y := 205.0
const ROW_HEIGHT := 58.0

var _entries: Array[LeaderboardEntry]
var _highlighted_rank: Variant
var _highlighted_rider_kind: StringName


func show_entries(
	entries: Array[LeaderboardEntry],
	highlighted_rank: Variant = null,
	highlighted_rider_kind: StringName = &""
) -> void:
	_entries = entries
	_highlighted_rank = highlighted_rank
	_highlighted_rider_kind = highlighted_rider_kind
	if is_inside_tree():
		_build()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = OVERLAY_SIZE
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", ArcadeTheme.dialog_panel_style())
	add_child(panel)
	var title := Sprite2D.new()
	title.texture = TOP_RIDERS_TITLE
	title.position = Vector2(OVERLAY_SIZE.x / 2.0, 40)
	title.scale = Vector2.ONE * (760.0 / 1983.0)
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(title)
	_add_cell(
		panel,
		"RANK",
		Vector2(0, 160),
		Vector2(160, 30),
		20,
		Color("42eaff"),
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_add_cell(
		panel,
		"RIDER",
		Vector2(205, 160),
		Vector2(260, 30),
		20,
		Color("42eaff"),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_add_cell(panel, "SCORE", Vector2(540, 160), Vector2(100, 30), 20, Color("42eaff"))
	_add_row_dividers(panel)
	for entry_index in _entries.size():
		_add_entry_row(panel, _entries[entry_index], entry_index + 1)


func _add_entry_row(parent: Control, entry: LeaderboardEntry, rank: int) -> void:
	var y_position := ROW_START_Y + (rank - 1) * ROW_HEIGHT
	var is_highlighted: bool = _highlighted_rank is int and _highlighted_rank == rank
	if is_highlighted:
		var highlight := Panel.new()
		highlight.position = Vector2(85, y_position + 4)
		highlight.size = Vector2(570, ROW_HEIGHT - 8)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.add_theme_stylebox_override(
			"panel", ArcadeTheme.button_style(Color("0b294c"), Color("ff8a00"), 3, 5)
		)
		parent.add_child(highlight)
		var rider := RiderPreview.create(
			"HighlightedRider",
			_highlighted_rider_sheet(),
			Vector2(55, y_position + ROW_HEIGHT / 2.0)
		)
		rider.scale = Vector2.ONE * 0.135
		parent.add_child(rider)
	var row_color := Color("fff16a") if is_highlighted else Color("fff7cf")
	if rank <= 3:
		_add_medal(parent, rank, y_position)
	else:
		_add_cell(
			parent,
			"%d" % rank,
			Vector2(90, y_position),
			Vector2(70, ROW_HEIGHT),
			22,
			row_color,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	_add_cell(
		parent,
		entry.player_name,
		Vector2(205, y_position),
		Vector2(260, ROW_HEIGHT),
		22,
		row_color,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_add_cell(
		parent,
		"%d" % entry.total_score,
		Vector2(540, y_position),
		Vector2(100, ROW_HEIGHT),
		22,
		row_color,
		HORIZONTAL_ALIGNMENT_RIGHT
	)


func _add_row_dividers(parent: Control) -> void:
	for row_index in range(_entries.size() + 1):
		var divider := ColorRect.new()
		divider.position = Vector2(90, ROW_START_Y + row_index * ROW_HEIGHT)
		divider.size = Vector2(550, 1)
		divider.color = Color("42eaff66")
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(divider)


func _add_medal(parent: Control, rank: int, y_position: float) -> void:
	var medal := Sprite2D.new()
	medal.texture = [GOLD_MEDAL, SILVER_MEDAL, BRONZE_MEDAL][rank - 1]
	medal.position = Vector2(125, y_position + ROW_HEIGHT / 2.0)
	medal.scale = Vector2.ONE * (41.0 / 468.0)
	medal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(medal)


func _add_cell(
	parent: Control,
	text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color,
	alignment := HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	var cell := ArcadeTheme.make_label(text, font_size, color)
	cell.position = position_value
	cell.size = size_value
	cell.horizontal_alignment = alignment
	parent.add_child(cell)


func _highlighted_rider_sheet() -> Texture2D:
	return SKIER_SHEET if _highlighted_rider_kind == RiderKind.SKIER else SNOWBOARDER_SHEET
