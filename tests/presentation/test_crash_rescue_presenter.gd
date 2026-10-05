## Headless checks for the presentation-only crash rescue sequence.
extends SceneTree

const CrashRescuePresenterScene := preload(
	"res://src/presentation/gameplay/crash_rescue_presenter.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_actors_enter_from_their_required_sides_and_stop_near_the_crash()
	_test_presentation_can_finish_without_owning_session_progression()
	if _failures.is_empty():
		print("Crash rescue presenter checks passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_actors_enter_from_their_required_sides_and_stop_near_the_crash() -> void:
	var rescue := _rescue()
	var crash_site := Vector2(820.0, 530.0)
	_expect(rescue.start(crash_site), "A recorded crash must start one rescue sequence.")
	_expect(
		rescue.helicopter_position().x < crash_site.x,
		"The helicopter medic must enter from the left."
	)
	_expect(
		rescue.toboggan_position().x > crash_site.x, "The toboggan medic must enter from the right."
	)
	rescue.advance(CrashRescuePresenter.MINIMUM_DISPLAY_DURATION)
	_expect(
		rescue.helicopter_position() == crash_site + CrashRescuePresenter.HELICOPTER_STOP_OFFSET,
		"The helicopter medic must stop at its authored crash-site offset."
	)
	_expect(
		rescue.toboggan_position() == crash_site + CrashRescuePresenter.TOBOGGAN_STOP_OFFSET,
		"The toboggan medic must stop at its authored crash-site offset."
	)
	rescue.queue_free()


func _test_presentation_can_finish_without_owning_session_progression() -> void:
	var rescue := _rescue()
	rescue.start(Vector2(400.0, 300.0))
	rescue.advance(CrashRescuePresenter.MINIMUM_DISPLAY_DURATION)
	_expect(
		rescue.is_active(), "Rescue presentation must remain active until its session phase ends."
	)
	rescue.finish()
	_expect(
		not rescue.is_active(),
		"Finishing rescue must stop presentation without changing session state."
	)
	rescue.queue_free()


func _rescue() -> CrashRescuePresenter:
	var rescue := CrashRescuePresenterScene.new()
	get_root().add_child(rescue)
	return rescue


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
