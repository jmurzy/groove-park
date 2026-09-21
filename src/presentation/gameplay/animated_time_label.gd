## Label that counts up from a start time as MM:SS.CS.
## Example: `AnimatedTimeLabel.new(0.0)`.
class_name AnimatedTimeLabel
extends Label

var elapsed_seconds := 0.0


func _init(start_seconds: float) -> void:
	elapsed_seconds = start_seconds
	_update_text()


func _process(delta: float) -> void:
	elapsed_seconds += delta
	_update_text()


func _update_text() -> void:
	var centiseconds := int(elapsed_seconds * 100.0)
	var minutes := centiseconds / 6000
	var seconds := (centiseconds / 100) % 60
	text = "%02d:%02d.%02d" % [minutes, seconds, centiseconds % 100]
