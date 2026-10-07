## Steps the park run for its rider.
## Owns the RiderState, the shared RiderSimulation, and run lifecycle:
## setup / step / restart / spawn placement. Presentation (views, HUD, camera)
## stays in GameplayScreen. Example: `run.step(input, course, tuning, delta)`.
class_name RiderRunManager
extends RefCounted

signal event_emitted(event: AudioManager.Event)
signal loop_event_started(loop_event: AudioManager.LoopEvent)
signal loop_event_updated(loop_event: AudioManager.LoopEvent, intensity: float)
signal loop_event_stopped(loop_event: AudioManager.LoopEvent)

var rider_state: RiderState
var has_started_moving := false

var _simulation: RiderSimulation
var _terminal_snapshot: JumpSnapshot
var _loop_events: Array[bool] = []


func setup(course: ParkCourse) -> void:
	_simulation = RiderSimulation.new()
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false
	_terminal_snapshot = null
	_loop_events.clear()
	for _action: int in AudioManager.LoopEvent.values():
		_loop_events.append(false)


func step(input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float) -> void:
	var previous_phase := rider_state.run.run_phase
	var previous_rotations := rider_state.jump.completed_rotations
	var previous_rotation_phase := rider_state.jump.rotation_gesture_phase
	var release_deadline_was_crossed := rider_state.jump.release_deadline_crossed
	var previous_outcome := rider_state.run.jump_outcome
	_simulation.step(rider_state, input, course, tuning, delta)
	_sync_loop_events(tuning)
	_emit_transitions(
		previous_phase,
		previous_rotations,
		previous_rotation_phase,
		release_deadline_was_crossed,
		previous_outcome
	)
	if not has_started_moving and rider_state.kinematics.ground_velocity.length() > 1.0:
		has_started_moving = true
	if is_complete() and _terminal_snapshot == null:
		_terminal_snapshot = _freeze_terminal_snapshot(tuning)


func reset_run(course: ParkCourse) -> void:
	suspend_loop_events()
	rider_state = _spawn_at_route(course, course.default_route_index())
	has_started_moving = false
	_terminal_snapshot = null


func suspend_loop_events() -> void:
	for action: int in AudioManager.LoopEvent.values():
		if _loop_events[action]:
			loop_event_stopped.emit(action)
		_loop_events[action] = false


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
	previous_rotations: int,
	previous_rotation_phase: int,
	release_deadline_was_crossed: bool,
	previous_outcome: int
) -> void:
	if (
		previous_phase == RiderRunState.RunPhase.APPROACH
		and rider_state.run.run_phase == RiderRunState.RunPhase.FLIGHT
	):
		event_emitted.emit(AudioManager.Event.TAKEOFF)
	if rider_state.jump.completed_rotations > previous_rotations:
		event_emitted.emit(AudioManager.Event.FULL_ROTATION)
	elif (
		previous_rotation_phase == JumpState.RotationGesturePhase.ROTATING_FIRST_HALF
		and (
			rider_state.jump.rotation_gesture_phase
			== JumpState.RotationGesturePhase.WAITING_SECOND_PRESS
		)
	):
		event_emitted.emit(AudioManager.Event.HALF_ROTATION)
	if not release_deadline_was_crossed and rider_state.jump.release_deadline_crossed:
		event_emitted.emit(AudioManager.Event.RELEASE_WARNING)
	if (
		previous_outcome == JumpOutcome.Value.NONE
		and rider_state.run.jump_outcome != JumpOutcome.Value.NONE
	):
		suspend_loop_events()
		match rider_state.run.jump_outcome:
			JumpOutcome.Value.CLEAN:
				event_emitted.emit(AudioManager.Event.LAND_CLEAN)
			JumpOutcome.Value.SKETCHY:
				event_emitted.emit(AudioManager.Event.LAND_SKETCHY)
			JumpOutcome.Value.BAIL:
				event_emitted.emit(AudioManager.Event.BAIL)
			JumpOutcome.Value.CRASH:
				event_emitted.emit(AudioManager.Event.CRASH)
			JumpOutcome.Value.LOW_MOMENTUM:
				event_emitted.emit(AudioManager.Event.LOW_MOMENTUM)


func _sync_loop_events(tuning: RiderTuning) -> void:
	var speed_intensity := clampf(
		(
			rider_state.kinematics.ground_velocity.length()
			/ maxf(tuning.maximum_takeoff_course_speed, 0.001)
		),
		0.0,
		1.0
	)
	_sync_loop_event(AudioManager.LoopEvent.CARVE, rider_state.run.edge_active, speed_intensity)
	_sync_loop_event(AudioManager.LoopEvent.BRAKE, rider_state.run.brake_active, speed_intensity)
	_sync_loop_event(AudioManager.LoopEvent.TUCK, rider_state.run.tuck_active, speed_intensity)
	_sync_loop_event(
		AudioManager.LoopEvent.COMPRESSION,
		rider_state.jump.compression_active,
		clampf(
			rider_state.jump.compression_amount / maxf(tuning.maximum_compression, 0.001), 0.0, 1.0
		)
	)
	_sync_loop_event(
		AudioManager.LoopEvent.GRAB,
		rider_state.jump.trick_tracker.grab_active,
		clampf(
			rider_state.jump.trick_tracker.grab_duration / tuning.minimum_grab_duration, 0.0, 1.0
		)
	)


func _sync_loop_event(
	loop_event: AudioManager.LoopEvent, is_active: bool, intensity: float
) -> void:
	var was_active := _loop_events[loop_event]
	if is_active and not was_active:
		loop_event_started.emit(loop_event)
	elif not is_active and was_active:
		loop_event_stopped.emit(loop_event)
	_loop_events[loop_event] = is_active
	if is_active:
		loop_event_updated.emit(loop_event, intensity)
