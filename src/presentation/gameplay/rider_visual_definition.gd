## Immutable sprite and semantic clip configuration for one rider presentation.
class_name RiderVisualDefinition
extends Resource

const LOOP_FPS := 9.0
const TRANSITION_FPS := 12.0

var view_name: StringName
var baseline := 820.0
var carve_a_animation: StringName
var carve_b_animation: StringName
var spin_regular_negative: StringName
var spin_regular_positive: StringName
var spin_tweak_negative: StringName
var spin_tweak_positive: StringName
var _animations: Array[Dictionary] = []
var _sprite_frames: SpriteFrames

static var _skier_definition: RiderVisualDefinition
static var _snowboarder_definition: RiderVisualDefinition


static func skier() -> RiderVisualDefinition:
	if _skier_definition == null:
		_skier_definition = _create(
			&"SkierView",
			"skier",
			&"carve_uphill",
			&"carve_downhill",
			&"spin_regular_left",
			&"spin_regular_right",
			&"spin_tweak_left",
			&"spin_tweak_right"
		)
	return _skier_definition


static func snowboarder() -> RiderVisualDefinition:
	if _snowboarder_definition == null:
		_snowboarder_definition = _create(
			&"SnowboarderView",
			"snowboarder",
			&"carve_heel",
			&"carve_toe",
			&"spin_regular_backside",
			&"spin_regular_frontside",
			&"spin_tweak_backside",
			&"spin_tweak_frontside"
		)
	return _snowboarder_definition


static func warm() -> void:
	skier()
	snowboarder()


static func _create(
	next_view_name: StringName,
	rider_id: String,
	next_carve_a: StringName,
	next_carve_b: StringName,
	next_spin_regular_negative: StringName,
	next_spin_regular_positive: StringName,
	next_spin_tweak_negative: StringName,
	next_spin_tweak_positive: StringName
) -> RiderVisualDefinition:
	var definition := RiderVisualDefinition.new()
	definition.view_name = next_view_name
	definition.carve_a_animation = next_carve_a
	definition.carve_b_animation = next_carve_b
	definition.spin_regular_negative = next_spin_regular_negative
	definition.spin_regular_positive = next_spin_regular_positive
	definition.spin_tweak_negative = next_spin_tweak_negative
	definition.spin_tweak_positive = next_spin_tweak_positive
	definition._add_indexed_animation(
		rider_id, &"neutral_glide", "neutral_glide", 4, LOOP_FPS, true
	)
	definition._add_indexed_animation(rider_id, &"tuck", "tuck", 2, LOOP_FPS, true)
	definition._add_indexed_animation(
		rider_id, next_carve_a, String(next_carve_a), 2, LOOP_FPS, true
	)
	definition._add_indexed_animation(
		rider_id, next_carve_b, String(next_carve_b), 2, LOOP_FPS, true
	)
	definition._add_indexed_animation(
		rider_id, &"compression", "compression", 3, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(
		rider_id, &"takeoff_extension", "takeoff_extension", 2, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(rider_id, &"neutral_air", "neutral_air", 2, LOOP_FPS, true)
	definition._add_spin_animation(rider_id, next_spin_regular_negative)
	definition._add_spin_animation(rider_id, next_spin_regular_positive)
	definition._add_spin_animation(rider_id, next_spin_tweak_negative)
	definition._add_spin_animation(rider_id, next_spin_tweak_positive)
	definition._add_indexed_animation(
		rider_id, &"grab_reach", "grab_reach", 1, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(rider_id, &"grab_hold", "grab_hold", 2, LOOP_FPS, true)
	definition._add_indexed_animation(
		rider_id, &"grab_tweak", "grab_tweak", 2, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(
		rider_id, &"landing_prep", "landing_prep", 2, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(
		rider_id, &"deep_landing", "deep_landing", 2, TRANSITION_FPS, false
	)
	definition._add_indexed_animation(
		rider_id, &"sketchy_recovery", "sketchy_recovery", 4, LOOP_FPS, false
	)
	definition._add_indexed_animation(rider_id, &"crash", "crash", 4, TRANSITION_FPS, false)
	definition._add_indexed_animation(rider_id, &"celebration", "celebration", 3, LOOP_FPS, false)
	return definition


func build_sprite_frames() -> SpriteFrames:
	if _sprite_frames != null:
		return _sprite_frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation in _animations:
		var animation_name: StringName = animation["name"]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, animation["fps"])
		frames.set_animation_loop(animation_name, animation["loop"])
		for frame: Texture2D in animation["frames"]:
			frames.add_frame(animation_name, frame)
	_sprite_frames = frames
	return _sprite_frames


func _add_indexed_animation(
	rider_id: String,
	animation_name: StringName,
	source_name: String,
	count: int,
	fps: float,
	loop: bool
) -> void:
	var frames: Array[Texture2D] = []
	for frame_index in count:
		frames.append(_load_texture(rider_id, "%s_f%d" % [source_name, frame_index]))
	_add_animation(animation_name, frames, fps, loop)


func _add_spin_animation(rider_id: String, animation_name: StringName) -> void:
	var frames: Array[Texture2D] = []
	for spin_frame in 8:
		var angle := spin_frame * 45
		frames.append(_load_texture(rider_id, "%s_%03d" % [animation_name, angle]))
	_add_animation(animation_name, frames, TRANSITION_FPS, false)


func _add_animation(
	animation_name: StringName, frames: Array[Texture2D], fps: float, loop: bool
) -> void:
	_animations.append({"name": animation_name, "frames": frames, "fps": fps, "loop": loop})


func _load_texture(rider_id: String, frame_name: String) -> Texture2D:
	var path := "res://artwork/players/%s/%s_%s.png" % [rider_id, rider_id, frame_name]
	var texture := load(path) as Texture2D
	assert(texture != null, "Missing rider animation frame: %s" % path)
	return texture
