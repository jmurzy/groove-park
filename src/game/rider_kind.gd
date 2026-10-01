## Canonical rider identities for round state and presentation.
class_name RiderKind
extends RefCounted

const SNOWBOARDER := &"snowboarder"
const SKIER := &"skier"


static func is_valid(kind: StringName) -> bool:
	return kind == SNOWBOARDER or kind == SKIER
