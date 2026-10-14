## Live keyboard diagram: displayed keys show pressed states with click sounds.
## Call `tick()` each frame.
class_name ControlsKeyboardView
extends ControlsView

const CONTROL_BUTTONS := preload("res://artwork/controls/keyboard_control_buttons.png")
const CONTROL_BUTTONS_DEPRESSED := preload(
	"res://artwork/controls/keyboard_control_buttons_depressed.png"
)
const KEYBOARD_BASE := preload("res://artwork/controls/keyboard_controls_base.png")
const CONTROL_LAYOUT_SIZE := Vector2(1900, 648)
const CABINET_ART_SIZE := Vector2(686, 456)

var _control_sprites: Dictionary[StringName, Sprite2D]
var _control_textures: Dictionary[StringName, Array]


func _ready() -> void:
	name = "ControlsKeyboardView"
	position = Vector2(0, 114)
	scale = Vector2.ONE * CABINET_ART_SIZE.x / CONTROL_LAYOUT_SIZE.x
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_base()
	_build_buttons()


func tick() -> void:
	_update_buttons()


func _build_base() -> void:
	var base := Sprite2D.new()
	base.texture = KEYBOARD_BASE
	base.centered = false
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(base)


func _build_buttons() -> void:
	_add_control_button(&"exit_escape", Rect2(57, 54, 282, 169))
	_add_control_button(&"action_lt", Rect2(161, 224, 238, 176))
	_add_control_button(&"move_up", Rect2(400, 224, 238, 176))
	_add_control_button(&"action_rt", Rect2(640, 224, 238, 176))
	_add_control_button(&"move_left", Rect2(228, 400, 240, 178))
	_add_control_button(&"move_down", Rect2(469, 400, 240, 178))
	_add_control_button(&"move_right", Rect2(710, 400, 252, 178))
	_add_control_button(&"action_lb", Rect2(1017, 224, 238, 176))
	_add_control_button(&"action_y", Rect2(1257, 224, 238, 176))
	_add_control_button(&"action_rb", Rect2(1497, 224, 268, 176))
	_add_control_button(&"action_a", Rect2(1078, 400, 240, 178))
	_add_control_button(&"action_b", Rect2(1319, 400, 240, 178))
	_add_control_button(&"action_x", Rect2(1560, 400, 268, 178))


func _add_control_button(action: StringName, region: Rect2) -> void:
	var button := Sprite2D.new()
	button.position = region.get_center()
	button.texture = _atlas_texture(CONTROL_BUTTONS, region)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(button)
	_control_sprites[action] = button
	_control_textures[action] = [
		_atlas_texture(CONTROL_BUTTONS, region),
		_atlas_texture(CONTROL_BUTTONS_DEPRESSED, region),
	]


func _update_buttons() -> void:
	for action in _control_sprites:
		_control_sprites[action].texture = _control_textures[action][int(
			Input.is_action_pressed(action)
		)]
		if Input.is_action_just_pressed(action):
			audio_manager.play_event(AudioManager.Event.CONTROL_BUTTON_PRESS)


func _atlas_texture(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture
