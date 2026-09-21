## Looping waving Heavenly logomark sprite.
## Example: `HeavenlyLogomark.create(0.15)` then position it.
class_name HeavenlyLogomark
extends AnimatedSprite2D

const LOGOMARK_SPRITE := preload("res://artwork/features/heavenly_logomark_sprite.png")
const FRAME_COUNT := 4
const FRAME_RATE := 2.5


static func create(logomark_scale: float = 1.0) -> HeavenlyLogomark:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("wave")
	frames.set_animation_loop("wave", true)
	frames.set_animation_speed("wave", FRAME_RATE)
	var frame_width := LOGOMARK_SPRITE.get_width() / FRAME_COUNT
	for frame_index in FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = LOGOMARK_SPRITE
		frame.region = Rect2(
			frame_index * frame_width, 0, frame_width, LOGOMARK_SPRITE.get_height()
		)
		frames.add_frame("wave", frame)

	var logomark := HeavenlyLogomark.new()
	logomark.name = "HeavenlyLogomark"
	logomark.sprite_frames = frames
	logomark.animation = "wave"
	logomark.scale = Vector2.ONE * logomark_scale
	logomark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logomark.play()
	return logomark
