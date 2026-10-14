class_name HowToPlayScreen
extends Control

signal closed

enum InfoCard { APPROACH, AIR }

const CARD_FILL := Color("061325f2")
const APPROACH_BORDER := Color("238bd4")
const AIR_BORDER := Color("b000d4")
const SELECTED_BORDER := Color("fff16a")
const INACTIVE_BORDER := Color("238bd4")

var audio_manager: AudioManager
var _controls_view: ControlsView
var _demo: RiderDemoPanel
var _approach_card: Panel
var _air_card: Panel
var _selected_card: int = InfoCard.APPROACH


func _ready() -> void:
	name = _screen_name()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_shade()
	_build_panel()
	_update_card_selection()


func _process(delta: float) -> void:
	if is_instance_valid(_controls_view):
		_controls_view.tick()
	if is_instance_valid(_demo):
		_demo.tick(delta)


func _screen_name() -> StringName:
	return &"HowToPlayScreen"


func _build_shade() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fed")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)


func _build_panel() -> void:
	pass


func _add_control_card(
	panel: Panel,
	heading: String,
	body: String,
	position: Vector2,
	card_size: Vector2,
	border: Color
) -> Panel:
	var card := Panel.new()
	card.position = position
	card.size = card_size
	card.add_theme_stylebox_override("panel", ArcadeTheme.button_style(CARD_FILL, border, 5, 6))
	panel.add_child(card)
	var card_heading := ArcadeTheme.make_label(heading, 24, Color("fff16a"))
	card_heading.position = Vector2(24, 18)
	card_heading.size = Vector2(card.size.x - 48, 42)
	card.add_child(card_heading)
	var controls := Label.new()
	controls.text = body
	controls.position = Vector2(42, 78)
	controls.size = Vector2(card.size.x - 84, card.size.y - 96)
	controls.add_theme_font_override("font", ArcadeTheme.ARCADE_FONT)
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color("fff7cf"))
	controls.add_theme_color_override("font_outline_color", Color("061020"))
	controls.add_theme_constant_override("outline_size", 4)
	controls.add_theme_constant_override("line_spacing", 7)
	card.add_child(controls)
	return card


func _select_card(card_index: int) -> void:
	var clamped_index := clampi(card_index, InfoCard.APPROACH, InfoCard.AIR)
	if clamped_index == _selected_card:
		return
	_selected_card = clamped_index
	_update_card_selection()
	audio_manager.play_event(AudioManager.Event.UI_MOVE)


func _update_card_selection() -> void:
	if not is_instance_valid(_approach_card) or not is_instance_valid(_air_card):
		return
	_apply_card_border(_approach_card, APPROACH_BORDER, _selected_card == InfoCard.APPROACH)
	_apply_card_border(_air_card, AIR_BORDER, _selected_card == InfoCard.AIR)
	if is_instance_valid(_demo):
		var air_selected := _selected_card == InfoCard.AIR
		_demo.set_airborne_lift(air_selected)
		if air_selected:
			_demo.set_speed_mph(0.0)


func _apply_card_border(card: Panel, _base_border: Color, selected: bool) -> void:
	if selected:
		card.add_theme_stylebox_override(
			"panel", ArcadeTheme.button_style(CARD_FILL, SELECTED_BORDER, 8, 12)
		)
	else:
		card.add_theme_stylebox_override(
			"panel", ArcadeTheme.button_style(CARD_FILL, INACTIVE_BORDER, 5, 6)
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"controller_back"):
		_select_card(InfoCard.AIR if _selected_card == InfoCard.APPROACH else InfoCard.APPROACH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		_select_card(InfoCard.APPROACH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_select_card(InfoCard.AIR)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
