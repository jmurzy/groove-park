## Owns primary-menu button presentation, focus traversal, and menu sounds.
class_name AttractMenu
extends Control

signal start_requested
signal controls_requested
signal exit_requested

var audio_manager: AudioManager
var _has_focus := false


func _ready() -> void:
	name = "AttractMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var controls := _build_button("ControlsButton", "HOW TO PLAY", Vector2(665, 650))
	var start := _build_button("StartGameButton", "START GAME", Vector2(665, 724))
	var exit := _build_button("ExitButton", "EXIT", Vector2(665, 798))
	controls.pressed.connect(controls_requested.emit)
	start.pressed.connect(start_requested.emit)
	exit.pressed.connect(exit_requested.emit)
	controls.focus_neighbor_top = NodePath(".")
	controls.focus_neighbor_bottom = controls.get_path_to(start)
	start.focus_neighbor_top = start.get_path_to(controls)
	start.focus_neighbor_bottom = start.get_path_to(exit)
	exit.focus_neighbor_top = exit.get_path_to(start)
	exit.focus_neighbor_bottom = NodePath(".")
	start.call_deferred("grab_focus")


func play_confirmation() -> void:
	audio_manager.play_confirmation()


func focus_default() -> void:
	get_node("StartGameButton").call_deferred("grab_focus")


func focus_controls() -> void:
	get_node("ControlsButton").call_deferred("grab_focus")


func _build_button(
	button_name: StringName, button_text: String, position: Vector2
) -> ArcadeMenuButton:
	var button := ArcadeMenuButton.new()
	button.name = button_name
	button.position = position
	button.size = Vector2(590, 54)
	button.configure(button_text, 28, true)
	button.selection_focused.connect(_on_button_focused)
	add_child(button)
	return button


func _on_button_focused() -> void:
	if _has_focus:
		audio_manager.play_menu_switch()
	_has_focus = true
