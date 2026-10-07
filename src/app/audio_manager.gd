## Owns application-level semantic audio, music transitions, and owned looping sounds.
class_name AudioManager
extends Node

enum Event {
	UI_MOVE,
	UI_BACK,
	UI_CONFIRM,
	CONTROL_BUTTON_PRESS,
	JOYSTICK_MOVE,
	ROUND_START,
	JUMP_START,
	TAKEOFF,
	HALF_ROTATION,
	FULL_ROTATION,
	RELEASE_WARNING,
	LAND_CLEAN,
	LAND_SKETCHY,
	BAIL,
	CRASH,
	LOW_MOMENTUM,
	SCORE_TICK,
	SCORE_TOTAL,
	NEXT_JUMP,
	GAME_OVER,
	HIGH_SCORE,
	KEYBOARD_MOVE,
	KEYBOARD_INTERACTION,
	NAME_CONFIRM,
	NAME_SKIP,
	RESULTS_REVEAL,
}

enum LoopEvent {
	CARVE,
	BRAKE,
	TUCK,
	COMPRESSION,
	GRAB,
}

const BACKGROUND_MUSIC := preload("res://assets/audio/slimeyfox-gameotoon.mp3")
const GAMEPLAY_MUSIC := preload("res://assets/audio/freesound_community-ski-67717.mp3")
const CONFIRMATION_SOUND := preload("res://assets/audio/confirmation_002.ogg")
const SCORE_TICK_SOUND := preload("res://assets/audio/score_tick.ogg")
const MENU_SWITCH_SOUND := preload("res://assets/audio/switch32.ogg")
const CABINET_SWITCH_SOUND := preload("res://assets/audio/switch24.ogg")
const JOYSTICK_SOUND := preload("res://assets/audio/switch38.ogg")
const BACK_SOUND := preload("res://assets/audio/back_003.ogg")
const KEYBOARD_SELECTION_SOUND := preload("res://assets/audio/koiroylers-keyboard-press-351952.mp3")
const HELICOPTER_HOVER_SOUND := preload(
	"res://assets/audio/flutie8211-helicopter-hovering-598081.mp3"
)
# Temporary loop source until dedicated gameplay loop assets are selected.
const GAMEPLAY_ACTION_LOOP_SOUND := MENU_SWITCH_SOUND

# Looping attract music.
const MUSIC_BUS := &"Music"
# Gameplay ambience, helicopter hover, and future continuous gameplay effects.
const GAMEPLAY_SFX_BUS := &"GameplaySfx"
# Menu, cabinet, keyboard, score-tick, and current gameplay-event one-shots.
const UI_SFX_BUS := &"UiSfx"

const UI_ONE_SHOT_AUDIO_STREAM_COUNT := 5
# Temporary switch-loop bounds: intensity interpolates from nearly silent/low pitch to an
# audible/higher pitch. Calibrate replacement action-loop assets on cabinet speakers.
const GAMEPLAY_ACTION_LOOP_MIN_VOLUME_DB := -30.0
const GAMEPLAY_ACTION_LOOP_MAX_VOLUME_DB := -14.0
const GAMEPLAY_ACTION_LOOP_MIN_PITCH_SCALE := 0.8
const GAMEPLAY_ACTION_LOOP_MAX_PITCH_SCALE := 1.2
# Category buses begin at unity gain. Source-level gain establishes the normal mix;
# bus gain is reserved for category-wide controls such as post-round ducking.
const MUSIC_BUS_VOLUME_DB := 0.0
const GAMEPLAY_SFX_BUS_VOLUME_DB := 0.0
const UI_SFX_BUS_VOLUME_DB := 0.0
# -6 dB is approximately 50% amplitude.
const MUSIC_VOLUME_DB := -6.0
const MUSIC_FADE_DURATION := 0.25
# A 75% amplitude reduction is approximately -12.04 dB.
const POST_ROUND_GAMEPLAY_SFX_VOLUME_DB := -12.1
const GAMEPLAY_SFX_FADE_DURATION := 0.2
# -6 dB is approximately 50% amplitude.
const HELICOPTER_HOVER_ENTRY_VOLUME_DB := -6.0
# 0 dB is 100% amplitude.
const HELICOPTER_HOVER_LANDING_VOLUME_DB := 0.0
# -20 dB is 10% amplitude.
const GAMEPLAY_MUSIC_RESCUE_DUCK_VOLUME_DB := -20.0
# -30 dB is approximately 3% amplitude.
const MUSIC_FADE_START_VOLUME_DB := -30.0

var _background_music_player: AudioStreamPlayer

var _gameplay_helicopter_player: AudioStreamPlayer
var _gameplay_ambience_player: AudioStreamPlayer
var _gameplay_action_loop_players: Array[AudioStreamPlayer] = []

var _one_shot_pools: Dictionary = {}
var _next_one_shot_player: Dictionary = {}

var _music_fade: Tween
var _gameplay_sfx_fade: Tween


func configure() -> void:
	_ensure_bus(MUSIC_BUS, MUSIC_BUS_VOLUME_DB)
	_ensure_bus(GAMEPLAY_SFX_BUS, GAMEPLAY_SFX_BUS_VOLUME_DB)
	_ensure_bus(UI_SFX_BUS, UI_SFX_BUS_VOLUME_DB)

	# MUSIC_BUS
	_background_music_player = _build_looping_player(
		MUSIC_BUS, &"BackgroundMusic", BACKGROUND_MUSIC
	)

	# GAMEPLAY_SFX_BUS
	_gameplay_ambience_player = _build_looping_player(
		GAMEPLAY_SFX_BUS, &"GameplayAmbience", GAMEPLAY_MUSIC
	)
	_gameplay_helicopter_player = _build_looping_player(
		GAMEPLAY_SFX_BUS,
		&"HelicopterHover",
		HELICOPTER_HOVER_SOUND,
		HELICOPTER_HOVER_ENTRY_VOLUME_DB
	)
	for loop: int in LoopEvent.values():
		_gameplay_action_loop_players.append(
			_build_looping_player(
				GAMEPLAY_SFX_BUS,
				&"GameplayLoop%d" % loop,
				GAMEPLAY_ACTION_LOOP_SOUND,
				GAMEPLAY_ACTION_LOOP_MIN_VOLUME_DB
			)
		)

	# UI_SFX_BUS
	_build_one_shot_pool(
		UI_SFX_BUS, &"ConfirmationSound", CONFIRMATION_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)
	_build_one_shot_pool(
		UI_SFX_BUS, &"MenuSwitchSound", MENU_SWITCH_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)
	_build_one_shot_pool(
		UI_SFX_BUS, &"CabinetSwitchSound", CABINET_SWITCH_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)
	_build_one_shot_pool(
		UI_SFX_BUS, &"JoystickSound", JOYSTICK_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)
	_build_one_shot_pool(UI_SFX_BUS, &"BackSound", BACK_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT)
	_build_one_shot_pool(
		UI_SFX_BUS,
		&"KeyboardSelectionSound",
		KEYBOARD_SELECTION_SOUND,
		UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)
	_build_one_shot_pool(
		UI_SFX_BUS, &"ScoreTickSound", SCORE_TICK_SOUND, UI_ONE_SHOT_AUDIO_STREAM_COUNT
	)


func _ensure_bus(bus_name: StringName, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _build_one_shot_pool(
	bus: StringName, pool_name: StringName, stream: AudioStream, audio_stream_count: int
) -> void:
	var players: Array[AudioStreamPlayer] = []
	for player_index in audio_stream_count:
		players.append(_build_player(bus, "%s%d" % [pool_name, player_index], stream))
	_one_shot_pools[pool_name] = players
	_next_one_shot_player[pool_name] = 0


func _build_looping_player(
	bus: StringName,
	player_name: StringName,
	stream: AudioStream,
	# 0 dB is 100% amplitude.
	initial_volume_db: float = 0.0
) -> AudioStreamPlayer:
	var looping_stream := stream.duplicate()
	if looping_stream is AudioStreamMP3:
		(looping_stream as AudioStreamMP3).loop = true
	elif looping_stream is AudioStreamOggVorbis:
		(looping_stream as AudioStreamOggVorbis).loop = true
	else:
		push_error("Looping audio requires an MP3 or Ogg Vorbis stream.")
	var player := _build_player(bus, player_name, looping_stream)
	player.volume_db = initial_volume_db
	return player


func _build_player(
	bus: StringName, player_name: StringName, stream: AudioStream
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


func play_event(event: Event) -> void:
	match event:
		Event.UI_MOVE:
			_play_one_shot(&"MenuSwitchSound")
		Event.KEYBOARD_INTERACTION, Event.CONTROL_BUTTON_PRESS:
			_play_one_shot(&"CabinetSwitchSound")
		Event.KEYBOARD_MOVE:
			_play_one_shot(&"KeyboardSelectionSound")
		Event.UI_BACK, Event.NAME_SKIP:
			_play_one_shot(&"BackSound")
		Event.UI_CONFIRM, Event.NAME_CONFIRM, Event.ROUND_START:
			_play_one_shot(&"ConfirmationSound")
		Event.SCORE_TICK:
			_play_one_shot(&"ScoreTickSound")
		Event.NEXT_JUMP, Event.FULL_ROTATION:
			_play_one_shot(&"CabinetSwitchSound")
		Event.JOYSTICK_MOVE, Event.JUMP_START, Event.TAKEOFF, Event.LAND_CLEAN:
			_play_one_shot(&"JoystickSound")
		Event.HALF_ROTATION:
			_play_one_shot(&"CabinetSwitchSound")
		Event.RELEASE_WARNING:
			_play_one_shot(&"BackSound")
		Event.CRASH, Event.BAIL:
			_play_one_shot(&"BackSound")
		Event.LAND_SKETCHY, Event.LOW_MOMENTUM:
			_play_one_shot(&"KeyboardSelectionSound")
		Event.HIGH_SCORE:
			_play_one_shot(&"ConfirmationSound")
		Event.RESULTS_REVEAL, Event.SCORE_TOTAL:
			_play_one_shot(&"CabinetSwitchSound")
		# No game-over asset is available yet; retain the semantic event without playback.
		Event.GAME_OVER:
			pass


func play_loop_event(loop_event: LoopEvent) -> void:
	if loop_event < 0 or loop_event >= _gameplay_action_loop_players.size():
		return
	var player := _gameplay_action_loop_players[loop_event]
	if not player.playing:
		player.play()


func update_loop_event(loop_event: LoopEvent, intensity: float) -> void:
	if loop_event < 0 or loop_event >= _gameplay_action_loop_players.size():
		return
	var player := _gameplay_action_loop_players[loop_event]
	var normalized_intensity := clampf(intensity, 0.0, 1.0)
	player.volume_db = lerpf(
		GAMEPLAY_ACTION_LOOP_MIN_VOLUME_DB, GAMEPLAY_ACTION_LOOP_MAX_VOLUME_DB, normalized_intensity
	)
	player.pitch_scale = lerpf(
		GAMEPLAY_ACTION_LOOP_MIN_PITCH_SCALE,
		GAMEPLAY_ACTION_LOOP_MAX_PITCH_SCALE,
		normalized_intensity
	)


func stop_loop_event(loop_event: LoopEvent) -> void:
	if loop_event < 0 or loop_event >= _gameplay_action_loop_players.size():
		return
	_gameplay_action_loop_players[loop_event].stop()


func stop_loop_events() -> void:
	for player in _gameplay_action_loop_players:
		player.stop()


func play_background_music() -> void:
	_play_music(_background_music_player, _gameplay_ambience_player)


func stop_background_music() -> void:
	_stop_music(_background_music_player)


func play_gameplay_ambience() -> void:
	restore_gameplay_sfx_mix()
	_play_music(_gameplay_ambience_player, _background_music_player)


func stop_gameplay_ambience() -> void:
	_stop_music(_gameplay_ambience_player)


func duck_gameplay_ambience_for_rescue() -> void:
	if not _gameplay_ambience_player.playing:
		return
	_fade_music_to(_gameplay_ambience_player, GAMEPLAY_MUSIC_RESCUE_DUCK_VOLUME_DB, 0.2)


func start_helicopter_hover() -> void:
	_gameplay_helicopter_player.volume_db = HELICOPTER_HOVER_ENTRY_VOLUME_DB
	if not _gameplay_helicopter_player.playing:
		_gameplay_helicopter_player.play()


func stop_helicopter_hover() -> void:
	if _gameplay_helicopter_player:
		_gameplay_helicopter_player.stop()


func set_helicopter_hover_progress(progress: float) -> void:
	_gameplay_helicopter_player.volume_db = lerpf(
		HELICOPTER_HOVER_ENTRY_VOLUME_DB,
		HELICOPTER_HOVER_LANDING_VOLUME_DB,
		clampf(progress, 0.0, 1.0)
	)


func _play_one_shot(pool_name: StringName) -> void:
	if not _one_shot_pools.has(pool_name):
		return
	var players: Array[AudioStreamPlayer] = _one_shot_pools[pool_name]
	var player_index: int = _next_one_shot_player[pool_name]
	_next_one_shot_player[pool_name] = (player_index + 1) % players.size()
	players[player_index].play()


func _play_music(next_player: AudioStreamPlayer, previous_player: AudioStreamPlayer) -> void:
	_stop_music(previous_player)
	if next_player.playing:
		return
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	next_player.volume_db = MUSIC_FADE_START_VOLUME_DB
	next_player.play()
	_fade_music_to(next_player, MUSIC_VOLUME_DB, MUSIC_FADE_DURATION)


func _fade_music_to(player: AudioStreamPlayer, volume_db: float, duration: float) -> void:
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	_music_fade = create_tween()
	_music_fade.tween_property(player, "volume_db", volume_db, duration)


func duck_gameplay_sfx_for_post_round() -> void:
	_fade_bus_to(GAMEPLAY_SFX_BUS, POST_ROUND_GAMEPLAY_SFX_VOLUME_DB)


func restore_gameplay_sfx_mix() -> void:
	if _gameplay_sfx_fade and _gameplay_sfx_fade.is_valid():
		_gameplay_sfx_fade.kill()
	_set_bus_volume(GAMEPLAY_SFX_BUS, GAMEPLAY_SFX_BUS_VOLUME_DB)


func _fade_bus_to(bus_name: StringName, volume_db: float) -> void:
	if _gameplay_sfx_fade and _gameplay_sfx_fade.is_valid():
		_gameplay_sfx_fade.kill()
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	_gameplay_sfx_fade = create_tween()
	_gameplay_sfx_fade.tween_method(
		func(next_volume_db: float) -> void: _set_bus_volume(bus_name, next_volume_db),
		AudioServer.get_bus_volume_db(bus_index),
		volume_db,
		GAMEPLAY_SFX_FADE_DURATION
	)


func _set_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func _stop_music(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()


func shutdown() -> void:
	stop_background_music()
	stop_gameplay_ambience()
	stop_helicopter_hover()
	stop_loop_events()
	for players: Array[AudioStreamPlayer] in _one_shot_pools.values():
		for player in players:
			player.stop()
