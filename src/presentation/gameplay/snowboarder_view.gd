class_name SnowboarderView
extends RiderViewBase

const BOARD_BASELINE := 820.0

const CARVE_HEEL_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_carve_heel_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_carve_heel_f1.png"),
]
const CARVE_TOE_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_carve_toe_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_carve_toe_f1.png"),
]
const CELEBRATION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_celebration_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_celebration_f1.png"),
	preload("res://artwork/players/snowboarder/snowboarder_celebration_f2.png"),
]
const COMPRESSION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_compression_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_compression_f1.png"),
	preload("res://artwork/players/snowboarder/snowboarder_compression_f2.png"),
]
const CRASH_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_crash_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_crash_f1.png"),
	preload("res://artwork/players/snowboarder/snowboarder_crash_f2.png"),
	preload("res://artwork/players/snowboarder/snowboarder_crash_f3.png"),
]
const DEEP_LANDING_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_deep_landing_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_deep_landing_f1.png"),
]
const GRAB_HOLD_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_grab_hold_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_grab_hold_f1.png"),
]
const GRAB_REACH_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_grab_reach_f0.png"),
]
const GRAB_TWEAK_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_grab_tweak_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_grab_tweak_f1.png"),
]
const LANDING_PREP_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_landing_prep_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_landing_prep_f1.png"),
]
const NEUTRAL_AIR_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_neutral_air_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_neutral_air_f1.png"),
]
const NEUTRAL_GLIDE_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_neutral_glide_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_neutral_glide_f1.png"),
	preload("res://artwork/players/snowboarder/snowboarder_neutral_glide_f2.png"),
	preload("res://artwork/players/snowboarder/snowboarder_neutral_glide_f3.png"),
]
const SKETCHY_RECOVERY_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_sketchy_recovery_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_sketchy_recovery_f1.png"),
	preload("res://artwork/players/snowboarder/snowboarder_sketchy_recovery_f2.png"),
	preload("res://artwork/players/snowboarder/snowboarder_sketchy_recovery_f3.png"),
]
const TAKEOFF_EXTENSION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_takeoff_extension_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_takeoff_extension_f1.png"),
]
const TUCK_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/snowboarder/snowboarder_tuck_f0.png"),
	preload("res://artwork/players/snowboarder/snowboarder_tuck_f1.png"),
]


func _ready() -> void:
	_setup_sprite(BOARD_BASELINE, &"SnowboarderView")
	_sprite.sprite_frames = _build_frames()
	_play(&"neutral_glide")


func update_from_state(state: RiderState, screen_position: Vector2, ground_rotation: float) -> void:
	position = screen_position
	rotation = ground_rotation
	_play(_ground_animation(state))


func _ground_animation(state: RiderState) -> StringName:
	if state.tuck_active:
		return &"tuck"
	if state.edge_active or state.brake_active:
		return &"carve_heel" if state.heading.y < 0.0 else &"carve_toe"
	return &"neutral_glide"


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"neutral_glide", NEUTRAL_GLIDE_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"tuck", TUCK_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"carve_heel", CARVE_HEEL_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"carve_toe", CARVE_TOE_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"compression", COMPRESSION_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"takeoff_extension", TAKEOFF_EXTENSION_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"neutral_air", NEUTRAL_AIR_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"grab_reach", GRAB_REACH_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"grab_hold", GRAB_HOLD_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"grab_tweak", GRAB_TWEAK_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"landing_prep", LANDING_PREP_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"deep_landing", DEEP_LANDING_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"sketchy_recovery", SKETCHY_RECOVERY_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"crash", CRASH_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"celebration", CELEBRATION_FRAMES, LOOP_FPS, true)
	return frames
