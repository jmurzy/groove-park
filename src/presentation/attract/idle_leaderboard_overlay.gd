## Screensaver-style shared leaderboard that stays within the primary display's safe area.
class_name IdleLeaderboardOverlay
extends Control

const SAFE_BOUNDS := Rect2(80, 135, 1760, 925)
const VELOCITY := Vector2(74, 31)
const DISPLAY_SCALE := 0.6

var _velocity := VELOCITY
var _leaderboard_overlay: LeaderboardOverlay
var _entries: Array[LeaderboardEntry]


func show_entries(entries: Array[LeaderboardEntry]) -> void:
	_entries = entries.duplicate()
	if _leaderboard_overlay:
		_leaderboard_overlay.show_entries(_entries)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var next_position := position + _velocity * delta
	var maximum_position := SAFE_BOUNDS.position + SAFE_BOUNDS.size - displayed_size()
	for axis in 2:
		if next_position[axis] < SAFE_BOUNDS.position[axis]:
			next_position[axis] = SAFE_BOUNDS.position[axis]
			_velocity[axis] = absf(_velocity[axis])
		elif next_position[axis] > maximum_position[axis]:
			next_position[axis] = maximum_position[axis]
			_velocity[axis] = -absf(_velocity[axis])
	position = next_position


func _ready() -> void:
	name = "IdleLeaderboardOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = SAFE_BOUNDS.position
	_leaderboard_overlay = LeaderboardOverlay.new()
	add_child(_leaderboard_overlay)
	_leaderboard_overlay.show_entries(_entries)
	var hint := ArcadeTheme.make_label("PRESS ANY KEY OR BUTTON", 16, Color("fff7cf"))
	hint.position = Vector2(0, LeaderboardOverlay.OVERLAY_SIZE.y + 18)
	hint.size = Vector2(LeaderboardOverlay.OVERLAY_SIZE.x, 28)
	add_child(hint)
	size = Vector2(LeaderboardOverlay.OVERLAY_SIZE.x, LeaderboardOverlay.OVERLAY_SIZE.y + 46)
	scale = Vector2.ONE * DISPLAY_SCALE


func displayed_size() -> Vector2:
	return size * scale
