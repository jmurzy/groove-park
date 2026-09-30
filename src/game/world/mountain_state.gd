## Snapshot of lift statuses for the whole mountain.
class_name MountainState
extends Resource

var lifts: Array[LiftState] = []


static func create(lift_states: Array[LiftState]) -> MountainState:
	var mountain_state := MountainState.new()
	mountain_state.lifts = lift_states
	return mountain_state
