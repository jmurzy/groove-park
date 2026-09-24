# HEAVENLY Gameplay Implementation Plan

## Status

Milestones 1 through 8 are complete. Rotation requirements and final landing judgment remain incremental later milestones.

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

- Existing approach movement, speed building, braking, tucking, and path selection remain intact.
- Stick Up and Down select the neighboring authored approach path.
- Moving fully from Right to Up or Down releases downhill input and naturally loses speed.
- Holding Right while pressing Up-Right or Down-Right changes paths without releasing downhill input. This is an intentional, undocumented advanced technique rather than a How to Play instruction.
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
- Holding X through the lip auto-releases the stored compression at takeoff with 70% timing quality.
- A held approach button never activates a grab in flight; grab activation requires a fresh press after takeoff.

### Flight

- Approach controls stop applying immediately at takeoff.
- Flight follows deterministic ballistic movement using captured takeoff velocity, gravity, and air drag.
- The rider cannot steer the flight trajectory after takeoff.
- `A` holds the standard grab.
- `B` holds the tweak-grab variation.
- Releasing the held grab button ends its grab immediately.
- `X`, `Y`, `LB`, and `RB` have no flight role in the initial control set.
- `LT` and `RT` trigger spins. Rotations are available only while either grab is held.

### Rotation Gesture

- A 360 is a horizontal aerial spin represented by authored side-view artwork; it never rotates the rider node in the screen plane.
- Rotations are available only while either grab is held.
- The spin uses same-trigger two-tap gestures with arcade `2X` wording on the How to Play card: `A/B+LT 2X` and `A/B+RT 2X`.
- `LT` selects the left/backside direction: skier-left, snowboarder-backside.
- `RT` selects the right/frontside direction: skier-right, snowboarder-frontside.
- The first fresh trigger press starts an automatic first 180-degree half-turn. Releasing the trigger does not cancel or rewind it.
- The rider holds the dedicated 180-degree pose after the first half-turn completes.
- Both triggers must be released (re-armed) before the second press of the same trigger starts the second automatic 180-degree half-turn. Holding through does not auto-complete.
- `LT, release, LT` completes a left/backside 360. `RT, release, RT` completes a right/frontside 360.
- Pressing the opposite trigger mid-spin is ignored; it neither completes nor cancels the active spin.
- A completed turn returns to that direction set's authored 000-degree pose and counts one 360. The player must release the triggers again before beginning another turn.
- Held triggers do not repeat input, and a new half-turn is accepted only after the previous half-turn reaches its target.
- Releasing the active grab during either moving half-turn freezes the current spin pose and records an incomplete rotation.
- Takeoff speed determines how quickly each half-turn advances. Faster takeoff speed therefore allows more complete rotations before the release deadline.
- Rotations do not modify linear flight velocity or the ballistic trajectory.
- Skier directions are labelled `LEFT` and `RIGHT`. Snowboarder directions are labelled `BACKSIDE` (LT) and `FRONTSIDE` (RT).

### Rotation Artwork

- Each spin set is self-contained with its own authored 000-degree pose. Rotation artwork never reuses the stationary `grab_hold` or `grab_tweak` frames at runtime, and direction sets never share frames with each other.
- Eight direction-specific sets of eight poses each (64 files total). Every set contains authored 000, 045, 090, 135, 180, 225, 270, and 315 degree poses. A completed 360 returns to that set's authored 000-degree pose.
- Each direction plays its own clip forward; reverse playback of another direction's clip is not used.
- The stationary grab clips remain the presentation for an active grab before a spin begins and after it ends. The 000-degree spin poses only need to be visually close to them, not pixel-identical.
- The 180-degree pose is a stable held pose shown while waiting for the re-armed second trigger press.

| Rider | Grab style | Direction set | Authored files |
| --- | --- | --- | --- |
| Skier | Regular | Left | `skier_spin_regular_left_000.png` through `skier_spin_regular_left_315.png`, in 45-degree increments |
| Skier | Regular | Right | `skier_spin_regular_right_000.png` through `skier_spin_regular_right_315.png`, in 45-degree increments |
| Skier | Tweak | Left | `skier_spin_tweak_left_000.png` through `skier_spin_tweak_left_315.png`, in 45-degree increments |
| Skier | Tweak | Right | `skier_spin_tweak_right_000.png` through `skier_spin_tweak_right_315.png`, in 45-degree increments |
| Snowboarder | Regular | Backside | `snowboarder_spin_regular_backside_000.png` through `snowboarder_spin_regular_backside_315.png`, in 45-degree increments |
| Snowboarder | Regular | Frontside | `snowboarder_spin_regular_frontside_000.png` through `snowboarder_spin_regular_frontside_315.png`, in 45-degree increments |
| Snowboarder | Tweak | Backside | `snowboarder_spin_tweak_backside_000.png` through `snowboarder_spin_tweak_backside_315.png`, in 45-degree increments |
| Snowboarder | Tweak | Frontside | `snowboarder_spin_tweak_frontside_000.png` through `snowboarder_spin_tweak_frontside_315.png`, in 45-degree increments |

Pose roles are identical across sets; body mechanics are authored per rider, grab style, and direction:

| Pose | Spin state | Authoring intent |
| ---: | --- | --- |
| 000° | Start / finished 360 | Direction-specific grabbed takeoff-facing pose; entry pose on first press and completion pose at end of second half. |
| 045° | Early first half | Shoulders, hips, and skis or board begin turning into that set's direction. |
| 090° | Quarter turn | Most side-on to the camera; front- or back-facing depends on direction and stance. |
| 135° | Late first half | Continues toward opposite-facing while preserving the grab hand-to-equipment hold. |
| 180° | Half-turn hold | Stable opposite-facing grabbed pose, held until the re-armed second press. Must read as a rest pose. |
| 225° | Early second half | Leaves the held 180° pose toward landing-facing. |
| 270° | Three-quarter turn | Second side-on view; must differ from the 090° pose in body lead, head check, and equipment movement. |
| 315° | Final approach | Spots and squares into the set's own 000° completion pose; must transition seamlessly into it. |

All 64 direction-specific sprites are authored and integrated. The obsolete non-directional spin files have been removed. Future replacements must preserve the shared 1024x1024 canvas, true alpha, stable equipment/pivot anchors, readable 180° holds, and seamless 315°-to-000° transitions defined in `artwork/ARTWORK_BRIEFS.md`.

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
    WAITING_DIRECTION,
    ROTATING_FIRST_HALF,
    WAITING_SECOND_PRESS,
    ROTATING_SECOND_HALF,
}
```

Required fields include:

```text
rotation_gesture_phase
spin_direction
spin_rearmed
spin_progress
rotation_target
rotation_rate
completed_rotations
required_rotations
rotation_incomplete
```

Behavior:

- Holding either grab button arms `WAITING_DIRECTION`.
- A fresh `LT` edge selects direction -1 (left/backside); a fresh `RT` edge selects direction +1 (right/frontside). The first edge starts the first half-turn toward its 180-degree target.
- Spin progress advances toward the target at `rotation_rate`.
- Reaching the half-turn target enters `WAITING_SECOND_PRESS` and holds the 180-degree pose.
- Both triggers must be released (`spin_rearmed`) before a fresh press of the same trigger starts the second half-turn.
- Reaching the full-turn target increments `completed_rotations` and returns to `WAITING_DIRECTION`.
- Releasing both grab buttons stops accepting rotation gestures.
- Releasing the active grab during either rotating state freezes progress and records an incomplete rotation.

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

## Grab State

The initial implementation supports two held grab presentations: the standard A grab and
the B tweak grab.

Required fields:

```text
grab_active
tweak_active
grab_started_airtime
grab_released_airtime
grab_released_after_deadline
```

Input sampling should expose phase-neutral held intents:

```text
grab_pressed
tweak_pressed
```

`grab_pressed` is true while A is held. `tweak_pressed` is true while B is held. Holding
either control enables the same-trigger LT/RT `2X` rotation gesture. `spin_lt_pressed` is
true while LT is held and `spin_rt_pressed` is true while RT is held, with matching
`just_pressed` edge intents for starting each half-turn.

## Presentation Contract

### Rider

- Grounded approach uses existing glide, tuck, compression, and carve animations.
- Early flight uses takeoff extension.
- Flight without a grab uses neutral air.
- A grab uses grab reach and grab hold; B uses the tweak-grab presentation.
- Rotation is presented by selecting frames from the matching direction-specific spin set using authoritative spin progress. The rider node is never rotated for spin.
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
spin_direction
spin_rearmed
spin_progress
rotation_target
rotation_rate
completed_rotations
required_rotations
rotation_incomplete
```

Remove or leave unused old free-torque, compact, and landing-prep concepts until they have an approved gameplay role.

### `RiderInputFrame`

Keep approach intent and add held A-grab and B-tweak-grab intents plus held and edge LT/RT spin intents. Flight reads fresh LT/RT trigger edges for spins but ignores approach movement actions.

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
tests/game/park/test_rider_grabs.gd
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
- Extended debug drawing with landing labels and lips.
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

### Milestone 6: Compression and Pop - Complete

Implementation:

- Activated compression only within the configurable pre-lip window.
- Charged compression while X is held, capped at the configured maximum.
- Recorded release progress and distance-based timing quality.
- Added normalized pop impulse along the authored lip normal.
- Auto-released held compression at the exact lip with 70% timing quality.
- Kept X compression separate from the future B tweak-grab intent.
- Added flashing compression feedback in a second marker below the rider.

Automated acceptance:

- X outside the window does not charge compression.
- Charge caps at the configured maximum.
- No compression still permits takeoff.
- Ideal release produces the maximum configured pop.
- Held-through-lip auto-release preserves charge with reduced timing quality.
- Held X does not activate a flight grab without a fresh press.

Manual acceptance:

- No-pop, early-release, ideal-release, and held-through-lip arcs are visibly different.

### Milestone 7: Held Grabs - Complete

Implementation:

- Sampled A and B as phase-neutral held and fresh-press grab intents.
- Activated standard A grabs through reach and hold presentation states.
- Activated B grabs through the distinct tweak-grab presentation state.
- Released each grab immediately when its corresponding button was released.
- Prevented approach-held buttons and the unused takeoff-tick fraction from activating grabs.
- Reset transient grab state at takeoff and run restart.
- Added a dedicated headless held-grab acceptance suite.

Automated acceptance:

- Holding A starts the standard grab.
- Holding B starts the tweak grab.
- Releasing a held grab button ends its grab.
- Held approach buttons do not trigger a grab after takeoff.
- Grounded button behavior remains unchanged.

Manual acceptance:

- A and B produce distinct, readable grab presentations.

### Milestone 8: Horizontal Spin Gesture and Presentation - Complete

Implementation:

- Replaced screen-plane rider rotation with eight authored direction- and grab-specific horizontal-spin clips.
- Added same-trigger two-tap gestures: `LT, release, LT` spins left/backside; `RT, release, RT` spins right/frontside.
- Selected direction from the initial trigger edge and required both triggers released (re-armed) before the same-trigger second press.
- Ignored the opposite trigger while a spin waits for its second press.
- Advanced authoritative spin progress to half-turn targets at the takeoff-speed-scaled rate.
- Held the dedicated 180-degree pose while waiting for the second input.
- Counted only finished full turns and preserved incomplete rotation after early grab release.
- Kept terrain pitch and ballistic movement independent of horizontal spin progress.
- Migrated How to Play, gameplay simulation, rider views, and automated acceptance coverage.

Automated acceptance:

- `LT, release, LT` and `RT, release, RT` each complete exactly 360 degrees in opposite directions.
- The first half-turn completes and holds at exactly 180 degrees while waiting for the re-armed second press.
- A second press without release does not complete the turn.
- The opposite trigger mid-spin is ignored.
- Held triggers do not repeat.
- A second pair counts a second rotation.
- Faster takeoff speed completes turns faster.
- Rotation input without an active grab does nothing.
- Standard and tweak grabs select their corresponding directional spin clips.
- Rotation input does not change rider pitch or the ballistic trajectory.

Manual acceptance:

- Each tap feels discrete and readable on the cabinet triggers.
- The 180-degree hold and its prompt read clearly before the second tap.

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

Course tests cover authoring invariants and collision geometry. Rider simulation tests cover deterministic state transitions, fixed-step kinematics, held grabs, rotation gestures, deadlines, landing outcomes, and completion.

Manual testing should use `--show-terrain` while geometry or collision is changing. Each milestone should be tested on upper, center, and lower routes even when the change primarily targets flight.

## Deferred Work

The following work is intentionally excluded from this implementation sequence:

- Score calculation and multipliers.
- Additional button-specific grab identities.
- Additional distinct grab animations.
- Grab-specific timing or difficulty.
- Trick naming and result summaries.
- Free angular torque.
- Compact, extend, or landing-prep controls.
- Multiplayer input-device separation.
- Final results-screen navigation.

Future grabs can add button-specific identities without changing the flight state machine,
deadline, landing rules, or rotation gesture.

## Definition of Complete

The gameplay loop is complete when:

- All three approach routes are selectable and finish correctly.
- Upper and center routes launch, fly, accept standard and tweak grabs with rotations, resolve landing, and complete.
- Lower route joins automatic grounded runout and completes.
- Takeoff speed controls both rotation rate and required rotation count.
- The release deadline is visible and authoritative.
- Clean, sketchy, and crash outcomes follow the agreed rules.
- Landing input is disabled.
- Restart fully resets the run.
- All automated checks pass.
- Scoring can be added afterward without changing the core simulation state machine.
