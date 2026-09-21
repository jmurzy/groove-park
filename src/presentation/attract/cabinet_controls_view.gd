## Live Sente cabinet diagram: joystick sprite follows the stick and buttons show
## pressed states with click sounds. Call `tick()` each frame.
class_name CabinetControlsView
extends Node2D

const CONTROL_BUTTONS := preload("res://artwork/controls/sente_control_buttons.png")
const CONTROL_BUTTONS_DEPRESSED := preload(
	"res://artwork/controls/sente_control_buttons_depressed.png"
)
const SWITCH_SOUND := preload("res://assets/audio/switch24.ogg")
const JOYSTICK_SOUND := preload("res://assets/audio/switch38.ogg")
const JOYSTICK_BASE := preload("res://artwork/controls/sente_controls_base.png")
const JOYSTICK_SPRITES := preload("res://artwork/controls/sente_joystick_sprite.png")
const CONTROL_LAYOUT_SIZE := Vector2(1487, 1058)
const CABINET_ART_SIZE := Vector2(686, 456)
const BUTTON_SHEET_COLUMNS := 4
const BUTTON_CELL_SIZE := Vector2(362, 362)
const JOYSTICK_SHEET_COLUMNS := 3
const JOYSTICK_CELL_SIZE := Vector2(530, 530)
const JOYSTICK_POSITION := Vector2(303, 546)
const JOYSTICK_SCALE := 1.265
const BUTTON_SCALE := 0.64187710587

var _control_sprites: Dictionary[StringName, Sprite2D]
var _control_textures: Dictionary[StringName, Array]
var _joystick: Sprite2D
var _joystick_textures: Array[Texture2D]
var _joystick_direction := Vector2.ZERO
var _switch_sound: AudioStreamPlayer
var _joystick_sound: AudioStreamPlayer


func _ready() -> void:
	name = "CabinetControlsView"
	position = Vector2(0, 54)
	scale = CABINET_ART_SIZE / CONTROL_LAYOUT_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_base()
	_build_joystick()
	_build_buttons()
	_switch_sound = AudioStreamPlayer.new()
	_switch_sound.stream = SWITCH_SOUND
	add_child(_switch_sound)
	_joystick_sound = AudioStreamPlayer.new()
	_joystick_sound.stream = JOYSTICK_SOUND
	add_child(_joystick_sound)


func tick() -> void:
	_update_joystick()
	_update_buttons()


func _build_base() -> void:
	var base := Sprite2D.new()
	base.texture = JOYSTICK_BASE
	base.centered = false
	base.position = Vector2(250, 14)
	base.scale = Vector2(0.88, 0.91)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(base)


func _build_joystick() -> void:
	_joystick_textures = []
	for row in range(3):
		for column in range(3):
			_joystick_textures.append(
				_atlas_texture(JOYSTICK_SPRITES, JOYSTICK_CELL_SIZE, column, row)
			)
	_joystick = Sprite2D.new()
	_joystick.position = JOYSTICK_POSITION
	_joystick.scale = Vector2.ONE * JOYSTICK_SCALE
	_joystick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_joystick)


func _build_buttons() -> void:
	_add_control_button(&"cabinet_exit", Vector2(416, 170), 0, 0.94)
	_add_control_button(&"controller_back", Vector2(591, 167), 1, 0.94)
	_add_control_button(&"controller_start", Vector2(770, 170), 2, 0.94)
	_add_control_button(&"action_y", Vector2(1004, 276), 3)
	_add_control_button(&"action_lb", Vector2(1199, 290), 4)
	_add_control_button(&"action_x", Vector2(824, 407), 5)
	_add_control_button(&"action_b", Vector2(1007, 510), 6)
	_add_control_button(&"action_rb", Vector2(1221, 511), 7)
	_add_control_button(&"action_a", Vector2(812, 630), 8)
	_add_control_button(&"action_lt", Vector2(602, 923), 9, 1.06)
	_add_control_button(&"action_rt", Vector2(806, 871), 10, 1.06)


func _add_control_button(
	action: StringName, position: Vector2, index: int, scale_multiplier: float = 1.0
) -> void:
	var column := index % BUTTON_SHEET_COLUMNS
	var row := index / BUTTON_SHEET_COLUMNS
	var button := Sprite2D.new()
	button.position = position
	button.scale = Vector2.ONE * BUTTON_SCALE * scale_multiplier
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(button)
	_control_sprites[action] = button
	_control_textures[action] = [
		_atlas_texture(CONTROL_BUTTONS, BUTTON_CELL_SIZE, column, row),
		_atlas_texture(CONTROL_BUTTONS_DEPRESSED, BUTTON_CELL_SIZE, column, row),
	]


func _update_joystick() -> void:
	if not is_instance_valid(_joystick):
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var column := int(sign(direction.x)) + 1
	var row := int(sign(direction.y)) + 1
	var frame := row * JOYSTICK_SHEET_COLUMNS + column
	_joystick.texture = _joystick_textures[frame]
	_joystick.position = JOYSTICK_POSITION
	var joystick_direction := Vector2(column - 1, row - 1)
	if joystick_direction != Vector2.ZERO and joystick_direction != _joystick_direction:
		_joystick_sound.play()
	_joystick_direction = joystick_direction


func _update_buttons() -> void:
	for action in _control_sprites:
		_control_sprites[action].texture = _control_textures[action][int(
			Input.is_action_pressed(action)
		)]
		if Input.is_action_just_pressed(action):
			_switch_sound.play()


func _atlas_texture(
	atlas: Texture2D, cell_size: Vector2, column: int, row: int, row_stride: float = cell_size.y
) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(column * cell_size.x, row * row_stride), cell_size)
	return texture
