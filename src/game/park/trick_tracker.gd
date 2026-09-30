## Flight-only trick measurements: signed rotation and grab/tweak timers.
class_name TrickTracker
extends RefCounted

# Flight-only measurements. Presentation and input events never author these values.
var cumulative_rotation := 0.0
var grab_active := false
var grab_duration := 0.0
var valid_grab_duration := 0.0
var tweak_duration := 0.0
var grab_release_airtime := -1.0


func reset() -> void:
	cumulative_rotation = 0.0
	grab_active = false
	grab_duration = 0.0
	valid_grab_duration = 0.0
	tweak_duration = 0.0
	grab_release_airtime = -1.0


func complete_rotation(direction: int) -> void:
	cumulative_rotation += signi(direction) * TAU


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
