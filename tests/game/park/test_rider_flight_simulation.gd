## Headless checks for airborne integration, projection, and landing contact.
extends SceneTree

const SuiteScene := preload("res://tests/game/park/park_flight_simulation_suite.gd")


func _init() -> void:
	_run("Rider flight checks")


func _run(label: String) -> void:
	var suite := SuiteScene.new()
	suite.run_checks()
	if suite.failures.is_empty():
		print("%s passed." % label)
		quit(0)
		return
	for failure in suite.failures:
		push_error(failure)
	quit(1)
