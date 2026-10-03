## Owns application-level background music and confirmation playback.
class_name AudioManager
extends Node

const BACKGROUND_MUSIC := preload("res://assets/audio/slimeyfox-gameotoon.mp3")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const SCORE_TICK_SOUND := preload("res://assets/audio/score_tick.ogg")
const SCORE_TICK_AUDIO_STREAM_COUNT := 5

var _background_music: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _score_tick_players: Array[AudioStreamPlayer] = []
var _next_score_tick_player := 0


func configure() -> void:
	_build_background_music()
	_build_confirmation_sound()
	_build_score_tick_players()


func _build_background_music() -> void:
	# Playback configuration must not mutate the shared preloaded music resource.
	var looping_background_music := BACKGROUND_MUSIC.duplicate() as AudioStreamMP3
	looping_background_music.loop = true
	_background_music = AudioStreamPlayer.new()
	_background_music.name = "BackgroundMusic"
	_background_music.stream = looping_background_music
	add_child(_background_music)


func _build_confirmation_sound() -> void:
	_confirmation_sound = AudioStreamPlayer.new()
	_confirmation_sound.stream = CONFIRMATION_SOUND
	add_child(_confirmation_sound)


func _build_score_tick_players() -> void:
	for audio_stream_index in SCORE_TICK_AUDIO_STREAM_COUNT:
		var score_tick_player := AudioStreamPlayer.new()
		score_tick_player.name = "ScoreTick%d" % audio_stream_index
		score_tick_player.stream = SCORE_TICK_SOUND
		add_child(score_tick_player)
		_score_tick_players.append(score_tick_player)


func play_background_music() -> void:
	_background_music.play()


func stop_background_music() -> void:
	_background_music.stop()


func play_confirmation() -> void:
	_confirmation_sound.play()


func play_score_tick() -> void:
	if _score_tick_players.is_empty():
		return
	var player := _score_tick_players[_next_score_tick_player]
	_next_score_tick_player = (_next_score_tick_player + 1) % _score_tick_players.size()
	player.play()


func shutdown() -> void:
	_stop_and_release(_background_music)
	_stop_and_release(_confirmation_sound)
	for score_tick_player in _score_tick_players:
		_stop_and_release(score_tick_player)


func _stop_and_release(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
