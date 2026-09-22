## Shared polygon queries for authored park surfaces and control zones.
class_name Footprint2D
extends RefCounted

const EDGE_TOLERANCE := 0.01


static func contains(footprint: PackedVector2Array, point: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point, footprint):
		return true
	for point_index in footprint.size():
		var edge_start := footprint[point_index]
		var edge_end := footprint[(point_index + 1) % footprint.size()]
		if (
			Geometry2D.get_closest_point_to_segment(point, edge_start, edge_end).distance_to(point)
			<= EDGE_TOLERANCE
		):
			return true
	return false
