## Headless checks for canonical rider validation.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	_expect(RiderKind.is_valid(RiderKind.SNOWBOARDER), "Snowboarder must be valid.")
	_expect(RiderKind.is_valid(RiderKind.SKIER), "Skier must be valid.")
	_expect(not RiderKind.is_valid(&"sledder"), "Unknown rider kinds must be invalid.")
	if _failures.is_empty():
		print("Rider kind checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
