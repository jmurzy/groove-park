## Shared rider-sprite base: scaled AnimatedSprite2D setup, clip switching, and
## one-shot landing animations. Used via SkierView / SnowboarderView.
##
## Carve clip contract: each rider names their two carving clips differently, but
## the semantics are shared. `heading.y < 0` (into the slope / checking speed) maps
## to skier `carve_uphill` and snowboarder `carve_heel` (CARVE_A); `heading.y >= 0`
## (with the fall line) maps to skier `carve_downhill` and snowboarder `carve_toe`
## (CARVE_B). Keep this mapping in sync across SkierView, SnowboarderView, and
## RiderDemoPanel.
class_name RiderViewBase
extends Node2D

const CANVAS_SIZE := Vector2(1024, 1024)
# The camera expands the 724px-tall course to the 1080px cabinet viewport.
const SPRITE_SCALE := 0.0846
const LOOP_FPS := 9.0
const TRANSITION_FPS := 12.0

var _sprite: AnimatedSprite2D
var _show_source_bounds := false
var _repeat_crash := false
var _landing_animation_active := false
var _landing_animation: StringName
var _landing_animation_cycles := 0


func play_preview(animation_name: StringName) -> void:
	_play(animation_name)


func play_landing_animation(animation_name: StringName) -> void:
	if _sprite == null or _landing_animation_active:
		return
	_landing_animation_active = true
	_landing_animation = animation_name
	_landing_animation_cycles = 0
	_sprite.play(animation_name)


func is_playing_landing_animation() -> bool:
	return _landing_animation_active


func reset_presentation() -> void:
	_landing_animation_active = false
	_landing_animation = &""
	_landing_animation_cycles = 0


func set_show_source_bounds(enabled: bool) -> void:
	_show_source_bounds = enabled
	queue_redraw()


func _setup_sprite(baseline: float, view_name: StringName) -> void:
	name = String(view_name)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = Vector2(-CANVAS_SIZE.x * 0.5, -baseline) * SPRITE_SCALE
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	add_child(_sprite)
	queue_redraw()


func _draw() -> void:
	if not _show_source_bounds or _sprite == null:
		return
	# Show the complete source canvas, including transparent padding, at its rendered size.
	draw_rect(Rect2(_sprite.position, CANVAS_SIZE * SPRITE_SCALE), Color("ff00ff"), false, 2.0)
	# The sprite is positioned so this line is the source-art baseline at the rider's world position.
	draw_line(
		Vector2(_sprite.position.x, 0.0),
		Vector2(_sprite.position.x + CANVAS_SIZE.x * SPRITE_SCALE, 0.0),
		Color("ffff00"),
		2.0
	)


func _play(animation_name: StringName) -> void:
	if _sprite == null:
		return
	if _sprite.animation == animation_name:
		if not _sprite.is_playing():
			_sprite.play()
		return
	_repeat_crash = animation_name == &"crash"
	_sprite.play(animation_name)


func pause_idle_animation() -> void:
	if _sprite != null and _sprite.animation == &"neutral_glide":
		_sprite.pause()


func _on_sprite_animation_finished() -> void:
	if _sprite.animation == _landing_animation and _landing_animation_active:
		_landing_animation_cycles += 1
		if _landing_animation_cycles < 2:
			_sprite.frame = 0
			_sprite.play()
		else:
			_sprite.pause()
		return
	if _sprite.animation != &"crash" or not _repeat_crash:
		return
	_repeat_crash = false
	_sprite.frame = 0
	_sprite.play()


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	animation_frames: Array[Texture2D],
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for frame in animation_frames:
		frames.add_frame(animation_name, frame)
