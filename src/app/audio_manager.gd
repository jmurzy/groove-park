## Owns application-level background music and confirmation playback.
class_name AudioManager
extends Node

var _background_music: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer


func configure(background_music: AudioStreamMP3, confirmation_sound: AudioStream) -> void:
	background_music.loop = true
	_background_music = AudioStreamPlayer.new()
	_background_music.name = "BackgroundMusic"
	_background_music.stream = background_music
	add_child(_background_music)

	_confirmation_sound = AudioStreamPlayer.new()
	_confirmation_sound.stream = confirmation_sound
	add_child(_confirmation_sound)


func play_background_music() -> void:
	_background_music.play()


func stop_background_music() -> void:
	_background_music.stop()


func play_confirmation() -> void:
	_confirmation_sound.play()


func shutdown() -> void:
	if is_instance_valid(_background_music):
		_background_music.stop()
		_background_music.stream = null
