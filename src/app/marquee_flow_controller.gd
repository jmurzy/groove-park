## Owns the persistent marquee and keeps its presentation context in sync with a round.
class_name MarqueeFlowController
extends Node

const MarqueeScreenScene := preload("res://src/presentation/marquee/marquee_screen.gd")

var _game_session: GameSession
var _mountain_state_source: MountainStateSource
var _marquee_view: MarqueeScreen


func setup(game_session: GameSession, mountain_state_source: MountainStateSource) -> void:
	assert(game_session != null, "MarqueeFlowController requires a game session.")
	assert(mountain_state_source != null, "MarqueeFlowController requires a mountain state source.")
	_game_session = game_session
	_mountain_state_source = mountain_state_source
	_marquee_view = MarqueeScreenScene.new()
	add_child(_marquee_view)
	_game_session.phase_changed.connect(_on_session_context_changed)
	_game_session.leaderboard_changed.connect(_on_leaderboard_changed)
	_game_session.jump_started.connect(_on_jump_started)
	_mountain_state_source.state_changed.connect(_on_mountain_state_changed)
	if _mountain_state_source.mountain_state:
		_on_mountain_state_changed(_mountain_state_source.mountain_state)
	_refresh_session_context()


func _on_session_context_changed(_phase: int) -> void:
	_refresh_session_context()


func _on_leaderboard_changed(_leaderboard: Leaderboard) -> void:
	_refresh_session_context()


func _on_jump_started(_round_state: RoundState) -> void:
	_refresh_session_context()


func _on_mountain_state_changed(mountain_state: MountainState) -> void:
	_marquee_view.set_mountain_state(mountain_state)


func _refresh_session_context() -> void:
	_marquee_view.set_session_context(
		_game_session.session_phase, _game_session.round_state(), _game_session.leaderboard()
	)
