## Tracks the cabinet hard-exit hold: EXIT alone, or the legacy Start + Back combo.
class_name CabinetExitHandler
extends RefCounted

const HOLD_SECONDS := 2.0

var _hold_time := 0.0


func update(delta: float) -> bool:
	var hold_exit := (
		Input.is_action_pressed(&"cabinet_exit")
		or (
			Input.is_action_pressed(&"controller_start")
			and Input.is_action_pressed(&"controller_back")
		)
	)
	if not hold_exit:
		_hold_time = 0.0
		return false

	_hold_time += delta
	return _hold_time >= HOLD_SECONDS
