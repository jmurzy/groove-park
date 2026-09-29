## World-space label marker that stays upright above a rider.
class_name InfoMarker
extends RiderMarker


func _ready() -> void:
	_build_callout(&"InfoMarker", Color.WHITE, Color("f51e16"))
	modulate = Color(1.0, 1.0, 1.0, 0.8)


func update_from_rider(world_position: Vector2, label_text: String) -> void:
	set_callout_text(label_text)
	_refresh_callout_size()
	_place_above(world_position)
	_update_arrow_above()


func local_bounds() -> Rect2:
	return callout_bounds_above()
