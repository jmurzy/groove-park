class_name MarqueeScreen
extends Control

const DESIGN_SIZE := Vector2(1920, 360)

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service

var _state := {"status": "unknown", "open_count": 0, "hold_count": 0}
var _elapsed := 0.0
var _status_label: Label


func _ready() -> void:
	name = "MarqueeView"
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
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color("081b35"))
	for index in 6:
		var x := fposmod(float(index) * 370.0 + _elapsed * 15.0, 2050.0) - 70.0
		draw_line(Vector2(x, 350), Vector2(x + 250, 120), Color("17456a"), 3.0, true)
	var glow := _lift_color()
	draw_circle(Vector2(1610, 178), 86.0 + sin(_elapsed * 2.0) * 8.0, Color(glow, 0.15))
	draw_circle(Vector2(1610, 178), 44.0, Color(glow, 0.9))
	draw_line(Vector2(96, 289), Vector2(1824, 289), glow, 4.0, true)


func _build_labels() -> void:
	var title := Label.new()
	title.text = "HEAVENLY"
	title.position = Vector2(90, 48)
	title.add_theme_color_override("font_color", Color("f8fbff"))
	title.add_theme_color_override("font_outline_color", Color("16476c"))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_font_size_override("font_size", 112)
	add_child(title)

	_status_label = Label.new()
	_status_label.position = Vector2(98, 194)
	_status_label.add_theme_color_override("font_color", Color("b9d8f7"))
	_status_label.add_theme_font_size_override("font_size", 34)
	add_child(_status_label)
	_update_status_label()


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  |  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(98, 316)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 16)
	return diagnostics


func _lift_color() -> Color:
	match _state.status:
		"open": return Color("6ed6ff")
		"hold": return Color("ffbd4a")
		"closed": return Color("71879a")
		_: return Color("9aabb7")


func _on_state_changed(next_state: Dictionary) -> void:
	_state = next_state
	_update_status_label()


func _update_status_label() -> void:
	match _state.status:
		"open": _status_label.text = "%d LIFTS OPEN  /  FIND YOUR LINE" % _state.open_count
		"hold": _status_label.text = "%d LIFTS ON HOLD  /  WEATHER WATCH" % _state.hold_count
		"closed": _status_label.text = "LIFTS CLOSED  /  THE MOUNTAIN WAITS"
		_: _status_label.text = "MOUNTAIN STATUS UNAVAILABLE"
