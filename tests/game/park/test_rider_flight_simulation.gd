## Headless checks for airborne integration, projection, and landing contact.
extends SceneTree

const HarnessScene := preload("res://tests/game/park/park_simulation_harness.gd")


func _init() -> void:
	_run("Rider flight checks", &"run_flight_checks")


func _run(label: String, suite: StringName) -> void:
	var harness := HarnessScene.new()
	harness.call(suite)
	if harness.failures.is_empty():
		print("%s passed." % label)
		quit(0)
		return
	for failure in harness.failures:
		push_error(failure)
	quit(1)
