class_name PrimaryScreen
extends Control

const DESIGN_SIZE := Vector2(1920, 1080)

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service

var _state := {"status": "unknown", "open_count": 0, "hold_count": 0, "closed_count": 0}
var _elapsed := 0.0
var _status_label: Label


func _ready() -> void:
	name = "PrimaryView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	if show_diagnostics:
		add_child(_build_diagnostics())
	if liftie_state_service != null:
		_state = liftie_state_service.state
		liftie_state_service.state_changed.connect(_on_state_changed)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var sky_top := Color("071a3b")
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), sky_top)
	for index in 9:
		var x := fposmod(float(index) * 263.0 + _elapsed * 9.0, DESIGN_SIZE.x + 80.0) - 40.0
		var y := fposmod(float(index) * 137.0 + _elapsed * 54.0, 650.0)
		draw_circle(Vector2(x, y), 3.0 + float(index % 3), Color(0.9, 0.96, 1.0, 0.72))

	# Stacked silhouettes keep the scene recognizable without dashboard chrome.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 720), Vector2(390, 410), Vector2(710, 700), Vector2(1040, 340), Vector2(1430, 710), Vector2(1760, 450), Vector2(1920, 650), Vector2(1920, 1080), Vector2(0, 1080)]), Color("183f64"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 830), Vector2(500, 570), Vector2(805, 830), Vector2(1250, 480), Vector2(1550, 790), Vector2(1920, 610), Vector2(1920, 1080), Vector2(0, 1080)]), Color("0c294d"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 940), Vector2(440, 720), Vector2(750, 900), Vector2(1170, 620), Vector2(1510, 890), Vector2(1920, 720), Vector2(1920, 1080), Vector2(0, 1080)]), Color("071b36"))

	var lift_color := _lift_color()
	var cable_start := Vector2(450, 585)
	var cable_end := Vector2(1480, 350)
	draw_line(cable_start, cable_end, lift_color, 7.0, true)
	for chair_index in 5:
		var progress := (float(chair_index) / 5.0 + _chair_progress())
		var position := cable_start.lerp(cable_end, progress)
		draw_line(position, position + Vector2(0, 48), lift_color, 5.0, true)
		draw_rect(Rect2(position + Vector2(-27, 48), Vector2(54, 20)), lift_color, true)
	var beacon_alpha := 0.65 + 0.35 * sin(_elapsed * 5.0) if _state.status == "hold" else 1.0
	draw_circle(Vector2(1515, 350), 19.0, Color(lift_color, beacon_alpha))


func _build_labels() -> void:
	var title := Label.new()
	title.text = "HEAVENLY"
	title.position = Vector2(92, 76)
	title.add_theme_color_override("font_color", Color("f7f9ff"))
	title.add_theme_color_override("font_outline_color", Color("0b2d50"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_font_size_override("font_size", 126)
	add_child(title)

	_status_label = Label.new()
	_status_label.position = Vector2(96, 228)
	_status_label.add_theme_color_override("font_color", Color("b9d8f7"))
	_status_label.add_theme_font_size_override("font_size", 34)
	add_child(_status_label)
	_update_status_label()


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  |  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(92, 1000)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 20)
	return diagnostics


func _chair_progress() -> float:
	return fposmod(_elapsed * 0.075, 1.0) if _state.status == "open" else 0.0


func _lift_color() -> Color:
	match _state.status:
		"open": return Color("e8f7ff")
		"hold": return Color("ffbd4a")
		"closed": return Color("6d8294")
		_: return Color("8aa0ad")


func _on_state_changed(next_state: Dictionary) -> void:
	_state = next_state
	_update_status_label()


func _update_status_label() -> void:
	match _state.status:
		"open": _status_label.text = "%d LIFTS OPEN  |  RIDE THE HIGH COUNTRY" % _state.open_count
		"hold": _status_label.text = "%d LIFTS ON HOLD  |  MOUNTAIN WEATHER" % _state.hold_count
		"closed": _status_label.text = "LIFTS CLOSED  |  SEE YOU ON THE MOUNTAIN"
		_: _status_label.text = "MOUNTAIN CONDITIONS UNAVAILABLE"
