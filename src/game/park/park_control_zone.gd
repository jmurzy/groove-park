@tool
## Polygonal region that selects a RiderState.ControlMode by priority.
## Example: entering the "compression" zone enables pop charging.
class_name ParkControlZone
extends Resource

const RiderStateScene := preload("res://src/game/park/rider_state.gd")

@export var id: StringName
@export var control_mode := RiderStateScene.ControlMode.APPROACH
@export var footprint := PackedVector2Array()
@export var priority := 0
@export var fall_line_direction := Vector2.RIGHT
@export_range(0.1, 3.0, 0.05) var snow_resistance_multiplier := 1.0
@export_range(0.1, 3.0, 0.05) var edge_grip_multiplier := 1.0


func contains(ground_position: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(ground_position, footprint):
		return true
	for point_index in footprint.size():
		var edge_start := footprint[point_index]
		var edge_end := footprint[(point_index + 1) % footprint.size()]
		if (
			(
				Geometry2D
				. get_closest_point_to_segment(ground_position, edge_start, edge_end)
				. distance_to(ground_position)
			)
			<= 0.01
		):
			return true
	return false


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("ParkControlZone needs an id.")
	if footprint.size() < 3:
		errors.append("ParkControlZone needs at least three footprint points.")
	if fall_line_direction.is_zero_approx():
		errors.append("ParkControlZone needs a fall-line direction.")
	return errors
