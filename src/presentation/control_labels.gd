## User-facing input names for the active export target.
class_name ControlLabels
extends RefCounted


static func is_web() -> bool:
	return OS.has_feature("web")


static func action(action_name: StringName) -> String:
	if is_web():
		match action_name:
			&"move_left":
				return "A"
			&"move_right":
				return "D"
			&"move_up":
				return "W"
			&"move_down":
				return "S"
			&"action_a":
				return "J"
			&"action_b":
				return "K"
			&"action_x":
				return "L"
			&"action_lt":
				return "Q"
			&"action_rt":
				return "E"
	else:
		match action_name:
			&"move_left":
				return "LEFT"
			&"move_right":
				return "RIGHT"
			&"move_up":
				return "UP"
			&"move_down":
				return "DOWN"
			&"action_a":
				return "A"
			&"action_b":
				return "B"
			&"action_x":
				return "X"
			&"action_lt":
				return "LT"
			&"action_rt":
				return "RT"
	return ""
