class_name RiderDemoPanel
extends Control

const DEMO_POSITION := Vector2(60, 124)
const DEMO_SIZE := Vector2(1696, 389)
const SKIER_LANE_POSITION := Vector2(188, 97)
const SNOWBOARDER_LANE_POSITION := Vector2(1220, 97)
const LANE_SIZE := Vector2(288, 195)
const RIDER_SCALE := 1.12

var _skier: SkierView
var _snowboarder: SnowboarderView
var _skier_status: Label
var _snowboarder_status: Label


func _ready() -> void:
	name = "RiderDemoPanel"
	position = DEMO_POSITION
	size = DEMO_SIZE
	clip_contents = true
	_add_rider_lane("SKIER", SKIER_LANE_POSITION, true)
	_add_rider_lane("SNOWBOARDER", SNOWBOARDER_LANE_POSITION, false)
	_skier_status = _add_rider_status(Vector2(188, 300))
	_snowboarder_status = _add_rider_status(Vector2(1220, 300))


func tick() -> void:
	if (
		not is_instance_valid(_skier)
		or not is_instance_valid(_snowboarder)
		or not is_instance_valid(_skier_status)
		or not is_instance_valid(_snowboarder_status)
	):
		return
	var animation := _demo_animation()
	_skier.play_preview(animation.skier)
	_snowboarder.play_preview(animation.snowboarder)
	_skier_status.text = animation.label
	_snowboarder_status.text = animation.label


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
	rider.position = Vector2(144, 139 if is_skier else 159)
	rider.scale = Vector2.ONE * RIDER_SCALE
	lane.add_child(rider)
	if is_skier:
		_skier = rider as SkierView
	else:
		_snowboarder = rider as SnowboarderView


func _add_rider_status(status_position: Vector2) -> Label:
	var status := ArcadeTheme.make_label("IDLE GLIDE", 13, Color("aefcff"))
	status.position = status_position
	status.size = Vector2(LANE_SIZE.x, 24)
	add_child(status)
	return status


func _demo_animation() -> Dictionary:
	var skier := &"neutral_glide"
	var snowboarder := &"neutral_glide"
	var label := "IDLE GLIDE"
	if Input.is_action_pressed(&"action_x"):
		skier = &"grab_tweak"
		snowboarder = &"grab_tweak"
		label = "BLUE X  TWEAK"
	elif Input.is_action_pressed(&"action_a"):
		skier = &"grab_hold"
		snowboarder = &"grab_hold"
		label = "A  GRAB / TUCK"
	elif Input.is_action_pressed(&"move_down"):
		skier = &"compression"
		snowboarder = &"compression"
		label = "DOWN  COMPACT"
	elif Input.is_action_pressed(&"move_up"):
		skier = &"takeoff_extension"
		snowboarder = &"takeoff_extension"
		label = "UP  EXTEND"
	elif Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"action_b"):
		skier = &"carve_uphill"
		snowboarder = &"carve_heel"
		label = "LEFT / B  CHECK SPEED"
	elif Input.is_action_pressed(&"move_right") or Input.is_action_pressed(&"action_y"):
		skier = &"carve_downhill"
		snowboarder = &"carve_toe"
		label = "RIGHT / Y  CARVE"
	return {"skier": skier, "snowboarder": snowboarder, "label": label}
