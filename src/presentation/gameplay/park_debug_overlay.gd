## Camera-aligned terrain debug overlay drawn above the park world.
class_name ParkDebugOverlay
extends Node2D

const GAMEPLAY_BG := preload("res://artwork/gameplay/gameplay_bg.png")
const CourseDebugDrawScene := preload("res://src/presentation/gameplay/course_debug_draw.gd")

var projection: ParkProjection


func setup(next_projection: ParkProjection) -> void:
	projection = next_projection


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if projection == null:
		return
	CourseDebugDrawScene.draw_course_debug(self, projection, Vector2(GAMEPLAY_BG.get_size()))
	CourseDebugDrawScene.draw_terrain_handles(self, projection)
