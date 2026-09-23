# HEAVENLY Gameplay Implementation Plan

## Status

Milestones 1 through 5 are complete. Every shipped route now has a deterministic start-to-finish movement loop; compression, grabs, rotations, and final landing judgment remain incremental later milestones.

## Goal

Build one complete park run with three top-level gameplay phases:

1. Approach
2. Flight
3. Landing

Landing includes clean runout, sketchy recovery, and crash outcomes. The run ends after the landing sequence. Scoring and distinct grab identities are deferred until the gameplay loop is stable.

## Agreed Gameplay Rules

### Routes

- The rider chooses one of three authored approach paths.
- The upper and center routes are flight routes.
- The final point of a flight approach path is its lip.
- The lower route is a grounded route and joins directly to its runout.
- Each approach path has a corresponding landing path.
- Flight-route landing paths are independently authored.
- A flight route's landing path starts strictly down-course from its lip.
- The active route is frozen at takeoff and selects the matching landing path.

### Approach

- Existing approach movement, speed building, braking, tucking, edging, and path selection remain intact.
- A rider does not need to pass an arbitrary takeoff-speed threshold.
- Ramp geometry and momentum determine whether the rider reaches the lip.
- A rider without enough momentum naturally stalls before crossing the endpoint.
- Compression is an optional approach mechanic, not a phase.
- A flight route becomes airborne when forward movement crosses its final path point.
- The grounded lower route enters automatic runout when it crosses its approach endpoint.

### Compression

- X charges compression inside a configurable pre-lip window.
- Releasing near the lip converts charge and timing quality into upward pop.
- Reaching the lip without compression still launches from ramp geometry.
- Holding X through the lip auto-releases the stored compression at takeoff.
- A held approach button never activates a grab in flight; grab activation requires a fresh press after takeoff.

### Flight

- Approach controls stop applying immediately at takeoff.
- Flight follows deterministic ballistic movement using captured takeoff velocity, gravity, and air drag.
- The rider cannot steer the flight trajectory after takeoff.
- The six action-cluster buttons are `A`, `B`, `X`, `Y`, `LB`, and `RB`.
- For now, all six buttons toggle one generic grab identity.
- Pressing any grab button while not grabbing starts the generic grab.
- Pressing any grab button while grabbing releases the generic grab.
- The activating button is not recorded as a distinct trick identity.
- `LT` and `RT` remain unused.
- Rotations are available only while the generic grab is active.

### Rotation Gesture

- One 360 uses a strict Left-then-Right joystick gesture.
- Left starts the first 180 degrees.
- Right starts the second 180 degrees after the first half-turn finishes.
- Completing the second half-turn returns the rider to the takeoff orientation and counts one 360.
- Another Left-then-Right sequence performs another 360.
- Right before Left does nothing.
- Holding a direction does not repeat input.
- A new half-turn is accepted only after the previous half-turn reaches its target.
- Releasing the grab during an unfinished half-turn leaves the rotation incomplete.
- Takeoff speed determines how quickly each half-turn can finish.
- Faster takeoff speed therefore allows more complete rotations before the release deadline.
- Rotations do not modify linear flight velocity or the ballistic trajectory.

### Required Rotations

- The run calculates a minimum required rotation count once at takeoff.
- The requirement is frozen for the rest of the jump.
- Low-speed flights may require zero rotations.
- Faster flights require progressively more rotations.
- Initial implementation formula:

```text
required_rotations = ceil(
    max(0, takeoff_speed - safe_no_rotation_speed)
    / speed_per_required_rotation
)
```

- `takeoff_speed` is the captured world-space launch velocity magnitude.
- `safe_no_rotation_speed` and `speed_per_required_rotation` are exported tuning values.
- The HUD displays completed rotations against required rotations.
- Excessive speed may create a requirement that is difficult or impossible to satisfy. This intentionally rewards approach-speed control.

### Grab Release Deadline

- Takeoff captures the lip's vertical world position as `release_deadline_y`.
- The rider begins exactly on that line, so only a descending crossing counts.
- The deadline is crossed when the rider moves from above the line to below it with downward vertical velocity.
- A warning line appears shortly before the descending crossing.
- Releasing the grab before crossing preserves a clean landing opportunity.
- Releasing after crossing but before ground contact marks the landing sketchy.
- Starting another grab after crossing also marks the landing sketchy.
- Still grabbing at ground contact causes a crash.

### Landing Outcomes

The first swept contact with the selected landing path resolves the landing exactly once. Outcome priority is:

```text
Still grabbing              -> CRASH
Half-rotation unfinished    -> CRASH
Completed rotations < quota -> CRASH
Release deadline missed     -> SKETCHY
Otherwise                   -> CLEAN
```

- A clean landing enters automatic runout with celebration presentation.
- An abandon enters automatic runout with deep-landing presentation and no celebration.
- An airborne abandon follows the active route's curved abandon line; the lower grounded route follows its authored runout path.
- A sketchy landing enters automatic runout with recovery presentation.
- A crash stops or settles the rider and completes after a deterministic delay.
- Landing controls are always disabled.
- Clean and sketchy runouts preserve contact momentum but are advanced automatically.
- The run completes at the selected landing path endpoint.
- The lower grounded route resolves as `ABANDON` and enters the same automatic runout without a flight or trick requirement.

## Authoritative State Model

Replace the current overlapping `MotionPhase` and `ControlMode` models with one run phase and one landing outcome.

```gdscript
enum RunPhase {
    APPROACH,
    FLIGHT,
    LANDING,
    COMPLETE,
}

enum LandingOutcome {
    NONE,
    ABANDON,
    CLEAN,
    SKETCHY,
    CRASH,
}
```

`RunPhase` controls simulation dispatch. `LandingOutcome` controls landing presentation and terminal behavior. Compression, grab state, and rotation gesture state are ordinary jump data, not additional phases.

## Course Contract

`ParkCourse` owns three matching route records through parallel arrays:

```gdscript
approach_paths[route_index]
landing_paths[route_index]
route_kinds[route_index]
```

Route kinds are:

```gdscript
FLIGHT
GROUND_RUNOUT
```

Course validation guarantees:

- Exactly three approach paths.
- Exactly three landing paths.
- Exactly three route kinds.
- Every path has at least two points.
- Every path is strictly ordered by increasing X progress.
- A flight landing starts after its approach endpoint.
- A grounded runout begins exactly at its approach endpoint.
- Lane bounds are valid.
- Flight collision tests only explicitly authored landing-path segments.

## Simulation Architecture

Use one `RiderSimulation` as the phase dispatcher rather than creating simulations for every conceptual section.

```gdscript
func step(state, input, course, tuning, delta):
    match state.run_phase:
        RunPhase.APPROACH:
            _step_approach(...)
        RunPhase.FLIGHT:
            _step_flight(...)
        RunPhase.LANDING:
            _step_landing(...)
        RunPhase.COMPLETE:
            pass
```

Recommended internal functions:

```text
_step_approach
_update_compression
_cross_approach_endpoint
_begin_flight
_step_flight
_update_grab
_update_rotation_gesture
_cross_release_deadline
_resolve_landing_contact
_begin_ground_runout
_step_landing
_complete_run
```

`RiderSimulation` now dispatches by run phase and retains the existing approach helpers with minimal behavioral changes.

## Takeoff Calculation

At the lip:

1. Clamp the rider to the exact lip position.
2. Freeze the selected route index.
3. Capture the lip tangent and upward normal.
4. Convert horizontal course progress velocity into velocity along the lip tangent.
5. Add optional compression pop along the lip normal.
6. Store the resulting world-space takeoff velocity.
7. Capture lip Y as the release deadline.
8. Calculate required rotations and speed-scaled rotation rate.
9. Reset transient grab and rotation state.
10. Change phase to `FLIGHT`.
11. Integrate any unused fraction of the physics tick as flight time.

The conversion must account for screen-space Y increasing downward:

```text
surface_speed = course_speed / max(lip_tangent.x, epsilon)
takeoff_velocity = lip_tangent * surface_speed
takeoff_velocity += lip_normal * pop_impulse
```

## Flight Integration

Each fixed physics tick:

```text
previous_position = position
velocity.y += gravity * delta
velocity *= air_drag_factor
position += velocity * delta
contact = landing_swept_terrain_intersection(
    previous_position,
    position,
    active_route_index
)
```

Collision uses swept line-segment intersection so high velocity cannot tunnel through landing geometry. Only the selected landing path participates.

Flight termination guards are required for missing or overshooting terrain. Passing the landing path endpoint or leaving world bounds without contact resolves as a crash rather than allowing endless flight.

## Rotation State

Add a small deterministic gesture state:

```gdscript
enum RotationGesturePhase {
    WAITING_LEFT,
    ROTATING_FIRST_HALF,
    WAITING_RIGHT,
    ROTATING_SECOND_HALF,
}
```

Required fields include:

```text
rotation_gesture_phase
rotation_target
rotation_rate
completed_rotations
required_rotations
rotation_incomplete
previous_horizontal_input
```

Behavior:

- Grab activation initializes `WAITING_LEFT`.
- A fresh Left edge in `WAITING_LEFT` adds PI to `rotation_target`.
- Orientation advances toward the target at `rotation_rate`.
- Reaching the target enters `WAITING_RIGHT`.
- A fresh Right edge in `WAITING_RIGHT` adds another PI.
- Reaching that target increments `completed_rotations` and returns to `WAITING_LEFT`.
- Grab release stops accepting rotation gestures.
- Releasing during either rotating state records an incomplete rotation.

Initial speed mapping:

```text
speed_factor = clamp(
    inverse_lerp(min_rotation_speed, max_rotation_speed, takeoff_speed),
    0,
    1
)
rotation_rate = lerp(min_rotation_rate, max_rotation_rate, speed_factor)
```

All four bounds are exported in `RiderTuning` and adjusted through playtesting.

## Generic Grab State

The initial implementation intentionally has no grab identity enum.

Required fields:

```text
grab_active
grab_started_airtime
grab_released_airtime
grab_released_after_deadline
```

Input sampling should expose one phase-neutral event:

```text
grab_toggle_just_pressed
```

That event is true when any of `A/B/X/Y/LB/RB` is freshly pressed. Multiple simultaneous presses still produce one toggle event. Future work may replace it with a button-specific grab request without changing flight phase transitions.

## Presentation Contract

### Rider

- Grounded approach uses existing glide, tuck, compression, and carve animations.
- Early flight uses takeoff extension.
- Flight without a grab uses neutral air.
- Generic grab uses grab reach and grab hold.
- Rotation is presented by rotating the rider view from authoritative orientation.
- Clean contact uses deep landing followed by celebration.
- Sketchy contact uses deep landing followed by recovery.
- Crash uses the crash sequence.

### Camera

- Approach keeps the current horizontal follow behavior.
- Flight follows both horizontal and vertical position while keeping landing terrain visible.
- Landing returns toward ground-oriented framing.
- Camera behavior must not affect simulation or completion timing.

### HUD

- Approach shows speed and contextual approach controls.
- Flight shows `completed_rotations / required_rotations`.
- The release deadline appears only during descending approach to lip height.
- The warning becomes urgent while a grab is active.
- Landing shows clean, sketchy, or crash feedback.
- Complete shows a restart prompt.
- The metric HUD hides while the primary rider's rendered bounds overlap its frame, then returns when clear.

### Debug Overlay

- Approach and landing paths remain visible under `--show-terrain`.
- Flight routes shade an abandon zone between their virtual miss boundaries and curved zone floors; the authoritative `ABANDON LINE` runs through the center.
- The lower route labels its `GROUND JOIN`.
- Future flight debugging should add velocity vectors, predicted trajectory, release deadline, and first contact.

## Data Changes

### `RiderRunState`

Replace the current phase and control-mode fields with:

```text
run_phase
landing_outcome
recovery_time_remaining
completion_time_remaining
```

### `RiderKinematics`

Add or formalize:

```text
active_route_index
flight_position
flight_velocity
```

Existing course progress and vertical position may remain the authoritative world position components if doing so avoids duplicate state.

### `JumpState`

Retain takeoff measurements and add:

```text
takeoff_position
takeoff_velocity
release_deadline_y
release_deadline_crossed
grab_released_after_deadline
rotation_gesture_phase
rotation_target
rotation_rate
completed_rotations
required_rotations
rotation_incomplete
```

Remove or leave unused old free-torque, tweak, compact, and landing-prep concepts until they have an approved gameplay role.

### `RiderInputFrame`

Keep approach intent and add a single generic grab toggle event generated from the six action-cluster buttons. Flight reads horizontal joystick edges but ignores approach movement actions.

### `RiderTuning`

Required tuning values:

```text
compression_window_distance
compression_rate
maximum_compression
maximum_pop_impulse
flight_arc_height_multiplier
maximum_takeoff_course_speed
gravity
air_drag
safe_no_rotation_speed
speed_per_required_rotation
min_rotation_speed
max_rotation_speed
min_rotation_rate
max_rotation_rate
release_warning_time
runout_drag
minimum_runout_speed
crash_completion_delay
```

## File Map

Primary implementation files:

```text
src/game/park/park_course.gd
src/game/park/park_course.tres
src/game/park/park_course_editor.gd
src/game/park/park_course_editor.tscn
src/game/park/rider_run_state.gd
src/game/park/rider_kinematics.gd
src/game/park/jump_state.gd
src/game/park/rider_state.gd
src/game/park/rider_input_frame.gd
src/game/park/rider_tuning.gd
src/game/park/rider_simulation.gd
src/game/park/rider_run_manager.gd
src/presentation/gameplay/course_debug_draw.gd
src/presentation/gameplay/park_projection.gd
src/presentation/gameplay/park_world_presenter.gd
src/presentation/gameplay/rider_view_base.gd
src/presentation/gameplay/gameplay_hud_presenter.gd
src/presentation/attract/how_to_play_screen.gd
```

Tests:

```text
tests/game/park/test_park_course.gd
tests/game/park/test_rider_simulation.gd
tests/game/park/test_rider_simulation.gd
```

## Milestones

### Milestone 1: Landing Path Authoring - Complete

Implementation:

- Added `landing_paths` to `ParkCourse`.
- Added route kinds for two flight routes and one grounded route.
- Added down-course flight landing and continuous ground-join validation.
- Added initial upper, center, and lower landing geometry.
- Extended the visual editor to load and save landing paths.
- Generalized the editor path component to `ParkCoursePath`.
- Added landing-only swept collision queries.
- Extended debug drawing with landing labels, lips, and ground join.
- Added headless course-contract tests.

Acceptance:

- The shipped course validates.
- Upper and center landing paths are independently editable.
- Upper and center landing paths start after their lips.
- Lower landing begins exactly at the lower approach endpoint.
- Swept collision detects explicitly authored landing geometry.
- Existing approach simulation tests continue to pass.

### Milestone 2: Run State Model - Complete

Implementation:

- Added `RunPhase` and `LandingOutcome`.
- Migrated simulation, manager, effects, and rider presentation to the new lifecycle state.
- Removed `MotionPhase`, `ControlMode`, and control-zone state after replacing all references.
- Added setup, crash-status, and reset coverage for both managed riders.
- Kept runtime behavior approach-only during this milestone.

Automated acceptance:

- A new run starts in `APPROACH` with outcome `NONE`.
- Reset restores the same state.
- Existing approach movement remains unchanged.
- No code reads the removed control-mode enum.

Manual acceptance:

- Starting, moving, switching paths, stopping, and restarting look unchanged.

### Milestone 3: Takeoff Transition - Complete

Implementation:

- Promoted `ApproachSimulation` to phase-dispatched `RiderSimulation`.
- Preserved momentum when crossing a flight-route endpoint.
- Captured the frozen route, lip position, final-segment tangent, normal, and takeoff velocity.
- Entered `FLIGHT` instead of stopping on the upper and center routes.
- Transitioned the lower route directly into `LANDING` runout.
- Rejected path changes too close to the lip to finish blending before takeoff.
- Left flight and landing integration paused behind the dispatcher for Milestones 4 and 5.

Automated acceptance:

- A slow rider stalls before a lip.
- A fast upper or center rider crosses the lip and enters `FLIGHT`.
- Velocity is not cleared at takeoff.
- The selected route index is frozen.
- The lower route never enters `FLIGHT`.
- Crossing remains deterministic at different fixed deltas.

Manual acceptance:

- Upper and center riders visibly leave their lips.
- Lower rider stays grounded and enters automatic runout.

### Milestone 4: Basic Ballistics - Complete

Implementation:

- Integrated flight velocity, scaled time, gravity, and non-reversing drag.
- Integrated the unused fraction of the lip-crossing tick as flight time.
- Updated rider projection, speed display, airborne orientation, and landing-path shadows.
- Added flight-aware camera zoom and vertical tracking while keeping landing terrain visible.
- Added horizontal and vertical out-of-bounds guards that resolve a terminal missed-flight crash.
- Kept flight input inert; grabs and rotations remain deferred.

Automated acceptance:

- Flight position matches known fixed-step trajectories.
- Gravity increases downward velocity.
- Air drag never reverses velocity.
- Approach input cannot steer airborne position.

Manual acceptance:

- Both flight routes produce stable, readable arcs.
- The rider remains visible throughout ascent and descent.

### Milestone 5: Landing Contact and Automatic Runout - Complete

Implementation:

- Swept every flight tick against only the frozen route's landing path.
- Resolved the earliest contact exactly once and preserved its measurements.
- Initially classified every valid contact as clean.
- Projected contact velocity onto the landing tangent.
- Continued unused contact-frame time through automatic runout.
- Disabled input and auto-advanced clean landings and the grounded lower route.
- Marked the run `COMPLETE` at the selected landing endpoint.
- Completed missed-flight crashes after a deterministic simulation-owned delay.
- Added an automatic runout handoff when a descending rider falls below the visible center abandon line.
- Added matching shaded warning zones, miss boundaries, and crash-floor lines to `--show-terrain`.
- Added end-to-end clean completion coverage for all three shipped routes at baseline speed.

Automated acceptance:

- High-speed flight cannot tunnel through landing terrain.
- Terrain seams do not resolve contact twice.
- Only the selected landing path can be hit.
- Input does not affect runout.
- Completion occurs once.

Manual acceptance:

- Every route now has a complete start-to-finish loop.

### Milestone 6: Compression and Pop

Implementation:

- Activate compression only within the pre-lip window.
- Charge while X is held.
- Record release timing quality.
- Add pop impulse along the lip normal.
- Auto-release held compression at the lip.

Automated acceptance:

- X outside the window does not charge compression.
- Charge caps at the configured maximum.
- No compression still permits takeoff.
- Ideal release produces the maximum configured pop.
- Held X does not activate a flight grab without a fresh press.

Manual acceptance:

- No-pop, early-release, ideal-release, and held-through-lip arcs are visibly different.

### Milestone 7: Generic Grab Toggle

Implementation:

- Sample fresh presses from `A/B/X/Y/LB/RB` into one toggle event.
- Start or release one generic grab.
- Ignore `LT` and `RT`.
- Drive grab reach and hold presentation.
- Reset grab state at takeoff and run restart.

Automated acceptance:

- Each of the six buttons starts the same generic grab.
- Any of the six buttons releases the active generic grab.
- Simultaneous presses produce one toggle.
- Held approach actions do not trigger a grab after takeoff.
- Grounded button behavior remains unchanged.

Manual acceptance:

- Every action-cluster button produces identical grab behavior and animation.

### Milestone 8: Left-Right Rotation Gesture

Implementation:

- Add the rotation gesture state machine.
- Detect fresh horizontal direction edges.
- Advance authoritative orientation toward half-turn targets.
- Count only finished Left-then-Right pairs.
- Scale rotation rate from takeoff speed.
- Record incomplete rotation on early grab release.

Automated acceptance:

- Right-first does nothing.
- Left completes exactly 180 degrees.
- Right then completes exactly 360 degrees.
- Held directions do not repeat.
- A second pair counts a second rotation.
- Faster takeoff speed completes turns faster.
- Rotation input without an active grab does nothing.

Manual acceptance:

- The gesture feels discrete and readable on the eight-way cabinet stick.

### Milestone 9: Rotation Requirement and HUD

Implementation:

- Calculate required rotations at takeoff.
- Freeze the requirement for the jump.
- Display completed and required counts.
- Add debug output for takeoff speed and rotation rate.

Automated acceptance:

- Speeds below the safe threshold require zero rotations.
- Crossing each configured speed band increases the requirement.
- Requirement does not change during flight.

Manual acceptance:

- The player can understand the requirement immediately after takeoff.
- Initial thresholds are tuned so each flight route has achievable and intentionally unsafe speeds.

### Milestone 10: Release Deadline

Implementation:

- Detect descending crossing of captured lip Y.
- Record whether the grab was active at crossing.
- Mark grabs started after crossing as late.
- Draw the warning line as crossing approaches.
- Do not trigger the deadline at the takeoff frame.

Automated acceptance:

- Ascending passage does not trigger the deadline.
- Descending passage triggers exactly once.
- Release before crossing remains clean-eligible.
- Release after crossing records sketchy eligibility.
- A post-deadline grab is immediately late.

Manual acceptance:

- The warning appears with enough time to react and remains legible over the course.

### Milestone 11: Final Landing Outcomes

Implementation:

- Apply the agreed outcome priority on first contact.
- Add clean celebration, sketchy recovery, and crash behavior.
- Auto-run clean and sketchy outcomes to the endpoint.
- Complete crashes after a simulation-owned timer.
- Ignore animation callbacks for completion logic.

Automated acceptance:

- Still grabbing at contact crashes.
- An incomplete half-turn crashes.
- Missing the required count crashes.
- A late release with enough rotations is sketchy.
- An early release with enough rotations is clean.
- Outcome resolves once and cannot change afterward.

Manual acceptance:

- Every outcome can be reproduced intentionally from controls.
- Animation and simulation outcomes remain synchronized.

### Milestone 12: Completion and Gameplay Polish

Implementation:

- Freeze at `COMPLETE`.
- Show restart instructions.
- Update action hints and the how-to-play screen.
- Finalize flight camera, shadow projection, and effects.
- Add debug trajectory and deadline visualization.
- Run fixed-step and cabinet-input regression passes.

Automated acceptance:

- Completion occurs once.
- Restart clears every jump, grab, rotation, outcome, and presentation field.
- Simulation results match at supported fixed physics rates.
- `just check` passes.

Manual acceptance:

- Complete runs work on all three routes.
- Controls are readable without developer explanation.
- No approach controls leak into flight or landing.
- No flight controls leak into approach or landing.

## Testing Strategy

Every milestone must end with both automated and manual verification before beginning the next milestone.

Standard automated commands:

```sh
just test
just typecheck
just lint-check
just format-check
```

Course tests cover authoring invariants and collision geometry. Rider simulation tests cover deterministic state transitions, fixed-step kinematics, grab toggles, rotation gestures, deadlines, landing outcomes, and completion.

Manual testing should use `--show-terrain` while geometry or collision is changing. Each milestone should be tested on upper, center, and lower routes even when the change primarily targets flight.

## Deferred Work

The following work is intentionally excluded from this implementation sequence:

- Score calculation and multipliers.
- Button-specific grab identities.
- Distinct grab animations.
- Grab-specific timing or difficulty.
- Trick naming and result summaries.
- Multiple rotation directions.
- Free angular torque.
- Tweak, compact, extend, or landing-prep controls.
- Multiplayer input-device separation.
- Final results-screen navigation.

Future distinct grabs can replace the generic toggle with a button-specific grab request. The flight state machine, deadline, landing rules, and rotation gesture do not need to change when that happens.

## Definition of Complete

The gameplay loop is complete when:

- All three approach routes are selectable and finish correctly.
- Upper and center routes launch, fly, accept generic grabs and rotations, resolve landing, and complete.
- Lower route joins automatic grounded runout and completes.
- Takeoff speed controls both rotation rate and required rotation count.
- The release deadline is visible and authoritative.
- Clean, sketchy, and crash outcomes follow the agreed rules.
- Landing input is disabled.
- Restart fully resets the run.
- All automated checks pass.
- Scoring can be added afterward without changing the core simulation state machine.
