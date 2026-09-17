class_name PrimaryScreen
extends Control

signal start_game_requested
signal exit_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const PRIMARY_BACKGROUND := preload("res://artwork/primary_bg.png")
const HEAVENLY_LOGO := preload("res://artwork/heavenly_logo_no_tahoe.png")
const GONDOLA_SHEET := preload("res://artwork/gondola_sprite.png")
const SNOWFLAKE_TEXTURE := preload("res://artwork/snowflake.png")
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
const ARCADE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LOGO_SUBTITLE_WAVE_SHADER := """
shader_type canvas_item;

void vertex() {
	VERTEX.y += round(sin(VERTEX.x * 0.035 + TIME * 2.0) * 2.0);
}
"""

@export var screen_index: int = 0
var show_diagnostics := false
var liftie_state_service
var logo_bob_time := 0.0
var logo_subtitle: Label
var gondola: AnimatedSprite2D
var _snowflakes: Array[Dictionary] = []
var _snow_random := RandomNumberGenerator.new()


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
	_build_snow()
	var start_button := _build_start_button()
	add_child(start_button)
	_animate_start_button(start_button)
	add_child(_build_exit_button())
	if show_diagnostics:
		add_child(_build_diagnostics())
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(PRIMARY_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	draw_texture_rect(HEAVENLY_LOGO, LOGO_RECT, false)


func _process(delta: float) -> void:
	logo_bob_time += delta
	_update_snow(delta)
	gondola.position.x = GONDOLA_LANE.position.x + pingpong(logo_bob_time * GONDOLA_SPEED, GONDOLA_LANE.size.x)
	queue_redraw()


func _build_snow() -> void:
	_snow_random.seed = 2026
	for index in SNOWFLAKE_COUNT:
		var snowflake := Sprite2D.new()
		snowflake.name = "Snowflake%d" % (index + 1)
		snowflake.texture = SNOWFLAKE_TEXTURE
		snowflake.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		snowflake.position = Vector2(
			_snow_random.randf_range(-40.0, DESIGN_SIZE.x + 40.0),
			_snow_random.randf_range(-80.0, DESIGN_SIZE.y + 40.0)
		)
		snowflake.rotation = _snow_random.randf_range(0.0, TAU)
		var snowflake_scale := _snow_random.randf_range(0.035, 0.08)
		snowflake.scale = Vector2.ONE * snowflake_scale
		add_child(snowflake)
		_snowflakes.append({
			"node": snowflake,
			"velocity": Vector2(_snow_random.randf_range(-3.0, 7.0), _snow_random.randf_range(24.0, 36.0)),
			"spin": _snow_random.randf_range(-0.2, 0.2),
		})


func _update_snow(delta: float) -> void:
	for snowflake_data in _snowflakes:
		var snowflake: Sprite2D = snowflake_data.node
		snowflake.position += snowflake_data.velocity * delta
		snowflake.rotation += snowflake_data.spin * delta
		if snowflake.position.y > DESIGN_SIZE.y + 50.0:
			snowflake.position = Vector2(_snow_random.randf_range(-40.0, DESIGN_SIZE.x + 40.0), -50.0)


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
	button.position = Vector2(681, 786.1)
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
	button.add_theme_stylebox_override("normal", _button_style(Color("d92c0ba6"), Color("ffb000"), 7, 12))
	button.add_theme_stylebox_override("hover", _button_style(Color("f0440de6"), Color("ffe04a"), 9, 14))
	button.add_theme_stylebox_override("pressed", _button_style(Color("9f1607bf"), Color("ff8a00"), 7, 5))
	button.add_theme_stylebox_override("focus", _button_style(Color("f0440de6"), Color("fff16a"), 9, 14))
	button.pressed.connect(_on_start_game_pressed)
	button.call_deferred("grab_focus")
	return button


func _build_exit_button() -> Button:
	var button := Button.new()
	button.name = "ExitButton"
	button.text = "EXIT"
	button.position = Vector2(780, 918.1)
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
	button.add_theme_stylebox_override("normal", _button_style(Color("b000d4a6"), Color("43f4ff"), 5, 8))
	button.add_theme_stylebox_override("hover", _button_style(Color("e000cfe6"), Color("aefcff"), 7, 10))
	button.add_theme_stylebox_override("pressed", _button_style(Color("7200a8bf"), Color("20dfea"), 5, 4))
	button.add_theme_stylebox_override("focus", _button_style(Color("e000cfe6"), Color("ffffff"), 7, 10))
	button.pressed.connect(_on_exit_pressed)
	return button


func _animate_start_button(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * 1.035, 0.7)
	tween.parallel().tween_property(button, "modulate", Color("fff4cf"), 0.7)
	tween.tween_property(button, "scale", Vector2.ONE, 0.7)
	tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.7)


func _button_style(background: Color, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color("b0000000")
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 9)
	return style


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  |  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(92, 1020)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 20)
	return diagnostics


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"controller_start"):
		_on_start_game_pressed()
		get_viewport().set_input_as_handled()


func _on_start_game_pressed() -> void:
	start_game_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()
