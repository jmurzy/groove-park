## Headless checks for clean runout, abandoned runs, crashes, and course completion.
extends SceneTree

const HarnessScene := preload("res://tests/game/park/park_simulation_harness.gd")


func _init() -> void:
	_run("Rider runout checks", &"run_runout_checks")


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
