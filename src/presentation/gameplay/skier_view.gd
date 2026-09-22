## Animated skier sprite: maps ground/air/grab/landing state to clips and rotates
## to `orientation` while airborne.
class_name SkierView
extends RiderViewBase

const SKI_BASELINE := 820.0

const CARVE_DOWNHILL_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_carve_downhill_f0.png"),
	preload("res://artwork/players/skier/skier_carve_downhill_f1.png"),
]
const CARVE_UPHILL_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_carve_uphill_f0.png"),
	preload("res://artwork/players/skier/skier_carve_uphill_f1.png"),
]
const CELEBRATION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_celebration_f0.png"),
	preload("res://artwork/players/skier/skier_celebration_f1.png"),
	preload("res://artwork/players/skier/skier_celebration_f2.png"),
]
const COMPRESSION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_compression_f0.png"),
	preload("res://artwork/players/skier/skier_compression_f1.png"),
	preload("res://artwork/players/skier/skier_compression_f2.png"),
]
const CRASH_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_crash_f0.png"),
	preload("res://artwork/players/skier/skier_crash_f1.png"),
	preload("res://artwork/players/skier/skier_crash_f2.png"),
	preload("res://artwork/players/skier/skier_crash_f3.png"),
]
const DEEP_LANDING_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_deep_landing_f0.png"),
	preload("res://artwork/players/skier/skier_deep_landing_f1.png"),
]
const GRAB_HOLD_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_grab_hold_f0.png"),
	preload("res://artwork/players/skier/skier_grab_hold_f1.png"),
]
const GRAB_REACH_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_grab_reach_f0.png"),
]
const GRAB_TWEAK_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_grab_tweak_f0.png"),
	preload("res://artwork/players/skier/skier_grab_tweak_f1.png"),
]
const LANDING_PREP_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_landing_prep_f0.png"),
	preload("res://artwork/players/skier/skier_landing_prep_f1.png"),
]
const NEUTRAL_AIR_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_neutral_air_f0.png"),
	preload("res://artwork/players/skier/skier_neutral_air_f1.png"),
]
const NEUTRAL_GLIDE_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_neutral_glide_f0.png"),
	preload("res://artwork/players/skier/skier_neutral_glide_f1.png"),
	preload("res://artwork/players/skier/skier_neutral_glide_f2.png"),
	preload("res://artwork/players/skier/skier_neutral_glide_f3.png"),
]
const SKETCHY_RECOVERY_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_sketchy_recovery_f0.png"),
	preload("res://artwork/players/skier/skier_sketchy_recovery_f1.png"),
	preload("res://artwork/players/skier/skier_sketchy_recovery_f2.png"),
	preload("res://artwork/players/skier/skier_sketchy_recovery_f3.png"),
]
const TAKEOFF_EXTENSION_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_takeoff_extension_f0.png"),
	preload("res://artwork/players/skier/skier_takeoff_extension_f1.png"),
]
const TUCK_FRAMES: Array[Texture2D] = [
	preload("res://artwork/players/skier/skier_tuck_f0.png"),
	preload("res://artwork/players/skier/skier_tuck_f1.png"),
]


func _ready() -> void:
	_setup_sprite(SKI_BASELINE, &"SkierView")
	_sprite.sprite_frames = _build_frames()
	_play(&"neutral_glide")


func update_from_state(state: RiderState, world_position: Vector2, ground_rotation: float) -> void:
	position = world_position
	rotation = state.orientation if state.phase == RiderState.Phase.AIRBORNE else ground_rotation
	if state.landing_resolved or is_playing_landing_animation():
		play_landing_animation(_landing_animation_for_state(state))
		return
	_play(_animation_for_state(state))
	if state.ground_velocity.is_zero_approx():
		pause_idle_animation()


func _landing_animation_for_state(state: RiderState) -> StringName:
	if state.phase == RiderState.Phase.CRASHED:
		return &"crash"
	if state.phase == RiderState.Phase.RECOVERING:
		return &"sketchy_recovery"
	return &"celebration"


func _animation_for_state(state: RiderState) -> StringName:
	var animation: StringName = &"neutral_glide"
	if state.phase == RiderState.Phase.CRASHED:
		animation = &"crash"
	elif state.phase == RiderState.Phase.RECOVERING:
		animation = &"sketchy_recovery"
	elif state.phase == RiderState.Phase.LANDED:
		animation = &"deep_landing"
	elif state.phase == RiderState.Phase.AIRBORNE:
		if state.airtime < 0.12:
			animation = &"takeoff_extension"
		elif state.landing_prep_active:
			animation = &"landing_prep"
		elif state.grab_reach_active:
			animation = &"grab_reach"
		elif state.tweak_active:
			animation = &"grab_tweak"
		elif state.trick_tracker.grab_active:
			animation = &"grab_hold"
		else:
			animation = &"neutral_air"
	elif state.compression_active:
		animation = &"compression"
	elif state.tuck_active:
		animation = &"tuck"
	elif state.edge_active or state.brake_active:
		animation = &"carve_uphill" if state.heading.y < 0.0 else &"carve_downhill"
	return animation


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"neutral_glide", NEUTRAL_GLIDE_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"tuck", TUCK_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"carve_downhill", CARVE_DOWNHILL_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"carve_uphill", CARVE_UPHILL_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"compression", COMPRESSION_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"takeoff_extension", TAKEOFF_EXTENSION_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"neutral_air", NEUTRAL_AIR_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"grab_reach", GRAB_REACH_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"grab_hold", GRAB_HOLD_FRAMES, LOOP_FPS, true)
	_add_animation(frames, &"grab_tweak", GRAB_TWEAK_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"landing_prep", LANDING_PREP_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"deep_landing", DEEP_LANDING_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"sketchy_recovery", SKETCHY_RECOVERY_FRAMES, LOOP_FPS, false)
	_add_animation(frames, &"crash", CRASH_FRAMES, TRANSITION_FPS, false)
	_add_animation(frames, &"celebration", CELEBRATION_FRAMES, LOOP_FPS, false)
	return frames
