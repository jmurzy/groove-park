# HEAVENLY — Park Game Design

## The pitch

**Build speed. Leave the lip clean. Spin big. Put it down.**

`HEAVENLY PARK` is a 2D arcade ski and snowboard game built around Olympic-scale jumps. One or two players descend the same park line, launch from enormous kickers, perform spins and grabs, and try to land with control. Every run is judged on speed, airtime, rotation, style, and landing quality.

Two players share one screen and one camera. This is a judged event, not a race: crossing the finish first has no value, players do not collide, and each rider receives an independent score. The course and camera are designed to keep both riders visible as they approach and hit each feature together.

The game should be easy to understand from one attempt and difficult to master over many. Holding spin is not enough. Players must choose an approach speed, leave the ramp in balance, manage angular momentum in the air, spot the landing, and stop rotating before touchdown.

The gameplay screen reference is `plans/look-and-feel.png` (relative to this file: `./look-and-feel.png`). The supplied `HEAVENLY / LAKE TAHOE` title, selection, game-screen, and marquee artwork remain the visual source of truth. New park art must look as though it shipped in the same arcade cabinet.

Proposed numbers in this document are playtest starting points, not fixed balance requirements.

## 1. Product identity

- **Game title:** `HEAVENLY`
- **Subtitle:** `LAKE TAHOE`
- **Featured event:** `HEAVENLY PARK`
- **Primary fantasy:** perform huge, clean tricks on an Olympic-scale mountain park
- **Format:** short, replayable arcade score attack
- **Players:** one or two local players on one shared screen
- **Playable riders:** skier and snowboarder
- **Visual authority:** the supplied HEAVENLY reference screens, with the gameplay screen reference at `plans/look-and-feel.png` (`./look-and-feel.png` relative to this file)

`HEAVENLY` owns the title screen, shell, menus, and cabinet presentation. `HEAVENLY PARK` names the event inside that game. Do not replace the established `HEAVENLY / LAKE TAHOE` lockup with an unrelated park logo.

## 2. Design pillars

1. **Takeoff, trick, landing.** Every jump has three meaningful phases. A great score requires all three.
2. **Physics players can learn.** Speed, ramp shape, gravity, rotation, and landing angle behave consistently enough to predict and master.
3. **Big readable air.** Jumps feel enormous, silhouettes remain clear, and the player can read orientation throughout the trick.
4. **Style with control.** More rotation and longer grabs increase potential score, but only when the rider lands the trick.
5. **Shared-screen spectacle.** Two riders can perform together without split-screen, collision, or racing incentives.
6. **Fast arcade rhythm.** A complete run is short, restarts are immediate, and scoring explains itself.
7. **One visual world.** Gameplay, menus, results, and marquee presentation match the supplied HEAVENLY art.

## 3. Player flow

1. The `HEAVENLY / LAKE TAHOE` title screen invites the player to start.
2. The player chooses `1 PLAYER` or `2 PLAYERS`.
3. Each player chooses `SKIER` or `SNOWBOARDER`. The choice changes animation and feel, but neither is allowed a systematic scoring advantage.
4. The game shows `BUILD SPEED  •  SPIN  •  GRAB  •  STICK THE LANDING`.
5. Riders enter a short approach, pass a visible speed check, and hit the first kicker.
6. Each trick is called and scored immediately after landing without obscuring the next approach.
7. A run contains three judged jumps with increasing size and scoring potential.
8. Results show each rider's jump scores, best trick, total score, and highest speed.
9. Players can retry immediately or return to rider selection.
10. After inactivity, the game returns to the title and mountain presentation.

### Event format

- One complete run should last **60–90 seconds**, including short scoring beats.
- A run contains **three jumps**: a forgiving opener, a technical middle jump, and a large final jump.
- Each jump is scored independently out of 10,000 points.
- The event total is the sum of all three jump scores.
- A crash scores zero for that jump but does not end the run.
- In 2P, both riders complete all three jumps and receive separate totals.
- Highest total wins the local session; ties are broken by the higher single-jump score, then better combined landing quality.
- Results presentation may name a winner, but gameplay never rewards reaching a jump or finish line first.

## 4. Perspective and shared camera

### 2D gameplay view

Use a side-on 2D profile of the slope. Terrain forms a readable line from the upper-left approach toward the lower-right landing. This view makes launch speed, jump arc, rider rotation, and landing alignment visible at a glance.

The rider and equipment must have a clear long axis so players can judge whether the skis or board will meet the landing surface correctly. Shadows may help communicate height but must never substitute for a readable rider silhouette.

### Shared-screen camera

One camera contains both riders. There is no split view in any mode.

- Keep the complete active feature visible: approach, lip, flight path, and landing.
- Frame both riders with a modest safe margin and zoom out gently when they separate.
- Use authored camera zones for each jump so zoom and pan are predictable.
- Favor the airborne rider and landing visibility over showing distant scenery.
- Never zoom so far out that rider orientation or grabs become unreadable.
- Do not tether riders with visible force, rubber-band their physics, or change a rider's score because of camera position.
- Disable rider-to-rider collision so overlapping lines cannot cause griefing.

The course keeps players naturally together through short staging gates before each jump. When both riders enter a staging zone, a brief shared count-in releases them onto parallel approach lanes. If one rider arrives first, that rider can carve in a broad waiting lane without scoring penalty. After a crash, the rider recovers at the next staging zone while the other player's result resolves.

The two lanes use identical ramp and landing geometry. They are separated visually by flags and track marks but occupy the same camera view. Lane choice must not affect scoring potential.

## 5. Controls

### Cabinet controls

| Input | Ground action | Air action |
| --- | --- | --- |
| Joystick left / right | Carve and adjust approach speed | Rotate backward / forward |
| Hold A | Tuck for speed | Grab and stabilize the current trick |
| Hold B | Check speed / brake | Spot landing and reduce rotation |
| Down + A near lip | Compress for a stronger pop | — |
| Release Down at lip | Extend and pop | — |
| Start | Pause / resume the full session | Pause / resume the full session |
| Existing cabinet exit inputs | Preserve Escape and two-second Start + Back hold | Same |

The controls must work with a digital arcade stick. Analog support is optional and must not create a scoring advantage. Provide independent keyboard mappings for P1 and P2 during development.

If A and B are held together in the air, landing preparation wins: the grab releases and rotation damping begins. Inputs are buffered for a short, visible window around takeoff so a player is not punished by one simulation tick.

### Control goals

- A first-time player can tuck, rotate once, release, and land the first jump.
- Skilled players use carving, pop timing, delayed rotation, grabs, and early spotting to improve scores.
- The game never performs an unrequested trick automatically.
- Rotation controls remain responsive without allowing instant starts, stops, or reversals.
- Skiers and snowboarders use the same control grammar.

## 6. Physics model

Physics quality is the core production risk. Build and tune the movement sandbox before producing the full course or trick catalog.

### Ground movement

Represent each rider with position, linear velocity, orientation, angular velocity, grounded state, and contact information. While grounded, movement follows the terrain tangent rather than a fixed screen axis.

- Gravity accelerates the rider down the local slope.
- Tucking reduces drag and keeps the rider aligned for maximum speed.
- Carving redirects velocity and adds controllable speed loss based on carve strength.
- Braking increases drag progressively; it must not set speed directly.
- Rolling resistance remains light and stable across simulation rates.
- Ground contact follows smooth terrain without gluing the rider to sharp convex crests.
- The rider leaves the surface when momentum carries them away from it or when they pop from the lip.
- The approach speed shown in the HUD comes from physical velocity, not animation or scroll speed.

### Takeoff

Takeoff determines the quality and shape of the entire trick.

- Preserve the rider's physical velocity across the lip.
- Ramp tangent and current speed establish the base launch vector.
- A timed compression and extension adds a bounded impulse along the ramp normal.
- Releasing too early gives a weak pop; releasing near the lip gives maximum pop; releasing late reduces balance and may cause an off-axis takeoff.
- Carving hard on the lip transfers some input into angular velocity and lowers takeoff quality.
- Ramp collision must use continuous or swept detection so high-speed riders cannot tunnel through the lip.
- No hidden launch animation may override a valid physical trajectory.

### Flight

Once airborne, the trajectory is primarily ballistic.

- Gravity affects linear velocity every fixed simulation step.
- Use modest, consistent air drag only if needed to keep jump distances within authored bounds.
- Left and right apply bounded torque rather than setting rider angle directly.
- Angular acceleration, maximum angular velocity, and rotational damping are explicit tuning values.
- Reversing a spin requires overcoming existing angular momentum.
- Holding a grab modestly reduces control authority and can slightly conserve rotation, creating a real commitment.
- Holding landing preparation increases angular damping but cannot snap the rider upright.
- Rider animation follows the physics orientation. It does not drive the body transform.

### Landing

Landing quality is determined at first meaningful contact with the landing surface.

Compare the rider's equipment axis and velocity to the local landing tangent:

- **Perfect:** small angle error, velocity directed along the slope, low excess angular velocity, and stable contact.
- **Clean:** moderate angle error that can be absorbed without a hand or body touch.
- **Sketchy:** large but recoverable angle error, strong compression, hand drag, or significant sideways velocity.
- **Crash:** body-first contact, excessive angle error, excessive angular velocity, or landing outside the valid zone.

Suggested initial thresholds:

| Result | Equipment-to-slope error | Excess angular speed | Score effect |
| --- | --- | --- | --- |
| Perfect | 0–8° | Very low | 1.15× landing multiplier |
| Clean | 9–20° | Low | 1.00× landing multiplier |
| Sketchy | 21–35° | Moderate | 0.55–0.80× multiplier |
| Crash | Above 35° or body contact | High | Zero for the jump |

Thresholds should be continuous around their boundaries. Avoid a one-degree difference producing a wildly different result. The final implementation may use a blended quality curve while retaining these labels for player feedback.

On a successful landing, absorb impact over a short suspension/compression phase and return control smoothly. Do not bounce a good landing because of a single-point collision seam. On a crash, resolve one clear failure, remove scoring control, and recover quickly at the next safe point.

### Simulation requirements

- Run gameplay physics at a fixed timestep independent of rendering.
- Keep world position and velocity authoritative; camera movement is presentation only.
- Use continuous collision detection or swept tests for fast riders and thin ramp surfaces.
- Build terrain collision from smooth joined segments with stable normals.
- Separate visual sprite bounds from board/ski, body, and ground-contact shapes.
- Record deterministic-enough input and state traces for repeatable physics debugging.
- Add a debug overlay for velocity, speed, trajectory prediction, ground normal, takeoff point, angle error, and angular velocity.
- Test at low and high render rates and confirm the same input trace produces materially equivalent results.

## 7. Trick system

The first release focuses on readable rotations and grabs rather than a large move list.

### Rotations

In the side view, a full 360-degree body rotation counts as one spin. Direction is called as `FORWARD` or `BACKWARD` to keep the move understandable from the cabinet.

- Count only completed rotations at landing.
- Partial rotation contributes risk but no full-spin base points.
- One, two, and three rotations should be achievable on progressively larger jumps.
- Four or more rotations may be possible on the final jump only after tuning confirms they remain readable and landable.
- Direction changes during one flight are allowed but cost time and angular control.
- Do not award repeated input taps; score the measured physical rotation.

### Grabs

Holding A while airborne initiates a grab when the rider is in a valid pose. The grab ends when A is released or landing preparation begins.

- Longer held grabs earn more style value up to a cap.
- A grab must be established for a minimum duration to count.
- Grabbing reduces rotation correction, making timing meaningful.
- Releasing before landing avoids a landing penalty.
- The first release may use one clearly animated signature grab per rider type.
- Additional named grabs can be added only when their silhouettes are readable at gameplay scale.

### Rider parity

The skier and snowboarder may differ slightly in animation, rotational inertia, carve feel, and grab pose. Their complete score potential must remain equivalent. If physical differences create mode-leading advantages, normalize them or use shared competitive physics with presentation-only distinctions.

## 8. Scoring

Scores should reward ambition only when the rider demonstrates control.

### Jump score components

| Component | Measures | Purpose |
| --- | --- | --- |
| Approach | speed entering the takeoff zone | rewards confident setup |
| Takeoff | pop timing, balance, and lip position | rewards precision before flight |
| Airtime | time clearly airborne, capped per feature | celebrates jump scale |
| Rotation | completed physical spins and direction | provides the main difficulty value |
| Grab | valid grab duration and release timing | rewards style and commitment |
| Landing | angle, velocity alignment, and angular control | determines whether the trick was completed |

Use an additive trick value followed by a landing multiplier. A crash always reduces the final jump score to zero. Speed and airtime must be capped by the authored feature so exploits cannot dominate normal trick play.

Suggested conceptual formula:

```text
base = approach + takeoff + airtime + rotation + grab
jump_score = base × landing_multiplier × variety_multiplier
```

### Scoring rules

- Show the trick call, completed spins, grab, landing label, and total points after each jump.
- Never award rotation based only on button hold duration.
- A faster approach improves score modestly but mainly creates more distance and airtime for harder tricks.
- Perfect landings are valuable but cannot make a trivial straight air outscore a clean difficult trick.
- Crashed difficulty does not earn consolation trick points.
- Repeating the identical trick across all three jumps applies a small variety reduction after the first repeat.
- Do not use opaque random judge scores.
- Keep all judging deterministic from recorded gameplay state.

Example calls:

- `FORWARD 360  •  CLEAN  •  4,280`
- `BACKWARD 720 + GRAB  •  PERFECT  •  7,940`
- `1080 ATTEMPT  •  CRASH  •  0`

## 9. Course design

The first course is one authored park line with three features.

### Jump 1 — Timberline

- Wide approach and gentle table jump.
- Teaches tuck, pop, one rotation, and landing preparation.
- A straight air lands safely at moderate speed.
- Overshooting is possible only at extreme speed.

### Jump 2 — Sky Gap

- Longer approach with a shallow carve section.
- Requires deliberate speed choice to clear the knuckle.
- Supports one strong grab or two controlled rotations.
- Landing is steeper, making alignment more important.

### Jump 3 — Heavenly Flight

- Olympic-scale final kicker with the longest visible flight.
- Broad, clearly marked speed check before the lip.
- Supports the run's highest rotation and airtime values.
- Uses a long landing zone so advanced attempts fail from rider control, not arbitrary precision.
- Receives the strongest crowd, audio, and marquee presentation.

### Course rules

- Keep approach surfaces smooth enough that small collision seams never alter a run.
- Mark ideal speed bands visually without drawing an exact racing line.
- Show jump knuckles, landing slopes, and out-of-bounds areas clearly.
- Use flags, pines, lift towers, and Tahoe scenery as landmarks outside collision-critical silhouettes.
- Provide parallel identical lanes in 2P and center a solo rider between them in 1P.
- Do not place random obstacles on judged approaches.
- Keep weather visual only in ranked play.

## 10. Multiplayer

Two-player mode is simultaneous shared-screen score attack.

- Players use independent controls, riders, physics state, and scores.
- Riders occupy parallel lanes with identical geometry.
- Riders have no collision or drafting effect.
- A shared count-in begins each approach.
- Early movement may animate, but the scoring approach begins from the same gate for both players.
- If one player crashes, the other player completes the jump without interruption.
- The next staging gate waits briefly for both riders, then recovers any missing rider automatically.
- No speed rubber-banding, forced matching, or score handicap occurs during a competitive run.
- The camera may zoom to contain both riders but never modifies their trajectories.
- Player identity remains obvious through palette, lane markers, labels, and landing score panels.

The result is two athletes performing in the same event, not racing for track position. The exciting multiplayer moment is seeing both riders airborne at once, choosing different tricks, and waiting for the landing scores.

## 11. Visual and audio direction

### Visual source of truth

Match the supplied HEAVENLY reference screens — gameplay screen: `plans/look-and-feel.png` (`./look-and-feel.png` relative to this file) — for pixel density, palette, typography, framing, mountain scenery, snow treatment, characters, and cabinet-era presentation.

- Use native pixel-art sprites and backgrounds, not smooth vector or painted approximations.
- Author at one low internal resolution and scale by integer multiples with nearest-neighbor filtering.
- Snap sprites and UI to the pixel grid when grounded; preserve smooth enough physics sampling for airborne movement without visible shimmer.
- Keep rider silhouettes and equipment readable through every rotation.
- Use compact snow spray at takeoff and landing; effects must not hide orientation or contact.
- Do not bake scanlines or CRT effects into individual assets.

### Primary display: 1920 × 1080

- Keep the supplied arcade framing on title, selection, pause, and results screens.
- Gameplay may use a lighter edge treatment to maximize the visible jump profile.
- Persistent HUD: player label, speed, current jump, total score, and compact rotation indicator.
- Temporary jump result: trick call, landing quality, and points near that player's side of the screen.
- Keep all UI out of the predicted flight and landing corridor.
- In 2P, use a shared event header and mirrored player score blocks without dividing the world view.

### Optional marquee: 1920 × 360

- Attract mode shows the HEAVENLY mountain identity and park event.
- During a run, show jump number, P1/P2 totals, and the latest trick calls.
- On the final jump, shift to a dedicated wide big-air composition.
- Results show the winner and best trick without becoming necessary to understand the primary display.

### Sound

- Ski hiss rises with speed; carving and braking have distinct snow sounds.
- Tucking adds a subtle wind cue.
- Light and heavy impacts sound clearly different.
- Wind intensity follows physical speed.
- Skis and snowboard have distinct but equally readable carve and brake sounds.
- Compression, lip release, grab lock, landing compression, and crash each have clear cues.
- Crowd response follows trick difficulty and landing quality, never unlanded rotation alone.
- Music drops back briefly during flight and hits on landing without changing gameplay timing.
- Keep announcer calls short: trick name, landing result, new best, and event winner.

## 12. Modes and replayability

### First release

1. **Practice:** one player selects any jump with immediate retry, trajectory tools optional.
2. **Solo Event:** three-jump score attack with local records.
3. **Two-Player Event:** simultaneous shared-screen score attack.
4. **Local records:** total score, best single jump, highest completed rotation, rider type, and rules version.

### Later possibilities

- Additional park lines with different ramp shapes and landing demands.
- More grabs and switch-stance scoring.
- Daily fixed-condition challenge with rules versioning.
- Cooperative team score where both riders must land complementary tricks.
- Replay ghosts or synchronized highlight replays.
- Online leaderboards after validation and deterministic scoring are proven.

Do not add rails, halfpipe, procedural jumps, equipment upgrades, or online competition before the core big-air physics is satisfying.

## 13. First playable milestone

**Goal: prove that accelerating, launching, rotating, and landing one large jump feels fair and worth repeating.**

### Included

- One skier and one snowboarder with reference-matched placeholder or approved pixel art.
- One full approach, kicker, flight, and landing profile.
- Tuck, carve, brake, timed pop, physical rotation, landing preparation, and crash recovery.
- Fixed-timestep physics and high-speed collision protection.
- One valid grab per rider type.
- Speed, airtime, completed rotation, and landing-quality scoring.
- Solo full-screen play and two-player shared-screen play on parallel lanes.
- Shared camera framing with both riders airborne at different heights and speeds.
- Immediate restart and a compact jump result.
- Physics debug overlay and repeatable input traces.

### Deferred

The complete three-jump event, additional tricks, advanced stance rules, rails, halfpipe, online records, dynamic weather, equipment stats, progression, and cosmetic unlocks.

### Implementation sequence

1. **Physics sandbox:** build smooth terrain, acceleration, carving, braking, takeoff, ballistic flight, rotation, and landing contact using debug shapes.
2. **Landing truth:** classify perfect, clean, sketchy, and crash outcomes from measurable contact state; test boundary continuity.
3. **Camera proof:** frame one and two riders across the complete jump without split-screen or unreadable zoom.
4. **Control pass:** tune pop timing, torque, damping, grab commitment, and landing preparation for digital controls.
5. **Scoring pass:** derive transparent scores from recorded physics and display a concise result breakdown.
6. **Shared-screen session:** add staging, parallel lanes, independent outcomes, recovery, and session results.
7. **Course expansion:** build and tune the three-jump line only after the prototype jump is consistently fun.
8. **Presentation pass:** replace placeholders, add sound, crowd response, marquee states, and cabinet polish.

### Acceptance checks

- The same approach speed and takeoff input produce predictably similar trajectories.
- A faster approach visibly travels farther and creates more airtime without hidden assistance.
- A well-timed pop is distinguishable from early, late, or absent pop.
- Rotation begins and ends through torque and damping, never angle snapping.
- Players can explain why they landed, landed sketchily, or crashed.
- Landing labels vary smoothly near their thresholds and do not flicker from collision seams.
- A completed rotation is measured from physical orientation, not inferred from input.
- A basic trick is accessible, while a high-rotation grab requires speed, timing, and early landing preparation.
- Skier and snowboarder have equivalent top-level scoring potential.
- Two riders can take off, trick, and land independently on one screen without collision.
- The shared camera never makes either player's orientation unreadable during valid play.
- A crashed player cannot interrupt or obscure the other player's scoring attempt.
- No advantage is awarded for reaching the finish first.
- Simulation outcomes remain materially consistent across supported frame rates.
- Gameplay remains smooth at the existing 1080p / 75 Hz primary target while the marquee is active.
- Every screen and asset looks native to the supplied HEAVENLY references.

## 14. Implementation boundaries

Use the project's established Godot/GDScript architecture. Keep simulation, judging, and presentation separate.

- **Park session:** phase, mode, jump index, rules version, per-player score, total, and result.
- **Rider controller:** input mapping, grounded/airborne state, movement forces, angular state, and recovery.
- **Terrain:** authored profile, smooth collision geometry, staging zones, takeoff zone, landing zone, and safe recovery points.
- **Trick tracker:** cumulative signed rotation, completed rotations, grab state, and trick validity.
- **Judge:** approach, takeoff, airtime, rotation, grab, landing measurements, and deterministic score breakdown.
- **Shared camera:** authored feature bounds plus dynamic two-rider containment within readability limits.
- **Presenters:** gameplay world, HUD, results, effects, and optional marquee, all driven from session state.

Suggested phases are `attract → select → staging → approach → airborne → landed/crashed → score → staging`, followed by `results` after jump three. Each player can move through airborne and landing substates independently while the shared session controls staging and transition timing.

Keep scoring based on simulation state, not sprite frames. Keep terrain and rider coordinates in world space. Keep camera scroll and zoom purely presentational. Store records only for completed events and include course, physics, and scoring versions so incompatible scores are not compared.

## 15. AI-generated asset briefs

### Reference rule for every generation

Attach the supplied HEAVENLY game-screen reference image (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file) to every generation request.

> Match the attached game-screen reference exactly. The new asset must look native to that game, not like an interpretation of it. Do not add text, logos, watermarks, UI, or a background unless requested. Preserve true transparency for isolated assets. Do not bake scanlines or CRT effects into isolated sprites; the game applies those globally.

Generate one approval sample before each complete set. Keep approved rider design, side-view camera, scale, palette, pixel density, lighting, outlines, and equipment anchors consistent across later generations.

### Priority 1 — riders

**Asset: `heavenly_park_skier_pose_set`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create one side-view freestyle skier in gameplay poses: neutral glide, tuck, carve uphill, carve downhill, compression, takeoff extension, neutral air, grab, landing preparation, deep landing compression, sketchy recovery, crash, and celebration. Keep the same character, skis, scale, and body anchors in every pose. Deliver separate transparent pixel-art PNGs on a shared grid. No snow, shadow, text, UI, background, scanlines, or CRT effect.

**Asset: `heavenly_park_snowboarder_pose_set`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create one side-view freestyle snowboarder matching the skier set's scale and poses: neutral glide, tuck, heel/toe carve variants, compression, takeoff extension, neutral air, grab, landing preparation, deep landing compression, sketchy recovery, crash, and celebration. Keep board and body anchors consistent. Deliver separate transparent pixel-art PNGs on a shared grid. No snow, shadow, text, UI, background, scanlines, or CRT effect.

### Priority 2 — park

**Asset: `heavenly_big_air_course_set`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create modular side-view pixel-art snow terrain for three big-air features: a forgiving table jump, a long technical gap, and an Olympic-scale final kicker. Include separate approach, lip, knuckle, landing, and runout pieces with quiet snow texture and readable edges. Deliver tile-compatible PNG layers without riders, crowds, logos, text, UI, collision guides, scanlines, or CRT effect.

**Asset: `heavenly_park_dressing_set`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create side-view park flags, lane markers, pines, distant lift towers, safety fencing, a compact spectator group, and unbranded score structures. Deliver separate transparent pixel-art PNGs. Keep collision-critical terrain unobscured. No text, logos, riders, UI, scanlines, or CRT effect.

### Priority 3 — effects and results

**Asset: `heavenly_park_fx_set`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create short transparent pixel-art animation sequences for carve spray, hard braking spray, takeoff burst, perfect landing spray, sketchy landing spray, and crash plume. Keep every effect compact enough that rider orientation and equipment contact remain visible. No rider, terrain, text, background, scanlines, or CRT effect.

**Asset: `heavenly_park_results_scene`**

> Using the attached HEAVENLY game-screen reference (`plans/look-and-feel.png`, or `./look-and-feel.png` relative to this file), create a 16:9 pixel-art results background showing the final big-air landing area at Lake Tahoe with a skier and snowboarder celebrating together. Leave the center-right visually quiet for runtime scores. No baked-in text, numbers, logos, medals, UI panels, scanlines, or CRT effect.

### Asset acceptance

- Approve one rider rotating over one jump in the actual camera before generating complete pose sets.
- Confirm skis and snowboard remain readable at every 90-degree orientation.
- Confirm rider anchors do not wobble when animation frames change.
- Reject art that hides the lip, landing tangent, equipment, or rider orientation.
- Reject art that shares only a general winter theme rather than the supplied HEAVENLY style.
- Check transparency, pixel grid, scale, palette, outlines, and nearest-neighbor scaling in-engine.
- Build collision geometry, score text, trajectory tools, shadows, and changing UI in-engine.

## 16. Playtest questions

1. Can a new player land a simple trick within three attempts?
2. Can players predict jump distance from approach speed?
3. Does the lip feel like physical terrain rather than a scripted launch trigger?
4. Can players read rotation and know when to prepare for landing?
5. Do crashes feel attributable to speed, angle, or rotation rather than collision noise?
6. Does a grab create a meaningful control tradeoff?
7. Are difficult landed tricks reliably worth more than safe straight airs?
8. Can both players follow their riders and scores without a split screen?
9. Does staging keep two players together without feeling like rubber-banding?
10. Are skier and snowboarder equally viable at expert score levels?
11. Is a three-jump run short enough to demand an immediate retry?
12. Does the final jump feel substantially bigger without requiring different controls?
13. Does the game preserve the identity of the supplied HEAVENLY screens?

**The first milestone succeeds when a player crashes, immediately understands the needed correction, and presses Start to try the jump again.**
