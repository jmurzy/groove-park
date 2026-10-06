## Headless checks for semantic audio routing and owned-loop cleanup.
extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_category_buses_start_at_unity()
	_test_session_lifecycle_signals_fire_once()
	_test_run_manager_semantic_transitions_fire_once()
	await _test_post_round_ducks_gameplay_sfx()
	await _test_owned_loops_stop_together()
	await _test_attract_music_and_gameplay_ambience_do_not_overlap()
	await _test_rapid_ui_events_use_a_player_pool()
	if _failures.is_empty():
		print("Audio-manager checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_category_buses_start_at_unity() -> void:
	var audio := AudioManager.new()
	get_root().add_child(audio)
	audio.configure()
	for bus_name: StringName in [
		AudioManager.MUSIC_BUS,
		AudioManager.GAMEPLAY_SFX_BUS,
		AudioManager.UI_SFX_BUS,
	]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		_expect(bus_index >= 0, "%s must be configured." % bus_name)
		_expect(
			is_zero_approx(AudioServer.get_bus_volume_db(bus_index)),
			"%s must begin at unity gain." % bus_name
		)
	audio.free()


func _test_session_lifecycle_signals_fire_once() -> void:
	var session := GameSession.new()
	var jump_starts: Array[bool] = []
	var jump_results: Array[bool] = []
	session.jump_started.connect(func(_round_state: RoundState) -> void: jump_starts.append(true))
	session.jump_result_recorded.connect(
		func(_round_state: RoundState, _result: JumpResult) -> void: jump_results.append(true)
	)
	session.start_game(RiderKind.SKIER)
	_expect(jump_starts.size() == 1, "Starting a round must emit one jump-start lifecycle signal.")
	session.run_manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
	session.run_manager.rider_state.run.run_phase = RiderRunState.RunPhase.COMPLETE
	session.step_run(RiderInputFrame.new(), 0.0)
	session.step_run(RiderInputFrame.new(), 0.0)
	_expect(
		jump_results.size() == 1,
		"Repeated completion observations must not record another jump result."
	)
	session.complete_tally()
	_expect(
		jump_starts.size() == 2,
		"Completing a tally must emit one lifecycle signal for the next jump."
	)
	session.free()


func _test_post_round_ducks_gameplay_sfx() -> void:
	var audio := AudioManager.new()
	get_root().add_child(audio)
	audio.configure()
	await process_frame
	audio.play_gameplay_ambience()
	audio.start_helicopter_hover()
	audio.duck_gameplay_sfx_for_post_round()
	await create_timer(AudioManager.GAMEPLAY_SFX_FADE_DURATION + 0.05).timeout
	var gameplay_sfx_bus := AudioServer.get_bus_index(AudioManager.GAMEPLAY_SFX_BUS)
	var ui_sfx_bus := AudioServer.get_bus_index(AudioManager.UI_SFX_BUS)
	_expect(
		is_equal_approx(
			AudioServer.get_bus_volume_db(gameplay_sfx_bus),
			AudioManager.POST_ROUND_GAMEPLAY_SFX_VOLUME_DB
		),
		"Game over must duck ambience and helicopter together."
	)
	_expect(
		is_zero_approx(AudioServer.get_bus_volume_db(ui_sfx_bus)),
		"Game-over UI cues must remain at the normal UI mix."
	)
	audio.play_gameplay_ambience()
	_expect(
		is_zero_approx(AudioServer.get_bus_volume_db(gameplay_sfx_bus)),
		"Starting gameplay must restore the gameplay SFX mix."
	)
	audio.shutdown()
	audio.free()


func _test_run_manager_semantic_transitions_fire_once() -> void:
	var manager := RiderRunManager.new()
	manager.setup(load("res://src/game/park/park_course.tres") as ParkCourse)
	var received := {
		"takeoff": 0,
		"compression": 0,
		"grab": 0,
		"carve": 0,
		"brake": 0,
		"tuck": 0,
		"outcome": 0,
	}
	manager.takeoff.connect(func() -> void: received.takeoff += 1)
	manager.compression_charged.connect(func() -> void: received.compression += 1)
	manager.grab_started.connect(func() -> void: received.grab += 1)
	manager.carve_started.connect(func() -> void: received.carve += 1)
	manager.brake_started.connect(func() -> void: received.brake += 1)
	manager.tuck_started.connect(func() -> void: received.tuck += 1)
	manager.outcome_resolved.connect(func(_outcome: int) -> void: received.outcome += 1)
	manager.rider_state.run.run_phase = RiderRunState.RunPhase.FLIGHT
	manager.rider_state.jump.compression_active = true
	manager.rider_state.jump.trick_tracker.start_grab()
	manager.rider_state.run.edge_active = true
	manager.rider_state.run.brake_active = true
	manager.rider_state.run.tuck_active = true
	manager.rider_state.run.jump_outcome = JumpOutcome.Value.CLEAN
	manager._emit_transitions(
		RiderRunState.RunPhase.APPROACH,
		false,
		false,
		0,
		0,
		false,
		false,
		false,
		false,
		JumpOutcome.Value.NONE
	)
	manager._emit_transitions(
		RiderRunState.RunPhase.FLIGHT,
		true,
		true,
		0,
		0,
		false,
		true,
		true,
		true,
		JumpOutcome.Value.CLEAN
	)
	for event_name: String in received:
		_expect(
			received[event_name] == 1,
			"%s must emit once when its run-state transition is first observed." % event_name
		)


func _test_owned_loops_stop_together() -> void:
	var audio := AudioManager.new()
	get_root().add_child(audio)
	audio.configure()
	await process_frame
	audio.play_gameplay_ambience()
	audio.start_helicopter_hover()
	audio.play_event(AudioManager.Event.UI_MOVE)
	var gameplay_ambience := audio.get_node("GameplayAmbience") as AudioStreamPlayer
	var helicopter_hover := audio.get_node("HelicopterHover") as AudioStreamPlayer
	var ui_sound := audio.get_node("MenuSwitchSound0") as AudioStreamPlayer
	_expect(gameplay_ambience.playing, "Gameplay ambience must be owned by the audio manager.")
	_expect(helicopter_hover.playing, "Rescue hover must be owned by the audio manager.")
	_expect(ui_sound.playing, "One-shot sounds must be owned by the audio manager.")
	audio.duck_gameplay_ambience_for_rescue()
	await create_timer(0.25).timeout
	_expect(
		is_equal_approx(
			gameplay_ambience.volume_db, AudioManager.GAMEPLAY_MUSIC_RESCUE_DUCK_VOLUME_DB
		),
		"Crash rescue must duck gameplay ambience."
	)
	audio.shutdown()
	_expect(not gameplay_ambience.playing, "Shutdown must stop gameplay ambience.")
	_expect(not helicopter_hover.playing, "Shutdown must stop rescue hover.")
	_expect(not ui_sound.playing, "Shutdown must stop active one-shot sounds.")
	audio.free()


func _test_attract_music_and_gameplay_ambience_do_not_overlap() -> void:
	var audio := AudioManager.new()
	get_root().add_child(audio)
	audio.configure()
	await process_frame
	var background_music := audio.get_node("BackgroundMusic") as AudioStreamPlayer
	var gameplay_ambience := audio.get_node("GameplayAmbience") as AudioStreamPlayer
	audio.play_background_music()
	_expect(
		background_music.playing and not gameplay_ambience.playing,
		"Starting attract music must leave gameplay ambience stopped."
	)
	audio.play_gameplay_ambience()
	_expect(
		gameplay_ambience.playing and not background_music.playing,
		"Starting gameplay ambience must stop attract music before playback."
	)
	audio.play_background_music()
	_expect(
		background_music.playing and not gameplay_ambience.playing,
		"Returning to attract music must stop gameplay ambience before playback."
	)
	audio.shutdown()
	audio.free()


func _test_rapid_ui_events_use_a_player_pool() -> void:
	var audio := AudioManager.new()
	get_root().add_child(audio)
	audio.configure()
	await process_frame
	for _index in AudioManager.UI_ONE_SHOT_AUDIO_STREAM_COUNT:
		audio.play_event(AudioManager.Event.UI_MOVE)
	for player_index in AudioManager.UI_ONE_SHOT_AUDIO_STREAM_COUNT:
		var player := audio.get_node("MenuSwitchSound%d" % player_index) as AudioStreamPlayer
		_expect(player.playing, "Rapid UI events must occupy separate one-shot players.")
	audio.shutdown()
	audio.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
