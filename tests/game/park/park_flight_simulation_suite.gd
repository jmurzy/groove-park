## Focused airborne integration, projection, and landing contact checks.
class_name ParkFlightSimulationSuite
extends "res://tests/game/park/park_simulation_harness.gd"


func run_checks() -> void:
	_test_arc_height_multiplier_preserves_flight_range()
	_test_ballistic_flight_matches_known_step()
	_test_air_drag_cannot_reverse_velocity()
	_test_air_input_does_not_steer()
	_test_flight_projection_uses_landing_path()
	_test_swept_landing_contact_resolves_once()
	_test_flight_only_hits_selected_landing_path()
