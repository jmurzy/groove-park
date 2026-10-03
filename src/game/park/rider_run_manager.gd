## Steps the park run for its rider.
## Owns the RiderState, the shared RiderSimulation, and run lifecycle:
## setup / step / restart / spawn placement. Presentation (views, HUD, camera)
## stays in GameplayScreen. Example: `run.step(input, course, tuning, delta)`.
class_name RiderRunManager
extends RefCounted

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
	_simulation.step(rider_state, input, course, tuning, delta)
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


func _freeze_terminal_snapshot(tuning: RiderTuning) -> JumpSnapshot:
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
		rider_state.run.jump_outcome,
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
