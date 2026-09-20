class_name RiderSimulation
extends RefCounted

const JumpJudgeScene := preload("res://src/game/park/jump_judge.gd")
const JumpScoreScene := preload("res://src/game/park/jump_score.gd")


func step(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	if state.phase == RiderState.Phase.AIRBORNE:
		_step_airborne(state, input, course, tuning, delta)
		return
	if state.phase == RiderState.Phase.LANDED or state.phase == RiderState.Phase.RECOVERING:
		_step_recovery(state, course, tuning, delta)
		return
	if state.phase != RiderState.Phase.GROUNDED:
		return
	if not input.heading.is_zero_approx():
		state.desired_heading = input.heading
		state.has_ground_intent = true
	if not state.has_ground_intent:
		return

	var speed := state.ground_velocity.length()
	var turn_multiplier := 1.0
	if input.tuck_pressed:
		turn_multiplier *= tuning.tuck_steering_multiplier
	if input.edge_pressed:
		turn_multiplier *= tuning.strong_edge_turn_multiplier
	if input.brake_pressed:
		turn_multiplier *= tuning.brake_turn_multiplier
	var speed_turn_penalty := 1.0 / (1.0 + speed / tuning.turn_speed_penalty)
	var maximum_turn := tuning.maximum_turn_rate * turn_multiplier * speed_turn_penalty * delta
	state.heading = state.heading.rotated(
		clampf(state.heading.angle_to(state.desired_heading), -maximum_turn, maximum_turn)
	)

	# Gravity always pulls down the fall line; heading only redirects existing momentum.
	state.ground_velocity += Vector2.RIGHT * tuning.fall_line_acceleration * delta
	if speed > 0.0:
		var redirected_velocity := state.heading * state.ground_velocity.length()
		state.ground_velocity = state.ground_velocity.move_toward(
			redirected_velocity, tuning.steering_response * turn_multiplier * delta
		)

	_apply_drag(state, input, tuning, delta)
	_apply_lane_containment(state, course, tuning, delta)

	var previous_progress := state.course_progress
	var next_progress := previous_progress + state.ground_velocity.x * delta
	if course.crosses_progress(previous_progress, next_progress, course.compression_start):
		state.approach_speed = state.ground_velocity.length()
		state.approach_speed_captured = true
	_update_compression(state, input, course, tuning, delta)
	state.course_progress = next_progress
	state.lane_position += state.ground_velocity.y * delta
	if course.crosses_lip(previous_progress, next_progress):
		_transition_to_takeoff(state, course, tuning, delta)
		return
	if state.course_progress >= course.recovery_progress:
		state.course_progress = course.recovery_progress
		state.ground_velocity.x = 0.0
	var lane_bounds := course.lane_bounds_at(state.course_progress)
	state.lane_position = clampf(state.lane_position, lane_bounds.x, lane_bounds.y)
	state.vertical_position = course.surface_y_at(state.course_progress)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = state.ground_velocity.y
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.tuck_active = input.tuck_pressed
	state.brake_active = input.brake_pressed
	state.edge_active = input.edge_pressed


func _update_compression(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var is_in_compression_zone := (
		state.course_progress >= course.compression_start
		and state.course_progress <= course.compression_end
	)
	if input.pop_just_pressed and is_in_compression_zone and not input.tuck_pressed:
		state.compression_active = true
		state.compression_amount = 0.0
		state.compression_release_progress = -1.0
		state.compression_release_quality = 0.0
	if state.compression_active and input.pop_pressed:
		state.compression_amount = minf(
			state.compression_amount + tuning.compression_rate * delta, tuning.maximum_compression
		)
	if state.compression_active and input.pop_just_released:
		state.compression_release_progress = state.course_progress
		state.compression_release_quality = _release_quality(state.course_progress, course, tuning)
		state.compression_active = false


func _release_quality(release_progress: float, course: ParkCourse, tuning: RiderTuning) -> float:
	if release_progress > course.lip_progress:
		return 0.0
	return clampf(
		1.0 - (course.lip_progress - release_progress) / tuning.pop_release_window, 0.0, 1.0
	)


func _transition_to_takeoff(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var lip_progress := course.lip_progress
	var tangent := course.tangent_at(lip_progress)
	var normal := course.normal_at(lip_progress)
	var pop_impulse := (
		state.compression_amount * state.compression_release_quality * tuning.maximum_pop_impulse
	)
	if not state.approach_speed_captured:
		state.approach_speed = state.ground_velocity.length()
		state.approach_speed_captured = true

	state.phase = RiderState.Phase.AIRBORNE
	state.course_progress = lip_progress
	state.lane_position = clampf(
		state.lane_position,
		course.lane_bounds_at(lip_progress).x,
		course.lane_bounds_at(lip_progress).y
	)
	state.vertical_position = course.surface_y_at(lip_progress)
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	var launch_ground_speed := minf(
		state.ground_velocity.x,
		_maximum_landing_ground_speed(
			state.ground_velocity.x, tangent, normal, pop_impulse, course, tuning, delta
		)
	)
	state.course_speed = launch_ground_speed + normal.x * pop_impulse
	state.lane_speed = state.ground_velocity.y
	state.vertical_speed = (
		launch_ground_speed * tangent.y / maxf(tangent.x, 0.001) + normal.y * pop_impulse
	)
	state.takeoff_course_speed = state.course_speed
	state.takeoff_lane_speed = state.lane_speed
	state.takeoff_vertical_speed = state.vertical_speed
	state.takeoff_pop_impulse = pop_impulse
	state.takeoff_tangent = tangent
	state.takeoff_normal = normal
	state.orientation = tangent.angle()
	state.angular_velocity = 0.0
	state.airtime = 0.0
	state.body_compact = false
	state.body_extended = false
	state.landing_prep_active = false
	state.grab_reach_active = false
	state.tweak_active = false
	state.grab_active_at_landing = false
	state.trick_tracker.reset(state.orientation)
	state.trick_call = ""
	state.landing_resolved = false
	state.landing_label = ""
	state.landing_quality = 0.0
	state.jump_score = 0
	state.score_breakdown = {}
	state.tuck_active = false
	state.brake_active = false
	state.edge_active = false
	state.compression_active = false


func _maximum_landing_ground_speed(
	requested_speed: float,
	tangent: Vector2,
	normal: Vector2,
	pop_impulse: float,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float
) -> float:
	var highest_safe_speed := 0.0
	for sample_index in range(1, 33):
		var sample_speed := requested_speed * float(sample_index) / 32.0
		if (
			_landing_progress_for_ground_speed(
				sample_speed, tangent, normal, pop_impulse, course, tuning, delta
			)
			<= course.landing_end
		):
			highest_safe_speed = sample_speed
	if is_zero_approx(highest_safe_speed):
		return requested_speed
	var unsafe_speed := minf(highest_safe_speed + requested_speed / 32.0, requested_speed)
	for _iteration in 12:
		var candidate_speed := (highest_safe_speed + unsafe_speed) * 0.5
		if (
			_landing_progress_for_ground_speed(
				candidate_speed, tangent, normal, pop_impulse, course, tuning, delta
			)
			<= course.landing_end
		):
			highest_safe_speed = candidate_speed
		else:
			unsafe_speed = candidate_speed
	return highest_safe_speed


func _landing_progress_for_ground_speed(
	ground_speed: float,
	tangent: Vector2,
	normal: Vector2,
	pop_impulse: float,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float
) -> float:
	return _landing_progress_for_speed(
		ground_speed + normal.x * pop_impulse,
		ground_speed * tangent.y / maxf(tangent.x, 0.001) + normal.y * pop_impulse,
		course,
		tuning,
		delta
	)


func _landing_progress_for_speed(
	initial_course_speed: float,
	initial_vertical_speed: float,
	course: ParkCourse,
	tuning: RiderTuning,
	delta: float
) -> float:
	delta *= tuning.air_time_scale
	var previous_position := course.surface_position_at(course.lip_progress)
	var course_speed := initial_course_speed
	var vertical_speed := initial_vertical_speed
	var position := previous_position
	for _tick in 600:
		vertical_speed += tuning.gravity * delta
		course_speed *= maxf(0.0, 1.0 - tuning.air_drag * delta)
		position += Vector2(course_speed, vertical_speed) * delta
		if vertical_speed > 0.0:
			var contact := course.swept_terrain_intersection(previous_position, position)
			if not contact.is_empty():
				var contact_position: Vector2 = contact["position"]
				return contact_position.x
		if position.x > course.landing_end:
			return INF
		previous_position = position
	return INF


func _step_airborne(
	state: RiderState, input: RiderInputFrame, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	# Flight translation is ballistic. Air input is intentionally limited to body rotation.
	# Slow the simulation while airborne so players have time to read and act on landing cues.
	delta *= tuning.air_time_scale
	var previous_position := Vector2(state.course_progress, state.vertical_position)
	state.vertical_speed += tuning.gravity * delta
	var air_drag_factor := maxf(0.0, 1.0 - tuning.air_drag * delta)
	state.course_speed *= air_drag_factor
	state.lane_speed *= air_drag_factor
	state.course_progress += state.course_speed * delta
	state.lane_position += state.lane_speed * delta
	state.vertical_position += state.vertical_speed * delta
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = Vector2(state.course_speed, state.lane_speed)
	state.airtime += delta
	if state.course_progress >= course.recovery_progress:
		_resolve_missed_landing(state, course, tuning)
		return

	state.body_compact = input.heading.y > 0.0
	state.body_extended = input.heading.y < 0.0
	state.landing_prep_active = input.landing_prep_pressed
	if state.landing_prep_active:
		state.trick_tracker.release_grab(state.airtime, tuning.minimum_grab_duration)
		state.grab_reach_active = false
	elif input.grab_just_pressed:
		# A must be released after takeoff, then pressed again, to become a grab.
		state.trick_tracker.start_grab()
		state.grab_reach_active = true
	elif state.trick_tracker.grab_active and not input.grab_pressed:
		state.trick_tracker.release_grab(state.airtime, tuning.minimum_grab_duration)
		state.grab_reach_active = false
	if not state.trick_tracker.grab_active or not input.tweak_pressed:
		state.tweak_active = false
	elif input.tweak_just_pressed:
		# X also needs a fresh airborne press; holding compression through the lip is inert.
		state.tweak_active = true
	state.trick_tracker.step_grab(delta, state.tweak_active)
	if state.grab_reach_active and state.trick_tracker.grab_duration >= tuning.grab_reach_duration:
		state.grab_reach_active = false
	var inertia_multiplier := 1.0
	if state.body_compact:
		inertia_multiplier = tuning.compact_inertia_multiplier
	elif state.body_extended:
		inertia_multiplier = tuning.extended_inertia_multiplier
	var control_multiplier := 1.0
	if state.trick_tracker.grab_active:
		control_multiplier = tuning.grab_rotation_control_multiplier
		if input.tweak_pressed:
			control_multiplier = tuning.tweak_rotation_control_multiplier
	var torque := input.heading.x * tuning.air_torque * control_multiplier / inertia_multiplier
	state.angular_velocity += torque * delta
	state.angular_velocity = clampf(
		state.angular_velocity, -tuning.maximum_angular_velocity, tuning.maximum_angular_velocity
	)
	var damping := tuning.air_angular_damping
	if state.landing_prep_active:
		damping += tuning.landing_prep_damping
	state.angular_velocity = move_toward(state.angular_velocity, 0.0, damping * delta)
	state.orientation += state.angular_velocity * delta
	state.trick_tracker.track_rotation(state.orientation)
	if state.vertical_speed <= 0.0:
		return
	var contact := course.swept_terrain_intersection(
		previous_position, Vector2(state.course_progress, state.vertical_position)
	)
	if not contact.is_empty():
		_resolve_landing(state, course, tuning, contact)


func _resolve_missed_landing(state: RiderState, course: ParkCourse, tuning: RiderTuning) -> void:
	# Flight past the runout cannot intersect authored terrain, so make the miss terminal.
	state.landing_resolved = true
	state.trick_tracker.release_grab(state.airtime, tuning.minimum_grab_duration)
	state.grab_reach_active = false
	state.tweak_active = false
	state.trick_call = state.trick_tracker.trick_call()
	state.landing_label = "CRASH"
	state.landing_quality = 0.0
	state.landing_position = course.surface_position_at(course.recovery_progress)
	state.landing_tangent = course.tangent_at(course.recovery_progress)
	state.landing_normal = course.normal_at(course.recovery_progress)
	state.landing_angle_error_degrees = 180.0
	state.landing_velocity_alignment = 0.0
	state.landing_normal_impact = 0.0
	state.landing_angular_speed = state.angular_velocity
	state.landing_in_zone = false
	state.score_breakdown = JumpScoreScene.evaluate(state, state.landing_quality, tuning)
	state.jump_score = int(state.score_breakdown["total"])
	state.course_progress = course.recovery_progress
	state.vertical_position = state.landing_position.y
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.phase = RiderState.Phase.CRASHED
	state.ground_velocity = Vector2.ZERO
	state.course_speed = 0.0
	state.lane_speed = 0.0
	state.vertical_speed = 0.0


func _resolve_landing(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, contact: Dictionary
) -> void:
	if state.landing_resolved:
		return
	var contact_position: Vector2 = contact["position"]
	var tangent: Vector2 = contact["tangent"]
	var normal: Vector2 = contact["normal"]
	state.landing_resolved = true
	state.grab_active_at_landing = state.trick_tracker.grab_active
	state.trick_tracker.release_grab(state.airtime, tuning.minimum_grab_duration)
	state.grab_reach_active = false
	state.tweak_active = false
	state.trick_call = state.trick_tracker.trick_call()
	if state.landing_prep_active:
		# Landing prep gives beginners a small correction without rescuing an uncontrolled trick.
		state.orientation += clampf(
			angle_difference(state.orientation, tangent.angle()),
			-deg_to_rad(tuning.landing_prep_alignment_assist_degrees),
			deg_to_rad(tuning.landing_prep_alignment_assist_degrees)
		)
	var result: Dictionary = JumpJudgeScene.evaluate(
		state, course, contact_position, tangent, normal, tuning
	)
	state.landing_label = str(result["label"])
	state.landing_quality = float(result["quality"])
	state.landing_position = contact_position
	state.landing_tangent = tangent
	state.landing_normal = normal
	state.landing_angle_error_degrees = float(result["equipment_error_degrees"])
	state.landing_velocity_alignment = float(result["velocity_alignment"])
	state.landing_normal_impact = float(result["normal_impact"])
	state.landing_angular_speed = float(result["angular_speed"])
	state.landing_in_zone = bool(result["in_landing_zone"])
	state.score_breakdown = JumpScoreScene.evaluate(state, state.landing_quality, tuning)
	state.jump_score = int(state.score_breakdown["total"])
	state.course_progress = contact_position.x
	state.vertical_position = contact_position.y
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	if bool(result["crash"]):
		state.phase = RiderState.Phase.CRASHED
		state.ground_velocity = Vector2.ZERO
		state.course_speed = 0.0
		state.lane_speed = 0.0
		state.vertical_speed = 0.0
		return
	var landing_speed := maxf(Vector2(state.course_speed, state.vertical_speed).dot(tangent), 0.0)
	# Terrain tangent is course/vertical space; lane speed is a separate simulation axis.
	state.ground_velocity = Vector2(landing_speed * tangent.x, state.lane_speed)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = state.ground_velocity.y
	state.vertical_speed = 0.0
	state.angular_velocity = 0.0
	state.orientation = tangent.angle()
	state.phase = (
		RiderState.Phase.RECOVERING if state.landing_label == "SKETCHY" else RiderState.Phase.LANDED
	)
	state.recovery_time_remaining = (
		tuning.sketchy_recovery_duration
		if state.phase == RiderState.Phase.RECOVERING
		else tuning.landing_recovery_duration
	)


func _step_recovery(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	state.course_progress = minf(
		state.course_progress + state.ground_velocity.x * delta, course.recovery_progress
	)
	state.lane_position += state.ground_velocity.y * delta
	var lane_bounds := course.lane_bounds_at(state.course_progress)
	state.lane_position = clampf(state.lane_position, lane_bounds.x, lane_bounds.y)
	state.vertical_position = course.surface_y_at(state.course_progress)
	state.ground_position = Vector2(state.course_progress, state.lane_position)
	state.ground_velocity = state.ground_velocity.move_toward(
		Vector2.ZERO, tuning.snow_resistance * delta
	)
	state.course_speed = state.ground_velocity.x
	state.lane_speed = state.ground_velocity.y
	state.recovery_time_remaining = maxf(state.recovery_time_remaining - delta, 0.0)
	if is_zero_approx(state.recovery_time_remaining):
		state.phase = RiderState.Phase.GROUNDED


func _apply_drag(
	state: RiderState, input: RiderInputFrame, tuning: RiderTuning, delta: float
) -> void:
	var speed := state.ground_velocity.length()
	if is_zero_approx(speed):
		return
	var drag := tuning.snow_resistance + tuning.aerodynamic_drag * speed * speed
	if input.tuck_pressed:
		drag *= tuning.tuck_drag_multiplier
	var traverse_amount := absf(state.heading.y)
	drag += tuning.edge_drag * traverse_amount
	if input.edge_pressed:
		drag += tuning.strong_edge_drag
	if input.brake_pressed:
		drag += tuning.brake_drag
	state.ground_velocity = state.ground_velocity.move_toward(Vector2.ZERO, drag * delta)


func _apply_lane_containment(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> void:
	var bounds := course.lane_bounds_at(state.course_progress)
	var distance_to_edge := minf(state.lane_position - bounds.x, bounds.y - state.lane_position)
	if distance_to_edge >= tuning.lane_boundary_margin:
		return
	var edge_pressure := clampf(
		(tuning.lane_boundary_margin - distance_to_edge) / tuning.lane_boundary_margin, 0.0, 2.0
	)
	var center := (bounds.x + bounds.y) * 0.5
	var direction_to_center := signf(center - state.lane_position)
	state.ground_velocity.y += (
		direction_to_center * tuning.lane_boundary_force * edge_pressure * delta
	)
	state.ground_velocity.y /= 1.0 + tuning.lane_boundary_damping * edge_pressure * delta
