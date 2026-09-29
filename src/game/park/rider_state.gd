## Aggregate root for one rider's mutable runtime state, split into focused
## kinematics, run lifecycle, and jump models.
class_name RiderState
extends RefCounted

var kinematics := RiderKinematics.new()
var run := RiderRunState.new()
var jump := JumpState.new()


func movement_velocity() -> Vector2:
	if run.run_phase == RiderRunState.RunPhase.FLIGHT:
		return Vector2(kinematics.course_speed, kinematics.vertical_speed)
	return kinematics.ground_velocity
