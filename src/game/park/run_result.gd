## Immutable completed-run contract, including score-compatible course and rules versions.
class_name RunResult
extends RefCounted

var selected_player_count: int:
	get:
		return _selected_player_count
var course_version: String:
	get:
		return _course_version
var rules_version: String:
	get:
		return _rules_version
var participant_results: Array[ParticipantRunResult]:
	get:
		return _participant_results.duplicate()
var primary_result: ParticipantRunResult:
	get:
		return _participant_results[0] if not _participant_results.is_empty() else null

var _selected_player_count: int
var _course_version: String
var _rules_version: String
var _participant_results: Array[ParticipantRunResult]


func _init(
	initial_selected_player_count: int,
	initial_course_version: String,
	initial_rules_version: String,
	initial_participant_results: Array[ParticipantRunResult]
) -> void:
	_selected_player_count = initial_selected_player_count
	_course_version = initial_course_version
	_rules_version = initial_rules_version
	_participant_results = initial_participant_results.duplicate()


static func from_primary_rider(
	selected_player_count: int, rider_state: RiderState, course: ParkCourse, tuning: RiderTuning
) -> RunResult:
	return RunResult.new(
		selected_player_count,
		course.course_version,
		tuning.rules_version,
		[ParticipantRunResult.from_rider_state(1, rider_state)]
	)
