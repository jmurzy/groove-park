## Focused approach movement, path selection, and terrain traversal checks.
class_name ParkApproachSimulationSuite
extends "res://tests/game/park/park_simulation_harness.gd"


func run_checks() -> void:
	_test_neutral_input_does_not_start_a_run()
	_test_shipped_course_has_an_approach_line()
	_test_downhill_input_starts_a_run()
	_test_releasing_right_carves_to_a_stop()
	_test_left_brakes_without_turning_uphill()
	_test_tuck_builds_more_speed()
	_test_vertical_heading_does_not_free_carve()
	_test_vertical_input_switches_approach_paths_smoothly()
	_test_braking_reduces_speed()
	_test_path_change_is_rejected_too_close_to_lip()
	_test_route_tangent_follows_selected_path()
	_test_gradient_sign_matches_terrain_pitch()
	_test_uphill_stalls_without_momentum()
	_test_uphill_clears_with_momentum()
