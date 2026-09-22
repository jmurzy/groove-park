## Main attract screen: logo, gondola, snowfall, and START / HOW TO PLAY / EXIT
## menu. Emits `start_game_requested` and `exit_requested`.
class_name PrimaryScreen
extends Control

signal start_game_requested(player_count: int)
signal exit_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const PRIMARY_BACKGROUND := preload("res://artwork/attract/primary_bg.png")
const HEAVENLY_LOGO := preload("res://artwork/attract/heavenly_logo_no_tahoe.png")
const GONDOLA_SHEET := preload("res://artwork/attract/gondola_sprite.png")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const SnowfallLayerScene := preload("res://src/presentation/effects/snowfall_layer.gd")
const HowToPlayScreenScene := preload("res://src/presentation/attract/how_to_play_screen.gd")
const LOGO_RECT := Rect2(289, 20, 1387, 480)
const LOGO_SUBTITLE_RECT := Rect2(276, 328, 1387, 62)
const LOGO_SUBTITLE_GLYPH_SPACING := 12
const LOGO_SUBTITLE_SPACE_SPACING := -14
const GONDOLA_FRAME_COLUMNS := 4
const GONDOLA_FRAME_ROWS := 2
const GONDOLA_FRAME_RATE := 6.0
const GONDOLA_SCALE := 0.36
const GONDOLA_LANE := Rect2(712, 448, 497, 0)
const GONDOLA_SPEED := 65.0
const SNOWFLAKE_COUNT := 84
const SNOW_SAFE_INSET := 60.0
const FOOTER_COPYRIGHT_FORMAT := "© %d JULIA & JAKE MURZY - ALL RIGHTS RESERVED"
const FOOTER_DEV_SUFFIX := "DEV BUILD: BUT EXPECT NO BUGS!"
const ARCADE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LOGO_SUBTITLE_WAVE_SHADER := """
shader_type canvas_item;

void vertex() {
	VERTEX.y += round(sin(VERTEX.x * 0.035 + TIME * 2.0) * 2.0);
}
"""

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service: LiftieStateService
var logo_bob_time := 0.0
var logo_subtitle: Label
var gondola: AnimatedSprite2D
var start_button: Button
var controls_button: Button
var exit_button: Button
var confirmation_sound: AudioStreamPlayer
var switch_sound: AudioStreamPlayer
var back_sound: AudioStreamPlayer
var player_select: PlayerSelectScreen
var controls_screen: HowToPlayScreen
var _focused_menu_button: Button


func _ready() -> void:
	name = "PrimaryView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_subtitle = _build_logo_subtitle()
	add_child(logo_subtitle)
	_apply_logo_subtitle_wave()
	gondola = _build_gondola()
	add_child(gondola)
	gondola.play()
	add_child(SnowfallLayerScene.create(DESIGN_SIZE, SNOWFLAKE_COUNT, SNOW_SAFE_INSET))
	confirmation_sound = AudioStreamPlayer.new()
	confirmation_sound.stream = CONFIRMATION_SOUND
	add_child(confirmation_sound)
	switch_sound = AudioStreamPlayer.new()
	switch_sound.stream = SWITCH_SOUND
	add_child(switch_sound)
	back_sound = AudioStreamPlayer.new()
	back_sound.stream = BACK_SOUND
	add_child(back_sound)
	start_button = _build_start_button()
	add_child(start_button)
	controls_button = _build_controls_button()
	add_child(controls_button)
	exit_button = _build_exit_button()
	add_child(exit_button)
	_apply_attract_menu_style()
	_wire_menu_button_focus()
	_build_footer()
	if show_diagnostics:
		add_child(_build_diagnostics())
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(PRIMARY_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	draw_texture_rect(HEAVENLY_LOGO, LOGO_RECT, false)


func _process(delta: float) -> void:
	logo_bob_time += delta
	gondola.position.x = (
		GONDOLA_LANE.position.x + pingpong(logo_bob_time * GONDOLA_SPEED, GONDOLA_LANE.size.x)
	)
	queue_redraw()


func _build_gondola() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("travel")
	frames.set_animation_loop("travel", true)
	frames.set_animation_speed("travel", GONDOLA_FRAME_RATE)
	var frame_size := Vector2i(
		GONDOLA_SHEET.get_width() / GONDOLA_FRAME_COLUMNS,
		GONDOLA_SHEET.get_height() / GONDOLA_FRAME_ROWS
	)
	for row in GONDOLA_FRAME_ROWS:
		for column in GONDOLA_FRAME_COLUMNS:
			var frame := AtlasTexture.new()
			frame.atlas = GONDOLA_SHEET
			frame.region = Rect2(Vector2i(column, row) * frame_size, frame_size)
			frames.add_frame("travel", frame)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Gondola"
	sprite.sprite_frames = frames
	sprite.animation = "travel"
	sprite.position = Vector2(GONDOLA_LANE.position.x, GONDOLA_LANE.position.y)
	sprite.scale = Vector2.ONE * GONDOLA_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _build_logo_subtitle() -> Label:
	var subtitle := Label.new()
	subtitle.name = "LogoSubtitle"
	subtitle.text = "LAKE TAHOE"
	subtitle.position = LOGO_SUBTITLE_RECT.position
	subtitle.size = LOGO_SUBTITLE_RECT.size
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var subtitle_font := FontVariation.new()
	subtitle_font.base_font = ARCADE_FONT
	subtitle_font.spacing_glyph = LOGO_SUBTITLE_GLYPH_SPACING
	subtitle_font.spacing_space = LOGO_SUBTITLE_SPACE_SPACING
	subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 50)
	subtitle.add_theme_color_override("font_color", Color("aefcff"))
	subtitle.add_theme_constant_override("outline_size", 2)
	subtitle.add_theme_color_override("font_outline_color", Color("062a3a"))
	subtitle.add_theme_color_override("font_shadow_color", Color("42eaffcc"))
	subtitle.add_theme_constant_override("shadow_outline_size", 5)
	return subtitle


func _apply_logo_subtitle_wave() -> void:
	var shader := Shader.new()
	shader.code = LOGO_SUBTITLE_WAVE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	logo_subtitle.material = material


func _build_start_button() -> Button:
	var button := Button.new()
	button.name = "StartGameButton"
	button.text = "START GAME"
	button.position = Vector2(681, 766.1)
	button.size = Vector2(558, 109.8)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 43)
	button.add_theme_color_override("font_color", Color("fff7cf"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("fff19a"))
	button.add_theme_color_override("font_focus_color", Color("ffffff"))
	button.add_theme_color_override("font_outline_color", Color("260700"))
	button.add_theme_constant_override("outline_size", 8)
	button.add_theme_stylebox_override(
		"normal", ArcadeTheme.button_style(Color("d92c0ba6"), Color("ffb000"), 7, 12)
	)
	button.add_theme_stylebox_override(
		"hover", ArcadeTheme.button_style(Color("f0440dbf"), Color("ffe04a"), 9, 14)
	)
	button.add_theme_stylebox_override(
		"pressed", ArcadeTheme.button_style(Color("9f1607e6"), Color("ff8a00"), 7, 5)
	)
	button.add_theme_stylebox_override(
		"focus", ArcadeTheme.button_style(Color("f0440dbf"), Color("fff16a"), 9, 14)
	)
	button.pressed.connect(_open_player_select)
	button.focus_entered.connect(_on_menu_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	button.call_deferred("grab_focus")
	return button


func _build_exit_button() -> Button:
	var button := Button.new()
	button.name = "ExitButton"
	button.text = "EXIT"
	button.position = Vector2(780, 926.0)
	button.size = Vector2(360, 73.8)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Color("fff4ff"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("aefcff"))
	button.add_theme_color_override("font_focus_color", Color("ffffff"))
	button.add_theme_color_override("font_outline_color", Color("28002f"))
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_stylebox_override(
		"normal", ArcadeTheme.button_style(Color("b000d4a6"), Color("43f4ff"), 5, 8)
	)
	button.add_theme_stylebox_override(
		"hover", ArcadeTheme.button_style(Color("e000cfbf"), Color("aefcff"), 7, 10)
	)
	button.add_theme_stylebox_override(
		"pressed", ArcadeTheme.button_style(Color("7200a8e6"), Color("20dfea"), 5, 4)
	)
	button.add_theme_stylebox_override(
		"focus", ArcadeTheme.button_style(Color("e000cfbf"), Color("ffffff"), 7, 10)
	)
	button.pressed.connect(_on_exit_pressed)
	button.focus_entered.connect(_on_menu_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _build_controls_button() -> Button:
	var button := Button.new()
	button.name = "ControlsButton"
	button.text = "HOW TO PLAY"
	button.position = Vector2(681, 852.0)
	button.size = Vector2(558, 58)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("d4efff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("aefcff"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("061020"))
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_stylebox_override(
		"normal", ArcadeTheme.button_style(Color("062a55cc"), Color("238bd4"), 5, 7)
	)
	button.add_theme_stylebox_override(
		"hover", ArcadeTheme.button_style(Color("0a3d78e6"), Color("aefcff"), 7, 9)
	)
	button.add_theme_stylebox_override(
		"pressed", ArcadeTheme.button_style(Color("041a38e6"), Color("238bd4"), 5, 4)
	)
	button.add_theme_stylebox_override(
		"focus", ArcadeTheme.button_style(Color("0a3d78e6"), Color("fff16a"), 7, 9)
	)
	button.pressed.connect(_open_controls)
	button.focus_entered.connect(_on_menu_button_focused.bind(button))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _wire_menu_button_focus() -> void:
	controls_button.focus_neighbor_top = NodePath(".")
	controls_button.focus_neighbor_bottom = controls_button.get_path_to(start_button)
	start_button.focus_neighbor_top = start_button.get_path_to(controls_button)
	start_button.focus_neighbor_bottom = start_button.get_path_to(exit_button)
	exit_button.focus_neighbor_top = exit_button.get_path_to(start_button)
	exit_button.focus_neighbor_bottom = NodePath(".")


func _apply_attract_menu_style() -> void:
	_style_attract_menu_button(controls_button, Vector2(665, 650))
	_style_attract_menu_button(start_button, Vector2(665, 724))
	_style_attract_menu_button(exit_button, Vector2(665, 798))


func _style_attract_menu_button(button: Button, button_position: Vector2) -> void:
	button.position = button_position
	button.size = Vector2(590, 54)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color("e8f7ff"))
	button.add_theme_color_override("font_hover_color", Color("fff7cf"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("fff16a"))
	button.add_theme_color_override("font_outline_color", Color("010713"))
	button.add_theme_constant_override("outline_size", 8)
	button.add_theme_color_override("font_shadow_color", Color("01040aff"))
	button.add_theme_constant_override("shadow_offset_x", 4)
	button.add_theme_constant_override("shadow_offset_y", 4)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _selected_menu_style())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", _selected_menu_style())
	_set_menu_button_text(button, false)


func _selected_menu_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("03162be0")
	style.border_color = Color("fff16a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color("01040add")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 5)
	return style


func _set_menu_button_text(button: Button, selected: bool) -> void:
	var label := ""
	match button.name:
		"StartGameButton":
			label = "START GAME"
		"ControlsButton":
			label = "HOW TO PLAY"
		"ExitButton":
			label = "EXIT"
	button.text = ">  %s  <" % label if selected else label


func _on_menu_button_focused(button: Button) -> void:
	if _focused_menu_button == button:
		return
	var is_first_focus := _focused_menu_button == null
	if _focused_menu_button:
		_set_menu_button_text(_focused_menu_button, false)
	_focused_menu_button = button
	_set_menu_button_text(button, true)
	if not is_first_focus:
		switch_sound.play()


func _open_player_select() -> void:
	if player_select or controls_screen:
		return
	confirmation_sound.play()
	start_button.hide()
	controls_button.hide()
	exit_button.hide()
	player_select = PlayerSelectScreen.new()
	player_select.confirmed.connect(_on_player_select_confirmed)
	player_select.cancelled.connect(_on_player_select_cancelled)
	add_child(player_select)
	player_select.focus_default()


func _close_player_select() -> void:
	if not player_select:
		return
	player_select.queue_free()
	player_select = null
	start_button.show()
	controls_button.show()
	exit_button.show()
	start_button.call_deferred("grab_focus")


func handle_escape() -> bool:
	if controls_screen:
		_close_controls()
		return true
	if player_select:
		_close_player_select()
		return true
	return false


func _open_controls() -> void:
	if controls_screen or player_select:
		return
	confirmation_sound.play()
	controls_screen = HowToPlayScreenScene.new()
	controls_screen.closed.connect(_close_controls)
	add_child(controls_screen)


func _close_controls() -> void:
	if not controls_screen:
		return
	controls_screen.queue_free()
	controls_screen = null
	back_sound.play()
	controls_button.call_deferred("grab_focus")


func _on_player_select_confirmed(player_count: int) -> void:
	if not player_select:
		return
	player_select = null
	start_game_requested.emit(player_count)


func _on_player_select_cancelled() -> void:
	_close_player_select()


func _build_footer() -> void:
	var year: int = Time.get_datetime_dict_from_system().get("year", 2026)
	var footer := Label.new()
	footer.name = "FooterLabel"
	footer.text = ("%s   ◆   %s" % [FOOTER_COPYRIGHT_FORMAT % year, FOOTER_DEV_SUFFIX])
	footer.position = Vector2(0, 1000)
	footer.size = Vector2(DESIGN_SIZE.x, 34)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_font_size_override("font_size", 26)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	footer.add_theme_color_override("font_outline_color", Color("061020"))
	footer.add_theme_constant_override("outline_size", 6)
	footer.add_theme_color_override("font_shadow_color", Color("02060fcc"))
	footer.add_theme_constant_override("shadow_offset_x", 3)
	footer.add_theme_constant_override("shadow_offset_y", 3)
	add_child(footer)


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  |  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(92, 1020)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 20)
	return diagnostics


func _unhandled_input(event: InputEvent) -> void:
	if player_select or controls_screen:
		return
	if event.is_action_pressed(&"controller_start"):
		_open_player_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"action_y"):
		_open_controls()
		get_viewport().set_input_as_handled()


func _on_exit_pressed() -> void:
	exit_requested.emit()
