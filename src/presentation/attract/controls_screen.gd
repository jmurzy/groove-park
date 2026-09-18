class_name ControlsScreen
extends Control

signal closed

const CONTROLS_ART := preload("res://artwork/attract/sente_controls.png")
const CONTROLS_ART_SIZE := Vector2(1487, 1058)
const CABINET_ART_SIZE := Vector2(618, 440)


func _ready() -> void:
	name = "ControlsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_shade()
	_build_panel()


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
	var title := ArcadeTheme.make_label("HOW TO PLAY", 42, Color("fff16a"))
	title.position = Vector2(0, 20)
	title.size = Vector2(panel.size.x, 70)
	panel.add_child(title)
	var subtitle := ArcadeTheme.make_label(
		"BUILD SPEED  •  LEAVE THE LIP CLEAN  •  STICK THE LANDING", 15, Color("aefcff")
	)
	subtitle.position = Vector2(0, 88)
	subtitle.size = Vector2(panel.size.x, 28)
	panel.add_child(subtitle)
	var cabinet_frame := Panel.new()
	cabinet_frame.position = Vector2(60, 148)
	cabinet_frame.size = Vector2(650, 608)
	cabinet_frame.clip_contents = true
	cabinet_frame.add_theme_stylebox_override(
		"panel", ArcadeTheme.button_style(Color("04152de6"), Color("238bd4"), 5, 8)
	)
	panel.add_child(cabinet_frame)
	var cabinet_label := ArcadeTheme.make_label("SENTE CABINET CONTROLS", 18, Color("fff16a"))
	cabinet_label.position = Vector2(16, 18)
	cabinet_label.size = Vector2(cabinet_frame.size.x - 32, 34)
	cabinet_frame.add_child(cabinet_label)
	var cabinet := Sprite2D.new()
	cabinet.texture = CONTROLS_ART
	cabinet.position = Vector2(16, 82) + CABINET_ART_SIZE / 2.0
	cabinet.scale = CABINET_ART_SIZE / CONTROLS_ART_SIZE
	cabinet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cabinet_frame.add_child(cabinet)
	var cabinet_hint := ArcadeTheme.make_label(
		"BLUE X IS GAMEPLAY. WHITE EXIT IS SYSTEM ONLY.", 12, Color("d4efff")
	)
	cabinet_hint.position = Vector2(16, 548)
	cabinet_hint.size = Vector2(cabinet_frame.size.x - 32, 24)
	cabinet_frame.add_child(cabinet_hint)
	_add_control_card(
		panel,
		"ON THE APPROACH",
		(
			"STICK       PICK YOUR LINE\nRIGHT       POINT DOWNHILL\nUP / DOWN   CARVE ACROSS SLOPE\n"
			+ "A           TUCK FOR SPEED\nB           CHECK SPEED\nBLUE X      HOLD, RELEASE AT LIP\n"
			+ "Y           STRONGER CARVE"
		),
		Vector2(758, 148),
		Color("238bd4")
	)
	_add_control_card(
		panel,
		"IN THE AIR",
		(
			"LEFT / RIGHT   ROTATE\nDOWN / UP      COMPACT / EXTEND\nA              SIGNATURE GRAB\n"
			+ "B              SPOT THE LANDING\nBLUE X         TWEAK ACTIVE GRAB\n"
			+ "Y / LB / RB    RESERVED\nLT / RT        RESERVED"
		),
		Vector2(758, 466),
		Color("b000d4")
	)
	_add_footer(panel)


func _add_control_card(
	panel: Panel, heading: String, body: String, position: Vector2, border: Color
) -> void:
	var card := Panel.new()
	card.position = position
	card.size = Vector2(998, 300)
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


func _add_footer(panel: Panel) -> void:
	var system := ArcadeTheme.make_label(
		"START  PAUSE / RESUME     SELECT OR B  BACK     EXIT  HOLD TO QUIT", 17, Color("d4efff")
	)
	system.position = Vector2(60, 794)
	system.size = Vector2(panel.size.x - 100, 34)
	panel.add_child(system)
	var note := ArcadeTheme.make_label(
		"RELEASE, THEN PRESS AGAIN AFTER TAKEOFF TO TURN A TUCK INTO A GRAB", 14, Color("aefcff")
	)
	note.position = Vector2(60, 850)
	note.size = Vector2(panel.size.x - 100, 30)
	panel.add_child(note)
	var dismiss := ArcadeTheme.make_label("PRESS SELECT OR B TO RETURN", 18, Color("fff7cf"))
	dismiss.position = Vector2(60, 918)
	dismiss.size = Vector2(panel.size.x - 100, 34)
	panel.add_child(dismiss)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(&"controller_back")
		or event.is_action_pressed(&"action_b")
		or event.is_action_pressed(&"ui_cancel")
	):
		closed.emit()
		get_viewport().set_input_as_handled()
