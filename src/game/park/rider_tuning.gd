## Editable balance numbers for rider physics, rotation, landing strictness, and
## scoring. Example: raise `maximum_pop_impulse` for bigger air off the lip.
class_name RiderTuning
extends Resource

@export var fall_line_acceleration := 540.0
@export var slope_gravity := 980.0
@export var uphill_pump_cut_gradient := 0.33
@export var snow_resistance := 48.0
@export var aerodynamic_drag := 0.00115
@export var tuck_drag_multiplier := 0.38
@export var edge_drag := 105.0
@export var brake_drag := 820.0
@export var release_carve_drag := 570.0
@export var steering_response := 480.0
@export var maximum_turn_rate := 3.8
@export var tuck_steering_multiplier := 0.42
@export var brake_turn_multiplier := 1.85
@export var compression_rate := 1.8
@export var maximum_compression := 1.0
@export var compression_window_distance := 220.0
@export var maximum_pop_impulse := 260.0
@export_range(0.0, 1.0) var compression_auto_release_quality := 0.7
@export var flight_arc_height_multiplier := 1.25
@export var maximum_takeoff_course_speed := 500.0
@export var gravity := 980.0
@export var air_drag := 0.05
@export var air_time_scale := 0.72
@export var min_rotation_speed := 150.0
@export var max_rotation_speed := 500.0
@export var min_rotation_rate := TAU
@export var max_rotation_rate := TAU * 2.0
@export var safe_no_rotation_speed := 500.0
@export var speed_per_required_rotation := 175.0
@export var grab_reach_duration := 0.12
@export var minimum_grab_duration := 0.2
@export var runout_drag := 48.0
@export var minimum_runout_speed := 120.0
@export var crash_completion_delay := 1.2
@export var score_approach_speed_cap := 900.0
@export var score_approach_max := 250
@export var score_takeoff_max := 175
@export var score_airtime_cap := 1.5
@export var score_airtime_max := 175
@export var score_rotation_per_rotation := 300
@export var score_grab_duration_cap := 0.8
@export var score_grab_per_second := 150
@export var score_tweak_duration_cap := 0.6
@export var score_tweak_per_second := 100
