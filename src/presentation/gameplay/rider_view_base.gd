class_name RiderViewBase
extends Node2D

const CANVAS_SIZE := Vector2(1024, 1024)
# The camera expands the 724px-tall course to the 1080px cabinet viewport.
const SPRITE_SCALE := 0.094
const LOOP_FPS := 9.0
const TRANSITION_FPS := 12.0

var _sprite: AnimatedSprite2D
var _repeat_crash := false


func play_preview(animation_name: StringName) -> void:
	_play(animation_name)


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


func _play(animation_name: StringName) -> void:
	if _sprite == null:
		return
	if _sprite.animation == animation_name:
		return
	_repeat_crash = animation_name == &"crash"
	_sprite.play(animation_name)


func _on_sprite_animation_finished() -> void:
	if _sprite.animation != &"crash" or not _repeat_crash:
		return
	_repeat_crash = false
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
