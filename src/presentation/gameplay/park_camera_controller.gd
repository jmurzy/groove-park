## Tracks the rider while keeping the authored gameplay world inside camera bounds.
class_name ParkCameraController
extends RefCounted

const DESIGN_SIZE := Vector2(1920, 1080)
const CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 724.0, DESIGN_SIZE.y / 724.0)
const FLIGHT_CAMERA_ZOOM := Vector2(DESIGN_SIZE.y / 640.0, DESIGN_SIZE.y / 640.0)
const ZOOM_RESPONSE := 3.5


func update(
	camera: Camera2D,
	state: RiderState,
	projection: ParkProjection,
	world_size: Vector2,
	delta: float
) -> void:
	var is_flying := state.run.run_phase == RiderRunState.RunPhase.FLIGHT
	var target_zoom := FLIGHT_CAMERA_ZOOM if is_flying else CAMERA_ZOOM
	camera.zoom = camera.zoom.lerp(target_zoom, clampf(ZOOM_RESPONSE * delta, 0.0, 1.0))
	var half_view_size := DESIGN_SIZE / camera.zoom * 0.5
	var target_x := clampf(
		state.kinematics.course_progress, half_view_size.x, world_size.x - half_view_size.x
	)
	var target_y := world_size.y * 0.5
	if is_flying:
		target_y = (
			(projection.project_rider(state).y + projection.project_rider_ground(state).y) * 0.5
		)
	target_y = clampf(target_y, half_view_size.y, world_size.y - half_view_size.y)
	camera.position = Vector2(target_x, target_y)
