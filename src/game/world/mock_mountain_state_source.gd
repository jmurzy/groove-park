## Fake mountain feed for dev and offline cabinets: emits a fixed 5-lift
## Heavenly lineup once on ready.
class_name MockMountainStateSource
extends MountainStateSource


func _ready() -> void:
	(
		state_changed
		. emit(
			(
				MountainState
				. create(
					[
						LiftState.create(
							"heavenly-gondola", "Heavenly Gondola", LiftState.Status.OPEN
						),
						LiftState.create(
							"gunbarrel-express", "Gunbarrel Express", LiftState.Status.OPEN
						),
						LiftState.create(
							"powderbowl-express", "Powderbowl Express", LiftState.Status.OPEN
						),
						LiftState.create("sky-express", "Sky Express", LiftState.Status.HOLD),
						LiftState.create(
							"dipper-express", "Dipper Express", LiftState.Status.CLOSED
						),
					]
				)
			)
		)
	)
