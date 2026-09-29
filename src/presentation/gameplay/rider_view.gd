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


func _visual_definition() -> RiderVisualDefinition:
	return _definition
