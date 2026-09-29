## Advances airborne kinematics and reports terrain contact without resolving outcomes.
class_name FlightIntegrator
extends RefCounted


func advance(
	state: RiderState, course: ParkCourse, tuning: RiderTuning, delta: float
) -> Dictionary:
	var flight_delta := delta * tuning.air_time_scale
	var previous_position := Vector2(
		state.kinematics.course_progress, state.kinematics.vertical_position
	)
	var previous_lane_position := state.kinematics.lane_position
	var previous_course_speed := state.kinematics.course_speed
	var previous_lane_speed := state.kinematics.lane_speed
	var previous_vertical_speed := state.kinematics.vertical_speed
	var next_vertical_speed := (
		previous_vertical_speed
		+ tuning.gravity * tuning.flight_arc_height_multiplier * flight_delta
	)
	var drag_factor := maxf(0.0, 1.0 - tuning.air_drag * flight_delta)
	var next_course_speed := previous_course_speed * drag_factor
	var next_lane_speed := previous_lane_speed * drag_factor
	next_vertical_speed *= drag_factor
	var next_position := (
		previous_position + Vector2(next_course_speed, next_vertical_speed) * flight_delta
	)
	var next_lane_position := previous_lane_position + next_lane_speed * flight_delta
	var contact := course.landing_swept_terrain_intersection(
		previous_position, next_position, state.kinematics.active_route_index
	)
	if not contact.is_empty():
		var contact_time := float(contact["time"])
		state.kinematics.course_speed = lerpf(
			previous_course_speed, next_course_speed, contact_time
		)
		state.kinematics.lane_speed = lerpf(previous_lane_speed, next_lane_speed, contact_time)
		state.kinematics.vertical_speed = lerpf(
			previous_vertical_speed, next_vertical_speed, contact_time
		)
		state.kinematics.lane_position = lerpf(
			previous_lane_position, next_lane_position, contact_time
		)
		return {
			"contact": contact,
			"airtime_delta": flight_delta * contact_time,
			"remaining_delta": delta * (1.0 - contact_time),
		}
	state.kinematics.course_speed = next_course_speed
	state.kinematics.lane_speed = next_lane_speed
	state.kinematics.vertical_speed = next_vertical_speed
	state.kinematics.course_progress = next_position.x
	state.kinematics.lane_position = next_lane_position
	state.kinematics.vertical_position = next_position.y
	state.kinematics.ground_position = Vector2(
		state.kinematics.course_progress, state.kinematics.lane_position
	)
	state.kinematics.ground_velocity = Vector2(
		state.kinematics.course_speed, state.kinematics.lane_speed
	)
	return {"airtime_delta": flight_delta, "remaining_delta": -1.0}


func has_overshot_landing(state: RiderState, course: ParkCourse) -> bool:
	return (
		state.kinematics.course_progress
		> course.landing_end_at(state.kinematics.active_route_index).x
	)


func should_abandon(state: RiderState, course: ParkCourse) -> bool:
	return (
		state.kinematics.vertical_speed > 0.0
		and (
			state.kinematics.vertical_position
			> course.flight_abandon_trigger_y_at(
				state.kinematics.course_progress, state.kinematics.active_route_index
			)
		)
	)
