## Procedural rider effects: altitude-faded shadow blob plus carve/brake snow spray.
class_name RiderEffects
extends Node2D

var _state: RiderState
var _projection: ParkProjection
var _elapsed := 0.0


func update_from_state(state: RiderState, projection: ParkProjection, delta: float) -> void:
	_state = state
	_projection = projection
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _state == null or _projection == null:
		return
	var rider_position := _projection.project_rider(_state)
	var surface_position := _projection.project_rider_ground(_state)
	var height := maxf(surface_position.y - rider_position.y, 0.0)
	var shadow_alpha := clampf(0.42 - height / 820.0, 0.08, 0.42)
	draw_set_transform(surface_position, 0.0, Vector2(1.8, 0.42))
	draw_circle(Vector2.ZERO, 38.0 + height * 0.05, Color(0.0, 0.05, 0.12, shadow_alpha))
	draw_set_transform(Vector2.ZERO)

	if _state.phase != RiderState.Phase.GROUNDED or _state.ground_velocity.length() < 45.0:
		return
	var spray_strength := 0.0
	if _state.brake_active:
		spray_strength = 1.0
	elif _state.edge_active:
		spray_strength = 0.72
	elif absf(_state.lane_speed) > 35.0:
		spray_strength = 0.36
	if is_zero_approx(spray_strength):
		return
	var spray_origin := surface_position + Vector2(-18.0, -4.0)
	for particle_index in range(7):
		var phase := _elapsed * (10.0 + particle_index) + particle_index * 1.7
		var length := (18.0 + fposmod(phase * 13.0, 26.0)) * spray_strength
		var offset := Vector2(-particle_index * 7.0, sin(phase) * 6.0 - particle_index * 2.0)
		draw_line(
			spray_origin + offset,
			spray_origin + offset + Vector2(-length, -length * 0.18),
			Color(0.84, 0.97, 1.0, 0.24 + spray_strength * 0.38),
			2.0
		)
