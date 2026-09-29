## Immutable completed-run contract.
class_name RunResult
extends RefCounted

var participant_results: Array[ParticipantRunResult]:
	get:
		return _participant_results.duplicate()
var primary_result: ParticipantRunResult:
	get:
		return _participant_results[0] if not _participant_results.is_empty() else null

var _participant_results: Array[ParticipantRunResult]


func _init(initial_participant_results: Array[ParticipantRunResult]) -> void:
	_participant_results = initial_participant_results.duplicate()


static func from_primary_rider(
	rider_state: RiderState, _course: ParkCourse, _tuning: RiderTuning
) -> RunResult:
	return RunResult.new([ParticipantRunResult.from_rider_state(1, rider_state)])
