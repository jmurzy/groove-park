## Steps the park run for its rider.
## Owns the RiderState, the shared RiderSimulation, and run lifecycle:
## setup / step / restart / spawn placement. Presentation (views, HUD, camera)
## stays in GameplayScreen. Example: `run.step(input, course, tuning, delta)`.
class_name RiderRunManager
extends RefCounted

signal takeoff
signal compression_charged
signal compression_released
signal grab_started
signal grab_released
signal half_rotation_completed
signal full_rotation_completed
signal release_deadline_crossed
signal carve_started
signal brake_started
signal tuck_started
signal outcome_resolved(outcome: int)

var rider_state: RiderState
var has_started_moving := false

var _simulation: RiderSimulation
var _terminal_snapshot: JumpSnapshot


func setup(course: ParkCourse) -> void:
	_simulation = RiderSimulation.new()
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false
	_terminal_snapshot = null


func step(input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	var previous_phase := rider_state.run.run_phase
	var was_compressing := rider_state.jump.compression_active
	var was_grabbing := rider_state.jump.trick_tracker.grab_active
	var previous_rotations := rider_state.jump.completed_rotations
	var previous_rotation_phase := rider_state.jump.rotation_gesture_phase
	var release_deadline_was_crossed := rider_state.jump.release_deadline_crossed
	var was_carving := rider_state.run.edge_active
	var was_braking := rider_state.run.brake_active
	var was_tucking := rider_state.run.tuck_active
	var previous_outcome := rider_state.run.jump_outcome
	_simulation.step(rider_state, input, course, tuning, delta)
	_emit_transitions(
		previous_phase,
		was_compressing,
		was_grabbing,
		previous_rotations,
		previous_rotation_phase,
		release_deadline_was_crossed,
		was_carving,
		was_braking,
		was_tucking,
		previous_outcome
	)
	if not has_started_moving and rider_state.kinematics.ground_velocity.length() > 1.0:
		has_started_moving = true
	if is_complete() and _terminal_snapshot == null:
		_terminal_snapshot = _freeze_terminal_snapshot(tuning)


func reset_run(course: ParkCourse) -> void:
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false
	_terminal_snapshot = null


func is_crashed() -> bool:
	return rider_state.run.jump_outcome == JumpOutcome.Value.CRASH


func is_bailed() -> bool:
	return rider_state.run.jump_outcome == JumpOutcome.Value.BAIL


func is_low_momentum() -> bool:
	return rider_state.run.jump_outcome == JumpOutcome.Value.LOW_MOMENTUM


func is_complete() -> bool:
	return rider_state.run.run_phase == RiderRunState.RunPhase.COMPLETE


func terminal_snapshot() -> JumpSnapshot:
	return _terminal_snapshot


func preview_score(tuning: RiderTuning) -> int:
	if is_complete():
		return 0
	# An active jump has no outcome yet; project it with the clean 1.0 multiplier.
	var snapshot := _create_snapshot(JumpOutcome.Value.CLEAN, tuning)
	return JumpScorer.score_jump(snapshot, tuning).total() if snapshot != null else 0


func _freeze_terminal_snapshot(tuning: RiderTuning) -> JumpSnapshot:
	return _create_snapshot(rider_state.run.jump_outcome, tuning)


func _create_snapshot(outcome: int, tuning: RiderTuning) -> JumpSnapshot:
	var tracker := rider_state.jump.trick_tracker
	var grab_style := rider_state.jump.scored_grab_style
	var valid_grab_duration := tracker.valid_grab_duration
	if tracker.grab_active and tracker.grab_duration >= tuning.minimum_grab_duration:
		grab_style = (
			JumpSnapshot.GrabStyle.TWEAK
			if rider_state.jump.tweak_active
			else JumpSnapshot.GrabStyle.STANDARD
		)
		valid_grab_duration = tracker.grab_duration
	var created := JumpSnapshot.create(
		outcome,
		maxf(rider_state.jump.takeoff_velocity.x, 0.0),
		maxf(rider_state.jump.takeoff_pop_impulse, 0.0),
		maxf(rider_state.jump.airtime, 0.0),
		maxi(rider_state.jump.completed_rotations, 0),
		grab_style,
		maxf(valid_grab_duration, 0.0)
	)
	if not created.is_valid:
		push_error("Unable to freeze terminal jump measurements: %s" % "; ".join(created.errors))
		return null
	return created.value


func _spawn_at_route(course: ParkCourse, route_index: int) -> RiderState:
	var state := RiderState.new()
	state.kinematics.approach_path_target = route_index
	state.kinematics.approach_path_position = float(route_index)
	state.kinematics.course_progress = course.route_start_at(
		state.kinematics.approach_path_position
	)
	_sync_spawn_position(state, course)
	return state


func _sync_spawn_position(state: RiderState, course: ParkCourse) -> void:
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.vertical_position = course.route_surface_y_at(
		state.kinematics.course_progress, state.kinematics.approach_path_position
	)


func _emit_transitions(
	previous_phase: int,
	was_compressing: bool,
	was_grabbing: bool,
	previous_rotations: int,
	previous_rotation_phase: int,
	release_deadline_was_crossed: bool,
	was_carving: bool,
	was_braking: bool,
	was_tucking: bool,
	previous_outcome: int
) -> void:
	if (
		previous_phase == RiderRunState.RunPhase.APPROACH
		and rider_state.run.run_phase == RiderRunState.RunPhase.FLIGHT
	):
		takeoff.emit()
	if not was_compressing and rider_state.jump.compression_active:
		compression_charged.emit()
	elif was_compressing and not rider_state.jump.compression_active:
		compression_released.emit()
	if not was_grabbing and rider_state.jump.trick_tracker.grab_active:
		grab_started.emit()
	elif was_grabbing and not rider_state.jump.trick_tracker.grab_active:
		grab_released.emit()
	if rider_state.jump.completed_rotations > previous_rotations:
		full_rotation_completed.emit()
	elif (
		previous_rotation_phase == JumpState.RotationGesturePhase.ROTATING_FIRST_HALF
		and (
			rider_state.jump.rotation_gesture_phase
			== JumpState.RotationGesturePhase.WAITING_SECOND_PRESS
		)
	):
		half_rotation_completed.emit()
	if not release_deadline_was_crossed and rider_state.jump.release_deadline_crossed:
		release_deadline_crossed.emit()
	if not was_carving and rider_state.run.edge_active:
		carve_started.emit()
	if not was_braking and rider_state.run.brake_active:
		brake_started.emit()
	if not was_tucking and rider_state.run.tuck_active:
		tuck_started.emit()
	if (
		previous_outcome == JumpOutcome.Value.NONE
		and rider_state.run.jump_outcome != JumpOutcome.Value.NONE
	):
		outcome_resolved.emit(rider_state.run.jump_outcome)
