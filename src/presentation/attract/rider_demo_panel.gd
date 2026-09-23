## How-to-play live demo: two rider lanes mirroring the selected phase's inputs.
class_name RiderDemoPanel
extends Control

enum AirRotationPhase {WAITING_LEFT, WAITING_RIGHT}

const DEMO_POSITION := Vector2(60, 124)
const DEMO_SIZE := Vector2(1696, 389)
const SKIER_LANE_POSITION := Vector2(188, 97)
const SNOWBOARDER_LANE_POSITION := Vector2(1220, 97)
const LANE_SIZE := Vector2(288, 195)
const RIDER_POSITION := Vector2(144, 165)
const RIDER_SCALE := 1.12
const AIRBORNE_LIFT := Vector2(0, -50)
const INITIAL_SPEED_MPH := 0.0
const MAX_SPEED_MPH := 90.0
const SPEED_BUILD_RATE_MPH := 20.0
const SPEED_COAST_RATE_MPH := 15.0
const SPEED_CHECK_RATE_MPH := 45.0

var _skier: SkierView
var _snowboarder: SnowboarderView
var _skier_status: Label
var _snowboarder_status: Label
var _skier_speed: Label
var _snowboarder_speed: Label
var _airborne := false
var _air_rotation_phase := AirRotationPhase.WAITING_LEFT
var _air_rotation := 0.0
var _speed_mph := INITIAL_SPEED_MPH


func _ready() -> void:
	name = "RiderDemoPanel"
	position = DEMO_POSITION
	size = DEMO_SIZE
	clip_contents = true
	_add_rider_lane("SKIER", SKIER_LANE_POSITION, true)
	_add_rider_lane("SNOWBOARDER", SNOWBOARDER_LANE_POSITION, false)
	_skier_speed = _add_rider_speed(SKIER_LANE_POSITION + Vector2(0, 35))
	_snowboarder_speed = _add_rider_speed(SNOWBOARDER_LANE_POSITION + Vector2(0, 35))
	_skier_status = _add_rider_status(Vector2(188, 300))
	_snowboarder_status = _add_rider_status(Vector2(1220, 300))


func tick(delta: float = 0.0) -> void:
	if (
		not is_instance_valid(_skier)
		or not is_instance_valid(_snowboarder)
		or not is_instance_valid(_skier_status)
		or not is_instance_valid(_snowboarder_status)
	):
		return
	_update_speed(delta)
	var animation := _demo_animation()
	_skier.play_preview(animation.skier)
	_snowboarder.play_preview(animation.snowboarder)
	var speed_scale := _neutral_glide_speed_scale() if animation.skier == &"neutral_glide" else 1.0
	_skier.set_preview_speed_scale(speed_scale)
	_snowboarder.set_preview_speed_scale(speed_scale)
	_skier_status.text = animation.label
	_snowboarder_status.text = animation.label


func set_airborne_lift(lifted: bool) -> void:
	if _airborne != lifted:
		_air_rotation_phase = AirRotationPhase.WAITING_LEFT
		_air_rotation = 0.0
	_airborne = lifted
	var rider_position := RIDER_POSITION + AIRBORNE_LIFT if lifted else RIDER_POSITION
	if is_instance_valid(_skier):
		_skier.position = rider_position
	if is_instance_valid(_snowboarder):
		_snowboarder.position = rider_position
	_apply_air_rotation()


func _add_rider_lane(rider_name: String, lane_position: Vector2, is_skier: bool) -> void:
	var lane := Control.new()
	lane.position = lane_position
	lane.size = LANE_SIZE
	add_child(lane)
	var label := ArcadeTheme.make_label(rider_name, 18, Color("d4efff"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 8)
	label.size = Vector2(LANE_SIZE.x, 20)
	lane.add_child(label)
	var slope := Polygon2D.new()
	slope.polygon = PackedVector2Array(
		[Vector2(0, 141), Vector2(LANE_SIZE.x, 170), Vector2(LANE_SIZE.x, 195), Vector2(0, 195)]
	)
	slope.color = Color("b9f7ff")
	lane.add_child(slope)
	for scanline_y in range(137, 189, 8):
		var scanline := ColorRect.new()
		scanline.position = Vector2(0, scanline_y)
		scanline.size = Vector2(LANE_SIZE.x, 2)
		scanline.color = Color("4b93ce80")
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.add_child(scanline)
	var rider: RiderViewBase = SkierView.new() if is_skier else SnowboarderView.new()
	rider.position = RIDER_POSITION
	rider.scale = Vector2.ONE * RIDER_SCALE
	lane.add_child(rider)
	if is_skier:
		_skier = rider as SkierView
	else:
		_snowboarder = rider as SnowboarderView


func _add_rider_status(status_position: Vector2) -> Label:
	var status := ArcadeTheme.make_label("NEUTRAL GLIDE", 13, Color("aefcff"))
	status.position = status_position
	status.size = Vector2(LANE_SIZE.x, 24)
	add_child(status)
	return status


func _add_rider_speed(speed_position: Vector2) -> Label:
	var speed := ArcadeTheme.make_label("%d MPH" % roundi(_speed_mph), 12, Color("aefcff"))
	speed.position = speed_position
	speed.size = Vector2(LANE_SIZE.x, 18)
	speed.visible = not is_zero_approx(_speed_mph)
	add_child(speed)
	return speed


func set_speed_mph(speed_mph: float) -> void:
	_speed_mph = clampf(speed_mph, 0.0, MAX_SPEED_MPH)
	if is_instance_valid(_skier_speed):
		_skier_speed.text = "%d MPH" % roundi(_speed_mph)
		_skier_speed.visible = not is_zero_approx(_speed_mph)
	if is_instance_valid(_snowboarder_speed):
		_snowboarder_speed.text = "%d MPH" % roundi(_speed_mph)
		_snowboarder_speed.visible = not is_zero_approx(_speed_mph)


func _neutral_glide_speed_scale() -> float:
	return RiderViewBase.neutral_glide_speed_scale_for_mph(_speed_mph)


func _update_speed(delta: float) -> void:
	var target_speed := INITIAL_SPEED_MPH
	var change_rate := SPEED_COAST_RATE_MPH
	if (
		not _airborne
		and (Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"action_b"))
	):
		change_rate = SPEED_CHECK_RATE_MPH
	elif not _airborne and Input.is_action_pressed(&"move_right"):
		target_speed = MAX_SPEED_MPH
		change_rate = SPEED_BUILD_RATE_MPH
	set_speed_mph(move_toward(_speed_mph, target_speed, change_rate * delta))


func _demo_animation() -> Dictionary:
	var skier := &"neutral_glide"
	var snowboarder := &"neutral_glide"
	var label := "NEUTRAL GLIDE"
	if _airborne:
		if _air_grab_held():
			if Input.is_action_pressed(&"action_b"):
				skier = &"grab_tweak"
				snowboarder = &"grab_tweak"
				label = "B  HOLD TWEAK GRAB"
			else:
				skier = &"grab_hold"
				snowboarder = &"grab_hold"
				label = "A  HOLD GRAB"
			if (
				_air_rotation_phase == AirRotationPhase.WAITING_LEFT
				and Input.is_action_just_pressed(&"move_left")
			):
				_air_rotation = PI
				_air_rotation_phase = AirRotationPhase.WAITING_RIGHT
				label = "LEFT  FIRST 180"
			elif (
				_air_rotation_phase == AirRotationPhase.WAITING_RIGHT
				and Input.is_action_just_pressed(&"move_right")
			):
				_air_rotation = 0.0
				_air_rotation_phase = AirRotationPhase.WAITING_LEFT
				label = "RIGHT  COMPLETE 360"
		else:
			skier = &"neutral_air"
			snowboarder = &"neutral_air"
			label = "NEUTRAL AIR"
		_apply_air_rotation()
		return {"skier": skier, "snowboarder": snowboarder, "label": label}
	_apply_air_rotation()
	if Input.is_action_pressed(&"action_x"):
		skier = &"compression"
		snowboarder = &"compression"
		label = "X  CHARGE COMPRESSION"
	elif Input.is_action_pressed(&"action_a"):
		skier = &"tuck"
		snowboarder = &"tuck"
		label = "A  TUCK"
	elif Input.is_action_pressed(&"move_down"):
		label = "DOWN  PICK LINE"
	elif Input.is_action_pressed(&"move_up"):
		label = "UP  PICK LINE"
	elif Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"action_b"):
		skier = &"carve_uphill"
		snowboarder = &"carve_heel"
		label = "LEFT / B  CHECK SPEED"
	elif Input.is_action_pressed(&"move_right"):
		label = "RIGHT  BUILD SPEED"
	return {"skier": skier, "snowboarder": snowboarder, "label": label}


func _apply_air_rotation() -> void:
	if is_instance_valid(_skier):
		_skier.rotation = _air_rotation
	if is_instance_valid(_snowboarder):
		_snowboarder.rotation = _air_rotation


func _air_grab_held() -> bool:
	return Input.is_action_pressed(&"action_a") or Input.is_action_pressed(&"action_b")
