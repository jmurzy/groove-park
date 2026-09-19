class_name ControlsScreen
extends Control

signal closed

const CONTROL_BUTTONS := preload("res://artwork/controls/sente_control_buttons.png")
const CONTROL_BUTTONS_DEPRESSED := preload(
	"res://artwork/controls/sente_control_buttons_depressed.png"
)
const JOYSTICK_BASE := preload("res://artwork/controls/sente_controls_base.png")
const JOYSTICK_SPRITES := preload("res://artwork/controls/sente_joystick_sprite.png")
const CONTROL_LAYOUT_SIZE := Vector2(1487, 1058)
const CABINET_ART_SIZE := Vector2(686, 456)
const BUTTON_SHEET_COLUMNS := 4
const BUTTON_CELL_SIZE := Vector2(362, 362)
const JOYSTICK_SHEET_COLUMNS := 3
const JOYSTICK_CELL_SIZE := Vector2(530, 530)
const JOYSTICK_POSITION := Vector2(303, 546)
const JOYSTICK_SCALE := 1.265
const SkierViewScene := preload("res://src/presentation/gameplay/skier_view.gd")
const SnowboarderViewScene := preload("res://src/presentation/gameplay/snowboarder_view.gd")

var _skier: SkierView
var _snowboarder: SnowboarderView
var _skier_status: Label
var _snowboarder_status: Label
var _control_sprites: Dictionary[StringName, Sprite2D]
var _control_textures: Dictionary[StringName, Array]
var _joystick: Sprite2D
var _joystick_textures: Array[Texture2D]


func _ready() -> void:
	name = "ControlsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_shade()
	_build_panel()


func _process(_delta: float) -> void:
	_update_rider_demo()
	_update_control_overlay()


func _build_shade() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fed")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)


func _build_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(52, 34)
	panel.size = Vector2(1816, 1012)
	panel.add_theme_stylebox_override(
		"panel", ArcadeTheme.button_style(Color("071b39f7"), Color("aefcff"), 8, 12)
	)
	add_child(panel)
	var title := ArcadeTheme.make_label("HOW TO PLAY", 42, Color("aefcff"))
	title.position = Vector2(0, 20)
	title.size = Vector2(panel.size.x, 70)
	panel.add_child(title)
	var subtitle := ArcadeTheme.make_label(
		"BUILD SPEED  •  LEAVE THE LIP CLEAN  •  STICK THE LANDING", 15, Color("aefcff")
	)
	subtitle.position = Vector2(0, 88)
	subtitle.size = Vector2(panel.size.x, 28)
	panel.add_child(subtitle)
	var cabinet_frame := Control.new()
	cabinet_frame.position = Vector2(565, 124)
	cabinet_frame.size = Vector2(686, 510)
	panel.add_child(cabinet_frame)
	var cabinet_label := ArcadeTheme.make_label("CABINET CONTROLS", 24, Color("fff16a"))
	cabinet_label.position = Vector2(13, 11)
	cabinet_label.size = Vector2(cabinet_frame.size.x - 26, 28)
	cabinet_frame.add_child(cabinet_label)
	_build_control_overlay(cabinet_frame)
	_add_control_card(
		panel,
		"ON THE APPROACH",
		(
			"STICK       PICK YOUR LINE\nRIGHT       POINT DOWNHILL\nUP / DOWN   CARVE ACROSS SLOPE\n"
			+"A           TUCK FOR SPEED\nB           CHECK SPEED\nBLUE X      HOLD, RELEASE AT LIP\n"
			+"Y           STRONGER CARVE"
		),
		Vector2(80, 532),
		Vector2(624, 270),
		Color("238bd4")
	)
	_add_control_card(
		panel,
		"IN THE AIR",
		(
			"LEFT / RIGHT   ROTATE\nDOWN / UP      COMPACT / EXTEND\nA              SIGNATURE GRAB\n"
			+"B              SPOT THE LANDING\nBLUE X         TWEAK ACTIVE GRAB\n"
			+"Y / LB / RB    RESERVED\nLT / RT        RESERVED"
		),
		Vector2(1112, 532),
		Vector2(624, 270),
		Color("b000d4")
	)
	_build_rider_demo(panel)
	cabinet_frame.move_to_front()
	_add_footer(panel)


func _build_control_overlay(cabinet_frame: Control) -> void:
	var overlay := Node2D.new()
	overlay.position = Vector2(0, 54)
	overlay.scale = CABINET_ART_SIZE / CONTROL_LAYOUT_SIZE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cabinet_frame.add_child(overlay)
	var base := Sprite2D.new()
	base.texture = JOYSTICK_BASE
	base.centered = false
	base.position = Vector2(250, 14)
	base.scale = Vector2(0.88, 0.91)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.add_child(base)
	_joystick_textures = []
	for row in range(3):
		for column in range(3):
			_joystick_textures.append(
				_atlas_texture(JOYSTICK_SPRITES, JOYSTICK_CELL_SIZE, column, row)
			)
	_joystick = Sprite2D.new()
	_joystick.position = JOYSTICK_POSITION
	_joystick.scale = Vector2.ONE * JOYSTICK_SCALE
	_joystick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.add_child(_joystick)
	_add_control_button(overlay, &"cabinet_exit", Vector2(416, 170), 0, 0.94)
	_add_control_button(overlay, &"controller_back", Vector2(591, 167), 1, 0.94)
	_add_control_button(overlay, &"controller_start", Vector2(770, 170), 2, 0.94)
	_add_control_button(overlay, &"action_y", Vector2(1004, 276), 3)
	_add_control_button(overlay, &"action_lb", Vector2(1199, 290), 4)
	_add_control_button(overlay, &"action_x", Vector2(824, 407), 5)
	_add_control_button(overlay, &"action_b", Vector2(1007, 510), 6)
	_add_control_button(overlay, &"action_rb", Vector2(1221, 511), 7)
	_add_control_button(overlay, &"action_a", Vector2(812, 630), 8)
	_add_control_button(overlay, &"action_lt", Vector2(602, 923), 9, 1.06)
	_add_control_button(overlay, &"action_rt", Vector2(806, 871), 10, 1.06)


func _add_control_button(
	overlay: Node2D,
	action: StringName,
	position: Vector2,
	index: int,
	scale_multiplier: float = 1.0
) -> void:
	var column := index % BUTTON_SHEET_COLUMNS
	var row := index / BUTTON_SHEET_COLUMNS
	var button := Sprite2D.new()
	button.position = position
	button.scale = Vector2.ONE * 0.64187710587 * scale_multiplier
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.add_child(button)
	_control_sprites[action] = button
	_control_textures[action] = [
		_atlas_texture(CONTROL_BUTTONS, BUTTON_CELL_SIZE, column, row),
		_atlas_texture(CONTROL_BUTTONS_DEPRESSED, BUTTON_CELL_SIZE, column, row),
	]


func _atlas_texture(
	atlas: Texture2D, cell_size: Vector2, column: int, row: int, row_stride: float = cell_size.y
) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(column * cell_size.x, row * row_stride), cell_size)
	return texture


func _update_control_overlay() -> void:
	if not is_instance_valid(_joystick):
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var column := int(sign(direction.x)) + 1
	var row := int(sign(direction.y)) + 1
	var frame := row * JOYSTICK_SHEET_COLUMNS + column
	_joystick.texture = _joystick_textures[frame]
	_joystick.position = JOYSTICK_POSITION
	for action in _control_sprites:
		_control_sprites[action].texture = _control_textures[action][int(
			Input.is_action_pressed(action)
		)]


func _add_control_card(
	panel: Panel,
	heading: String,
	body: String,
	position: Vector2,
	card_size: Vector2,
	border: Color
) -> void:
	var card := Panel.new()
	card.position = position
	card.size = card_size
	card.add_theme_stylebox_override(
		"panel", ArcadeTheme.button_style(Color("061325f2"), border, 5, 6)
	)
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


func _build_rider_demo(panel: Panel) -> void:
	var demo := Control.new()
	demo.position = Vector2(60, 124)
	demo.size = Vector2(1696, 389)
	demo.clip_contents = true
	panel.add_child(demo)
	_add_rider_lane(demo, "SKIER", Vector2(188, 97), true)
	_add_rider_lane(demo, "SNOWBOARDER", Vector2(1220, 97), false)
	_skier_status = _add_rider_status(demo, Vector2(188, 300))
	_snowboarder_status = _add_rider_status(demo, Vector2(1220, 300))


func _add_rider_lane(
	demo: Control, rider_name: String, lane_position: Vector2, is_skier: bool
) -> void:
	var lane := Control.new()
	lane.position = lane_position
	lane.size = Vector2(288, 195)
	demo.add_child(lane)
	var label := ArcadeTheme.make_label(rider_name, 18, Color("d4efff"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 8)
	label.size = Vector2(288, 20)
	lane.add_child(label)
	var slope := Polygon2D.new()
	slope.polygon = PackedVector2Array(
		[Vector2(0, 141), Vector2(288, 170), Vector2(288, 195), Vector2(0, 195)]
	)
	slope.color = Color("b9f7ff")
	lane.add_child(slope)
	for scanline_y in range(137, 189, 8):
		var scanline := ColorRect.new()
		scanline.position = Vector2(0, scanline_y)
		scanline.size = Vector2(288, 2)
		scanline.color = Color("4b93ce80")
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.add_child(scanline)
	var rider: Node2D = SkierViewScene.new() if is_skier else SnowboarderViewScene.new()
	rider.position = Vector2(144, 139 if is_skier else 159)
	rider.scale = Vector2.ONE * 1.12
	lane.add_child(rider)
	if is_skier:
		_skier = rider as SkierView
	else:
		_snowboarder = rider as SnowboarderView


func _add_rider_status(demo: Control, status_position: Vector2) -> Label:
	var status := ArcadeTheme.make_label("IDLE GLIDE", 13, Color("aefcff"))
	status.position = status_position
	status.size = Vector2(288, 24)
	demo.add_child(status)
	return status


func _update_rider_demo() -> void:
	if (
		not is_instance_valid(_skier)
		or not is_instance_valid(_snowboarder)
		or not is_instance_valid(_skier_status)
		or not is_instance_valid(_snowboarder_status)
	):
		return
	var animation := _demo_animation()
	_skier.play_preview(animation.skier)
	_snowboarder.play_preview(animation.snowboarder)
	_skier_status.text = animation.label
	_snowboarder_status.text = animation.label


func _demo_animation() -> Dictionary:
	if Input.is_action_pressed(&"action_x"):
		return {"skier": &"grab_tweak", "snowboarder": &"grab_tweak", "label": "BLUE X  TWEAK"}
	if Input.is_action_pressed(&"action_a"):
		return {"skier": &"grab_hold", "snowboarder": &"grab_hold", "label": "A  GRAB / TUCK"}
	if Input.is_action_pressed(&"move_down"):
		return {"skier": &"compression", "snowboarder": &"compression", "label": "DOWN  COMPACT"}
	if Input.is_action_pressed(&"move_up"):
		return {
			"skier": &"takeoff_extension",
			"snowboarder": &"takeoff_extension",
			"label": "UP  EXTEND"
		}
	if Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"action_b"):
		return {
			"skier": &"carve_uphill", "snowboarder": &"carve_heel", "label": "LEFT / B  CHECK SPEED"
		}
	if Input.is_action_pressed(&"move_right") or Input.is_action_pressed(&"action_y"):
		return {
			"skier": &"carve_downhill", "snowboarder": &"carve_toe", "label": "RIGHT / Y  CARVE"
		}
	return {"skier": &"neutral_glide", "snowboarder": &"neutral_glide", "label": "IDLE GLIDE"}


func _add_footer(panel: Panel) -> void:
	var footer := Control.new()
	footer.position = Vector2(60, 824)
	footer.size = Vector2(panel.size.x - 120, 144)
	panel.add_child(footer)
	var cabinet_hint := ArcadeTheme.make_label(
		"BLUE X IS GAMEPLAY. WHITE EXIT IS SYSTEM ONLY.", 17, Color("aefcff")
	)
	cabinet_hint.position = Vector2(0, 12)
	cabinet_hint.size = Vector2(footer.size.x, 26)
	footer.add_child(cabinet_hint)
	var system := ArcadeTheme.make_label(
		"START  PAUSE / RESUME     SELECT OR B  BACK     EXIT  HOLD TO QUIT", 17, Color("d4efff")
	)
	system.position = Vector2(0, 53)
	system.size = Vector2(footer.size.x, 26)
	footer.add_child(system)
	var dismiss := ArcadeTheme.make_label("PRESS SELECT OR B TO RETURN", 18, Color("fff7cf"))
	dismiss.position = Vector2(0, 93)
	dismiss.size = Vector2(footer.size.x, 28)
	footer.add_child(dismiss)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"controller_back") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
