## 1P / 2P chooser overlay with rider-card previews. Emits `confirmed(count)` or
## `cancelled`; the 2P card is currently display-only.
class_name PlayerSelectScreen
extends Control

signal confirmed(player_count: int)
signal cancelled

const DESIGN_WIDTH := 1920.0
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SNOWBOARDER_SHEET := preload("res://artwork/marquee/snowboarder_sprite.png")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CARD_SIZE := Vector2(560, 385)
const ONE_PLAYER_POSITION := Vector2(375, 545)
const TWO_PLAYER_POSITION := Vector2(985, 545)

var selected_player_count := 1
var _cards: Array[Button] = []
var _riders: Array[RiderPreview] = []
var _switch_sound: AudioStreamPlayer


func _ready() -> void:
	name = "PlayerSelect"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shade()
	_build_title()
	_build_cards()
	_build_hint()
	_switch_sound = AudioStreamPlayer.new()
	_switch_sound.stream = SWITCH_SOUND
	add_child(_switch_sound)
	_select(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		_select(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"controller_start"):
		_confirm(selected_player_count)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"controller_back"):
		cancelled.emit()
		get_viewport().set_input_as_handled()


func focus_default() -> void:
	_select(1)


func _build_shade() -> void:
	var shade := ColorRect.new()
	shade.position = Vector2(34, 420)
	shade.size = Vector2(1852, 620)
	shade.color = Color("07162bd9")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_title() -> void:
	var title := ArcadeTheme.make_label("CHOOSE YOUR RUN", 44, Color("fff16a"))
	title.position = Vector2(0, 455)
	title.size = Vector2(DESIGN_WIDTH, 64)
	add_child(title)


func _build_cards() -> void:
	var one_player := _build_card(1, ONE_PLAYER_POSITION)
	add_child(one_player)
	var two_players := _build_card(2, TWO_PLAYER_POSITION)
	add_child(two_players)
	_cards.assign([one_player, two_players])
	two_players.focus_mode = Control.FOCUS_NONE
	two_players.mouse_filter = Control.MOUSE_FILTER_IGNORE

	one_player.focus_neighbor_left = NodePath(".")
	one_player.focus_neighbor_right = NodePath(".")


func _build_hint() -> void:
	var hint := ArcadeTheme.make_label(
		"<  SELECT  >     A / START  READY     B / MENU  BACK", 20, Color("d4efff")
	)
	hint.position = Vector2(0, 970)
	hint.size = Vector2(DESIGN_WIDTH, 40)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build_card(player_count: int, card_position: Vector2) -> Button:
	var card := Button.new()
	card.name = "Player%dCard" % player_count
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
	card.focus_entered.connect(_on_card_focused.bind(player_count))
	card.mouse_entered.connect(card.grab_focus)
	card.pressed.connect(_on_card_pressed.bind(player_count))

	var heading := ArcadeTheme.make_label(
		"%d PLAYER%s" % [player_count, "" if player_count == 1 else "S"], 30, Color("fff7cf")
	)
	heading.position = Vector2(0, 28)
	heading.size = Vector2(CARD_SIZE.x, 48)
	card.add_child(heading)

	if player_count == 1:
		_riders.append(RiderPreview.create("SoloSkier", SKIER_SHEET, Vector2(280, 208)))
		card.add_child(_riders.back())
	else:
		_riders.append(RiderPreview.create("TeamSkier", SKIER_SHEET, Vector2(205, 208)))
		card.add_child(_riders.back())
		_riders.append(RiderPreview.create("TeamSnowboarder", SNOWBOARDER_SHEET, Vector2(355, 208)))
		card.add_child(_riders.back())

	var run_type := ArcadeTheme.make_label(
		"SOLO RUN" if player_count == 1 else "TEAM RUN", 18, Color("aefcff")
	)
	run_type.position = Vector2(0, 323)
	run_type.size = Vector2(CARD_SIZE.x, 30)
	card.add_child(run_type)
	return card


func _select(player_count: int) -> void:
	var selection_changed := selected_player_count != player_count
	selected_player_count = player_count
	for index in _riders.size():
		var belongs_to_selection := index == 0 if player_count == 1 else index > 0
		_riders[index].set_highlighted(belongs_to_selection)
	if _cards.size() == 2:
		_cards[player_count - 1].call_deferred("grab_focus")
	if selection_changed:
		_switch_sound.play()


func _confirm(player_count: int) -> void:
	confirmed.emit(player_count)


func _on_card_focused(player_count: int) -> void:
	if player_count == selected_player_count:
		return
	_select(player_count)


func _on_card_pressed(player_count: int) -> void:
	selected_player_count = player_count
	_confirm(player_count)
