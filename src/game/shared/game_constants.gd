## Shared values used to project park coordinates into gameplay presentation.
class_name GameConstants
extends RefCounted

const LANE_PROJECTION_SCALE := 0.18
const KMH_TO_MPH := 0.621371
const WORLD_TO_DISPLAY_SPEED_SCALE := 0.12


static func speed_to_mph(world_speed: float) -> int:
	return roundi(maxf(world_speed, 0.0) * WORLD_TO_DISPLAY_SPEED_SCALE * KMH_TO_MPH)
