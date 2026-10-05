## Solo rider chooser overlay with snowboarder and skier previews.
class_name PlayerSelectScreen
extends Control

signal confirmed(rider_kind: StringName)
signal cancelled

const DESIGN_WIDTH := 1920.0
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SNOWBOARDER_SHEET := preload("res://artwork/marquee/snowboarder_sprite.png")
const CARD_SIZE := Vector2(560, 385)
const SNOWBOARDER_POSITION := Vector2(375, 545)
const SKIER_POSITION := Vector2(985, 545)

var selected_rider_kind: StringName = RiderKind.SNOWBOARDER
var input_router: InputRouter
var audio_manager: AudioManager
var _cards: Array[Button] = []
var _riders: Array[RiderPreview] = []


func _ready() -> void:
	name = "PlayerSelect"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shade()
	_build_title()
	_build_cards()
	_build_hint()
	_select(RiderKind.SNOWBOARDER)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		if input_router == null or not input_router.claim_from_rider_select(event):
			return
		_select(_other_rider_kind())
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"controller_start")
		or event.is_action_pressed(&"action_a")
		or event.is_action_pressed(&"ui_accept")
	):
		if input_router == null or not input_router.claim_from_rider_select(event):
			return
		_confirm(selected_rider_kind)
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"action_b")
		or event.is_action_pressed(&"controller_back")
	):
		cancelled.emit()
		get_viewport().set_input_as_handled()


func focus_default() -> void:
	_select(RiderKind.SNOWBOARDER)


func _build_shade() -> void:
	var shade := ColorRect.new()
	shade.position = Vector2(34, 420)
	shade.size = Vector2(1852, 620)
	shade.color = Color("07162bd9")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_title() -> void:
	var title := ArcadeTheme.make_label("CHOOSE YOUR RIDE", 44, Color("fff16a"))
	title.position = Vector2(0, 455)
	title.size = Vector2(DESIGN_WIDTH, 64)
	add_child(title)


func _build_cards() -> void:
	var snowboarder := _build_card(RiderKind.SNOWBOARDER, SNOWBOARDER_POSITION)
	add_child(snowboarder)
	var skier := _build_card(RiderKind.SKIER, SKIER_POSITION)
	add_child(skier)
	_cards.assign([snowboarder, skier])
	snowboarder.focus_neighbor_left = skier.get_path_to(snowboarder)
	snowboarder.focus_neighbor_right = snowboarder.get_path_to(skier)
	skier.focus_neighbor_left = skier.get_path_to(snowboarder)
	skier.focus_neighbor_right = skier.get_path_to(skier)


func _build_hint() -> void:
	var hint := ArcadeTheme.make_label(
		"<  SELECT  >     A / START  READY     B / MENU  BACK", 20, Color("d4efff")
	)
	hint.position = Vector2(0, 970)
	hint.size = Vector2(DESIGN_WIDTH, 40)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build_card(rider_kind: StringName, card_position: Vector2) -> Button:
	var card := Button.new()
	card.name = "%sCard" % rider_kind.capitalize()
	card.position = card_position
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override(
		"normal", ArcadeTheme.button_style(Color("061325e6"), Color("238bd4"), 6, 9)
	)
	card.add_theme_stylebox_override(
		"hover", ArcadeTheme.button_style(Color("0a2852f2"), Color("aefcff"), 8, 12)
	)
	card.add_theme_stylebox_override(
		"pressed", ArcadeTheme.button_style(Color("0b1935f2"), Color("ffb000"), 8, 5)
	)
	card.add_theme_stylebox_override(
		"focus", ArcadeTheme.button_style(Color("12366bf2"), Color("fff16a"), 10, 15)
	)
	card.focus_entered.connect(_on_card_focused.bind(rider_kind))
	card.mouse_entered.connect(card.grab_focus)
	card.pressed.connect(_on_card_pressed.bind(rider_kind))

	var heading := ArcadeTheme.make_label(rider_kind.to_upper(), 30, Color("fff7cf"))
	heading.position = Vector2(0, 28)
	heading.size = Vector2(CARD_SIZE.x, 48)
	card.add_child(heading)

	var sheet := SNOWBOARDER_SHEET if rider_kind == RiderKind.SNOWBOARDER else SKIER_SHEET
	_riders.append(RiderPreview.create(rider_kind.capitalize(), sheet, Vector2(280, 208)))
	card.add_child(_riders.back())

	var run_type := ArcadeTheme.make_label("SOLO RUN", 18, Color("aefcff"))
	run_type.position = Vector2(0, 323)
	run_type.size = Vector2(CARD_SIZE.x, 30)
	card.add_child(run_type)
	return card


func _select(rider_kind: StringName) -> void:
	var selection_changed := selected_rider_kind != rider_kind
	selected_rider_kind = rider_kind
	for index in _riders.size():
		_riders[index].set_highlighted(index == _rider_index(rider_kind))
	if _cards.size() == 2:
		_cards[_rider_index(rider_kind)].call_deferred("grab_focus")
	if selection_changed:
		audio_manager.play_menu_switch()


func _confirm(rider_kind: StringName) -> void:
	confirmed.emit(rider_kind)


func _on_card_focused(rider_kind: StringName) -> void:
	if rider_kind == selected_rider_kind:
		return
	_select(rider_kind)


func _on_card_pressed(rider_kind: StringName) -> void:
	selected_rider_kind = rider_kind
	_confirm(rider_kind)


func _other_rider_kind() -> StringName:
	return (
		RiderKind.SKIER if selected_rider_kind == RiderKind.SNOWBOARDER else RiderKind.SNOWBOARDER
	)


func _rider_index(rider_kind: StringName) -> int:
	return 0 if rider_kind == RiderKind.SNOWBOARDER else 1
