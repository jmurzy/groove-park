## Owns the active player session: presentation flow, rider selection, park run,
## and pause state.
class_name GameSession
extends Node

signal presentation_state_changed(state: PresentationState)
signal run_started(run_manager: RiderRunManager)
signal run_restarted(run_manager: RiderRunManager)
signal pause_changed(paused: bool)

enum PresentationState {
	ATTRACT,
	PLAYING,
}

var presentation_state: PresentationState = PresentationState.ATTRACT
var rider_kind: StringName = RiderKind.SNOWBOARDER
var run_manager: RiderRunManager
var is_paused := false


func start_game(selected_rider_kind: StringName) -> void:
	if not RiderKind.is_valid(selected_rider_kind):
		push_error("A game can only start with a valid rider kind.")
		return
	rider_kind = selected_rider_kind
	run_manager = null
	is_paused = false
	_set_presentation_state(PresentationState.PLAYING)


func begin_run(course: ParkCourse) -> void:
	if presentation_state != PresentationState.PLAYING:
		push_error("A run can only begin while playing.")
		return
	run_manager = RiderRunManager.new()
	run_manager.setup(course)
	run_started.emit(run_manager)


func step_run(
	input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if not run_manager or is_paused or presentation_state != PresentationState.PLAYING:
		return
	run_manager.step(input, course, tuning, delta)


func restart_run(course: ParkCourse) -> void:
	if not run_manager:
		begin_run(course)
		return
	run_manager.reset_run(course)
	run_restarted.emit(run_manager)


func set_paused(next_paused: bool) -> void:
	if is_paused == next_paused:
		return
	is_paused = next_paused
	pause_changed.emit(is_paused)


func return_to_attract() -> void:
	is_paused = false
	run_manager = null
	_set_presentation_state(PresentationState.ATTRACT)


func _set_presentation_state(next_state: PresentationState) -> void:
	if presentation_state == next_state:
		return
	presentation_state = next_state
	presentation_state_changed.emit(presentation_state)
