## Owns the persistent marquee and keeps its presentation context in sync with a round.
class_name MarqueeFlowController
extends Node

const MarqueeScreenScene := preload("res://src/presentation/marquee/marquee_screen.gd")

var _game_session: GameSession
var _marquee_view: MarqueeScreen


func setup(game_session: GameSession, liftie_state_service: LiftieStateService) -> void:
	assert(game_session != null, "MarqueeFlowController requires a game session.")
	assert(liftie_state_service != null, "MarqueeFlowController requires a Liftie state service.")
	_game_session = game_session
	_marquee_view = MarqueeScreenScene.new()
	_marquee_view.liftie_state_service = liftie_state_service
	add_child(_marquee_view)
	_game_session.phase_changed.connect(_on_session_context_changed)
	_game_session.leaderboard_changed.connect(_on_leaderboard_changed)
	_game_session.jump_started.connect(_on_jump_started)
	_refresh_session_context()


func _on_session_context_changed(_phase: int) -> void:
	_refresh_session_context()


func _on_leaderboard_changed(_leaderboard: Leaderboard) -> void:
	_refresh_session_context()


func _on_jump_started(_round_state: RoundState) -> void:
	_refresh_session_context()


func _refresh_session_context() -> void:
	_marquee_view.set_session_context(
		_game_session.session_phase, _game_session.round_state(), _game_session.leaderboard()
	)
