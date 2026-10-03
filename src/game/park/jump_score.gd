## Immutable integer score breakdown for one resolved jump.
class_name JumpScore
extends RefCounted

var _approach_points: int
var _takeoff_points: int
var _airtime_points: int
var _rotation_points: int
var _grab_points: int
var _style_bonus_points: int
var _landing_multiplier_milli: int
var _total: int


func _init(
	next_approach_points: int,
	next_takeoff_points: int,
	next_airtime_points: int,
	next_rotation_points: int,
	next_grab_points: int,
	next_style_bonus_points: int,
	next_landing_multiplier_milli: int,
	next_total: int
) -> void:
	_approach_points = next_approach_points
	_takeoff_points = next_takeoff_points
	_airtime_points = next_airtime_points
	_rotation_points = next_rotation_points
	_grab_points = next_grab_points
	_style_bonus_points = next_style_bonus_points
	_landing_multiplier_milli = next_landing_multiplier_milli
	_total = next_total


func approach_points() -> int:
	return _approach_points


func takeoff_points() -> int:
	return _takeoff_points


func airtime_points() -> int:
	return _airtime_points


func rotation_points() -> int:
	return _rotation_points


func grab_points() -> int:
	return _grab_points


func style_bonus_points() -> int:
	return _style_bonus_points


func landing_multiplier_milli() -> int:
	return _landing_multiplier_milli


func subtotal() -> int:
	return (
		_approach_points
		+ _takeoff_points
		+ _airtime_points
		+ _rotation_points
		+ _grab_points
		+ _style_bonus_points
	)


func total() -> int:
	return _total
