## Coordinates asynchronous signal completion.
class_name SignalUtils
extends RefCounted


static func await_both(tree: SceneTree, first: Signal, second: Signal) -> void:
	var completed := [false, false]
	first.connect(func(_value: Variant = null) -> void: completed[0] = true)
	second.connect(func() -> void: completed[1] = true)
	while not completed[0] or not completed[1]:
		await tree.process_frame
