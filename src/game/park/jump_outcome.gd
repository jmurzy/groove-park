## Canonical terminal outcome for one jump.
class_name JumpOutcome
extends RefCounted

enum Value { NONE, LOW_MOMENTUM, BAIL, CLEAN, SKETCHY, CRASH }


static func is_terminal(outcome: int) -> bool:
	return outcome >= Value.LOW_MOMENTUM and outcome <= Value.CRASH


static func label(outcome: int) -> String:
	match outcome:
		Value.LOW_MOMENTUM:
			return "LOW MOMENTUM"
		Value.BAIL:
			return "BAIL"
		Value.CLEAN:
			return "CLEAN"
		Value.SKETCHY:
			return "SKETCHY"
		Value.CRASH:
			return "CRASH"
	return ""
