## Flight-only trick measurements: unwrapped rotation, grab/tweak timers, and the
## display string. Example: `track_rotation(orientation)`, then `trick_call()`.
class_name TrickTracker
extends RefCounted

# Flight-only measurements. Presentation and input events never author these values.
var takeoff_orientation := 0.0
var previous_orientation := 0.0
var cumulative_rotation := 0.0
var completed_rotations := 0
var grab_active := false
var grab_duration := 0.0
var valid_grab_duration := 0.0
var tweak_duration := 0.0
var grab_release_airtime := -1.0


func reset(orientation: float) -> void:
	takeoff_orientation = orientation
	previous_orientation = orientation
	cumulative_rotation = 0.0
	completed_rotations = 0
	grab_active = false
	grab_duration = 0.0
	valid_grab_duration = 0.0
	tweak_duration = 0.0
	grab_release_airtime = -1.0


func track_rotation(orientation: float) -> void:
	cumulative_rotation += angle_difference(previous_orientation, orientation)
	previous_orientation = orientation
	completed_rotations = floori(absf(cumulative_rotation) / TAU)


func start_grab() -> void:
	grab_active = true


func release_grab(airtime: float, minimum_duration: float) -> void:
	if not grab_active:
		return
	grab_active = false
	grab_release_airtime = airtime
	if grab_duration >= minimum_duration:
		valid_grab_duration = grab_duration


func step_grab(delta: float, tweak_pressed: bool) -> void:
	if not grab_active:
		return
	grab_duration += delta
	if tweak_pressed:
		tweak_duration += delta


func trick_call() -> String:
	var parts := PackedStringArray()
	if completed_rotations > 0:
		var direction := "FORWARD" if cumulative_rotation > 0.0 else "BACKWARD"
		parts.append("%d %s" % [completed_rotations * 360, direction])
	if valid_grab_duration > 0.0:
		parts.append("SIGNATURE GRAB")
	if tweak_duration > 0.0:
		parts.append("TWEAK")
	return " ".join(parts) if not parts.is_empty() else "STRAIGHT AIR"
