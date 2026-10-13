## Snapshot of lift statuses for the whole mountain.
class_name MountainState
extends Resource

var lifts: Array[LiftState] = []
var open := 0
var closed := 0
var hold := 0
var scheduled := 0


static func create(lift_states: Array[LiftState]) -> MountainState:
	var mountain_state := MountainState.new()
	mountain_state.lifts = lift_states
	for lift_state in lift_states:
		match lift_state.status:
			LiftState.Status.OPEN:
				mountain_state.open += 1
			LiftState.Status.CLOSED:
				mountain_state.closed += 1
			LiftState.Status.HOLD:
				mountain_state.hold += 1
			LiftState.Status.SCHEDULED:
				mountain_state.scheduled += 1
	return mountain_state
