## Looping waving Heavenly logotype sprite.
## Example: `HeavenlyLogotype.create(0.12)` then position it.
class_name HeavenlyLogotype
extends AnimatedSprite2D

const LOGOTYPE_SPRITE := preload("res://artwork/features/heavenly_logotype_sprite.png")
const FRAME_COLUMNS := 2
const FRAME_ROWS := 2
const FRAME_RATE := 2.5
const TOP_ROW_OFFSET := 27.0


static func create(logotype_scale: float = 1.0) -> HeavenlyLogotype:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("wave")
	frames.set_animation_loop("wave", true)
	frames.set_animation_speed("wave", FRAME_RATE)
	var frame_size := Vector2(
		LOGOTYPE_SPRITE.get_width() / float(FRAME_COLUMNS),
		LOGOTYPE_SPRITE.get_height() / float(FRAME_ROWS)
	)
	for row in FRAME_ROWS:
		for column in FRAME_COLUMNS:
			var frame := AtlasTexture.new()
			frame.atlas = LOGOTYPE_SPRITE
			frame.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			var frame_offset := Vector2.ZERO
			if row == 0:
				frame_offset.y = -TOP_ROW_OFFSET
			frame.margin = Rect2(frame_offset, Vector2.ZERO)
			frames.add_frame("wave", frame)

	var logotype := HeavenlyLogotype.new()
	logotype.name = "HeavenlyLogotype"
	logotype.sprite_frames = frames
	logotype.animation = "wave"
	logotype.scale = Vector2.ONE * logotype_scale
	logotype.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logotype.play()
	return logotype
