## Abstract lift-state feed; emits `state_changed` when MountainState updates.
## Example: subclass and emit from `_ready()` or a poll timer.
class_name MountainStateSource
extends Node

signal state_changed(state: MountainState)
