## Typed state returned by the Liftie resort endpoint.
class_name LiftieResortResponse
extends RefCounted


class Timestamp:
	extends RefCounted

	var lifts: int
	var opening: int


class LiftPercentage:
	extends RefCounted

	var open: float
	var hold: float
	var scheduled: float
	var closed: float


class LiftStats:
	extends RefCounted

	var open: int
	var hold: int
	var scheduled: int
	var closed: int
	var percentage: LiftPercentage


class Lifts:
	extends RefCounted

	var status: Dictionary[String, String]
	var stats: LiftStats


var id: String
var open: bool
## X is longitude; Y is latitude.
var ll: Vector2
var timestamp: Timestamp
var lifts: Lifts
