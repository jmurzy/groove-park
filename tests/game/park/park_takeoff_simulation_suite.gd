## Focused compression, lip crossing, and takeoff checks.
class_name ParkTakeoffSimulationSuite
extends "res://tests/game/park/park_simulation_harness.gd"


func run_checks() -> void:
	_test_compression_only_charges_near_lip()
	_test_compression_charge_caps_at_maximum()
	_test_compression_release_records_timing_quality()
	_test_ideal_release_adds_maximum_pop()
	_test_held_compression_auto_releases_at_lip()
	_test_flight_route_transitions_at_lip()
	_test_arc_height_multiplier_steepens_uphill_launch()
	_test_takeoff_speed_cap_shortens_fast_launches()
	_test_lip_crossing_is_fixed_step_safe()
