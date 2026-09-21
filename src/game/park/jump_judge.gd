## Grades first terrain contact as PERFECT / CLEAN / SKETCHY / CRASH with a
## continuous 0-1 quality. Example: a misaligned or hard impact returns CRASH.
class_name JumpJudge
extends RefCounted


static func evaluate(
	state: RiderState,
	course: ParkCourse,
	contact_position: Vector2,
	tangent: Vector2,
	normal: Vector2,
	tuning: RiderTuning
) -> Dictionary:
	var velocity := Vector2(state.course_speed, state.vertical_speed)
	var equipment_error := absf(rad_to_deg(angle_difference(state.orientation, tangent.angle())))
	var velocity_alignment := (
		maxf(velocity.normalized().dot(tangent), 0.0) if not velocity.is_zero_approx() else 0.0
	)
	var normal_impact := absf(velocity.dot(normal))
	var angular_speed := absf(state.angular_velocity)
	var contact_surface := course.surface_at(Vector2(contact_position.x, state.lane_position))
	var in_landing_zone := (
		contact_surface != null and contact_surface.role == ParkSurface.Role.LANDING
	)
	var angle_quality := clampf(1.0 - equipment_error / tuning.crash_angle_degrees, 0.0, 1.0)
	var velocity_quality := clampf(
		(
			(velocity_alignment - tuning.minimum_landing_alignment)
			/ (1.0 - tuning.minimum_landing_alignment)
		),
		0.0,
		1.0
	)
	var impact_quality := clampf(1.0 - normal_impact / tuning.crash_normal_impact, 0.0, 1.0)
	var angular_quality := clampf(1.0 - angular_speed / tuning.crash_angular_velocity, 0.0, 1.0)
	var quality := minf(
		minf(angle_quality, velocity_quality), minf(impact_quality, angular_quality)
	)
	if state.grab_active_at_landing:
		quality *= 0.65
	var crash := (
		not in_landing_zone
		or equipment_error > tuning.crash_angle_degrees
		or normal_impact > tuning.crash_normal_impact
		or angular_speed > tuning.crash_angular_velocity
	)
	var label := "CRASH"
	if not crash:
		if (
			equipment_error <= tuning.perfect_angle_degrees
			and normal_impact <= tuning.perfect_normal_impact
			and angular_speed <= tuning.perfect_angular_velocity
			and not state.grab_active_at_landing
		):
			label = "PERFECT"
		elif equipment_error <= tuning.clean_angle_degrees:
			label = "CLEAN"
		else:
			label = "SKETCHY"
	return {
		"label": label,
		"quality": 0.0 if crash else quality,
		"equipment_error_degrees": equipment_error,
		"velocity_alignment": velocity_alignment,
		"normal_impact": normal_impact,
		"angular_speed": angular_speed,
		"in_landing_zone": in_landing_zone,
		"crash": crash,
		"grab_held_at_contact": state.grab_active_at_landing,
	}
