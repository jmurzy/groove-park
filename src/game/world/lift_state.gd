class_name LiftState
extends Resource

enum Status {
	OPEN,
	HOLD,
	CLOSED,
	UNKNOWN,
}

var id: String
var display_name: String
var status: Status = Status.UNKNOWN


static func create(lift_id: String, lift_display_name: String, lift_status: Status) -> LiftState:
	var lift_state := LiftState.new()
	lift_state.id = lift_id
	lift_state.display_name = lift_display_name
	lift_state.status = lift_status
	return lift_state
