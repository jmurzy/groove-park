## HOW TO PLAY overlay: cabinet diagram, approach/air control cards, live demo,
## and footer hints. SELECT toggles the active card; B emits `closed`.
## Ticked to animate demo and controls.
class_name HowToPlayAgsScreen
extends HowToPlayScreen

const PANEL_POSITION := Vector2(52, 34)
const PANEL_SIZE := Vector2(1816, 1012)
const CABINET_FRAME_POSITION := Vector2(565, 124)
const CABINET_FRAME_SIZE := Vector2(686, 510)


func _screen_name() -> StringName:
	return &"HowToPlayAgsScreen"


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
	_controls_view = ControlsCabinetView.new()
	_controls_view.audio_manager = audio_manager
	cabinet_frame.add_child(_controls_view)
	_approach_card = _add_control_card(
		panel,
		"ON THE APPROACH",
		(
			"RIGHT     BUILD SPEED\n"
			+ "LEFT/B    CHECK SPEED\n"
			+ "UP/DOWN   PICK YOUR LINE\n"
			+ "A         TUCK FOR SPEED\n"
			+ "X         COMPRESS"
		),
		Vector2(80, 532),
		Vector2(624, 270),
		APPROACH_BORDER
	)
	_air_card = _add_control_card(
		panel,
		"IN THE AIR",
		# Control fields are space-padded to equal widths; the arcade font is
		# monospace, so equal character counts keep descriptions aligned.
		(
			"A           GRAB\n"
			+ "B           TWEAK GRAB\n"
			+ "A/B+LT 2X   LEFT/BACKSIDE 360\n"
			+ "A/B+RT 2X   RIGHT/FRONTSIDE 360\n"
			+ "X           HOLD TO LAND"
		),
		Vector2(1112, 532),
		Vector2(624, 270),
		AIR_BORDER
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
		"SELECT  SWITCH CARD     B  BACK     EXIT  HOLD TO QUIT", 17, Color("d4efff")
	)
	system.position = Vector2(0, 53)
	system.size = Vector2(footer.size.x, 26)
	footer.add_child(system)
	var dismiss := ArcadeTheme.make_label(
		"PRESS SELECT TO SWITCH   PRESS B TO RETURN", 18, Color("fff7cf")
	)
	dismiss.position = Vector2(0, 93)
	dismiss.size = Vector2(footer.size.x, 28)
	footer.add_child(dismiss)
