## Animated skier and snowboarder loop for the marquee foreground.
class_name MarqueeRiderLoop
extends Node2D

const DESIGN_WIDTH := 1920.0
const SKIER_SHEET := preload("res://artwork/marquee/skiier_sprite.png")
const SNOWBOARDER_SHEET := preload("res://artwork/marquee/snowboarder_sprite.png")
const FRAME_COUNT := 8
const FRAME_RATE := 10.0
const SPEED := 150.0
const SCALE := 0.34
const OFFSCREEN_MARGIN := 160.0
const SNOWBOARDER_LEAD_DISTANCE := 280.0

var _elapsed := 0.0
var _skier: AnimatedSprite2D
var _snowboarder: AnimatedSprite2D


func _ready() -> void:
	_skier = _build_rider("Skier", SKIER_SHEET)
	add_child(_skier)
	_skier.play()
	_snowboarder = _build_rider("Snowboarder", SNOWBOARDER_SHEET)
	add_child(_snowboarder)
	_snowboarder.play()


func _process(delta: float) -> void:
	_elapsed += delta
	var travel_width := DESIGN_WIDTH + OFFSCREEN_MARGIN * 2.0
	_skier.position.x = -OFFSCREEN_MARGIN + fposmod(_elapsed * SPEED, travel_width)
	_snowboarder.position.x = (
		-OFFSCREEN_MARGIN + fposmod(_elapsed * SPEED + SNOWBOARDER_LEAD_DISTANCE, travel_width)
	)


func _build_rider(rider_name: String, sprite_sheet: Texture2D) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("ski")
	frames.set_animation_loop("ski", true)
	frames.set_animation_speed("ski", FRAME_RATE)
	var sheet_width := sprite_sheet.get_width()
	var sheet_height := sprite_sheet.get_height()
	for frame_index in FRAME_COUNT:
		var frame_start := roundi(float(frame_index) * sheet_width / FRAME_COUNT)
		var frame_end := roundi(float(frame_index + 1) * sheet_width / FRAME_COUNT)
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2(frame_start, 0, frame_end - frame_start, sheet_height)
		frames.add_frame("ski", frame)
	var rider := AnimatedSprite2D.new()
	rider.name = rider_name
	rider.sprite_frames = frames
	rider.animation = "ski"
	rider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rider.scale = Vector2.ONE * SCALE
	rider.position.y = 131
	return rider
