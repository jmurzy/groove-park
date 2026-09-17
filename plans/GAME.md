# HEAVENLY — Game Design

## The pitch

**25 laps. One legendary run. How fast can you finish with your body still intact?**

HEAVENLY is a retro arcade ski game set at Lake Tahoe. Its featured event, **GUNBARREL 25**, sends the player down Heavenly's mogul-packed Gunbarrel run 25 times. The player threads between bumps, manages speed, and decides when to attack and when to protect an increasingly battered skier.

Going faster saves time, but leaves less room to turn and makes every impact more dangerous. Braking is a racing skill. The fastest player reads the mountain and chooses a sustainable line instead of simply holding the accelerator.

The supplied title, run-selection, and marquee images are the visual source of truth for the game. New screens and generated artwork must look as though they shipped in the same arcade game.

Single-player is the complete first-release experience. The design may support competitive modes later, but they are not required to prove the core game.

Proposed numbers in this document are playtest starting points, not fixed balance requirements.

## 1. Product identity

- **Game title:** `HEAVENLY`
- **Subtitle:** `LAKE TAHOE`
- **Featured event:** `GUNBARREL 25`
- **Primary fantasy:** survive and master 25 descents of one famous run
- **Format:** immediate, cabinet-friendly arcade racing
- **Visual authority:** the supplied reference screens

`HEAVENLY` owns the title screen, shell, menus, and cabinet presentation. `GUNBARREL 25` names the event inside that game. Do not replace the main `HEAVENLY / LAKE TAHOE` lockup with a separate Gunbarrel logo.

## 2. Design pillars

1. **Readable danger.** Players see a hazard early enough to respond. Sprites, shadows, and collision boundaries must be trustworthy.
2. **Speed versus survival.** Speed improves a run but raises the cost of mistakes. Slowing down must clearly improve control.
3. **Skill over surprises.** Learnable terrain, consistent movement, and predictable collisions reward practice.
4. **An endurance story.** Every descent contributes to one 25-lap attempt. A bad opening can become a comeback; a reckless sprint can become a struggle to finish.
5. **Immediate arcade appeal.** One stick, two action buttons, one short prompt, and an obvious objective.
6. **One visual world.** Gameplay, menus, results, and the marquee must match the supplied HEAVENLY screens.

## 3. Player flow

1. The `HEAVENLY / LAKE TAHOE` title screen invites the player to start.
2. The player chooses **GUNBARREL 25** or **PRACTICE RUN**.
3. The game shows `STEER  •  A TUCK  •  B BRAKE  •  FINISH 25 LAPS`.
4. The player descends through the moguls, balancing pace, line choice, and injury risk.
5. Crossing the finish gate shows the lap split, cumulative time, and condition.
6. A short automatic lift-return transition resets the slope for the next lap.
7. The attempt ends after lap 25 or when condition reaches zero.
8. Results show the run summary and collect initials for a qualifying local record.
9. After inactivity, the game returns to the title and mountain presentation.

The run-selection screen should use the same composition and interaction language as the supplied selection reference. Do not show unavailable multiplayer choices in the first release; use the established card treatment for the two playable solo modes.

### Event timing

- Target **35–50 seconds per descent** at a competent pace, or roughly **16–23 minutes** for the full event including transitions.
- Practice is one complete descent with immediate retry and identical handling rules.
- Race time includes active descent time and crash recovery.
- Countdowns, results, and lift-return transitions do not add race time.
- Use a 2–3 second skippable lap transition. Skipping presentation must not alter race time.
- Show `LAP 01 / 25` on the first descent. Increment completed laps only after crossing the finish gate.
- Completing lap 25 ends the event immediately.
- A DNF records completed laps and distance through the current lap, but never outranks a finisher.

## 4. Controls and handling

### Cabinet controls

| Input | Action |
| --- | --- |
| Joystick left / right | Steer across the slope |
| Hold A | Tuck and accelerate toward maximum downhill speed |
| Hold B | Brake and gain tighter turning control |
| Release A and B | Coast toward a moderate downhill speed |
| Start during a solo race | Pause / resume |
| Existing cabinet exit inputs | Preserve Escape and the two-second Start + Back hold |

If A and B are held together, braking wins. Movement must work with a digital arcade stick; analog input is optional. Provide matching keyboard controls for development and desktop play. Forward and backward stick movement have no required gameplay action in the first release.

### Movement model

- The skier moves downhill continuously. There is no reverse movement or stationary hiding.
- Acceleration and braking are gradual and communicate momentum.
- Low speed allows quick, tight turns.
- High speed increases turning radius without adding artificial input delay.
- Braking reduces speed while improving the ability to change direction.
- Lateral velocity stays bounded and predictable. Avoid instant reversals or sideways snapping.
- Communicate speed through animation, ski spray, scrolling, audio, and a compact HUD meter.
- Any displayed speed is arcade tuning, not a simulation claim.

### Camera

Use an elevated three-quarter downhill view with the skier in the lower third and terrain moving toward the bottom of the screen. Match the skier proportions and pixel treatment of the supplied game-screen reference while adapting the character to this gameplay camera.

Keep enough terrain visible for a meaningful decision at maximum speed. Increase look-ahead gently with speed. Avoid camera rotation, fast zooms, and strong shake. Keep the full playable corridor visible horizontally.

## 5. Course and hazards

Moguls are the primary obstacle. Trees, rocks, course markers, snowbanks, and occasional park features make course sections memorable without competing with the racing line.

- **Small moguls:** forgive a light brush but interrupt rhythm.
- **Large moguls:** require a deliberate side and punish direct high-speed hits.
- **Mogul clusters:** create alternating lines and occasional narrow shortcuts.
- **Open lanes:** provide breathing room and acceleration opportunities.
- **Trees and rocks:** identify sections and narrow the corridor only where the route remains clear.
- **Park features:** provide optional risk/reward landmarks. In the first release, rails and boxes are solid obstacles rather than trick systems.

The first playable build may use one mogul type with varied placement. Add variants only after handling is fun.

### Course design

- Begin with a gentle entry that teaches steering.
- Alternate staggered bumps, offset channels, a dense technical section, and a fast finish.
- Provide at least one reasonably safe route through every section.
- Let riskier routes save distance or preserve more speed.
- Keep authored landmarks in repeatable positions so players can learn the course.
- Keep trees near course edges or in visible islands with generous escape routes.
- Never hide a collision boundary behind foliage, effects, UI, or the camera angle.
- Use park features as short optional sections with visible approaches, landings, and bypasses.
- Keep obstacles out of start and finish recovery zones.
- Snowbank contact slows and nudges the skier inward without trapping them.
- Decorative objects remain outside the playable corridor.
- Make the finish gate span the corridor so it cannot be missed accidentally.

### Collision contract

- Use a small, consistent contact footprint around the skis and body, not the full sprite or shadow.
- Keep collision footprints within the visible solid silhouette.
- Judge severity from impact speed and directness.
- Resolve each impact once; sustained overlap cannot repeatedly drain condition.
- During tumble recovery, keep race time running and temporarily disable additional damage.
- Recover the player into a safe nearby lane at reduced speed.
- Provide a short visible grace period and clear overlapping contacts before collisions resume.
- Prevent fast movement from tunneling through obstacles between simulation steps.

## 6. Condition and recovery

Use one readable `CONDITION` meter starting at 100. Damage appears through arcade reactions, animation, sound, and HUD feedback rather than graphic injury.

### Initial impact tuning

| Impact | Immediate consequence | Suggested condition loss |
| --- | --- | --- |
| Slow brush | Small speed loss and snow puff | 0–2 |
| Moderate hit | Noticeable slowdown and brief wobble | 4–8 |
| Fast direct hit | Tumble, major slowdown, and recovery time | 12–20 |

Interpolate severity so tiny speed differences do not produce radically different outcomes.

### Condition states

| Condition | State | Effect |
| --- | --- | --- |
| 70–100 | Fresh | Normal performance |
| 35–69 | Battered | Visible wear; slightly reduced acceleration |
| 1–34 | Hurting | Strong warning; modestly reduced maximum speed |
| 0 | Retired | End the attempt with a DNF |

Condition persists across laps. Preserve braking and steering authority so damage changes tactics without making the next crash inevitable. Initially cap the total performance penalty around 15%.

### Recovery choice — after the core prototype

After laps 5, 10, 15, and 20, offer `KEEP GOING` or `RECOVER`. Recovery restores 20 condition, up to the maximum, and immediately adds a visible 15-second service penalty. Do not make the player wait through the penalty.

Offer recovery once per checkpoint and default to continuing after a short selection window. Balance it so intentional crashing is never the fastest strategy. Omit recovery stops from the first playable milestone.

## 7. The 25-lap challenge

The event is about learning one legendary slope, not surviving 25 unrelated maps.

- Repeat one authored course for all 25 laps.
- Keep terrain stable so players can memorize and improve a line.
- Let damage and the clock create pressure before adding new difficulty systems.
- Celebrate laps 5, 10, 15, and 20 with brief callouts that do not hide terrain.
- Mark lap 25 with a short audio cue and `FINAL LAP` treatment.
- Finish immediately after the final gate crossing.

Later versions may add authored variants or seeded daily races. Competitive records must include course and rules versions. Weather and lighting may vary presentation, but ranked visibility and traction remain consistent. Live resort status must never alter race rules.

## 8. Racing and replayability

### First-release priorities

1. **Practice Run:** learn one descent and chase a best lap.
2. **Gunbarrel 25:** finish all 25 laps with the fastest total time.
3. **Local records:** separate practice laps and full-event times; show initials, time, and finish condition.

For finishers, lower total time wins. Remaining condition breaks equal recorded times. Store DNF progress separately.

Award presentation-only accolades such as `CLEAN LAP`, `NO FALLS`, and `IRON LEGS`. Do not hide time bonuses behind them.

### Later features

- **Personal-best ghost:** replay recorded movement as a non-colliding racer with split deltas.
- **Pass-the-cabinet challenge:** run the same course and compare results locally.
- **Two-player racing:** investigate only after solo handling and shared-screen readability are proven.
- **Daily race and online records:** add only with course versioning, validation, and offline behavior.

Do not add skier-to-skier collision to the first competitive version.

## 9. Visual and cabinet direction

### Visual source of truth

The supplied reference images define the finished look. Match them for all new artwork and interface work. If written guidance conflicts with a reference image, the image wins unless gameplay readability or technical output requirements would be harmed.

The visual system must preserve:

- native pixel-art forms and animation rather than smooth vector or painted rendering;
- the established `HEAVENLY / LAKE TAHOE` logo lockup;
- the same screen frame, panel construction, selection states, typography, icon language, and information density;
- the same approach to skier proportions, mountain scenery, snow, trees, gondolas, and weather effects;
- the same arcade-era treatment across the primary screen and ultrawide marquee.

Do not reinterpret the references as modern flat UI, mobile cards, glossy 3D art, painterly concept art, or high-resolution cel shading. Do not mix pixel art with smooth vector icons or unrelated fonts.

### Pixel-art pipeline

- Author screens at one agreed low internal resolution and scale by integer multiples with nearest-neighbor filtering.
- Keep sprite pixel density consistent with the supplied game-screen reference.
- Disable texture filtering, mipmap blur, and subpixel sprite placement.
- Snap screen-space art and UI to the internal pixel grid.
- Apply scanlines and any CRT treatment once as a controlled full-screen effect, not baked independently into gameplay sprites.
- Test moving sprites at cabinet resolution to catch shimmer, uneven scaling, and unreadable one-pixel details.
- Use runtime text for changing labels and numbers. Preserve the reference typography through an approved pixel font or purpose-built bitmap glyph set.

### Primary display: 1920 × 1080

- Keep the supplied arcade border visible on title, selection, pause, and results screens.
- During play, use a lighter gameplay frame or edge treatment only if the full border reduces the readable course area.
- Persistent HUD: lap, total time, speed, and condition.
- Secondary feedback: lap time, best lap, and brief split callouts.
- Use the reference panel and type treatments for prompts, warnings, and results.
- Keep the upcoming racing line free of large text, particles, and panels.
- Results include completed laps, total time, best lap, crashes, remaining condition, and personal-best status.

### Optional marquee: 1920 × 360

- Match the supplied marquee reference image.
- Attract mode shows the mountain identity and live lift-status presentation.
- Racing emphasizes `GUNBARREL 25`, lap progress, and elapsed time.
- Milestones and results use dedicated wide pixel-art compositions.
- The primary display always contains everything required to play.

### Motion and effects

- Animate at deliberate sprite-frame cadences that match the reference instead of smoothing every movement.
- Keep controls and physics at full simulation rate even when art uses stepped animation.
- Snowflakes may cross the frame in menus and ambient screens, as in the references.
- During gameplay, reduce foreground snow enough to keep moguls and routes readable.
- Keep impact flashes, snow spray, and screen shake short and compact.
- Never use effects that resemble hazards or obscure collision silhouettes.

### Sound

- Ski hiss rises with speed; carving and braking have distinct snow sounds.
- Tucking adds a subtle wind cue.
- Light and heavy impacts sound clearly different.
- Keep voice or text callouts sparse: start, milestones, low condition, final lap, and finish.
- Build musical intensity over the last five laps without changing gameplay timing.

### Attract-mode handoff

Start transitions from the HEAVENLY title or mountain presentation to event selection and then the start gate. Results return to attract mode after a short inactivity timeout. A paused session eventually retires after a visible warning countdown; any input cancels that timeout.

Preserve the existing Windows executable, primary display, optional independent marquee, and cabinet exit behavior established in the implementation plans.

## 10. First playable milestone

**Goal: prove that one descent is fun, then prove that repeating it 25 times creates a worthwhile endurance race.**

### Included

- One skier with reference-matched pixel art.
- One authored downhill course with moguls, snowbanks, tree landmarks, and one optional park-feature route.
- Steering, tuck, coast, and brake.
- Speed-sensitive collisions, condition loss, tumble recovery, and DNF.
- Practice and a complete 25-lap solo event on the same course.
- Race clock, lap transitions, HUD, results, and restart.
- Title-to-race and results-to-attract transitions.
- Basic sound and optional marquee race information.

### Deferred

Ghosts, multiplayer, online records, procedural courses, weather physics, gear upgrades, tricks, grinding, active jump controls, recovery checkpoints, and additional playable characters.

### Implementation sequence

1. **Visual lock:** establish internal resolution, pixel scaling, gameplay camera, one skier, and one mogul together in-engine.
2. **Handling sandbox:** tune steering, tuck, brake, coast, camera, and speed feedback on an empty slope.
3. **One fun descent:** add authored hazards, landmarks, collisions, safe recovery, and repeated Practice testing.
4. **Endurance rules:** add persistent condition, lap count, total time, 25-lap completion, and DNF.
5. **Cabinet loop:** connect title, selection, race, pause, results, restart, exit behavior, and marquee state.
6. **Presentation pass:** replace placeholders, add sound and milestones, and test on the cabinet.

### Acceptance checks

- Every screen looks like part of the same game as the supplied references.
- Pixel scaling stays crisp and stable on the 1920 × 1080 primary display and 1920 × 360 marquee.
- A new player understands the controls and finishes Practice from the on-screen prompt alone.
- Braking enables a route or turn that cannot be negotiated safely at full tuck.
- Clean aggressive skiing beats cautious skiing; repeated high-speed crashes erase that advantage.
- Hazard silhouettes and collision behavior agree at low and maximum speed.
- One overlap cannot deal repeated damage, and recovery cannot trap the skier.
- Race time includes crashes, excludes transitions, and is independent of animation skipping and render rate.
- Condition persists correctly and produces a DNF only at zero.
- The event completes exactly once after the 25th finish crossing.
- A cautious player can finish; a skilled player can improve through better lines and speed management.
- All required information remains readable from normal cabinet distance with or without the marquee.
- Gameplay remains smooth at the existing 1080p / 75 Hz primary target while the marquee is active.

## 11. Implementation boundaries

Use the project's established Godot/GDScript architecture. Keep race simulation separate from presentation on either display.

- **Race session:** phase, mode, course/rules version, lap state, timing, condition, and results.
- **Skier controller:** input, speed, steering, movement, and recovery state.
- **Course:** authored geometry, hazard placement, safe zones, and collision data.
- **Impact resolution:** severity, damage, slowdown, and recovery initiation.
- **Presenters:** primary world/HUD and optional marquee, both driven by race state.

Suggested phases are `attract → select → ready → racing → lap_transition → ready`, followed by `results` after completion or retirement. Pause suspends the solo session and timer. Reuse direct signals and the existing app-controller boundary rather than introducing a generic event framework.

Keep movement and timing independent of render frame rate. Keep downhill progress, collision coordinates, and finish detection in one course coordinate system. Screen scrolling is presentation, not the source of race distance. A finish gate can register only once per lap.

Live mountain data remains ambient and separate from race rules. Save records only for completed attempts in the relevant mode and include rules metadata needed to reject incompatible comparisons.

## 12. AI-generated asset briefs

### Reference rule for every generation

Attach the supplied HEAVENLY game-screen reference image to every generation request.

> Match the attached game-screen reference exactly. The new asset must look native to that game, not like an interpretation of it. Do not add text, logos, watermarks, UI, or a background unless requested. Preserve true transparency for isolated assets. Do not bake scanlines or CRT effects into isolated sprites; the game applies those globally.

Generate one approval sample before each complete set. Keep approved character design, camera, scale, lighting, palette, pixel density, and outlines consistent across later generations.

### Priority 1 — gameplay

**Asset: `heavenly_skier_pose_set`**

> Using the attached game-screen reference, create one approved player skier in eight gameplay poses: neutral downhill, tuck, brake/snowplow, carve left, carve right, light-hit wobble, tumble, and finish celebration. Rear elevated gameplay view. Keep the character design and scale identical in every pose. Deliver separate transparent PNGs on a shared pixel grid with equal framing and a consistent ski-contact anchor. No snow spray or ground shadow.

**Asset: `heavenly_mogul_set`**

> Using the attached game-screen reference, create one small and one large packed-snow mogul for the gameplay camera. Each must have a distinct, readable footprint. Deliver separate transparent PNGs on a shared pixel grid. No surrounding terrain, spray, or long cast shadow.

**Asset: `heavenly_snow_surface`**

> Using the attached game-screen reference, create a seamless gameplay snow tile. Keep it quiet enough for moguls, tracks, and the skier to remain readable. Deliver a tileable PNG with no objects, distinct hazards, deep grooves, text, or cast shadows.

### Priority 2 — course

**Asset: `heavenly_course_edge_set`**

> Using the attached game-screen reference, create individual snowy pines, pine clusters, snowbank segments, snow-covered rocks, and unbranded course-marker poles for the gameplay camera. Deliver each object as a separate transparent PNG on a shared pixel grid. Include left/right variants where needed. Collision trees must show their trunks clearly. No text or background.

**Asset: `heavenly_park_feature_set`**

> Using the attached game-screen reference, create a small snow kicker, rounded roller, low straight rail, wide box, and left/right berm pieces for the gameplay camera. Make approach direction and footprint readable at racing speed. Deliver each as a separate transparent PNG on a shared pixel grid. No riders, logos, text, background, or collision guides.

**Asset: `heavenly_start_finish_set`**

> Using the attached game-screen reference, create a start gate, finish gate, lap marker, and course flags for Gunbarrel 25. Deliver separate transparent PNGs on a shared pixel grid. Leave all changing words and numbers blank for runtime text. No logos or background.

### Priority 3 — effects and results

**Asset: `heavenly_snow_fx_set`**

> Using the attached game-screen reference, create three short pixel-art effects: light ski spray, strong braking spray, and a tumble snow burst. Deliver six ordered transparent frames per effect on a shared pixel grid. No skier, ground, text, background, scanlines, or CRT effect.

**Asset: `heavenly_finish_scene`**

> Using the attached game-screen reference, create a 16:9 results-screen background with the approved skier exhausted but triumphant at the bottom of Gunbarrel and Lake Tahoe in the distance. Leave the right third visually quiet for runtime results. No text, numbers, logos, medals, UI panels, scanlines, or CRT effect.

**Asset: `heavenly_marquee_race_set`**

> Using the attached marquee reference, create three 1920 × 360 backgrounds: race in progress, final lap, and finish celebration. Preserve clear areas for runtime event name, lap count, time, and status. No baked-in text, numbers, logos, scanlines, or CRT effect.

### Asset acceptance

- Approve one skier and one mogul together in the actual gameplay camera before generating full sets.
- Approve one tree and one park object in-engine before generating their complete sets.
- Reject assets that merely share a winter theme but do not match the supplied game-screen reference.
- Check transparency, pixel grid, edge cleanup, pose alignment, scale, and contrast in-engine.
- Verify tile seams manually.
- Derive collision geometry from approved visible footprints rather than generated masks.
- Reuse existing project art when it already matches the reference.
- Build runtime text, HUD values, focus states, simple shadows, and progress indicators in-engine.

## 13. Playtest questions

1. Does steering feel satisfying before hazards are introduced?
2. Can players distinguish a safe line from an ambitious one at racing speed?
3. Do trees and park features make sections memorable without hiding hazards?
4. Is braking a frequent deliberate choice instead of a panic button?
5. Does damage create suspense without making the attempt feel hopeless?
6. Is the full-event length compelling on the cabinet, or should descents be shorter?
7. Does repeating the course reward mastery through lap 25?
8. After losing, can the player explain what happened and name one improvement?
9. Does gameplay retain the same visual identity as the supplied title, selection, and marquee screens?

**The first milestone succeeds when the player wants another descent because they know they can ski a better line.**
