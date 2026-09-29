## Shows the release line only while the rider descends toward the captured lip height.
class_name ReleaseDeadlineWarning
extends Node2D

const HALF_WIDTH := 260.0
const WARNING_DISTANCE := 220.0

var _visible := false


func update_from_state(state: RiderState) -> void:
	_visible = (
		state.run.run_phase == RiderRunState.RunPhase.FLIGHT
		and not state.jump.release_deadline_crossed
		and state.kinematics.vertical_speed > 0.0
		and state.kinematics.vertical_position < state.jump.release_deadline_y
		and state.jump.release_deadline_y - state.kinematics.vertical_position <= WARNING_DISTANCE
	)
	if not _visible:
		visible = false
		return
	visible = true
	position = Vector2(state.kinematics.course_progress, state.jump.release_deadline_y)
	modulate = Color("ff4d68") if state.jump.trick_tracker.grab_active else Color("ffe126")


func _draw() -> void:
	draw_line(Vector2(-HALF_WIDTH, 0), Vector2(HALF_WIDTH, 0), Color.WHITE, 5.0)
	draw_line(Vector2(-HALF_WIDTH, 0), Vector2(HALF_WIDTH, 0), Color("7d1838"), 1.0)
