## One lift's display name and status (open / hold / closed / scheduled / unknown).
## Example: `LiftState.create("Sky Express", LiftState.Status.HOLD)`.
class_name LiftState
extends Resource

enum Status {
	OPEN,
	HOLD,
	CLOSED,
	SCHEDULED,
	UNKNOWN,
}

var display_name: String
var status: Status = Status.UNKNOWN


static func create(lift_display_name: String, lift_status: Status) -> LiftState:
	var lift_state := LiftState.new()
	lift_state.display_name = lift_display_name
	lift_state.status = lift_status
	return lift_state
