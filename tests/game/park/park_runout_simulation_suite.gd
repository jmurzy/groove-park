## Focused clean runout, abandoned runs, crashes, and completion checks.
class_name ParkRunoutSimulationSuite
extends "res://tests/game/park/park_simulation_harness.gd"


func run_checks() -> void:
	_test_flight_input_activates_landing_prep()
	_test_contact_outcome_priority()
	_test_contact_outcome_resolves_once()
	_test_runout_ignores_input_and_completes()
	_test_descending_below_abandon_line_enters_runout()
	_test_ascending_below_abandon_line_can_recover()
	_test_abandon_floor_does_not_preempt_landing_contact()
	_test_missed_flight_is_terminal()
	_test_shipped_routes_complete_with_landing_prep()
	_test_ground_route_transitions_to_landing()
