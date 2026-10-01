## Draws and animates the non-interactive layer of the primary attract screen.
class_name AttractBackdrop
extends Control

const DESIGN_SIZE := Vector2(1920, 1080)
const PRIMARY_BACKGROUND := preload("res://artwork/attract/primary_bg.png")
const HEAVENLY_LOGO := preload("res://artwork/attract/heavenly_logo_no_tahoe.png")
const GONDOLA_SHEET := preload("res://artwork/attract/gondola_sprite.png")
const SnowfallLayerScene := preload("res://src/presentation/effects/snowfall_layer.gd")
const LOGO_RECT := Rect2(289, 20, 1387, 480)
const LOGO_SUBTITLE_RECT := Rect2(276, 328, 1387, 62)
const GONDOLA_FRAME_COLUMNS := 4
const GONDOLA_FRAME_ROWS := 2
const GONDOLA_FRAME_RATE := 6.0
const GONDOLA_SCALE := 0.36
const GONDOLA_LANE := Rect2(712, 448, 497, 0)
const GONDOLA_SPEED := 65.0
const SNOWFLAKE_COUNT := 84
const SNOW_SAFE_INSET := 60.0
const ARCADE_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const FOOTER_COPYRIGHT_FORMAT := "© %d JULIA & JAKE MURZY - ALL RIGHTS RESERVED"
const FOOTER_DEV_SUFFIX := "DEV BUILD: BUT EXPECT NO BUGS!"
const FOOTER_AGS_SUFFIX := "AGS BUILD"
const FOOTER_WEB_SUFFIX := "WEB BUILD"
const LOGO_SUBTITLE_WAVE_SHADER := """
shader_type canvas_item;

void vertex() {
	VERTEX.y += round(sin(VERTEX.x * 0.035 + TIME * 2.0) * 2.0);
}
"""

var screen_index := 0
var show_diagnostics := false
var _elapsed := 0.0
var _gondola: AnimatedSprite2D


func _ready() -> void:
	name = "AttractBackdrop"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_build_logo_subtitle())
	_gondola = _build_gondola()
	add_child(_gondola)
	_gondola.play()
	add_child(_build_footer())
	add_child(SnowfallLayerScene.create(DESIGN_SIZE, SNOWFLAKE_COUNT, SNOW_SAFE_INSET))
	if show_diagnostics:
		add_child(_build_diagnostics())
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(PRIMARY_BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	draw_texture_rect(HEAVENLY_LOGO, LOGO_RECT, false)


func _process(delta: float) -> void:
	_elapsed += delta
	_gondola.position.x = (
		GONDOLA_LANE.position.x + pingpong(_elapsed * GONDOLA_SPEED, GONDOLA_LANE.size.x)
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
	sprite.position = GONDOLA_LANE.position
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
	subtitle_font.spacing_glyph = 12
	subtitle_font.spacing_space = -14
	subtitle.add_theme_font_override("font", subtitle_font)
	subtitle.add_theme_font_size_override("font_size", 50)
	subtitle.add_theme_color_override("font_color", Color("aefcff"))
	subtitle.add_theme_constant_override("outline_size", 2)
	subtitle.add_theme_color_override("font_outline_color", Color("062a3a"))
	subtitle.add_theme_color_override("font_shadow_color", Color("42eaffcc"))
	subtitle.add_theme_constant_override("shadow_outline_size", 5)
	var shader := Shader.new()
	shader.code = LOGO_SUBTITLE_WAVE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	subtitle.material = material
	return subtitle


func _build_footer() -> Label:
	var year: int = Time.get_datetime_dict_from_system().get("year", 2026)
	var footer := Label.new()
	footer.name = "FooterLabel"
	var build_suffix := FOOTER_DEV_SUFFIX
	if OS.has_feature("ags"):
		build_suffix = FOOTER_AGS_SUFFIX
	elif OS.has_feature("web"):
		build_suffix = FOOTER_WEB_SUFFIX
	footer.text = "%s   ◆   %s" % [FOOTER_COPYRIGHT_FORMAT % year, build_suffix]
	footer.position = Vector2(0, 1000)
	footer.size = Vector2(DESIGN_SIZE.x, 34)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 26)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	footer.add_theme_color_override("font_outline_color", Color("061020"))
	footer.add_theme_constant_override("outline_size", 6)
	footer.add_theme_color_override("font_shadow_color", Color("02060fcc"))
	footer.add_theme_constant_override("shadow_offset_x", 3)
	footer.add_theme_constant_override("shadow_offset_y", 3)
	return footer


func _build_diagnostics() -> Label:
	var diagnostics := Label.new()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	diagnostics.text = "Godot screen %d  |  %d x %d" % [screen_index, screen_size.x, screen_size.y]
	diagnostics.position = Vector2(92, 1020)
	diagnostics.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	diagnostics.add_theme_font_size_override("font_size", 20)
	return diagnostics
