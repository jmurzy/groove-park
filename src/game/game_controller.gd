## Tracks high-level flow (attract / playing / results) and forwards mountain
## lift state to presentation. Example: `start_game(1)` moves ATTRACT to PLAYING.
class_name GameController
extends Node

signal mountain_state_changed(state: MountainState)
signal presentation_state_changed(state: PresentationState)

enum PresentationState {
	ATTRACT,
	PLAYING,
	RESULTS,
}

var mountain_state: MountainState
var presentation_state: PresentationState = PresentationState.ATTRACT
var player_count := 1
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
	_set_presentation_state(PresentationState.PLAYING)


func show_results() -> void:
	_set_presentation_state(PresentationState.RESULTS)


func return_to_attract() -> void:
	_set_presentation_state(PresentationState.ATTRACT)


func _on_mountain_state_changed(next_state: MountainState) -> void:
	mountain_state = next_state
	mountain_state_changed.emit(mountain_state)


func _set_presentation_state(next_state: PresentationState) -> void:
	if presentation_state == next_state:
		return
	presentation_state = next_state
	presentation_state_changed.emit(presentation_state)
