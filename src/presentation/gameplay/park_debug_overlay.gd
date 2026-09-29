## Camera-aligned terrain debug overlay drawn above the park world.
class_name ParkDebugOverlay
extends Node2D

const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const CourseDebugDrawScene := preload("res://src/presentation/gameplay/course_debug_draw.gd")

var projection: ParkProjection
var active_route_index := -1
var compression_window_distance := 0.0
var rider_state: RiderState
var rider_tuning: RiderTuning


func setup(
	next_projection: ParkProjection,
	next_compression_window_distance: float,
	next_rider_tuning: RiderTuning
) -> void:
	projection = next_projection
	compression_window_distance = next_compression_window_distance
	rider_tuning = next_rider_tuning


func refresh() -> void:
	queue_redraw()


func set_active_route_index(next_route_index: int) -> void:
	if active_route_index == next_route_index:
		return
	active_route_index = next_route_index
	queue_redraw()


func set_rider_state(next_rider_state: RiderState) -> void:
	rider_state = next_rider_state
	queue_redraw()


func _draw() -> void:
	if projection == null:
		return
	CourseDebugDrawScene.draw_course_debug(
		self,
		projection,
		Vector2(GAMEPLAY_BG.get_size()),
		active_route_index,
		compression_window_distance
	)
	CourseDebugDrawScene.draw_terrain_handles(self, projection)
	if rider_state != null and rider_tuning != null:
		CourseDebugDrawScene.draw_flight_debug(self, rider_state, rider_tuning)
