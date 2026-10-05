## Plays the presentation-only rescue that follows a recorded crash.
class_name CrashRescuePresenter
extends Node2D

signal crash_rescue_started
signal crash_rescue_progress_changed(progress: float)

const AIR_RESCUE_SPRITESHEET := preload("res://artwork/gameplay/air_rescue.png")
const TOBOGGAN_SPRITESHEET := preload("res://artwork/marquee/toboggan_sprite.png")

const MINIMUM_DISPLAY_DURATION := GameSession.CRASH_RESCUE_MINIMUM_DURATION

const HELICOPTER_START_OFFSET := Vector2(-1400.0, -400.0)
const HELICOPTER_CRUISE_OFFSET := Vector2(-400.0, -400.0)
const HELICOPTER_STOP_OFFSET := Vector2(-60.0, 0.0)
const HELICOPTER_CRUISE_DURATION_RATIO := 0.6
const HELICOPTER_FLOAT_START_RATIO := 0.88
const HELICOPTER_FRAME_SIZE := 400
const HELICOPTER_FRAME_COUNT := 3
const HELICOPTER_ENTRY_SCALE := 0.32
const HELICOPTER_LANDING_SCALE := 0.624
const TOBOGGAN_STOP_OFFSET := Vector2(110.0, 0.0)
const TOBOGGAN_FRAME_COUNT := 2
const TOBOGGAN_FRAME_RATE := 5.0
const TOBOGGAN_SCALE := 0.14
const TOBOGGAN_PATH_COLOR := Color("ff4f99")
const TOBOGGAN_PATH_ANGLE := deg_to_rad(15.0)
const TOBOGGAN_OFFSCREEN_MARGIN := 100.0

var _crash_site := Vector2.ZERO
var _elapsed := 0.0
var _active := false
var _designer_mode := false
var _toboggan_start_position := Vector2.ZERO
var _helicopter: AnimatedSprite2D
var _toboggan: AnimatedSprite2D


func _ready() -> void:
	name = "CrashRescue"
	z_index = 4
	_helicopter = _build_helicopter()
	_toboggan = _build_toboggan()
	add_child(_helicopter)
	add_child(_toboggan)
	visible = false


func configure(designer_mode: bool) -> void:
	_designer_mode = designer_mode


func start(crash_site: Vector2) -> bool:
	if _active:
		return false
	_crash_site = crash_site
	_elapsed = 0.0
	_active = true
	visible = true
	_helicopter.position = _crash_site + HELICOPTER_START_OFFSET
	_helicopter.scale = Vector2.ONE * HELICOPTER_ENTRY_SCALE
	_toboggan_start_position = _toboggan_offscreen_start_position()
	_toboggan.position = _toboggan_start_position
	_toboggan.frame = 0
	_toboggan.play()
	queue_redraw()
	crash_rescue_started.emit()
	return true


func advance(delta: float) -> void:
	if not _active:
		return
	_elapsed += maxf(delta, 0.0)
	_update_actor_positions()
	crash_rescue_progress_changed.emit(clampf(_elapsed / MINIMUM_DISPLAY_DURATION, 0.0, 1.0))


func is_active() -> bool:
	return _active


func _draw() -> void:
	if _active and _designer_mode:
		draw_line(
			_toboggan_start_position,
			_crash_site + TOBOGGAN_STOP_OFFSET,
			TOBOGGAN_PATH_COLOR,
			4.0,
			true
		)


func crash_site() -> Vector2:
	return _crash_site


func helicopter_position() -> Vector2:
	return _helicopter.position


func toboggan_position() -> Vector2:
	return _toboggan.position


func _build_helicopter() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"fly")
	frames.set_animation_speed(&"fly", 8.0)
	frames.set_animation_loop(&"fly", true)
	for column in range(HELICOPTER_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = AIR_RESCUE_SPRITESHEET
		frame.region = Rect2(
			column * HELICOPTER_FRAME_SIZE, 0, HELICOPTER_FRAME_SIZE, HELICOPTER_FRAME_SIZE
		)
		frames.add_frame(&"fly", frame)
	var helicopter := AnimatedSprite2D.new()
	helicopter.name = "HelicopterMedic"
	helicopter.sprite_frames = frames
	helicopter.animation = &"fly"
	helicopter.scale = Vector2.ONE * HELICOPTER_ENTRY_SCALE
	helicopter.play()
	return helicopter


func _build_toboggan() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"ski")
	frames.set_animation_speed(&"ski", TOBOGGAN_FRAME_RATE)
	frames.set_animation_loop(&"ski", true)
	var frame_width := TOBOGGAN_SPRITESHEET.get_width() / TOBOGGAN_FRAME_COUNT
	for frame_index in range(TOBOGGAN_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = TOBOGGAN_SPRITESHEET
		frame.region = Rect2(
			frame_index * frame_width, 0, frame_width, TOBOGGAN_SPRITESHEET.get_height()
		)
		frames.add_frame(&"ski", frame)
	var toboggan := AnimatedSprite2D.new()
	toboggan.name = "SkierMedicWithStretcher"
	toboggan.sprite_frames = frames
	toboggan.animation = &"ski"
	toboggan.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	toboggan.scale = Vector2.ONE * TOBOGGAN_SCALE
	toboggan.play()
	return toboggan


func _toboggan_offscreen_start_position() -> Vector2:
	var stop_position := _crash_site + TOBOGGAN_STOP_OFFSET
	var local_to_screen := get_global_transform_with_canvas()
	var screen_stop_position := local_to_screen * stop_position
	var viewport_rect := get_viewport().get_visible_rect()
	var direction := Vector2.from_angle(TOBOGGAN_PATH_ANGLE)
	var right_edge_distance := (viewport_rect.end.x - screen_stop_position.x) / direction.x
	var bottom_edge_distance := (viewport_rect.end.y - screen_stop_position.y) / direction.y
	var screen_start_position := (
		screen_stop_position
		+ direction * (minf(right_edge_distance, bottom_edge_distance) + TOBOGGAN_OFFSCREEN_MARGIN)
	)
	return local_to_screen.affine_inverse() * screen_start_position


func _update_actor_positions() -> void:
	var progress := clampf(_elapsed / MINIMUM_DISPLAY_DURATION, 0.0, 1.0)
	var helicopter_offset: Vector2
	if progress < HELICOPTER_CRUISE_DURATION_RATIO:
		# Enter level through the left quarter of the view before beginning the landing descent.
		helicopter_offset = HELICOPTER_START_OFFSET.lerp(
			HELICOPTER_CRUISE_OFFSET, progress / HELICOPTER_CRUISE_DURATION_RATIO
		)
	else:
		var descent_progress := (
			(progress - HELICOPTER_CRUISE_DURATION_RATIO) / (1.0 - HELICOPTER_CRUISE_DURATION_RATIO)
		)
		helicopter_offset = HELICOPTER_CRUISE_OFFSET.lerp(HELICOPTER_STOP_OFFSET, descent_progress)
	if progress > HELICOPTER_FLOAT_START_RATIO:
		var landing_progress := (
			(progress - HELICOPTER_FLOAT_START_RATIO) / (1.0 - HELICOPTER_FLOAT_START_RATIO)
		)
		# The helicopter begins to float only once it is near the landing line.
		helicopter_offset.y -= sin(landing_progress * PI) * 12.0
	_helicopter.position = _crash_site + helicopter_offset
	_helicopter.scale = (
		Vector2.ONE * lerpf(HELICOPTER_ENTRY_SCALE, HELICOPTER_LANDING_SCALE, progress)
	)
	_toboggan.position = _toboggan_start_position.lerp(
		_crash_site + TOBOGGAN_STOP_OFFSET, ease(progress, -1.5)
	)
	if progress >= 1.0 and _toboggan.is_playing():
		_toboggan.stop()


func finish() -> void:
	if not _active:
		return
	_active = false
	queue_redraw()
