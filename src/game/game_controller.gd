## Owns the active game session: presentation flow, player selection, park run,
## score, pause state, and forwarded mountain lift state.
class_name GameController
extends Node

signal mountain_state_changed(state: MountainState)
signal presentation_state_changed(state: PresentationState)
signal run_started(run_manager: RiderRunManager)
signal run_restarted(run_manager: RiderRunManager)
signal run_score_changed(score: int)
signal pause_changed(paused: bool)
signal results_ready(result: RunResult)

enum PresentationState {
	ATTRACT,
	PLAYING,
	RESULTS,
}

var mountain_state: MountainState
var presentation_state: PresentationState = PresentationState.ATTRACT
var player_count := 1
var run_manager: RiderRunManager
var run_score := 0
var results: RunResult
var is_paused := false
var _mountain_state_source: MountainStateSource


func set_mountain_state_source(source: MountainStateSource) -> void:
	if _mountain_state_source:
		push_error("A mountain state source has already been configured.")
		return
	_mountain_state_source = source


func _ready() -> void:
	if not _mountain_state_source:
		push_error("GameController requires a MountainStateSource.")
		return
	_mountain_state_source.state_changed.connect(_on_mountain_state_changed)
	add_child(_mountain_state_source)


func start_game(selected_player_count: int) -> void:
	player_count = selected_player_count
	run_manager = null
	run_score = 0
	results = null
	is_paused = false
	_set_presentation_state(PresentationState.PLAYING)


func begin_run(course: ParkCourse) -> void:
	if presentation_state != PresentationState.PLAYING:
		push_error("A run can only begin while playing.")
		return
	run_manager = RiderRunManager.new()
	run_manager.setup(course)
	run_score = 0
	run_started.emit(run_manager)


func step_run(
	input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if not run_manager or is_paused or presentation_state != PresentationState.PLAYING:
		return
	run_manager.step(input, course, tuning, delta)
	_set_run_score(run_manager.rider_state.jump_score)


func restart_run(course: ParkCourse) -> void:
	if not run_manager:
		begin_run(course)
		return
	run_manager.reset_run(course)
	_set_run_score(0)
	run_restarted.emit(run_manager)


func set_paused(next_paused: bool) -> void:
	if is_paused == next_paused:
		return
	is_paused = next_paused
	pause_changed.emit(is_paused)


func show_results() -> void:
	if not run_manager:
		push_error("Cannot show results without an active run.")
		return
	_set_run_score(run_manager.rider_state.jump_score)
	results = RunResult.new(player_count, JumpResult.from_jump_state(run_manager.rider_state.jump))
	_set_presentation_state(PresentationState.RESULTS)
	results_ready.emit(results)


func return_to_attract() -> void:
	is_paused = false
	run_manager = null
	_set_presentation_state(PresentationState.ATTRACT)


func _on_mountain_state_changed(next_state: MountainState) -> void:
	mountain_state = next_state
	mountain_state_changed.emit(mountain_state)


func _set_presentation_state(next_state: PresentationState) -> void:
	if presentation_state == next_state:
		return
	presentation_state = next_state
	presentation_state_changed.emit(presentation_state)


func _set_run_score(next_score: int) -> void:
	if run_score == next_score:
		return
	run_score = next_score
	run_score_changed.emit(run_score)
