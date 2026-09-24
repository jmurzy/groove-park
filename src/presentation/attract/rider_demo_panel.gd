## How-to-play live demo: two rider lanes mirroring the selected phase's inputs,
## including frame-selected horizontal spin artwork.
class_name RiderDemoPanel
extends Control

enum AirRotationPhase {
	WAITING_DIRECTION, ROTATING_FIRST_HALF, WAITING_SECOND_DIRECTION, ROTATING_SECOND_HALF
}

const DEMO_POSITION := Vector2(60, 124)
const DEMO_SIZE := Vector2(1696, 389)
const SKIER_LANE_POSITION := Vector2(188, 97)
const SNOWBOARDER_LANE_POSITION := Vector2(1220, 97)
const LANE_SIZE := Vector2(288, 195)
const STATUS_SIZE := Vector2(600, 24)
const STATUS_Y := 300.0
const STATUS_COLOR := Color("aefcff")
const STATUS_PROMPT_COLOR := Color("fff16a")
const RIDER_POSITION := Vector2(144, 165)
const RIDER_SCALE := 1.12
const LINE_PICK_OFFSET := 10.0
const AIRBORNE_LIFT := Vector2(0, -50)
const INITIAL_SPEED_MPH := 0.0
const MAX_SPEED_MPH := 90.0
const SPEED_BUILD_RATE_MPH := 20.0
const SPEED_COAST_RATE_MPH := 15.0
const SPEED_CHECK_RATE_MPH := 45.0
# Deliberately slow enough for the How to Play screen to show the direction.
const SPIN_PROGRESS_RATE := 0.7

var _skier: SkierView
var _snowboarder: SnowboarderView
var _skier_status: Label
var _snowboarder_status: Label
var _skier_speed: Label
var _snowboarder_speed: Label
var _airborne := false
var _air_rotation_phase := AirRotationPhase.WAITING_DIRECTION
var _spin_direction := 0
var _spin_progress := 0.0
var _spin_rearmed := true
var _spin_grab_tweak := false
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
	_skier_status = _add_rider_status(SKIER_LANE_POSITION.x)
	_snowboarder_status = _add_rider_status(SNOWBOARDER_LANE_POSITION.x)


func tick(delta: float = 0.0) -> void:
	if (
		not is_instance_valid(_skier)
		or not is_instance_valid(_snowboarder)
		or not is_instance_valid(_skier_status)
		or not is_instance_valid(_snowboarder_status)
	):
		return
	_update_speed(delta)
	_update_air_rotation(delta)
	_update_rider_positions()
	var animation := _demo_animation()
	_play_demo_animation(animation)
	var speed_scale := _neutral_glide_speed_scale() if animation.skier == &"neutral_glide" else 1.0
	_skier.set_preview_speed_scale(speed_scale)
	_snowboarder.set_preview_speed_scale(speed_scale)
	_skier_status.text = String(animation.get("label_skier", animation.get("label", "")))
	_snowboarder_status.text = String(
		animation.get("label_snowboarder", animation.get("label", ""))
	)
	var prompt := _airborne and _air_rotation_phase == AirRotationPhase.WAITING_SECOND_DIRECTION
	var status_color := STATUS_PROMPT_COLOR if prompt else STATUS_COLOR
	_skier_status.add_theme_color_override("font_color", status_color)
	_snowboarder_status.add_theme_color_override("font_color", status_color)


func set_airborne_lift(lifted: bool) -> void:
	if _airborne != lifted:
		_reset_air_rotation()
	_airborne = lifted
	_update_rider_positions()
	_reset_rider_rotation()


func _update_rider_positions() -> void:
	var rider_position := RIDER_POSITION + AIRBORNE_LIFT if _airborne else RIDER_POSITION
	if not _airborne:
		var up_held := Input.is_action_pressed(&"move_up")
		var down_held := Input.is_action_pressed(&"move_down")
		if up_held and not down_held:
			rider_position += Vector2(0, -LINE_PICK_OFFSET)
		elif down_held and not up_held:
			rider_position += Vector2(0, LINE_PICK_OFFSET)
	if is_instance_valid(_skier):
		_skier.position = rider_position
	if is_instance_valid(_snowboarder):
		_snowboarder.position = rider_position


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


func _add_rider_status(lane_x: float) -> Label:
	var status := ArcadeTheme.make_label("NEUTRAL GLIDE", 13, STATUS_COLOR)
	# Long spin labels (e.g. "RT RIGHT/FRONTSIDE SECOND 180") are wider than a
	# lane, so use a wide box centered on the lane to keep them centered.
	status.position = Vector2(lane_x + LANE_SIZE.x * 0.5 - STATUS_SIZE.x * 0.5, STATUS_Y)
	status.size = STATUS_SIZE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.clip_text = false
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
		if Input.is_action_pressed(&"action_x"):
			skier = &"landing_prep"
			snowboarder = &"landing_prep"
			label = "X  HOLD TO LAND"
		elif _air_grab_held():
			if Input.is_action_pressed(&"action_b"):
				skier = &"grab_tweak"
				snowboarder = &"grab_tweak"
				label = "B  HOLD TWEAK GRAB"
			else:
				skier = &"grab_hold"
				snowboarder = &"grab_hold"
				label = "A  HOLD GRAB"
			if _air_rotation_phase != AirRotationPhase.WAITING_DIRECTION:
				var spin_frame := _spin_frame()
				return {
					"skier": _skier_spin_animation(),
					"snowboarder": _snowboarder_spin_animation(),
					"label_skier": _spin_label_for(_spin_style_label_skier()),
					"label_snowboarder": _spin_label_for(_spin_style_label_snowboarder()),
					"spin_frame": spin_frame,
				}
		else:
			skier = &"neutral_air"
			snowboarder = &"neutral_air"
			label = "NEUTRAL AIR"
		return {"skier": skier, "snowboarder": snowboarder, "label": label}
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


func _play_demo_animation(animation: Dictionary) -> void:
	var spin_frame := int(animation.get("spin_frame", -1))
	if spin_frame >= 0:
		_skier.play_preview_frame(animation.skier, spin_frame)
		_snowboarder.play_preview_frame(animation.snowboarder, spin_frame)
		return
	_skier.play_preview(animation.skier)
	_snowboarder.play_preview(animation.snowboarder)


func _update_air_rotation(delta: float) -> void:
	if not _airborne or not _air_grab_held():
		_reset_air_rotation()
		return
	var spin_input := 0
	if Input.is_action_just_pressed(&"action_lt"):
		spin_input = -1
	elif Input.is_action_just_pressed(&"action_rt"):
		spin_input = 1
	if not (Input.is_action_pressed(&"action_lt") or Input.is_action_pressed(&"action_rt")):
		_spin_rearmed = true
	match _air_rotation_phase:
		AirRotationPhase.WAITING_DIRECTION:
			if spin_input != 0:
				_spin_direction = spin_input
				_spin_grab_tweak = Input.is_action_pressed(&"action_b")
				_spin_progress = 0.0
				_spin_rearmed = false
				_air_rotation_phase = AirRotationPhase.ROTATING_FIRST_HALF
		AirRotationPhase.ROTATING_FIRST_HALF:
			_spin_progress = move_toward(_spin_progress, 0.5, SPIN_PROGRESS_RATE * delta)
			if is_equal_approx(_spin_progress, 0.5):
				_air_rotation_phase = AirRotationPhase.WAITING_SECOND_DIRECTION
		AirRotationPhase.WAITING_SECOND_DIRECTION:
			if _spin_rearmed and spin_input == _spin_direction and spin_input != 0:
				_spin_rearmed = false
				_air_rotation_phase = AirRotationPhase.ROTATING_SECOND_HALF
		AirRotationPhase.ROTATING_SECOND_HALF:
			_spin_progress = move_toward(_spin_progress, 1.0, SPIN_PROGRESS_RATE * delta)
			if is_equal_approx(_spin_progress, 1.0):
				_reset_air_rotation()


func _spin_frame() -> int:
	var step := mini(roundi(_spin_progress * 8.0), 8)
	return 0 if step >= 8 else step


func _skier_spin_animation() -> StringName:
	if _spin_grab_tweak:
		return &"spin_tweak_left" if _spin_direction < 0 else &"spin_tweak_right"
	return &"spin_regular_left" if _spin_direction < 0 else &"spin_regular_right"


func _snowboarder_spin_animation() -> StringName:
	if _spin_grab_tweak:
		return &"spin_tweak_backside" if _spin_direction < 0 else &"spin_tweak_frontside"
	return &"spin_regular_backside" if _spin_direction < 0 else &"spin_regular_frontside"


func _spin_label_for(style_label: String) -> String:
	match _air_rotation_phase:
		AirRotationPhase.ROTATING_FIRST_HALF:
			return "%s  %s FIRST 180" % [_spin_trigger_label(), style_label]
		AirRotationPhase.WAITING_SECOND_DIRECTION:
			return "...THEN %s TO COMPLETE" % _spin_trigger_label()
		AirRotationPhase.ROTATING_SECOND_HALF:
			return "%s  %s SECOND 180" % [_spin_trigger_label(), style_label]
		_:
			return "%s  360 COMPLETE" % style_label


func _spin_trigger_label() -> String:
	return "LT" if _spin_direction < 0 else "RT"


func _spin_style_label_skier() -> String:
	return "LEFT" if _spin_direction < 0 else "RIGHT"


func _spin_style_label_snowboarder() -> String:
	return "BACKSIDE" if _spin_direction < 0 else "FRONTSIDE"


func _reset_air_rotation() -> void:
	_air_rotation_phase = AirRotationPhase.WAITING_DIRECTION
	_spin_direction = 0
	_spin_progress = 0.0
	_spin_rearmed = true
	_spin_grab_tweak = false
	_reset_rider_rotation()


func _reset_rider_rotation() -> void:
	if is_instance_valid(_skier):
		_skier.rotation = 0.0
	if is_instance_valid(_snowboarder):
		_snowboarder.rotation = 0.0


func _air_grab_held() -> bool:
	return Input.is_action_pressed(&"action_a") or Input.is_action_pressed(&"action_b")
