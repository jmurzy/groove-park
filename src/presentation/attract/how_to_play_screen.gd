class_name HowToPlayScreen
extends Control

signal closed

const PANEL_POSITION := Vector2(52, 34)
const PANEL_SIZE := Vector2(1816, 1012)
const CABINET_FRAME_POSITION := Vector2(565, 124)
const CABINET_FRAME_SIZE := Vector2(686, 510)

var _controls_view: CabinetControlsView
var _demo: RiderDemoPanel


func _ready() -> void:
	name = "HowToPlayScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_shade()
	_build_panel()


func _process(_delta: float) -> void:
	if is_instance_valid(_controls_view):
		_controls_view.tick()
	if is_instance_valid(_demo):
		_demo.tick()


func _build_shade() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02060fed")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)


func _build_panel() -> void:
	var panel := Panel.new()
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override(
		"panel", ArcadeTheme.button_style(Color("071b39f7"), Color("aefcff"), 8, 12)
	)
	add_child(panel)
	_add_header(panel)
	var cabinet_frame := Control.new()
	cabinet_frame.position = CABINET_FRAME_POSITION
	cabinet_frame.size = CABINET_FRAME_SIZE
	panel.add_child(cabinet_frame)
	var cabinet_label := ArcadeTheme.make_label("CABINET CONTROLS", 24, Color("fff16a"))
	cabinet_label.position = Vector2(13, 11)
	cabinet_label.size = Vector2(cabinet_frame.size.x - 26, 28)
	cabinet_frame.add_child(cabinet_label)
	_controls_view = CabinetControlsView.new()
	cabinet_frame.add_child(_controls_view)
	_add_control_card(
		panel,
		"ON THE APPROACH",
		(
			"STICK       PICK YOUR LINE\nRIGHT       POINT DOWNHILL\nUP / DOWN   CARVE ACROSS SLOPE\n"
			+ "A           TUCK FOR SPEED\nB           CHECK SPEED\nBLUE X      HOLD, RELEASE AT LIP\n"
			+ "Y           STRONGER CARVE"
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
			+ "B              SPOT THE LANDING\nBLUE X         TWEAK ACTIVE GRAB\n"
			+ "Y / LB / RB    RESERVED\nLT / RT        RESERVED"
		),
		Vector2(1112, 532),
		Vector2(624, 270),
		Color("b000d4")
	)
	_demo = RiderDemoPanel.new()
	panel.add_child(_demo)
	cabinet_frame.move_to_front()
	_add_footer(panel)


func _add_header(panel: Panel) -> void:
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
