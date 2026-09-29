## Configurable rider sprite driven by a RiderVisualDefinition.
class_name RiderView
extends RiderViewBase

var _definition: RiderVisualDefinition


func _init(definition: RiderVisualDefinition) -> void:
	_definition = definition


func _ready() -> void:
	_setup_sprite(_definition.baseline, _definition.view_name)
	_sprite.sprite_frames = _definition.build_sprite_frames()
	_play(&"neutral_glide")


func _carve_animation(state: RiderState) -> StringName:
	return (
		_definition.carve_a_animation
		if state.kinematics.heading.y < 0.0
		else _definition.carve_b_animation
	)


func _spin_animation_for_state(state: RiderState) -> StringName:
	if state.jump.spin_grab_tweak:
		return (
			_definition.spin_tweak_negative
			if state.jump.spin_direction < 0
			else _definition.spin_tweak_positive
		)
	return (
		_definition.spin_regular_negative
		if state.jump.spin_direction < 0
		else _definition.spin_regular_positive
	)
