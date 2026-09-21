## Snapshot of lift statuses for the whole mountain.
## Example: `count_with_status(LiftState.Status.OPEN)`.
class_name MountainState
extends Resource

var lifts: Array[LiftState] = []


static func create(lift_states: Array[LiftState]) -> MountainState:
	var mountain_state := MountainState.new()
	mountain_state.lifts = lift_states
	return mountain_state


func count_with_status(status: int) -> int:
	var count := 0
	for lift in lifts:
		if lift.status == status:
			count += 1
	return count
