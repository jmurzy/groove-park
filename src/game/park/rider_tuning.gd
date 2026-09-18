class_name RiderTuning
extends Resource

@export var rules_version := "takeoff-v1"
@export var fall_line_acceleration := 540.0
@export var snow_resistance := 48.0
@export var aerodynamic_drag := 0.00115
@export var tuck_drag_multiplier := 0.38
@export var edge_drag := 105.0
@export var strong_edge_drag := 150.0
@export var brake_drag := 460.0
@export var steering_response := 480.0
@export var maximum_turn_rate := 3.8
@export var tuck_steering_multiplier := 0.42
@export var strong_edge_turn_multiplier := 1.55
@export var brake_turn_multiplier := 1.85
@export var turn_speed_penalty := 460.0
@export var lane_boundary_margin := 90.0
@export var lane_boundary_force := 1250.0
@export var lane_boundary_damping := 6.0
@export var compression_rate := 1.8
@export var maximum_compression := 1.0
@export var pop_release_window := 220.0
@export var maximum_pop_impulse := 260.0
