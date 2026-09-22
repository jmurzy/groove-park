> [!CAUTION]
> **OUTDATED — archived in `plans/` for historical reference only. Do not use as source of truth.**

# HEAVENLY PARK implementation plan

## 1. Purpose

Build the first playable `HEAVENLY PARK` jump as a simulation-heavy 2.5D
physics sandbox for the Polycade Sente. The milestone must prove that a player
can choose an approach line, manage speed by carving and tucking, launch from a
ramp, perform a physically measured trick, and understand why the landing
succeeded or failed.

This plan implements the first-playable portion of [GAME_PARK.md](GAME_PARK.md).
The cabinet's physical mappings are documented in
[`POLYCADE_SENTE_CONTROLS.md`](../POLYCADE_SENTE_CONTROLS.md).

This plan implements Stage A of `GAME_PARK.md` §13 and conforms to its §5 control table: blue `X` handles compression and pop because joystick up/down controls traversal across the slope.

The first playable is deliberately smaller than the complete event:

- One player.
- Keep the existing two-player selection card visible but non-interactive until
  the two-player foundation milestone. Only one-player selection may start the
  first playable.
- One rider, beginning with the skier.
- One broad approach, one ramp, and one landing.
- One fully animated grab.
- Immediate restart.
- Debug rendering and deterministic physics traces.
- No final art requirement.
- No complete three-jump event.
- No two-player simulation until the one-player physics passes its checks.

## 2. Fixed decisions

### Product and platform

- Use Godot 4.6, GDScript, and the Compatibility renderer.
- Preserve the 1920 x 1080 primary display and optional 1920 x 360 marquee.
- Keep gameplay operable without the marquee.
- When the marquee is present, treat it as part of the game display; closing its
  window may quit the application.
- Target the Polycade Sente's two identical Xbox-style control stations.
- Treat the cabinet's digital joystick as an 8-way input.
- Keep `EXIT`, `SELECT`, and `START` as system controls rather than gameplay
  actions.
- Treat both stations' `EXIT`, `SELECT`, and `START` controls as mirrored shared
  system controls, not independently assigned player inputs.
- Preserve the existing cabinet exit behavior.

### Game model

- Use a side-view presentation with a hidden lane coordinate, commonly called
  2.5D.
- Keep course progress, lane position, and airborne vertical position separate.
- Use momentum steering. Input requests a heading; it never directly sets
  position.
- Going straight down the fall line builds speed.
- Traversing across the fall line reduces acceleration and adds edge drag.
- Tucking reduces aerodynamic drag but weakens steering.
- A hard edge check increases grip and speed loss; it does not assign a speed.
- Ramps launch from physical approach velocity and ramp tangent.
- Airborne trajectory is ballistic and cannot be steered.
- Air controls affect rotation, body shape, grabs, tweaks, and landing
  preparation only.
- Rotation and completed tricks are measured from simulation state, not button
  duration or animation state.
- Landing quality is determined from first meaningful contact.

### Scope control

- Do not build the complete course before the single jump is fun.
- Do not add rails, halfpipes, equipment upgrades, progression, or online
  features.
- Do not add named grabs without a visually distinct pose.
- Do not add two-player physics until repeatable one-player input traces pass.
- Do not hide physics problems with scripted launches, angle snapping, or
  automatic landings.

## 3. Current-state assessment

The current prototype is not a physics controller:

- `gameplay_screen.gd` stores one `_skier_world_position`.
- Left and right directly change its X coordinate at a constant rate.
- `_slope_position()` replaces its Y coordinate every frame.
- Movement runs in `_process()` rather than `_physics_process()`.
- The slope is a sampled visual path, not collision or terrain state.
- Space starts a cosmetic tween through one full rotation.
- The camera is a horizontal texture crop with no vertical follow.
- HUD values are hard-coded.
- The existing two-player card is visible but disabled, and gameplay creates
  only one rider simulation.

Do not incrementally add gravity to this code path. First extract authoritative
simulation state from `GameplayScreen`; otherwise camera coordinates, hidden
lane position, terrain contact, and jump height will remain coupled.

## 4. Coordinate model

### Authoritative coordinates

Each rider owns three independent coordinates:

```text
course_progress   distance toward the end of the course; right-positive
lane_position     distance across the snow; down-screen-positive when projected
vertical_position physical vertical position; down-positive in Godot coordinates
```

Each coordinate has a corresponding velocity:

```text
course_speed
lane_speed
vertical_speed
```

The simulation may group ground-plane values for vector math:

```text
ground_position = Vector2(course_progress, lane_position)
ground_velocity = Vector2(course_speed, lane_speed)
```

Do not use `Node2D.position`, camera position, or sprite position as simulation
state.

### Terrain surface

The first course is a height profile extruded across a broad lane:

```text
surface_y = course.surface_y_at(course_progress)
```

The ramp and landing have identical physical height across the valid lane. This
keeps the first implementation understandable while still allowing the player
to traverse across the snow.

The course separately supplies:

- Minimum and maximum lane at a given progress value.
- Local terrain tangent and normal.
- Ramp approach start.
- Compression window.
- Lip position.
- Landing-zone start and end.
- Recovery position.
- Camera bounds.

### Projection

Project simulation state into the existing side-view artwork:

```text
screen_x = course_progress
screen_y = vertical_position + lane_position * lane_projection_scale
```

While grounded:

```text
vertical_position = surface_y_at(course_progress)
```

The lane projection scale should initially be modest. Up and down need to be
readable without making a rider at a lane edge appear detached from the broad
snow surface. Draw lane guides in debug mode before relying on background art.

Later art may add lane markers, perspective scaling, and shadows. None of those
may feed back into physics.

## 5. Simulation architecture

Implement the core simulation as data and pure stepping logic wherever
practical. Godot nodes adapt input and render the result.

### Proposed files

```text
src/game/park/
    park_course.gd
    park_course.tres
    rider_input_frame.gd
    rider_state.gd
    rider_tuning.gd
    rider_tuning.tres
    rider_simulation.gd
    trick_tracker.gd
    jump_judge.gd
    jump_result.gd
src/presentation/gameplay/
    skier_view.gd
    park_camera.gd
    physics_debug_overlay.gd
tests/game/park/
    test_rider_simulation.gd
    test_jump_judge.gd
    traces/
```

Create files only when the milestone that needs them begins. Do not create an
empty framework in advance.

### `ParkCourse`

Own authored, static course facts:

- Ordered terrain points.
- Lane bounds.
- Start position and heading.
- Ramp approach, compression, lip, landing, and recovery markers.
- Camera feature bounds.
- Terrain interpolation.
- Tangent and normal queries.
- Swept terrain intersection queries.

Reuse the current `SlopePath` points as initial authoring data, but move gameplay
queries behind `ParkCourse`. Validate that points are strictly ordered by
course progress and reject zero-width segments.

### `RiderInputFrame`

Represent one physics tick of player intent:

```text
heading: Vector2
tuck_pressed: bool
brake_pressed: bool
pop_pressed: bool
pop_just_pressed: bool
pop_just_released: bool
edge_pressed: bool
grab_pressed: bool
grab_just_pressed: bool
tweak_pressed: bool
landing_prep_pressed: bool
```

The simulation consumes this value and must not call `Input` itself. This makes
recorded input traces replayable and keeps cabinet mapping out of physics.

### `RiderState`

Own authoritative mutable rider state:

- Phase: grounded, airborne, landed, crashed, or recovering.
- Ground position and velocity.
- Vertical position and velocity.
- Heading and desired heading.
- Orientation and angular velocity.
- Current terrain tangent and normal.
- Compression amount and release timing.
- Tuck, edge, brake, grab, tweak, and landing-preparation state.
- Takeoff measurements.
- Airtime.
- Landing measurements.

### `RiderTuning`

Store tunable values in one resource rather than scattering constants:

- Gravity.
- Base snow resistance.
- Aerodynamic drag.
- Tuck drag multiplier.
- Steering acceleration and maximum turn rate.
- Tuck steering multiplier.
- Edge grip and edge drag.
- Brake grip and drag.
- Lane-boundary restoring force.
- Pop compression rate, release window, and impulse.
- Air drag.
- Rotation torque, maximum angular velocity, and damping.
- Compact and extended rotational inertia multipliers.
- Landing-preparation damping.
- Landing thresholds.

Every saved score must eventually carry a tuning/rules version. Local records
are outside the first sandbox scope.

### `RiderSimulation`

Advance one rider by one fixed physics tick:

```gdscript
func step(
    state: RiderState,
    input: RiderInputFrame,
    course: ParkCourse,
    tuning: RiderTuning,
    delta: float
) -> void:
```

It owns state transitions and force integration. It does not draw, play audio,
modify the HUD, or inspect sprite frames.

### `TrickTracker`

Track a single flight:

- Takeoff orientation.
- Previous orientation.
- Cumulative signed rotation.
- Completed full rotations.
- Rotation direction.
- Grab start, duration, and release.
- Tweak duration.
- Landing-preparation start.
- Trick validity.

### `JumpJudge`

Convert captured approach, takeoff, flight, and landing measurements into a
deterministic `JumpResult`. It must not inspect input events or visuals.

## 6. Sente input design

### Physical mapping

Each station has:

| Control | Physical mapping |
| --- | --- |
| Joystick | Digital 8-way direction |
| Blue | `X` |
| Yellow | `Y` |
| Orange | `LB` |
| Green | `A` |
| Red | `B` |
| Purple | `RB` |
| Lower-left white | `LT` |
| Lower-right white | `RT` |
| Top white controls | `EXIT`, `SELECT`, `START` |

The top white controls are electrically mirrored across the two stations and
produce shared application-level behavior. They are not part of player device
assignment. Keep the existing shared system-action behavior unless cabinet
testing disproves this hardware assumption.

The existing project already maps the standard system button indices for Back,
Guide, and Start. Use Godot's named joypad constants for new code rather than
embedding numeric values.

The Sente joystick is digital, but bind both standard D-pad directions and left
stick axes if the cabinet driver can emit either. Apply a deadzone only to axis
events; do not add acceleration based on analog magnitude because the cabinet
has no analog travel.

### Ground controls

| Control | Action |
| --- | --- |
| Joystick | Select desired ground heading |
| `A` | Tuck |
| `B` | Hard edge check/brake |
| `X` | Hold compression; release near the lip to pop |
| `Y` | Strong edge/carve modifier |
| `LB` | Reserved on the ground |
| `RB` | Reserved on the ground |
| `LT`, `RT` | Reserved for later use |

The 8-way headings are:

| Input | Desired heading | Expected speed effect |
| --- | --- | --- |
| Right | Straight down the fall line | Maximum acceleration |
| Up-right/down-right | Shallow traverse | Small carve loss |
| Up/down | Across the fall line | Strong edge loss |
| Up-left/down-left | Partly uphill | Aggressive speed loss |
| Left | Uphill | Strongest natural check |
| Neutral | Preserve intent and momentum | Gravity continues acting |

The rider turns toward the desired heading at a bounded rate. The joystick does
not set velocity or position.

### Air controls

| Control | Action |
| --- | --- |
| Joystick left/right | Backward/forward rotation torque |
| Joystick down | Compact body and rotate faster |
| Joystick up | Extend body and rotate slower |
| `A` | Signature grab |
| `B` | Release grab and prepare for landing |
| `X` | Tweak the active grab |
| `Y` | Alternate grab after matching art exists |
| `LB` | Front-equipment grab after matching art exists |
| `RB` | Rear-equipment grab after matching art exists |
| `LT`, `RT` | Reserved for later advanced tricks |

The first sandbox fully implements only the signature `A` grab. Reserve the
other final mappings, but do not score visually indistinguishable grabs.

### Input transition rules

- Holding `A` for a tuck through takeoff must not automatically start a grab.
- Holding `X` through takeoff must not automatically start a tweak.
- Require release and a fresh press after takeoff for context-changing actions.
- If grab and landing preparation are both held, landing preparation wins.
- Airborne input never changes course progress, lane position, or vertical
  trajectory directly.
- Pausing clears one-tick transitions so unpausing cannot trigger a pop or grab.

### Development keyboard mapping

Add keyboard controls for development without changing cabinet behavior. Keep
the keyboard layout documented next to the Input Map configuration. Keyboard
and controller inputs must produce the same `RiderInputFrame` fields.

Input actions should describe physical intent rather than phase-specific
meaning:

```text
move_left
move_right
move_up
move_down
action_a
action_b
action_x
action_y
action_lb
action_rb
action_lt
action_rt
```

The input adapter translates those actions according to authoritative rider
phase. Do not create separate `tuck` and `grab` Input Map actions bound to the
same `A` button; doing so makes fresh-press transitions and input traces
ambiguous.

### Two-player device assignment

Defer active P2 simulation until the one-player milestone passes, but do not
hard-code P1 to device 0 in simulation code.

The eventual join flow is:

1. The device that starts or confirms the session becomes P1.
2. Two-player selection shows `P2 PRESS A`.
3. The next distinct joypad device pressing `A` becomes P2.
4. Each input adapter stores its assigned device ID for the session.
5. Unassigned controllers cannot affect gameplay.
6. Disconnecting a joined device pauses and identifies the missing player.

This assignment applies only to gameplay controls. Mirrored `EXIT`, `SELECT`,
and `START` remain shared system controls regardless of which physical station
is used.

## 7. Ground physics

### Desired heading

Convert the digital joystick vector to one of eight normalized headings. Rotate
the rider's actual heading toward it using a maximum turn rate and available
edge grip.

Factors affecting turn authority:

- Higher speed requires a wider turn.
- Tucking reduces turn authority.
- `Y` increases edge engagement and turn authority while increasing drag.
- `B` provides the strongest edge engagement and speed loss.
- Reversing direction cannot happen in one tick.

### Forces

Apply forces rather than assigning speed:

```text
gravity force       pulls velocity down the fall line
snow resistance     opposes ground velocity
aerodynamic drag    increases with speed; reduced by tuck
edge drag           increases while traversing or turning
brake drag          increases while B is held
steering force      redirects velocity toward actual heading
boundary force      keeps the rider inside the authored lane
```

The initial model does not need a full rigid-body ski simulation. It must,
however, conserve enough momentum that direction changes and speed corrections
are predictable.

### Tuck

While `A` is held on the ground:

- Reduce aerodynamic drag.
- Reduce maximum steering rate.
- Reduce edge grip.
- Prevent new compression from beginning.

Tucking should be fastest on a straight line and risky near the ramp if a late
correction is required.

### Brake and strong edge

`B` and `Y` are not interchangeable:

- `Y` sharpens the requested carve and creates moderate additional drag.
- `B` is a deliberate speed check with greater drag and a lower maximum speed.
- Both produce snow spray proportional to force, but effects remain
  presentational.
- Holding either through the lip reduces takeoff-balance quality.

### Lane boundaries

Begin with soft containment:

- Apply an increasing restoring force near a boundary.
- Clamp only as a final numerical safeguard.
- Never bounce off an invisible wall.
- Draw boundaries in debug mode.
- Mark leaving the valid ramp or landing width as a missed feature or crash,
  rather than silently moving the rider back to center.

## 8. Compression, ramp, and takeoff

### Compression

`X` is not a general jump button.

1. Pressing `X` in the authored compression zone begins compression.
2. Compression builds over a bounded duration.
3. Releasing before the lip records release timing.
4. Releasing near the lip adds the strongest bounded normal impulse.
5. Releasing early gives a weaker impulse.
6. Holding through the lip gives little or no bonus and reduces takeoff balance.
7. Pressing outside a valid approach may animate but cannot launch the rider.

### Lip transition

When the rider crosses the lip moving forward:

- Query the terrain tangent immediately before the lip.
- Preserve course and lane velocity.
- Derive vertical velocity from terrain tangent and course speed.
- Add any valid pop impulse along the terrain normal.
- Capture approach speed, heading error, lane position, edge load, compression,
  and release timing.
- Set phase to airborne.
- Reset the trick tracker.

The lip marker identifies contact separation; it must not assign a canned flight
velocity.

### High-speed safety

Use the segment from previous to next ground position to detect lip crossing.
Never rely on exact equality with the lip coordinate. A rider must not skip the
takeoff transition because one fixed step crosses the marker.

## 9. Airborne physics

### Translation

At each fixed tick:

```text
vertical_speed += gravity * delta
course_progress += course_speed * delta
lane_position += lane_speed * delta
vertical_position += vertical_speed * delta
```

Apply modest air drag only if course tuning requires it. Do not let input change
course, lane, or vertical velocity.

### Rotation

Track unwrapped orientation and angular velocity:

```text
angular_velocity += torque_input * air_torque * delta
angular_velocity = clamp(angular_velocity, -maximum, maximum)
orientation += angular_velocity * delta
```

- Left and right apply opposing torque.
- Reversing spin must overcome existing angular momentum.
- Neutral input applies only natural damping.
- Compacting reduces effective rotational inertia and increases spin rate.
- Extending increases effective inertia and slows spin rate.
- Landing preparation adds bounded damping but cannot set an angle.
- The visual rider copies simulation orientation; animation never drives it.

### Grabs and tweaks

- A grab begins only after a fresh airborne press.
- A grab must remain held for a minimum duration to count.
- Grabbing reduces rotation-control authority.
- `X` can tweak only while a grab is active.
- Tweaking increases style value and further reduces correction authority.
- `B` immediately releases the grab and begins landing preparation.
- A held grab at touchdown creates a landing penalty or crash at extreme impact.

## 10. Swept landing detection

Do not test only the rider's final position. For each airborne tick:

1. Keep the previous progress and vertical position.
2. Integrate the proposed next state.
3. Query terrain segments crossed by the progress interval.
4. Find the earliest intersection between the rider's swept flight segment and
   the terrain profile.
5. Ignore contact while clearly ascending away from the surface.
6. Validate lane position against the landing width.
7. Resolve exactly one first meaningful contact.

Capture at contact:

- Contact position.
- Terrain tangent and normal.
- Equipment orientation.
- Equipment-to-slope angle error.
- Course, lane, and vertical velocity.
- Velocity alignment with the landing tangent.
- Angular velocity.
- Impact speed along the normal.
- Grab and landing-preparation state.
- Whether contact lies in the valid landing zone.

After contact, do not evaluate another landing result from collision jitter.

## 11. Landing classification

Start with the design ranges, then tune from traces:

| Result | Equipment-to-slope error | Other requirements |
| --- | --- | --- |
| Perfect | 0-8 degrees | Very low excess angular and normal speed |
| Clean | 9-20 degrees | Controlled impact and direction |
| Sketchy | 21-35 degrees | Recoverable impact and rotation |
| Crash | Above 35 degrees | Or body-first, outside zone, or excessive impact |

Use continuous quality values beneath the labels:

- Angle quality.
- Velocity-alignment quality.
- Impact quality.
- Angular-control quality.
- Grab-release quality.

Avoid a large score discontinuity at exactly 8, 20, or 35 degrees. Labels may
change at thresholds while the multiplier changes smoothly.

Successful landings enter a short compression/recovery phase. Crashes remove
trick control, display one clear outcome, and allow immediate restart in the
sandbox.

## 12. Trick measurement

At takeoff:

- Store the starting orientation.
- Reset cumulative signed rotation.
- Reset grab and tweak timers.
- Begin airtime measurement.

Each tick, accumulate the shortest signed angle difference from the previous
orientation. Do not wrap cumulative rotation to `0..TAU`.

At contact:

```text
completed_rotations = floor(abs(cumulative_rotation) / TAU)
```

- Score only completed rotations.
- Preserve the attempted partial rotation for the result call.
- Determine forward or backward from cumulative sign.
- Do not infer a rotation from held direction.
- Direction reversals remain physically possible and consume time and momentum.

## 13. Scoring

Implement scoring only after landing truth is stable.

### Captured components

- Approach speed inside an authored measurement zone.
- Heading and lane alignment at the lip.
- Compression amount and pop timing.
- Airtime, capped for the feature.
- Completed physical rotations.
- Valid grab duration.
- Valid tweak duration.
- Grab release timing.
- Landing quality.

### Initial formula

```text
base = approach + takeoff + airtime + rotation + grab + tweak
jump_score = round(base * landing_multiplier)
```

- Crash always produces zero.
- Approach and airtime are capped.
- Landing multiplier is continuous.
- A straight perfect landing cannot outscore a clean difficult trick.
- The result exposes every component for debugging.
- Variety scoring waits for the three-jump event; this matches `GAME_PARK.md` with `variety_multiplier = 1` for a single jump.

## 14. Presentation integration

### Skier view

`SkierView` is the skier-specific presentation adapter. Do not name it
`RiderView`: a future `SnowboarderView` will use the same presentation contract
with snowboard-specific art, equipment anchors, and possibly different visual
timing. Neither view owns rider physics.

`SkierView` reads `RiderState` and selects an animation from simulation state:

- Neutral glide.
- Tuck.
- Carve uphill and carve downhill.
- Compression.
- Takeoff extension.
- Neutral air.
- Grab reach and grab hold.
- Grab tweak.
- Landing preparation.
- Deep landing compression.
- Sketchy recovery.
- Crash.
- Celebration.

Use an `AnimatedSprite2D` with a named animation for each state, rather than
one static `Sprite2D` per pose. Looping animations must be subtle and may play
only while their state remains active:

- Neutral glide: 3-4 frames at roughly 8-10 fps, with visible pole movement or
  ski shuffle.
- Tuck, both carves, and neutral air: 2-frame loops with restrained body motion.
- Grab hold: 2-frame loop after the reach transition.
- Sketchy recovery: 3-4 frame wobble loop.

Transitions must play once and hold their final frame when the simulation state
requires it:

- Compression: 2-3 crouch frames, then hold until release or takeoff.
- Takeoff extension: 1-2 frames.
- Grab reach and tweak: 1-2 frames before or from the grab-hold loop.
- Landing preparation and deep landing: 2 frames each.
- Crash: 3-4 frames, impact through settled pose, then hold until restart.
- Celebration: 2-4 frames, held or looped only after a successful run result.

Animation changes occur only on a presentation-state change; do not restart an
animation each physics tick. The view applies projected position and physical
orientation, using terrain tangent while grounded and simulated orientation in
the air. Pose selection, animation frames, and any visual easing may never
alter simulation state.

Keep all animation frames on a shared canvas and use a consistent equipment
contact/pivot anchor. The current variable-size static pose PNGs are temporary
keys; normalize future frames before integration so a frame switch cannot move
the skier through the snow or cause visible popping. Keep snow spray, shadows,
and crash plumes separate effects rather than baking them into skier frames.
Every frame must use true alpha transparency (background pixels fully
transparent, alpha 0). Reject any frame with a painted checkerboard, grid,
gradient, or other fake transparency background.

During migration, a one-frame animation made from each current pose key is an
acceptable fallback. New art should follow the `skier_<state>_f<index>.png`
naming convention under `artwork/players/skier/`, allowing additional frames to
be added without changing simulation or pose-selection code.

### Gameplay screen

Refactor `GameplayScreen` into a composition/presentation role:

- Create the course, rider simulation adapter, `SkierView`, camera, HUD, and
  debug overlay.
- Forward pause and exit requests.
- Advance simulation from `_physics_process()`.
- Advance visual-only effects from `_process()`.
- Remove direct skier movement and the cosmetic flip tween.
- Stop drawing the rider from camera-relative hand calculations once the world
  node and camera own projection.

### Camera

Replace the horizontal texture crop with a gameplay world and `Camera2D` once
the simulation is stable:

- Use authored bounds for the complete active feature.
- Lead the rider in the direction of travel.
- Raise framing during flight.
- Preserve landing visibility.
- Smooth position and zoom visually.
- Never alter rider physics.
- Keep the HUD in screen space, preferably under a `CanvasLayer`.

### HUD

Replace hard-coded HUD values with live state:

- Physical speed.
- Current jump.
- Total score.
- Cumulative rotation.
- Grounded/airborne status in debug builds.
- Temporary trick and landing result.

Do not make the HUD query sprite state.

## 15. Debugging tools

Provide a debug overlay toggled only in development builds:

- Course and lane coordinates.
- Ground and desired headings.
- Ground velocity vector.
- Vertical velocity vector.
- Current speed.
- Terrain tangent and normal.
- Ramp lip and compression window.
- Landing-zone bounds.
- Predicted no-input ballistic trajectory.
- Orientation and angular velocity.
- Cumulative rotation.
- Grab and landing-preparation state.
- Landing angle and velocity error.
- Current tuning/rules version.

Keep the existing draggable path editor only if it validates ordering and cannot
silently save invalid terrain. Otherwise replace it with editor-authored
resource values during the sandbox milestone.

## 16. Repeatable input traces

The physics sandbox requires reproducible traces. A trace records one
`RiderInputFrame` per physics tick plus initial course and tuning versions.

Create baseline traces for:

- Straight approach with no pop.
- Straight tuck and clean pop.
- Shallow carve followed by correction.
- Full traverse to shed speed.
- Hard brake before the ramp.
- One forward rotation and landing preparation.
- One backward rotation.
- Grab with timely release.
- Grab held into contact.
- Deliberate under-rotation.
- Deliberate over-rotation.
- Landing outside the lane.

Replay produces final measurements and a result. Tests should compare values
within tolerances rather than requiring bit-identical floating-point output
across platforms.

## 17. Automated checks

Add a minimal headless test runner if the repository still has no Godot test
framework. Keep simulation tests independent from rendering.

### Course tests

- Reject unordered points.
- Reject duplicate progress coordinates.
- Interpolate surface height correctly.
- Return normalized tangents and normals.
- Detect crossing the lip at high speed.
- Find the earliest swept terrain intersection.
- Enforce lane bounds.

### Ground tests

- Straight tuck accelerates more than an untucked straight run.
- A traverse accelerates less than a straight run.
- `Y` turns faster and loses more speed than an ordinary carve.
- `B` loses more speed than `Y`.
- Tuck reduces turning authority.
- Releasing input does not stop the rider instantly.
- Boundaries do not reflect velocity like hard walls.

### Flight tests

- Identical takeoff state produces equivalent trajectories.
- Faster approach travels farther.
- A valid pop increases vertical launch speed within its cap.
- Air input does not alter translational trajectory.
- Torque changes angular velocity rather than assigning orientation.
- Reversing torque first reduces existing angular velocity.
- Compact and extended poses change rotation rate predictably.
- One accumulated `TAU` counts exactly one completed rotation.

### Landing tests

- Perfect, clean, sketchy, and crash examples classify correctly.
- Classification remains stable around terrain-segment joins.
- A one-degree difference near a label boundary does not create a large score
  jump.
- Outside-zone contact crashes or misses as authored.
- A crash scores zero.
- First contact resolves only once.

### Existing checks

Continue running:

```text
just format-check
just lint-check
just typecheck
just check
```

Add the new headless simulation test command to `just check` only after it is
stable locally and in CI.

## 18. Implementation sequence

Each milestone ends at a playable or inspectable stop point. Do not combine all
milestones into one large change.

### Milestone 0: Cabinet input proof

Work:

1. Add a debug-only input screen or overlay.
2. Display connected device IDs and names.
3. Display joypad button constants and axis values as controls are pressed.
4. Verify both Sente stations appear independently.
5. Verify joystick diagonals.
6. Verify `A`, `B`, `X`, `Y`, `LB`, `RB`, `LT`, and `RT`.
7. Verify `EXIT`, `SELECT`, and `START` from either physical station produce the
   same mirrored system behavior and retain current behavior.
8. Record whether the joystick arrives as D-pad buttons, stick axes, or both.
9. Record trigger resting and pressed values.

Stop when every gameplay control has a verified Godot event and device ID on
the actual cabinet, and the mirrored system controls have verified shared
behavior from both physical stations.

### Milestone 1: Coordinate and rendering separation

Work:

1. Add rider state with course, lane, and vertical coordinates.
2. Add a projection function.
3. Render the existing rider from projected state.
4. Move simulation stepping to `_physics_process()`.
5. Keep temporary simple course movement for comparison.
6. Remove camera-relative position from authoritative state.

Stop when the rider can be placed at arbitrary course, lane, and vertical
coordinates without changing the camera or terrain data.

### Milestone 2: Authored one-jump course

Work:

1. Create `ParkCourse` and migrate the current path as seed data.
2. Author one smooth approach, ramp, gap/table, landing, and runout.
3. Add lane bounds and feature markers.
4. Add validation and debug drawing.
5. Add terrain tangent and normal queries.

Stop when course queries and markers are correct with no rider physics.

### Milestone 3: Ground steering and speed

Work:

1. Convert 8-way input to desired heading.
2. Add bounded momentum steering.
3. Add gravity, snow resistance, aerodynamic drag, and edge drag.
4. Add soft lane containment.
5. Add `A` tuck, `B` brake, and `Y` strong edge.
6. Feed physical speed to the HUD.
7. Add ground input traces and tests.

Stop when players can intentionally arrive at the ramp too slow, in the target
speed band, or too fast by choosing different lines and techniques.

### Milestone 4: Compression and takeoff

Work:

1. Add the compression zone and `X` state.
2. Measure release timing against the lip.
3. Detect swept lip crossing.
4. Preserve ground velocity into flight.
5. Add ramp-tangent vertical velocity and bounded pop impulse.
6. Capture takeoff measurements.
7. Add trajectory debug drawing.

Stop when speed and pop timing produce visibly different but predictable arcs.

### Milestone 5: Air rotation and body control

Work:

1. Add gravity-driven flight.
2. Preserve lane momentum and disable lane steering.
3. Add left/right torque.
4. Add compact/extend rotational inertia behavior.
5. Add `B` landing preparation.
6. Remove the cosmetic flip tween.
7. Add flight traces and tests.

Stop when a player can intentionally under-rotate, complete, and over-rotate one
flip without angle snapping.

### Milestone 6: Landing truth

Work:

1. Add swept terrain contact.
2. Capture first-contact measurements.
3. Implement continuous landing quality and display labels.
4. Add landing compression, sketchy recovery, and crash states.
5. Add immediate sandbox restart.
6. Add threshold and terrain-seam tests.

Stop when players and developers can explain every landing result from visible
debug values.

### Milestone 7: Signature grab and trick tracking

Work:

1. Add the fresh-press transition rule.
2. Add `A` signature grab with `SkierView` grab-reach and grab-hold animations.
3. Add minimum valid duration and release timing.
4. Add `X` tweak only if its distinct `SkierView` animation remains readable.
5. Track cumulative physical rotation.
6. Generate trick calls from measured state.

Stop when a landed grab is visibly and mechanically distinct from a straight
rotation.

### Milestone 8: Scoring and HUD

Work:

1. Implement deterministic score components.
2. Add continuous landing multiplier.
3. Replace HUD placeholders.
4. Show a compact post-landing breakdown.
5. Add score tests.

Stop when a player can see why one landed attempt scored above another.

### Milestone 9: Camera and presentation proof

Work:

1. Introduce world-space rendering and `Camera2D`.
2. Frame approach, lip, flight, and landing predictably.
3. Add `SkierView` pose animations, snow spray, shadow, and basic sound cues.
4. Keep HUD and pause UI fixed to the screen.
5. Verify 1920 x 1080 at the cabinet target refresh while the marquee runs.

Stop when the complete jump is readable without debug overlays.

### Milestone 10: Cabinet tuning pass

Work:

1. Play on the Sente, not only keyboard.
2. Tune steering for an 8-way digital stick.
3. Confirm action-button ergonomics with both player stations.
4. Confirm controls are readable from a short instruction card.
5. Test low, target, and high render rates.
6. Replay baseline traces on macOS and the Windows cabinet build.
7. Record tuning and device findings.

Stop when a new player can land a basic trick within three attempts and an
experienced player can intentionally vary line, speed, pop, and rotation.

### Milestone 11: Two-player foundation

Begin only after all previous acceptance checks pass.

Work:

1. Re-enable the existing two-player selection card.
2. Add device join and assignment.
3. Create independent rider states and input frames.
4. Disable rider collision.
5. Add parallel lane presentation over identical course physics.
6. Add shared camera containment.
7. Add independent results and crash recovery.
8. Stress-test both control stations and marquee output.

The complete event, staging gates, three jumps, records, and final results are a
later plan.

## 19. Instruction design

The player-facing instructions may describe the completed first-playable control
set before every mechanic is implemented, provided they remain consistent with
the final mappings below. During active play, teach only controls needed for the
next phase.

Before the approach:

```text
RIGHT             POINT DOWNHILL
UP / DOWN         CARVE ACROSS SLOPE
A                 TUCK
B                 CHECK SPEED
HOLD X, RELEASE   POP AT THE LIP
```

During first flight:

```text
LEFT / RIGHT      FLIP
DOWN / UP         TUCK / EXTEND
A                 GRAB
B                 SPOT LANDING
```

Do not show every future grab on the first attempt. Introduce `Y`, `LB`, and
`RB` after the player has landed the signature grab and matching art exists.

Because the cabinet has a blue gameplay `X` and a white `EXIT` button marked
with an X-shaped symbol, instructions must say `BLUE X` or `EXIT`, never merely
`PRESS X TO EXIT`.

## 20. First-playable acceptance checks

### Controls

- Every Sente control emits the expected Godot event.
- Both stations can be distinguished.
- Mirrored `EXIT`, `SELECT`, and `START` controls from either station produce the
  same shared system behavior and do not require player assignment.
- All eight joystick directions are recognized.
- Ground and air contexts change only on authoritative takeoff/contact state.
- Held ground actions do not accidentally become air tricks.
- System controls work while gameplay is active, paused, landed, or crashed.

### Ground movement

- Straight and tucked is the fastest normal approach.
- Shallow carving retains more speed than a full traverse.
- A full Up/Down traverse visibly and measurably sheds speed.
- Turning uphill slows the rider without setting speed directly.
- `Y` sharpens a carve with a speed cost.
- `B` produces the strongest intentional speed check.
- Tucking weakens late steering corrections.
- The rider cannot instantly reverse ground direction.

### Takeoff and flight

- Faster approach produces more distance and airtime.
- Pop timing produces explainable launch differences.
- Missing the pop still permits a natural ramp launch.
- Air input cannot change the ballistic path.
- Rotation responds to torque and momentum.
- Compacting and extending visibly change rotation rate.
- A completed rotation comes from measured orientation.

### Landing and scoring

- Perfect, clean, sketchy, and crash outcomes are reproducible.
- Landing labels remain stable across terrain segment joins.
- Players can connect failure to angle, impact, lane, or angular velocity.
- A crash scores zero.
- A difficult clean trick beats a perfect straight air under normal conditions.
- Score components can be inspected in debug mode.

### Technical

- Simulation runs at a fixed physics timestep.
- Baseline traces remain materially equivalent across supported render rates.
- Fast riders cannot skip the lip or tunnel through the landing.
- Camera and presentation never modify simulation state.
- The 1080p primary remains smooth with the marquee active.
- `just check` passes.
- A Windows export launches and accepts both Sente control stations.

## 21. Deferred work

Do not include the following in this implementation plan's first playable:

- Complete three-jump event flow.
- Final two-player staging and results.
- More grabs than available readable poses.
- Switch stance.
- Rails or halfpipe.
- Procedural terrain.
- Equipment statistics or upgrades.
- Online services and leaderboards.
- Final local-record persistence.
- Dynamic weather affecting physics.
- Final announcer, crowd, or marquee show package.

## 22. Completion record

Fill this in after the one-jump cabinet milestone:

```text
Date tested:
Git commit / build:
Godot version:
Windows / AGS version:
P1 device name and ID:
P2 device name and ID:
Joystick event type:
LT / RT axis behavior:
Physics tick rate:
Rules / tuning version:
Baseline trace result:
Target render-rate result:
Marquee-active performance:
New-player attempts to first landing:
Known physics issues:
Control changes requested:
Ready for two-player foundation: yes / no
```

The milestone is complete only when the acceptance checks pass on the Polycade,
not merely in the editor.
