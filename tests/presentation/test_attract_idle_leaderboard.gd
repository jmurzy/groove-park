## Headless checks for the attract-mode idle leaderboard lifecycle and motion.
extends SceneTree

const PrimaryScreenScene := preload("res://src/presentation/attract/primary_screen.gd")
const IdleLeaderboardOverlayScene := preload(
	"res://src/presentation/attract/idle_leaderboard_overlay.gd"
)
const AttractIdleFlowControllerScene := preload("res://src/app/attract_idle_flow_controller.gd")

const IDLE_LEADERBOARD_DELAY := 5.0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await _test_idle_request_and_display()
	await _test_attract_overlays_restart_the_interval()
	await _test_failed_and_cancelled_requests_do_not_show_an_overlay()
	await _test_dismissal_consumes_only_keys_and_buttons()
	await _test_overlay_motion_stays_inside_safe_bounds()
	if _failures.is_empty():
		print("Attract idle-leaderboard checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_idle_request_and_display() -> void:
	var fixture := await _fixture()
	fixture.repository.entries.append(_leaderboard_entry())
	_advance_idle(fixture.screen, IDLE_LEADERBOARD_DELAY - 0.01)
	_expect(fixture.screen._menu.visible, "Idle leaderboard must wait the full idle interval.")
	_advance_idle(fixture.screen, 0.01)
	_expect(
		not fixture.screen._menu.visible,
		"A successful idle request must replace the attract menu with the shared leaderboard overlay."
	)
	_free_fixture(fixture)


func _test_attract_overlays_restart_the_interval() -> void:
	var fixture := await _fixture()
	fixture.screen._open_controls()
	_advance_idle(fixture.screen, IDLE_LEADERBOARD_DELAY + 1.0)
	_expect(
		fixture.screen._menu.visible,
		"Controls must suspend idle leaderboard timing while they remain open."
	)
	fixture.screen._close_controls()
	_advance_idle(fixture.screen, IDLE_LEADERBOARD_DELAY - 0.01)
	_expect(fixture.screen._menu.visible, "Closing controls must require a fresh full interval.")
	_advance_idle(fixture.screen, 0.01)
	_expect(not fixture.screen._menu.visible, "The fresh interval must permit a new idle flow.")
	_free_fixture(fixture)


func _test_failed_and_cancelled_requests_do_not_show_an_overlay() -> void:
	var failed_fixture := await _fixture()
	failed_fixture.repository.are_top_entries_available = false
	_advance_idle(failed_fixture.screen, IDLE_LEADERBOARD_DELAY)
	_expect(
		failed_fixture.screen._menu.visible,
		"A failed idle request must leave the normal attract menu visible."
	)
	_advance_idle(failed_fixture.screen, IDLE_LEADERBOARD_DELAY - 0.01)
	_expect(
		failed_fixture.screen._menu.visible,
		"A failed request must not retry before another full idle interval."
	)
	_free_fixture(failed_fixture)

	var repository := FakeLeaderboardRepository.new()
	repository.deferred = true
	var presentation_parent := Control.new()
	var controller := AttractIdleFlowControllerScene.new()
	get_root().add_child(repository)
	get_root().add_child(presentation_parent)
	get_root().add_child(controller)
	controller.setup(presentation_parent, repository)
	controller.start_waiting()
	controller.advance(IDLE_LEADERBOARD_DELAY)
	controller.suspend()
	_expect(
		not controller.is_displaying(),
		"Suspending attract idle flow must prevent an in-flight request from displaying an overlay."
	)
	controller.free()
	presentation_parent.free()
	repository.free()


func _test_dismissal_consumes_only_keys_and_buttons() -> void:
	var fixture := await _fixture()
	_advance_idle(fixture.screen, IDLE_LEADERBOARD_DELAY)
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	_send_idle_input(fixture.screen, motion)
	_expect(
		not fixture.screen._menu.visible,
		"Joypad axis motion must not dismiss the idle leaderboard."
	)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	_send_idle_input(fixture.screen, key)
	_expect(
		(
			fixture.screen._menu.visible
			and fixture.screen._player_select == null
			and not fixture.input_router.has_owner()
		),
		"A key dismissal must restore attract without starting or claiming a round."
	)
	_free_fixture(fixture)


func _test_overlay_motion_stays_inside_safe_bounds() -> void:
	var overlay := IdleLeaderboardOverlayScene.new()
	get_root().add_child(overlay)
	await process_frame
	overlay.advance(100.0)
	var maximum := (
		IdleLeaderboardOverlay.SAFE_BOUNDS.position
		+ IdleLeaderboardOverlay.SAFE_BOUNDS.size
		- overlay.displayed_size()
	)
	_expect(
		(
			overlay.position.x >= IdleLeaderboardOverlay.SAFE_BOUNDS.position.x
			and overlay.position.x <= maximum.x
			and overlay.position.y >= IdleLeaderboardOverlay.SAFE_BOUNDS.position.y
			and overlay.position.y <= maximum.y
		),
		"The idle overlay must remain inside its authored safe bounds."
	)
	var position_at_edge := overlay.position
	overlay.advance(0.1)
	_expect(
		overlay.position != position_at_edge,
		"The idle overlay must reverse and continue after reaching a safe bound."
	)
	overlay.free()


class Fixture:
	extends RefCounted
	var screen: PrimaryScreen
	var repository: FakeLeaderboardRepository
	var input_router: InputRouter
	var audio_manager: AudioManager


func _fixture(deferred := false) -> Fixture:
	var fixture := Fixture.new()
	fixture.repository = FakeLeaderboardRepository.new()
	fixture.repository.deferred = deferred
	fixture.input_router = InputRouter.new()
	fixture.input_router.configure(true)
	fixture.audio_manager = AudioManager.new()
	fixture.audio_manager.configure()
	fixture.screen = PrimaryScreenScene.new()
	fixture.screen.leaderboard_repository = fixture.repository
	fixture.screen.input_router = fixture.input_router
	fixture.screen.audio_manager = fixture.audio_manager
	get_root().add_child(fixture.repository)
	get_root().add_child(fixture.input_router)
	get_root().add_child(fixture.audio_manager)
	get_root().add_child(fixture.screen)
	await process_frame
	return fixture


func _free_fixture(fixture: Fixture) -> void:
	fixture.screen.free()
	fixture.audio_manager.free()
	fixture.input_router.free()
	fixture.repository.free()


func _leaderboard_entry() -> LeaderboardEntry:
	var entry := LeaderboardEntry.new()
	entry.round_id = "idle-test"
	entry.player_name = "RIDER"
	entry.rider_kind = RiderKind.SKIER
	entry.total_score = 100
	entry.platform = &"ags"
	entry.created_at = "test"
	return entry


func _advance_idle(screen: PrimaryScreen, delta: float) -> void:
	screen.get_node("AttractIdleFlow").call("advance", delta)


func _send_idle_input(screen: PrimaryScreen, event: InputEvent) -> void:
	screen.get_node("AttractIdleFlow").call("_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
