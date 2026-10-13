## Lift-state feed for offline cabinets; publishes the Heavenly lineup every second.
class_name MountainStateSource
extends Node

signal state_changed(state: MountainState)

const LiftieStateServiceScene := preload("res://src/services/liftie/liftie_state_service.gd")

const REFRESH_SECONDS := 60.0

var mountain_state: MountainState
var _liftie_state_service: LiftieStateService


func _ready() -> void:
	_liftie_state_service = LiftieStateServiceScene.new()
	_liftie_state_service.state_received.connect(_on_liftie_state_received)
	add_child(_liftie_state_service)
	var refresh_timer := Timer.new()
	refresh_timer.wait_time = REFRESH_SECONDS
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_liftie_state_service.request_lift_data)
	add_child(refresh_timer)
	_refresh_mountain_state(_create_initial_mountain_state())


func _refresh_mountain_state(next_state: MountainState) -> void:
	mountain_state = next_state
	state_changed.emit(next_state)


func _on_liftie_state_received(liftie_state: LiftieResortResponse) -> void:
	if OS.is_debug_build():
		print("Liftie lift statuses: %s" % str(liftie_state.lifts.status))
	_refresh_mountain_state(_create_mountain_state(liftie_state))


func _create_mountain_state(liftie_state: LiftieResortResponse) -> MountainState:
	var lift_states: Array[LiftState] = []
	for lift_name: String in liftie_state.lifts.status:
		lift_states.append(
			LiftState.create(
				lift_name, _lift_status_from_string(liftie_state.lifts.status[lift_name])
			)
		)
	return MountainState.create(lift_states)


func _create_initial_mountain_state() -> MountainState:
	var lift_states: Array[LiftState] = [
		LiftState.create("Heavenly Gondola", _random_status()),
		LiftState.create("Aerial Tram", _random_status()),
		LiftState.create("Boulder", _random_status()),
		LiftState.create("Canyon Express", _random_status()),
		LiftState.create("Comet Express", _random_status()),
		LiftState.create("Dipper Express", _random_status()),
		LiftState.create("First Ride", _random_status()),
		LiftState.create("Galaxy", _random_status()),
		LiftState.create("Gunbarrel Express", _random_status()),
		LiftState.create("North Bowl", _random_status()),
		LiftState.create("Olympic Express", _random_status()),
		LiftState.create("Powderbowl Express", _random_status()),
		LiftState.create("Sky Express", _random_status()),
		LiftState.create("Sky Deck", _random_status()),
		LiftState.create("Stagecoach Express", _random_status()),
		LiftState.create("Tamarack Express", _random_status()),
		LiftState.create("Patsy's", _random_status()),
		LiftState.create("Maggie's", _random_status()),
		LiftState.create("Groove", _random_status()),
		LiftState.create("Ridge", _random_status()),
		LiftState.create("Mott Canyon", _random_status()),
		LiftState.create("Killebrew Canyon", _random_status()),
		LiftState.create("Olympic Downhill", _random_status()),
		LiftState.create("World Cup", _random_status()),
		LiftState.create("The Gondola Big Easy", _random_status()),
		LiftState.create("Black Bear Carpet", _random_status()),
		LiftState.create("Red Fir Mitey Mite", _random_status()),
		LiftState.create("Tubing Lift", _random_status()),
	]
	return MountainState.create(lift_states)


func _random_status() -> LiftState.Status:
	return randi_range(LiftState.Status.OPEN, LiftState.Status.SCHEDULED)


func _lift_status_from_string(status: String) -> LiftState.Status:
	match status:
		"open":
			return LiftState.Status.OPEN
		"hold":
			return LiftState.Status.HOLD
		"scheduled":
			return LiftState.Status.SCHEDULED
		"closed":
			return LiftState.Status.CLOSED
		_:
			return LiftState.Status.UNKNOWN
