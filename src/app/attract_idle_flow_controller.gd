## Owns attract idle timing and cancellable leaderboard display requests.
class_name AttractIdleFlowController
extends Node

signal overlay_started
signal overlay_dismissed

enum State {
	SUSPENDED,
	WAITING,
	FETCHING,
	DISPLAYING,
}

const IdleLeaderboardOverlayScene := preload(
	"res://src/presentation/attract/idle_leaderboard_overlay.gd"
)
const IDLE_LEADERBOARD_DELAY := 5.0

var _leaderboard_repository: LeaderboardRepository
var _presentation_parent: Control
var _state := State.SUSPENDED
var _elapsed := 0.0
var _request: LeaderboardRepository.Request
var _overlay: IdleLeaderboardOverlay


func setup(presentation_parent: Control, leaderboard_repository: LeaderboardRepository) -> void:
	assert(
		leaderboard_repository != null,
		"AttractIdleFlowController requires a leaderboard repository."
	)
	assert(presentation_parent != null, "AttractIdleFlowController requires a presentation parent.")
	_leaderboard_repository = leaderboard_repository
	_presentation_parent = presentation_parent


func start_waiting() -> void:
	_cancel_request()
	_elapsed = 0.0
	_state = State.WAITING


func suspend() -> void:
	_cancel_request()
	_elapsed = 0.0
	_state = State.SUSPENDED
	_remove_overlay()


func dismiss() -> void:
	if _state != State.DISPLAYING:
		return
	_remove_overlay()
	overlay_dismissed.emit()
	start_waiting()


func advance(delta: float) -> void:
	if _state != State.WAITING:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= IDLE_LEADERBOARD_DELAY:
		_request_top_entries()


func is_displaying() -> bool:
	return _state == State.DISPLAYING


func _input(event: InputEvent) -> void:
	if not _is_button_or_key_press(event):
		return
	if _state == State.DISPLAYING:
		dismiss()
		get_viewport().set_input_as_handled()
		return
	if _state != State.SUSPENDED:
		start_waiting()


func _request_top_entries() -> void:
	_elapsed = 0.0
	_state = State.FETCHING
	var request := _leaderboard_repository.get_top_entries()
	_request = request
	request.completed.connect(_on_top_entries_completed)
	if request.status != LeaderboardRepository.Request.Status.PENDING:
		_on_top_entries_completed(request)


func _on_top_entries_completed(request: LeaderboardRepository.Request) -> void:
	if request != _request:
		return
	_request = null
	if (
		request.status != LeaderboardRepository.Request.Status.SUCCEEDED
		or not request.result is LeaderboardTopEntriesResult
	):
		start_waiting()
		return
	_state = State.DISPLAYING
	_overlay = IdleLeaderboardOverlayScene.new()
	_overlay.show_entries(_top_entries_from(request.result))
	_presentation_parent.add_child(_overlay)
	overlay_started.emit()


func _cancel_request() -> void:
	if _request:
		var request := _request
		_request = null
		request.cancel()


func _top_entries_from(result: Variant) -> Array[LeaderboardEntry]:
	if result is LeaderboardTopEntriesResult:
		return result.entries
	return []


func _process(delta: float) -> void:
	advance(delta)
	if _overlay:
		_overlay.advance(delta)


func _remove_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _is_button_or_key_press(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event != null:
		return key_event.pressed
	var button_event := event as InputEventJoypadButton
	return button_event != null and button_event.pressed


func _exit_tree() -> void:
	_cancel_request()
	_remove_overlay()
