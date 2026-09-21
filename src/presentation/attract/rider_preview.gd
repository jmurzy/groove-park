## Small looping rider sprite for menus (attract / marquee cards).
## Example: `RiderPreview.create("SoloSkier", sheet, Vector2(280, 208))`.
class_name RiderPreview
extends AnimatedSprite2D

const FRAME_COUNT := 8
const FRAME_RATE := 10.0
const PREVIEW_SCALE := 0.62


static func create(
	rider_name: String, sprite_sheet: Texture2D, rider_position: Vector2
) -> RiderPreview:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("ride")
	frames.set_animation_loop("ride", true)
	frames.set_animation_speed("ride", FRAME_RATE)
	var sheet_width := sprite_sheet.get_width()
	var sheet_height := sprite_sheet.get_height()
	for frame_index in FRAME_COUNT:
		var frame_start := roundi(float(frame_index) * sheet_width / FRAME_COUNT)
		var frame_end := roundi(float(frame_index + 1) * sheet_width / FRAME_COUNT)
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2(frame_start, 0, frame_end - frame_start, sheet_height)
		frames.add_frame("ride", frame)

	var rider := RiderPreview.new()
	rider.name = rider_name
	rider.sprite_frames = frames
	rider.animation = "ride"
	rider.position = rider_position
	rider.scale = Vector2.ONE * PREVIEW_SCALE
	rider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rider.play()
	return rider


func set_highlighted(highlighted: bool) -> void:
	speed_scale = 1.0 if highlighted else 0.25
	modulate = Color.WHITE if highlighted else Color("8292a6")
