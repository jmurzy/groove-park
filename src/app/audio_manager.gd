## Owns application-level music and sound-effect playback.
class_name AudioManager
extends Node

const BACKGROUND_MUSIC := preload("res://assets/audio/slimeyfox-gameotoon.mp3")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const SCORE_TICK_SOUND := preload("res://assets/audio/score_tick.ogg")
const MENU_SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CABINET_SWITCH_SOUND := preload("res://assets/audio/switch24.ogg")
const JOYSTICK_SOUND := preload("res://assets/audio/switch38.ogg")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const HELICOPTER_HOVER_SOUND := preload(
	"res://assets/audio/flutie8211-helicopter-hovering-598081.mp3"
)
const SCORE_TICK_AUDIO_STREAM_COUNT := 5

# 0 dB is unity gain (100% amplitude); -6 dB is approximately 50% amplitude.
const HELICOPTER_HOVER_ENTRY_VOLUME_DB := -6.0
const HELICOPTER_HOVER_LANDING_VOLUME_DB := 0.0
const GAMEPLAY_MUSIC_RESCUE_DUCK_VOLUME_DB := -12.0

var _helicopter_hover: AudioStreamPlayer
var _background_music: AudioStreamPlayer
var _gameplay_music: AudioStreamPlayer
var _confirmation_sound: AudioStreamPlayer
var _menu_switch_sound: AudioStreamPlayer
var _cabinet_switch_sound: AudioStreamPlayer
var _joystick_sound: AudioStreamPlayer
var _back_sound: AudioStreamPlayer
var _score_tick_players: Array[AudioStreamPlayer] = []
var _next_score_tick_player := 0


func configure() -> void:
	_build_background_music()
	_build_gameplay_music()
	_build_confirmation_sound()
	_build_interface_sounds()
	_build_score_tick_players()
	_build_helicopter_hover()


func _build_background_music() -> void:
	# Playback configuration must not mutate the shared preloaded music resource.
	var looping_background_music := BACKGROUND_MUSIC.duplicate() as AudioStreamMP3
	looping_background_music.loop = true
	_background_music = AudioStreamPlayer.new()
	_background_music.name = "BackgroundMusic"
	_background_music.stream = looping_background_music
	add_child(_background_music)


func _build_gameplay_music() -> void:
	var looping_gameplay_music := GAMEPLAY_MUSIC.duplicate() as AudioStreamMP3
	looping_gameplay_music.loop = true
	_gameplay_music = AudioStreamPlayer.new()
	_gameplay_music.name = "GameplayMusic"
	_gameplay_music.stream = looping_gameplay_music
	add_child(_gameplay_music)


func _build_confirmation_sound() -> void:
	_confirmation_sound = _build_player("ConfirmationSound", CONFIRMATION_SOUND)


func _build_interface_sounds() -> void:
	_menu_switch_sound = _build_player("MenuSwitchSound", MENU_SWITCH_SOUND)
	_cabinet_switch_sound = _build_player("CabinetSwitchSound", CABINET_SWITCH_SOUND)
	_joystick_sound = _build_player("JoystickSound", JOYSTICK_SOUND)
	_back_sound = _build_player("BackSound", BACK_SOUND)


func _build_player(player_name: StringName, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	add_child(player)
	return player


func _build_score_tick_players() -> void:
	for audio_stream_index in SCORE_TICK_AUDIO_STREAM_COUNT:
		var score_tick_player := AudioStreamPlayer.new()
		score_tick_player.name = "ScoreTick%d" % audio_stream_index
		score_tick_player.stream = SCORE_TICK_SOUND
		add_child(score_tick_player)
		_score_tick_players.append(score_tick_player)


func _build_helicopter_hover() -> void:
	var looping_hover := HELICOPTER_HOVER_SOUND.duplicate() as AudioStreamMP3
	looping_hover.loop = true
	_helicopter_hover = AudioStreamPlayer.new()
	_helicopter_hover.name = "HelicopterHover"
	_helicopter_hover.stream = looping_hover
	_helicopter_hover.volume_db = HELICOPTER_HOVER_ENTRY_VOLUME_DB
	add_child(_helicopter_hover)


func play_background_music() -> void:
	_background_music.play()


func stop_background_music() -> void:
	_background_music.stop()


func play_gameplay_music() -> void:
	_gameplay_music.volume_db = 0.0
	_gameplay_music.play()


func duck_gameplay_music_for_rescue() -> void:
	_gameplay_music.create_tween().tween_property(
		_gameplay_music, "volume_db", GAMEPLAY_MUSIC_RESCUE_DUCK_VOLUME_DB, 0.2
	)


func stop_gameplay_music() -> void:
	_gameplay_music.stop()


func play_confirmation() -> void:
	_confirmation_sound.play()


func play_menu_switch() -> void:
	_menu_switch_sound.play()


func play_cabinet_switch() -> void:
	_cabinet_switch_sound.play()


func play_joystick() -> void:
	_joystick_sound.play()


func play_back() -> void:
	_back_sound.play()


func play_score_tick() -> void:
	if _score_tick_players.is_empty():
		return
	var player := _score_tick_players[_next_score_tick_player]
	_next_score_tick_player = (_next_score_tick_player + 1) % _score_tick_players.size()
	player.play()


func start_helicopter_hover() -> void:
	_helicopter_hover.volume_db = HELICOPTER_HOVER_ENTRY_VOLUME_DB
	_helicopter_hover.play()


func set_helicopter_hover_progress(progress: float) -> void:
	_helicopter_hover.volume_db = lerpf(
		HELICOPTER_HOVER_ENTRY_VOLUME_DB,
		HELICOPTER_HOVER_LANDING_VOLUME_DB,
		clampf(progress, 0.0, 1.0)
	)


func stop_helicopter_hover() -> void:
	_helicopter_hover.stop()


func shutdown() -> void:
	_stop_and_release(_helicopter_hover)
	_stop_and_release(_background_music)
	_stop_and_release(_gameplay_music)
	_stop_and_release(_confirmation_sound)
	_stop_and_release(_menu_switch_sound)
	_stop_and_release(_cabinet_switch_sound)
	_stop_and_release(_joystick_sound)
	_stop_and_release(_back_sound)
	for score_tick_player in _score_tick_players:
		_stop_and_release(score_tick_player)


func _stop_and_release(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
