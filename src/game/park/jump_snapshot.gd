## Immutable terminal measurements used by the pure jump scorer.
##
## Takeoff speed is horizontal course speed at the lip. A grab uses one selected
## style and one frozen duration; either style must satisfy the simulation's
## minimum hold duration before it scores.
class_name JumpSnapshot
extends RefCounted

enum GrabStyle { NONE, STANDARD, TWEAK }

var _outcome: int
var _takeoff_speed: float
var _takeoff_pop_impulse: float
var _airtime: float
var _completed_rotations: int
var _grab_style: int
var _valid_grab_duration: float


func _init(
	next_outcome: int,
	next_takeoff_speed: float,
	next_takeoff_pop_impulse: float,
	next_airtime: float,
	next_completed_rotations: int,
	next_grab_style: int,
	next_valid_grab_duration: float
) -> void:
	_outcome = next_outcome
	_takeoff_speed = next_takeoff_speed
	_takeoff_pop_impulse = next_takeoff_pop_impulse
	_airtime = next_airtime
	_completed_rotations = next_completed_rotations
	_grab_style = next_grab_style
	_valid_grab_duration = next_valid_grab_duration


static func create(
	outcome: int,
	takeoff_speed: float,
	takeoff_pop_impulse: float,
	airtime: float,
	completed_rotations: int,
	grab_style: int,
	valid_grab_duration: float
) -> RecordValidationResult:
	var errors := PackedStringArray()
	if not JumpOutcome.is_terminal(outcome):
		errors.append("JumpSnapshot requires a terminal JumpOutcome.")
	var measurements: Array[float] = [
		takeoff_speed,
		takeoff_pop_impulse,
		airtime,
		valid_grab_duration,
	]
	for measurement: float in measurements:
		if not is_finite(measurement) or measurement < 0.0:
			errors.append("JumpSnapshot measurements must be finite and non-negative.")
			break
	if completed_rotations < 0:
		errors.append("JumpSnapshot completed rotations must be non-negative.")
	if grab_style < GrabStyle.NONE or grab_style > GrabStyle.TWEAK:
		errors.append("JumpSnapshot requires a valid grab style.")
	if grab_style == GrabStyle.NONE and valid_grab_duration > 0.0:
		errors.append("A scoreable grab duration requires a grab style.")
	if not errors.is_empty():
		return RecordValidationResult.failure(errors)
	return RecordValidationResult.success(
		JumpSnapshot.new(
			outcome,
			takeoff_speed,
			takeoff_pop_impulse,
			airtime,
			completed_rotations,
			grab_style,
			valid_grab_duration
		)
	)


func outcome() -> int:
	return _outcome


func takeoff_speed() -> float:
	return _takeoff_speed


func takeoff_pop_impulse() -> float:
	return _takeoff_pop_impulse


func airtime() -> float:
	return _airtime


func completed_rotations() -> int:
	return _completed_rotations


func grab_style() -> int:
	return _grab_style


func valid_grab_duration() -> float:
	return _valid_grab_duration
