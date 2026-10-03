# HEAVENLY Production Completion Plan

## Status

Milestones 1 through 8 are complete. `PLAN.md` remains the record
of the completed single-jump gameplay loop. This document covers the remaining work required to
turn that loop into a complete three-jump arcade game and production-ready Polycade Sente and
Cloudflare Web/Wasm release.

The single-jump baseline includes low-momentum detection, rollback, terminal feedback, and
focused simulation coverage. It is not yet connected to the round outcome, scoring, or results
contracts described below.

The staged Worker implementation has begun the remote portion of Milestone 11 independently of
the game-side milestones. It provides the SQLite-backed `GlobalLeaderboard` Durable Object,
schema migration tracking, leaderboard endpoints, boundary validation, idempotent submission,
rank/top-10 responses, local Worker tests, and a deployment workflow. It does not yet provide
the Godot repository/client, game-session integration, abuse controls, staging composition, or
recovery operations. Milestone 11 remains in progress until its focused acceptance criteria are
completed and reconciled with the game-side repository contract.

## Goal

Ship one complete solo arcade round with:

1. Rider selection.
2. Three scored jumps.
3. Deterministic low-momentum, bail, clean, sketchy, and crash outcomes.
4. A readable score tally between jumps.
5. Game-over and round-results presentation.
6. A Cloudflare-authoritative online leaderboard and player-name entry.
7. Complete gameplay, UI, and results audio.
8. Reliable cabinet and Web/Wasm input, packaging, networking, and recovery behavior.

The game is production-ready when a player can begin at attract mode, complete up to three
jumps without developer intervention or end a round through a crash, understand every result,
enter a player name when
qualified, see the same persisted leaderboard on cabinet and web, and return automatically
to attract mode.

## Final Game Flow

```text
ATTRACT
  -> RIDER SELECT
  -> JUMP 1 GAMEPLAY
  -> JUMP 1 SCORE TALLY
  -> JUMP 2 GAMEPLAY
  -> JUMP 2 SCORE TALLY
  -> JUMP 3 GAMEPLAY
  -> JUMP 3 SCORE TALLY
  -> GAME OVER
       -> QUALIFICATION CHECK
        -> NAME ENTRY (qualifying score only)
       -> ROUND RESULTS / LEADERBOARD
  -> ATTRACT
```

- A round contains up to three jumps. A `CRASH` ends the round as soon as its current jump is
  recorded, cancelling every remaining jump and bypassing the between-jump tally.
- Each jump begins from a fresh rider simulation state on the shipped course.
- Rider selection persists for the full round.
- Round score and completed jump results persist between jumps.
- Every terminal outcome consumes the current jump: `LOW_MOMENTUM`, `BAIL`, `CLEAN`,
  `SKETCHY`, or `CRASH`.
- Simulation is paused during score tallies, game over, name entry, and results.
- The score tally advances automatically after a short readable delay. Start or A may
  accelerate the tally after its minimum display time but may not skip result recording.
- After a crash is recorded or the third non-crash tally, the game enters game over exactly once.
- An online score is qualified against Cloudflare's authoritative board.
- If the leaderboard request is unavailable at game over, show `LEADERBOARD OFFLINE`, skip
  name entry and submission, and continue to local round results.
- A qualifying score proceeds to name entry. A non-qualifying score proceeds directly
  to results and the leaderboard.
- Results return to attract automatically after a timeout. Start begins a new rider-select
  flow; Back returns to attract immediately where appropriate.

## Terminology And State Ownership

- **Jump**: one approach, optional flight, landing or terminal failure, and its score.
- **Round**: one to three recorded jumps by one selected rider; a crash may end it early.
- **Run simulation**: the deterministic per-jump rider simulation currently owned by
  `RiderRunManager`.
- **Game over**: the terminal round state after a crash or final non-crash jump has been recorded
  and tallied.
- **Leaderboard**: the shared, Cloudflare-authoritative high-score dataset.

`RiderSimulation` remains responsible only for one jump. `GameSession` becomes the
authoritative round coordinator. Presentation observes session state and never decides
whether a jump, round, score, or leaderboard entry is complete.

`RiderKind` remains the canonical rider identity for round state, validation, presentation, and
future leaderboard payloads. `RoundState` must depend on it rather than on `GameSession`.

`GameSession` owns creation and reset of every `RiderRunManager`. Course and tuning are
configured once when a jump begins through the session or an injected run factory; presentation
does not begin, replace, or reset a run as a screen lifecycle side effect, and physics stepping
receives only the input frame and fixed delta.

`JumpOutcome` is the sole terminal-outcome enum. Milestone 1 replaces
`RiderRunState.LandingOutcome`, its `landing_outcome` field, and every simulation, presentation,
and test consumer with `JumpOutcome` and a correctly named jump-outcome field. No conversion
layer or duplicate outcome enum remains after that milestone.

## Authoritative Round Model

Replace the current coarse `ATTRACT / PLAYING` lifecycle with explicit round
states. Names may be adjusted during implementation, but responsibilities must remain
separate:

```gdscript
enum SessionPhase {
    ATTRACT,
    RIDER_SELECT,
    JUMP_ACTIVE,
    JUMP_TALLY,
    GAME_OVER,
    QUALIFYING,
    NAME_ENTRY,
    RESULTS,
}
```

Required round data:

```text
round_id
rider_kind
current_jump_number       # 1 through 3 while active
jump_results              # immutable results, maximum length 3
round_score               # sum of recorded jump scores
session_phase
high_score_qualified
leaderboard_rank
leaderboard_status
```

`high_score_qualified` and `leaderboard_rank` are unknown while qualification is pending or
unavailable; do not represent an unknown remote result as a false qualification or numeric rank.

Rules:

- `round_score` is derived from recorded immutable jump results, not incrementally authored
  by animation or HUD code.
- A jump result may be appended exactly once.
- The next jump cannot begin until the current result is recorded.
- Jump four cannot begin.
- Only `CRASH` ends a round before its third jump; every other terminal outcome continues normally.
- Restarting the current jump is a development-only action and must not duplicate or erase
  previously recorded jump results.
- Starting a new round clears recorded jump results and score while preserving the database.
- Returning to attract bails the in-memory round but never deletes high scores.
- Every completed round receives a globally unique `round_id` before score submission.
- Leaderboard availability never changes the authoritative score or recorded jump results.

### Completion And Observation Contract

An outcome becoming known is distinct from its jump completing. Low momentum is known while the
rider rolls back, landing outcomes may be known during runout, and crash may be known during its
completion delay. `GameSession` records exactly one result only when the active run transitions
to `RiderRunState.RunPhase.COMPLETE`; the terminal outcome is immutable payload for that result.
Neither outcome polling, animation completion, nor presentation callbacks may record a result.

`GameSession` exposes typed, immutable observation snapshots or focused typed signals for phase
changes, jump starts, jump-result recording, round completion, and leaderboard-operation status.
Every signal is emitted after its state mutation and exactly once for each accepted transition.
Presentation derives HUD, tally, navigation, and audio from these notifications rather than
polling mutable simulation state to infer lifecycle transitions.

Round records use private backing fields and copied result collections. Results and nested score
records expose read-only getters only. Constructors or factories return an explicit testable
validation result for invalid data; logging an error is not the sole rejection mechanism.

## Per-Jump Outcome Model

`JumpOutcome` describes every terminal result, including `LOW_MOMENTUM`, which occurs during
approach rather than landing:

```gdscript
enum JumpOutcome {
    NONE,
    LOW_MOMENTUM,
    BAIL,
    CLEAN,
    SKETCHY,
    CRASH,
}
```

The simulation may resolve directly to `COMPLETE` with outcome `LOW_MOMENTUM`. It may first
keep the rider in approach long enough to visibly roll backward. In either design, low-momentum
timing is simulation-owned and presentation callbacks cannot complete the jump.

## Low-Momentum Rules

Low momentum means the rider is near a flight lip but has too little forward speed and cannot
recover enough acceleration under the best available non-braking input.

- Low momentum applies only to a flight route before its approach endpoint.
- It cannot occur before the rider has started moving.
- It cannot occur while a route change is still capable of completing.
- Merely releasing Right, braking, or stopping on recoverable terrain does not immediately
  count as low momentum.
- Detection occurs only inside a configurable near-lip distance and uses a configurable
  low-speed threshold, a no-progress duration, and the local maximum recoverable forward
  acceleration under Right plus tuck.
- The no-progress timer advances only while speed is below the threshold and maximum
  recoverable acceleration is non-positive.
- Recovering speed or positive progress resets the timer.
- Once detected, display `LOW MOMENTUM` and the restart prompt while allowing normal ground
  physics to roll the rider back down the slope.
- Resolve `LOW_MOMENTUM` after the rider has rolled back a configurable distance or remained
  below the low-speed threshold for a configurable stopped-rider duration.
- The lower grounded route cannot resolve low momentum; it continues into its authored runout.
- Low momentum awards zero points and consumes the jump.

Required tuning:

```text
low_momentum_detection_distance
low_momentum_speed_threshold
low_momentum_progress_epsilon
low_momentum_detection_duration
low_momentum_slide_distance
low_momentum_stop_duration
```

Debug terrain mode should show the low-momentum timer, recoverable acceleration, and reason
when the detector is armed.

## Scoring Contract

Scoring is resolved once when the jump reaches a terminal outcome. It never changes after
the immutable `JumpResult` is created.

### Components

```text
approach_points
takeoff_points
airtime_points
rotation_points
grab_points
style_bonus_points
landing_multiplier
total
```

- Approach points reward controlled speed at the lip, capped by tuning.
- Takeoff points reward compression release quality and pop.
- Airtime points use captured airtime and a cap.
- Rotation points count completed 360s only.
- Grab points use valid held-grab duration after the minimum duration, regardless of whether the
  rider selected the standard or tweak grab style.
- A valid tweak grab receives one fixed style bonus; it does not receive a separate duration
  score or stack with a standard grab.
- Incomplete rotations never score.
- Required rotations remain a HUD speed-management target; missing the quota does not add a
  separate penalty beyond the trick and landing result.
- `CLEAN` uses a `1.0` landing multiplier.
- `SKETCHY` initially uses a `0.5` multiplier exposed for tuning.
- `LOW_MOMENTUM`, `BAIL`, and `CRASH` use a `0.0` multiplier.
- Scores are non-negative integers. Each component and the final multiplied total use
  `roundi`; no intermediate floating-point value is displayed or persisted.
- The maximum achievable score must fit comfortably within a signed 32-bit integer for both
  a jump and a three-jump round.

Initial formula, using seconds for time and world units per second for speed and impulse:

```text
approach_points = round(
    clamp(takeoff_speed / score_approach_speed_cap, 0, 1)
    * score_approach_max
)

takeoff_points = round(
    clamp(takeoff_pop_impulse / maximum_pop_impulse, 0, 1)
    * score_takeoff_max
)

airtime_points = round(
    clamp(airtime / score_airtime_cap, 0, 1)
    * score_airtime_max
)

rotation_points = completed_rotations * score_rotation_per_rotation

grab_points = round(
    min(valid_grab_duration, score_grab_duration_cap)
    * score_grab_per_second
)

style_bonus_points = score_tweak_style_bonus
    if grab_style == TWEAK and valid_grab_duration > 0
    else 0

subtotal = approach_points + takeoff_points + airtime_points
    + rotation_points + grab_points + style_bonus_points

total = round(subtotal * landing_multiplier)
```

`takeoff_speed`, `takeoff_pop_impulse`, `airtime`, completed rotations, selected grab style, and
valid grab duration are frozen from simulation at terminal resolution. Zero or invalid caps
contribute zero rather than dividing by zero. Scoring tests define boundary behavior before tuning
values are adjusted through playtesting.

`takeoff_speed` is horizontal course speed at the lip. A standard or tweak grab must independently
satisfy the grab minimum hold duration to be valid; the selected style and active duration freeze
at terminal resolution, including bail or crash. Persisted score breakdowns use integer or
fixed-point fields only; no canonical request hash depends on cross-language floating-point
serialization.

The existing score tuning values in `RiderTuning` are provisional legacy inputs for this
formula. Keep or rename them only when the new `JumpScorer` and boundary tests make their
units and ownership authoritative; remove any value the formula does not use.

### Score Resolution

Introduce a pure scorer with no node, animation, audio, or database dependencies:

```gdscript
func score_jump(snapshot: JumpSnapshot, tuning: RiderTuning) -> JumpScore
```

`JumpSnapshot` contains only frozen simulation measurements. `JumpScore` contains
the final score and typed breakdown. The session converts the completed simulation into one
immutable `JumpResult` and appends it to the round.

The baseline contains no mutable score field, untyped score dictionary, trick-name generator,
or one-jump result factory. Introduce only the typed snapshot and result path described here.

Trick summary text should be generated from the immutable score snapshot or result. It may
display completed rotations, grab style, and outcome, but it does not author score.

Simulation and session integrations emit one authoritative semantic transition record for each
accepted lifecycle event. Audio consumes these records when it is added; it must not later infer
one-shot gameplay events by frame polling.

## HUD Contract

During gameplay the primary HUD displays:

```text
SCORE       JUMP       SPEED       ROTATION       SPINS
00450       2 / 3      31 MPH      +180°          0 / 1
```

- `SCORE` shows the accumulated score from completed jumps plus the active jump's live,
  unresolved score projection. The projection uses current measurements and assumes a clean
  landing; terminal scoring remains authoritative and may reduce it for a sketchy landing or
  resolve it to zero for low momentum, bail, or crash.
- `JUMP` is `1 / 3`, `2 / 3`, or `3 / 3`, driven by session state.
- Restarting an unrecorded current jump does not change score or jump number.
- Rotation and quota reset for every jump.
- HUD values never read hardcoded `01 / 01` text after setup.
- Existing rider-overlap hiding remains intact.

## Score Tally Presentation

After each non-crash jump, freeze gameplay and present a deterministic tally:

1. Outcome banner.
2. Trick summary.
3. Component rows with earned points.
4. Landing multiplier.
5. Jump score count-up.
6. Round score count-up.
7. `JUMP N COMPLETE` and next action.

- Count-up animation is presentation-only; the authoritative score is already resolved.
- Tick sounds are rate-limited so large awards do not create an audio storm.
- Non-crash zero-point outcomes still show the outcome and a clear `+0` result.
- A recorded crash or the third non-crash tally transitions to `GAME_OVER`, not directly to attract.
- Animation completion signals may accelerate presentation but never mutate session data.

Tally and screen timeout state machines advance from explicit `advance(delta)` operations or an
injected clock. Do not rely on free-running `Timer` nodes for authoritative navigation timing;
the same clock contract must be deterministic in headless tests.

## Game Over And Results

Game over begins after a crash is recorded or the third non-crash jump tally and is a distinct state.

- Show `GAME OVER`, final score, and high-score qualification status.
- Disable gameplay input and simulation.
- Do not allow Start to restart the third jump.
- Enter `QUALIFYING` while the authoritative online check is pending.
- If qualified, transition to name entry.
- If not qualified, transition to round results after a short delay.
- Results list every recorded outcome and score, final total, selected rider, and leaderboard.
- Results show `LEADERBOARD OFFLINE` when qualification could not be performed, without
  changing the local round score.
- Results time out back to attract.
- Start from results begins a new rider-select flow; Back returns to attract.
- Pause/exit remains available without corrupting local results or an in-flight request.

## Shared Leaderboard Architecture

Cloudflare is the only leaderboard store. The Web/Wasm build and cabinet communicate with the
same HTTPS Worker API. Local round results remain available in memory for the current session,
but neither platform stores or submits leaderboard scores while offline.

```text
Polycade cabinet
  Godot native build
          |
          | HTTPS
          v
Cloudflare Worker API
          |
          | Durable Object binding / RPC
          v
Leaderboard Durable Object
  authoritative SQLite-backed storage
          ^
          |
Cloudflare Web/Wasm build
  same-origin HTTPS API
```

- Submit immutable leaderboard entries through one small JSON protocol.
- Route every leaderboard request to one Durable Object named `leaderboard-global`.
- The global object owns qualification, insertion, ranking, duplicate prevention, and the board
  revision.
- Sharding, seasons, scoring-version boards, directory objects, receipt objects, and archival
  tiers are explicitly out of scope.
- The front Worker validates HTTP, authentication, rate limits, CORS, and payload shape. Only
  the Worker can access the Durable Object binding.
- Durable Object storage is SQLite-backed, transactional, and strongly consistent. Persist
  every accepted entry before returning success.

## Leaderboard Repository Contract

Game and presentation code depend on one platform-neutral repository interface:

```text
get_top_entries()
check_qualification(total_score)
submit_score(submission)
availability_changed
```

Repository operations use typed request and result values, an operation ID, and explicit
cancellation. A response is applied only if its operation still belongs to the same active
round/session generation. Attract-board refreshes and post-round qualification may be concurrent;
leaving a screen or returning to attract cancels its operation and late callbacks cannot mutate a
new round.

Implementations:

- **Cabinet and Web/Wasm**: `RemoteLeaderboardRepository` calls the Worker API directly.
- **Tests/development**: an in-memory fake supports deterministic session and presentation
  tests without network access.

The game has no native SQLite dependency and no IndexedDB leaderboard store.

## Cloudflare Worker API

Endpoints:

```text
GET  /api/liftie/resort/:resortName
GET  /api/leaderboard
POST /api/leaderboard/qualify
POST /api/leaderboard/submissions
```

- The staged Worker already proxies Liftie through `GET /api/liftie/resort/:resortName`. It sends
  the required `LIFTIE_USER_AGENT` upstream as a Worker secret, so the Web/Wasm client neither
  carries nor sends that header directly. Successful normalized resort responses are cached for
  60 seconds; invalid or unavailable upstream responses return the normalized `unknown` state
  with `503` and `Cache-Control: no-store`.
- Host the Web/Wasm game and API on the same origin so browser requests do not require broad
  CORS permissions.
- Cabinet requests use the same public HTTPS API and strict TLS validation.
- `GET /api/leaderboard` returns the current top 10.
- `qualify` performs a strongly consistent check in the global object.
- `submissions` accepts one immutable score and returns accepted state, current rank, and the
  current top 10.
- Apply request body, player name, enum, integer range, and timestamp limits before invoking the
  Durable Object.

Submission payload:

```text
roundId             # globally unique UUID for the completed round
playerName
riderKind
totalScore
platform            # "ags" or "web"
```

`roundId` is the idempotency key. The server validates the total score and payload shape.
`platform` is informational client metadata because the leaderboard is explicitly casual.
Responses use camelCase fields, including `topEntries` and `createdAt`.
`createdAt` is server-authored ISO-8601 text with the numeric offset for the configured `TZ`.

## Durable Object Storage

Declare one SQLite-backed Durable Object class with Wrangler's declarative `exports` configuration.
The object initializes its permanent schema before serving requests and uses bound
SQL parameters.

Initial remote schema:

```sql
CREATE TABLE leaderboard_entries (
    round_id TEXT PRIMARY KEY,
    player_name TEXT NOT NULL CHECK (length(player_name) BETWEEN 1 AND 12),
    total_score INTEGER NOT NULL CHECK (total_score BETWEEN 0 AND 2147483647),
    rider_kind TEXT NOT NULL CHECK (rider_kind IN ('skier', 'snowboarder')),
    platform TEXT NOT NULL CHECK (platform IN ('ags', 'web')),
    created_at TEXT NOT NULL
);

CREATE INDEX leaderboard_rank_idx
ON leaderboard_entries(total_score DESC, created_at ASC, round_id ASC);

```

Remote rules:

- Display the global top 10.
- A score qualifies when fewer than 10 entries exist or it is strictly greater than the
  current tenth-place score.
- Equal scores do not displace an earlier accepted entry. Rank by score descending, then server
  acceptance time and round ID; client clocks never control rank.
- Player names normalize to trimmed NFC text with one through 12 characters and no control characters.
- Accepted named submissions remain stored even if concurrent submissions move them below
  tenth place before results display. Return their current rank.
- Repeating a `round_id` returns the original result without creating another entry.
- Store all accepted entries in the one object. Expected game traffic does not require
  partitioning, compaction, or archival.
- The Worker validates only payload shape and integer score bounds. The leaderboard is explicitly
  casual and cannot verify client-observed gameplay.

### Remote Backup And Recovery

- Enable and document Durable Object SQLite point-in-time recovery bookmarks and the current
  Cloudflare retention window.
- Recovery restores the same global object from a selected bookmark.
- While recovery is active, return `503 BOARD_MAINTENANCE`; the current score is not submitted.
- Perform one restore drill before launch and document the result.

## Connectivity, Failure, And Recovery

- Failure to reach Cloudflare never prevents gameplay or local results presentation.
- At game over, an unavailable qualification request shows `LEADERBOARD OFFLINE`, skips
  name entry, and proceeds directly to results.
- A submission failure after name entry shows `SCORE NOT SUBMITTED` and proceeds to results.
- Failed submissions are not queued or retried after leaving the screen.
- Web assets may remain playable from browser cache, but leaderboard display, qualification,
  name entry, and submission require a live API connection.
- Log network, HTTP, Worker, and Durable Object errors with operation and correlation IDs but
  without unnecessary player data.

## Authentication And Abuse Policy

- Cabinet requests include a generated installation ID for rate-limit grouping, but it is not a
  credential and is not trusted as identity.
- Web submissions use Turnstile at submission.
- Apply Worker/Cloudflare rate limits by IP and installation ID where available.
- Launch version 1 is explicitly a casual global leaderboard: server formula validation and
  abuse controls prevent malformed or automated spam, but cannot prove that a public Web
  client honestly simulated every input.
- Store and return `platform`; show a subtle source badge without splitting the shared dataset.
- The schema and API reserve a future replay-proof field. A fully cheat-resistant Web board
  requires deterministic replay submission and server-side replay verification and is not
  implied by Turnstile or obfuscation.
- Turnstile verification and rate limits remain Worker-side.

## Player Name Entry

Player-name entry supports up to 12 characters on cabinet and keyboard without an on-screen keyboard.

- One to 12 character slots using the supported player-name character set.
- Left/Right selects a slot; Up/Down cycles the selected character with wraparound.
- Keyboard input enters supported characters directly.
- A or Start confirms a non-empty valid name and creates one immutable
  online submission.
- B deletes the selected character. Name entry itself has no score-discard action.
- A visible countdown prevents a cabinet from remaining blocked indefinitely.
- The field begins as `PLAYER`; timeout confirms the currently displayed name.
- Input is edge-triggered with repeat delay/rate for held directions.
- Confirmation sends one request and disables repeated input while it is in flight.
- Name entry transitions to results after remote acceptance or an explicitly handled failure.

## Audio Contract

Replace screen-owned and duplicated audio players with one application-level audio service
and named buses for `Music`, `GameplaySfx`, and `UiSfx`.

Required sound events:

```text
UI_MOVE
UI_BACK
UI_CONFIRM
ROUND_START
JUMP_START
CARVE
BRAKE
TUCK
COMPRESSION_CHARGE
COMPRESSION_RELEASE
TAKEOFF
GRAB_START
GRAB_RELEASE
HALF_ROTATION
FULL_ROTATION
RELEASE_WARNING
LAND_CLEAN
LAND_SKETCHY
BAIL
CRASH
LOW_MOMENTUM
SCORE_TICK
SCORE_TOTAL
NEXT_JUMP
GAME_OVER
HIGH_SCORE
LEADERBOARD_OFFLINE
NAME_MOVE
NAME_CONFIRM
RESULTS_REVEAL
```

- Simulation or session transitions emit semantic events exactly once.
- Audio never determines simulation, tally, or navigation timing.
- Continuous sounds such as carve, brake, tuck, and compression use explicit start/update/stop
  ownership and stop on pause, outcome, reset, or screen exit.
- Music transitions intentionally between attract, gameplay, game over, name entry, and results;
  duplicate tracks cannot overlap accidentally.
- Score ticks are throttled and pitch variation is bounded.
- Every new asset records source, author, license, modification, and attribution requirements.
- Mix validation must cover cabinet speakers at realistic ambient volume without clipping.

## Platform Input And Idle Behavior

- One controller owns a solo round from rider select through results.
- Ignore gameplay actions from other devices after ownership is established.
- Keyboard development input remains available without changing cabinet ownership rules.
- Controller disconnect pauses simulation and all presentation/idle timers and displays a
  reconnect prompt. Do not use controller GUID as physical identity. After a three-second
  debounce, Start on one connected controller explicitly claims ownership; all others remain
  ignored. In Web production, any keyboard confirm key may instead claim the logical keyboard
  owner. Cabinet production permits keyboard recovery only in development builds.
- Start pauses only during active gameplay. During tallies, game over, name entry, and results it
  performs the documented continue/confirm action.
- `R` may restart the current jump in debug/development builds; production cabinet input must
  not provide an accidental score retry.
- Attract, name entry, game over, and results have explicit idle timeouts.
- Exiting to AGS remains available from every state and cancels in-flight leaderboard requests.
- The production Web target supports desktop browsers with keyboard or a connected gamepad.
- Rider select establishes one input owner: a specific gamepad device ID or the logical
  keyboard owner. Once claimed, the other source is ignored until an explicit pause-menu
  handoff or disconnect recovery. Cabinet production disables keyboard claiming; Web
  production permits it.
- Touch-only mobile gameplay is not supported in this release. Mobile browsers show an
  explicit controller/desktop requirement instead of presenting unusable controls.
- Web name entry uses the same directional/button contract plus keyboard arrows, letters,
  Enter, and Backspace; it does not depend on touch controls.

Input ownership begins from raw keyboard and joypad events so the claiming device is retained.
The router filters gameplay frames, UI navigation, accept/cancel, pause, tally, and name-entry
commands from unowned sources, and intercepts default wildcard GUI focus navigation. The input
map must not retain device-0 bindings that bypass the claimed device. `R` restart is gated by
`OS.is_debug_build()` and is unavailable in production builds.

Pause has one authoritative policy shared by session and screen flow. The policy explicitly
defines which clocks and operations continue during gameplay pause, controller-disconnect pause,
qualification, name entry, results, and application exit.

## Remaining Replacement Map

| Current item | Final replacement |
| --- | --- |
| HUD hardcodes `01 / 01` | Session-driven `n / 3` |
| No results flow or screen | Automatic game-over and results flow owned by screen flow |
| Start restarts complete single run | Start advances or confirms according to round phase |
| Screen-local music/SFX players | Central semantic audio service and buses |
| No persistence | One online Cloudflare Durable Object leaderboard |

Do not introduce compatibility adapters for removed score or result behavior. The Durable
Object is the only persisted leaderboard.

## File Map

Expected primary additions or changes:

```text
DEFERRED_PLAN.md
src/game/game_session.gd
src/game/round_state.gd
src/game/park/jump_outcome.gd
src/game/park/jump_snapshot.gd
src/game/park/jump_score.gd
src/game/park/jump_scorer.gd
src/game/park/jump_result.gd
src/game/park/approach_simulation.gd
src/game/park/approach_motion.gd
src/game/park/rider_tuning.gd
src/services/leaderboard_repository.gd
src/services/remote_leaderboard_repository.gd
src/services/leaderboard_http_client.gd
src/app/audio_manager.gd
src/app/input_router.gd
src/app/screen_flow_controller.gd
src/presentation/gameplay/gameplay_hud.gd
src/presentation/gameplay/gameplay_hud_presenter.gd
src/presentation/gameplay/gameplay_run_presenter.gd
src/presentation/gameplay/score_tally_presenter.gd
src/presentation/results/game_over_screen.gd
src/presentation/results/player_name_entry_screen.gd
src/presentation/results/results_screen.gd
workers/api/src/index.ts
workers/api/src/leaderboard/durableObject.ts
workers/api/src/leaderboard/handlers.ts
workers/api/src/utils/http.ts
workers/api/src/workerTypes.ts
workers/api/wrangler.jsonc
workers/api/package.json
workers/api/package-lock.json
workers/api/tsconfig.json
workers/api/vitest.config.ts
workers/api/test/leaderboard.test.ts
```

Exact file boundaries may remain smaller where a separate type adds no clarity.

## Milestones

Work proceeds through these milestones in order. A milestone is complete only after its focused
automated acceptance is part of the standard test command and its manual acceptance has been
performed. Do not begin the next milestone while the current milestone has an unresolved failure.

### Milestone 1: Round Data Contracts

Status: Complete.

Implementation:

- Define the explicit session phases without changing scene navigation yet.
- Replace `RiderRunState.LandingOutcome` and every consumer with the canonical `JumpOutcome`.
  Rename the mutable simulation field to match, preserving existing single-jump behavior and
  removing the old enum in this milestone.
- Introduce an immutable minimal `JumpResult` using `JumpOutcome`. It must represent every
  terminal outcome with a resolved integer score.
- Define authoritative round data for rider, jump number, recorded results, derived round score,
  and phase. Validate rider values through the existing `RiderKind` contract.
- Define the immutable-record strategy and explicit validation-result behavior used by the round
  model.
- Keep scoring measurements and typed score breakdown work deferred to Milestone 6.
- Add `tests/game/test_round_state.gd`; standard test discovery includes it automatically.

Automated acceptance:

- A new round starts on jump 1 with zero score and no results.
- Round score is derived from immutable recorded results.
- Exposed result collections cannot mutate the round's internal result collection.
- Invalid jump numbers, result counts above three, and invalid rider kinds are rejected.
- Existing simulation, presentation, and test code use `JumpOutcome`; no `LandingOutcome` or
  outcome-conversion adapter remains.
- Existing park simulation tests remain unchanged and pass.

Manual acceptance:

- Launching the game still reaches attract mode and the existing single-jump loop behaves as
  before; the new contracts do not drive presentation yet.

### Milestone 2: Headless Round Progression

Status: Complete.

Implementation:

- Make `GameSession` start and bail a round using the new round model.
- Add one authoritative operation to record the active jump result exactly once, only from the
  active run's transition to `COMPLETE`.
- Add explicit operations to complete a tally and begin the next jump.
- Implement transitions through jump 1, jump 2, jump 3, and game over without connecting scenes
  or adding tally presentation. A non-crash result enters tally; a crash enters game over directly.
- Define typed session change notifications with post-mutation, exactly-once emission semantics.
- Keep leaderboard, name-entry, and results-screen transitions out of this milestone.

Automated acceptance:

- Exactly one result may be recorded for the active jump.
- Recording a non-crash result enters tally without changing the result afterward; recording a
  crash enters game over exactly once.
- Completing non-crash tallies 1 and 2 advances to the next jump.
- Recording a crash or completing tally 3 enters game over exactly once.
- A next jump cannot begin before a result is recorded, and jump 4 cannot begin.
- A crash ends the round and prevents every remaining jump from starting.
- Resetting an unrecorded current jump preserves prior results and the jump number.
- Starting a new round clears round data but not injected service state.
- Returning to attract bails only the in-memory round.

Manual acceptance:

- Run the focused session test directly and inspect its transition trace from jump 1 through
  game over; no gameplay scene behavior changes in this milestone.

### Milestone 3: Three-Jump Gameplay Integration

Status: Complete.

Implementation:

- Connect terminal simulation completion transitions to `GameSession.record_jump_result()`;
  outcomes are result payload and must not trigger recording before `COMPLETE`.
- Have `GameSession` create a fresh `RiderRunManager` and `RiderSimulation` for non-crash jumps
  2 and 3 while preserving round data. Configure course and tuning once per new jump rather than
  passing them from presentation on every physics step.
- Pause simulation while the session is in tally; use a temporary deterministic continue action
  until the real tally UI is added in Milestone 9.
- Preserve the completed single-jump simulation behavior within each jump.
- Construct an immutable zero-score `JumpResult` for each terminal outcome until scoring is
  integrated in Milestone 7.
- Emit authoritative semantic transition records needed later by audio without coupling the
  simulation to audio playback.

Automated acceptance:

- Every existing terminal outcome records at most one result even if completion is observed for
  multiple frames, and never records before the run completes.
- Each next jump receives fresh rider simulation state.
- Prior results and round score survive simulation resets.
- A crash transitions to game over without resetting for another jump.
- Physics stepping is ignored outside `JUMP_ACTIVE`.
- Existing approach, takeoff, flight, landing, and runout tests still pass.

Manual acceptance:

- Three non-crash gameplay loops can be completed consecutively without returning to attract.
- A crash on jump 1 or 2 visibly ends the round and does not start a later jump.
- Each jump visibly starts from the authored initial state, and input during the temporary tally
  cannot move the rider.

### Milestone 4: Input Ownership

Status: Complete.

Implementation:

- Introduce a per-device `InputRouter` before rider select.
- Allow rider select to claim the logical keyboard or one gamepad according to platform policy.
- Replace global wildcard action polling in gameplay with frames from the claimed owner.
- Route temporary tally and navigation actions through the same owner.
- Claim from raw keyboard and joypad events, retain the source device, and filter UI focus,
  accept/cancel, pause, tally, and name-entry commands from unowned devices.
- Remove device-specific InputMap bindings that bypass the claimed source, and gate debug restart
  behind `OS.is_debug_build()`.
- Defer disconnect recovery and explicit handoff polish to Milestone 18.

Automated acceptance:

- Keyboard and a specific gamepad can each be claimed when policy permits.
- Claiming one source excludes every other keyboard/gamepad source for the round.
- Unowned input cannot affect gameplay or advance the temporary tally.
- Returning to attract releases ownership; restarting the current jump does not.
- Cabinet production policy rejects keyboard claiming while Web production permits it.

Manual acceptance:

- With two controllers connected, only the controller used at rider select can control every
  non-crash jump and advance between them.

### Milestone 5: Low-Momentum Outcome

Status: Complete.

Implementation:

- Add debug diagnostics for detector timing, recoverable acceleration, and the armed reason.
- Verify deterministic behavior across supported fixed physics deltas.

Automated acceptance:

- A low-speed rider near an unrecoverable flight lip resolves low momentum once.
- A rider who can recover forward acceleration does not resolve low momentum.
- Braking or releasing input on recoverable terrain does not immediately resolve low momentum.
- Progress resets the low-momentum timer.
- The grounded route never resolves low momentum.
- The rider rolls back under normal physics before resolution, or resolves after the configured
  stopped-rider duration when rollback is impossible.
- Low momentum consumes one jump and records zero score.
- Detection remains deterministic across supported fixed physics deltas.

Manual acceptance:

- Players can intentionally reproduce low momentum, understand why the jump ended, and continue.

### Milestone 6: Pure Scoring Engine

Status: Complete.

Implementation:

- Add frozen score snapshots, a pure scorer, and a typed breakdown.
- Implement approach, pop, airtime, rotation, grab, tweak-style bonus, and outcome multiplier
  formulas using explicit provisional tuning values.
- Define the frozen measurement semantics for takeoff speed, selected grab style, and active grab
  duration at failure, and use integer or fixed-point score breakdown fields.
- Keep the scorer disconnected from live simulation and presentation.

Automated acceptance:

- Identical snapshots always produce identical scores.
- Each component respects its cap and rounding rule.
- Incomplete rotations do not score.
- Clean scores more than sketchy for the same trick.
- Low momentum, bail, and crash resolve to zero.
- Result totals equal their component formula.
- Zero or invalid caps contribute zero without division errors.

Manual acceptance:

- Run a fixed table of representative snapshots and inspect the printed component breakdowns;
  no live-game score changes are expected yet.

### Milestone 7: Scoring Integration

Status: Complete.

Implementation:

- Freeze live simulation measurements once at terminal resolution and score that snapshot.
- Store the typed score result in the immutable `JumpResult` recorded by `GameSession`.
- Generate trick summaries from resolved results.
- Replace the temporary zero-score result construction and tune the initial scoring values
  through the representative playtest cases.

Automated acceptance:

- Terminal resolution invokes scoring once and repeated completion frames cannot change score.
- Round total equals the sum of recorded jump scores.
- Restarting an unrecorded jump cannot retain partial score measurements.
- Result construction reads only the frozen typed score snapshot and result.
- Scoring changes do not alter deterministic rider motion or terminal outcomes.

Manual acceptance:

- A basic clean jump, a completed 360 with grab, and a stronger multi-rotation jump produce
  clearly different and understandable resolved scores.
- Replaying the same deterministic input sequence produces the same score.

### Milestone 8: Three-Jump HUD

Status: Complete.

Implementation:

- Drive `JUMP n / 3` from session state and `SCORE` from the recorded session total plus an
  active-jump live score projection.
- Reset world and per-jump HUD without resetting round totals.
- Keep the temporary tally continue behavior from Milestone 3.

Automated acceptance:

- HUD reports the correct jump number and accumulated score for every started jump, up to three.
- Recorded round totals update only from session changes; the active-jump projection is
  presentation-only and never mutates a `JumpResult` or round total.
- Restarting the unrecorded current jump leaves jump number and accumulated score unchanged and
  clears its live projection.

Manual acceptance:

- `SCORE` updates with active-jump measurements, resolves to the authoritative result after each
  terminal outcome, and `JUMP n / 3` remains correct through three jumps or an early crash at
  1920x1080 and at 30, 60, and 120 render FPS.

### Milestone 9: Score Tally Presentation

Implementation:

- Add the between-jump outcome, trick, component, multiplier, jump-total, and round-total tally.
- Add presentation-only count-up animation and rate-limited tick events.
- Add acceleration/continue input with minimum readable timing.
- Replace the temporary tally continue behavior from Milestone 3.

Automated acceptance:

- Tally animation never mutates authoritative score or recorded results.
- Zero-point outcomes still display `+0` and can complete.
- Continue input cannot append a result or complete a tally twice.
- Continue input before the minimum display time does nothing.
- Non-crash tallies 1 and 2 begin the next jump; a recorded crash or tally 3 transitions to game over.
- Count-up reaches the exact authoritative jump and round totals at multiple render deltas.

Manual acceptance:

- Every tally row remains readable at 1920x1080 and at 30, 60, and 120 render FPS.
- Normal and accelerated tallies both reach the correct next state without visible score jumps.

### Milestone 10: Online Leaderboard Client

Implementation:

- Add the remote leaderboard repository, HTTP client, and in-memory test fake.
- Add explicit available, unavailable, qualifying, submitting, accepted, and failed states.
- Define typed request/result values, operation IDs, cancellation, and session-generation guards
  so stale or abandoned callbacks cannot alter a later round.
- Keep completed round results in `GameSession` memory while navigating game over and results.
- Add one installation ID in normal Godot user settings for cabinet rate-limit grouping.

Automated acceptance:

- Available service returns qualification and leaderboard results.
- Timeout, DNS, TLS, HTTP, malformed-response, and service-unavailable failures enter the
  unavailable state without changing local round results.
- Confirm sends at most one submission while the request is in flight.
- Closing or leaving results does not start a retry queue.
- A late success after cancellation or return to attract cannot update another round.
- Cabinet and Web clients use the same repository contract.

Manual acceptance:

- Exercise the repository from its development harness against success, timeout, malformed, and
  unavailable responses; each request reaches the expected repository state without changing a
  completed in-memory round. Screen messaging is deferred to Milestone 16.

### Milestone 11: Cloudflare Leaderboard Core

Status: In progress. The staged Worker supplies the initial Durable Object, routing, schema
migration tracking, payload validation, idempotent submission, top-10/rank responses, local
Worker tests, package tooling, and deployment workflow. The API currently serializes JSON with
camelCase fields and stores the schema migrations in `durableObject.ts`; a separate `schema.ts`
module is not present.

Implementation:

- Add the Worker API, one SQLite-backed `GlobalLeaderboard` named `global`, declarative Wrangler
  class lifecycle configuration, and the permanent remote schema.
- Add the pinned Worker package manifest, lockfile, TypeScript configuration, Worker test
  configuration, generated-types policy, and Node/runtime version policy.
- Add qualification, idempotent single submission, ranking, and top-10 endpoints.
- Add payload validation and structured errors at the Worker boundary.
- Keep Turnstile, rate limiting, deployment, and recovery out of this milestone.
- Complete the unimplemented focused cases below, including full-board qualification/tie behavior
  and Durable Object restart coverage.
- Reconcile the Worker JSON contract with the platform-neutral Godot repository before connecting
  either client. Game-side integration remains blocked on Milestone 10.

Automated acceptance:

- New Durable Object storage initializes its schema exactly once.
- Empty, partial, full, tie, and greater-than-tenth qualification are strongly consistent.
- A repeated `round_id` returns the original result without another row.
- Submission validates totals and rejects malformed or impossible payloads.
- Submission validates payload shape and score bounds but documents that the Worker cannot prove
  client-observed motion measurements or validate scoring arithmetic from a total alone.
- Ranking uses server insertion order for ties and ignores client clock ordering.
- Concurrent submissions preserve unique round IDs and valid top-10 order.

Integration acceptance:

- Durable Object restart or eviction does not lose accepted entries.
- The Godot repository contract passes against a locally running Worker test environment.

### Milestone 12: Leaderboard Abuse Controls And Observability

Implementation:

- Add Turnstile verification for Web submissions and installation/IP rate limiting for cabinet
  requests.
- Add the Web Turnstile token bridge and lifecycle: acquisition, expiry, reset after failure, and
  development/test token injection. The Worker remains the sole verification authority.
- Add request IDs and observability for errors, rejections, latency, and rate-limit events without
  logging unnecessary player data.

Automated acceptance:

- Web submissions reject missing or invalid Turnstile tokens.
- Cabinet and Web requests follow configured rate limits and return structured errors.
- Logs include operation and correlation IDs but omit player names and full submission payloads.
- Rejected and rate-limited requests do not invoke or mutate the Durable Object.

Manual acceptance:

- Using the local Worker environment, valid Web and cabinet requests pass while invalid Turnstile
  and rate-limit cases return the documented errors and safe logs.

### Milestone 13: Staging Leaderboard Integration

Implementation:

- Deploy the Web/Wasm game and API on one staging origin.
- Add the Web export preset, `just web-export`, browser smoke harness, static-asset Worker
  configuration, headers/cache policy, and Web-specific application composition before staging.
- Define Web behavior for marquee windows, browser resize/fullscreen, cabinet exit, local
  settings, Liftie failures, and the touch-only unsupported screen.
- Use the staged same-origin Liftie proxy for Web/Wasm instead of direct browser requests to
  `liftie.info`; the required upstream `LIFTIE_USER_AGENT` is already secret-bound in the Worker.
  Wire the Web client to this endpoint and test the cached-success and `503 unknown` paths.
- Configure staging bindings, secrets, headers, and cache rules.
- Connect cabinet and Web clients to the same staging board.
- Keep production deployment and point-in-time recovery out of this milestone.

Automated acceptance:

- Staging smoke tests fetch the game and call its same-origin API.
- Cabinet and Web repository contract tests pass against the staging API.
- Staging responses use the expected TLS and CORS behavior.

Manual acceptance:

- A cabinet submission appears in the Web leaderboard and vice versa.
- An offline round is not submitted later.
- Refreshing the Web build and restarting the cabinet both preserve accepted staging entries.

### Milestone 14: Leaderboard Recovery Operations

Implementation:

- Add maintenance mode and prevent qualification or submission while it is active.
- Document point-in-time recovery bookmarks, retention, restore, validation, and abort procedures.
- Perform the first restore drill against the staging board.

Automated acceptance:

- Maintenance mode returns `503 BOARD_MAINTENANCE` without changing storage.
- Clients surface maintenance as unavailable and do not queue a retry.

Manual acceptance:

- Point-in-time recovery restores the global board from the selected bookmark.
- Submissions receiving `503 BOARD_MAINTENANCE` show failure and are not queued.

### Milestone 15: Local Game Over And Results Flow

Implementation:

- Add game-over and one-to-three-jump local results screens.
- Connect session phase changes to `ScreenFlowController`.
- Use the in-memory leaderboard fake to defer all online branching and name-entry behavior.
- Add deterministic game-over/results timeout behavior.
- Add Start, Back, pause, and exit behavior for game over and results.

Automated acceptance:

- Game over occurs once after a crash is recorded or the third non-crash tally completes.
- Gameplay physics does not run during game over, qualification, name entry, or results.
- Results contain every recorded jump, from one through three, and the correct total.
- Game over transitions to local results after its configured delay.
- Start, Back, and timeout follow the documented local destinations.
- Timeout and explicit navigation return safely to attract.

Manual acceptance:

- A three-jump non-crash round and crash-ended rounds flow from rider select through game over,
  local results, and back to attract without debug keys or a network connection.

### Milestone 16: Crash Rescue Presentation

Implementation:

- After a crash is recorded, retain the crash-site position and freeze rider gameplay while a
  presentation-only rescue sequence plays before the game-over screen.
- Have a helicopter medic enter the scene from the left and stop at an authored position near the
  crash site.
- Have a skier medic carrying a stretcher enter from the right and stop at an authored position
  near the crash site.
- The rescue sequence may observe the immutable recorded crash result and crash-site position, but
  must not change round state, score, recorded results, or the game-over transition decision.
- Define a minimum readable duration, explicit skip/continue policy, and timeout so the sequence
  cannot block progression.

Automated acceptance:

- A recorded crash starts exactly one rescue sequence and does not permit gameplay physics or input.
- Both rescue actors enter from their specified sides and stop at their authored positions near the
  captured crash site.
- Repeated completion observations, skip input, and timeout cannot start duplicate rescue sequences
  or transition to game over more than once.
- A non-crash terminal outcome never starts the rescue sequence.

Manual acceptance:

- Crashes at representative course locations show the helicopter medic entering from the left and
  the skier medic with stretcher entering from the right, with both stopping clearly near the rider
  before game over proceeds.

### Milestone 17: Qualification, Player Name, And Online Results

Implementation:

- Add cabinet/keyboard player-name entry and connect it to the claimed input owner.
- Integrate asynchronous qualification, availability, submission status, rank, platform source,
  and shared leaderboard data into the post-round flow.
- Add the leaderboard to attract and results presentation.
- Add name-entry timeout and duplicate-submit protection.

Automated acceptance:

- Character navigation wraps and emits only valid normalized player names up to 12 characters.
- Confirm and timeout each send at most one submission while a request is active.
- Non-qualifying and offline scores never open name entry.
- Qualifying, non-qualifying, rejected, submission-timeout, and offline branches reach the
  documented destination.
- Accepted entries display the server-returned rank.
- Leaving results does not queue or retry a failed submission.

Manual acceptance:

- A player name can be entered comfortably using the Sente joystick and buttons without a keyboard.
- Online qualifying, online non-qualifying, submission-failure, and offline rounds, including
  crash-ended rounds, all flow from rider select to results and back without debug keys.

### Milestone 18: Production Audio

Implementation:

- Centralize music and SFX routing.
- Add all required semantic gameplay, tally, game-over, name-entry, and results sounds.
- Consume the authoritative semantic transition records established in Milestones 3 and 7 rather
  than detecting events by polling mutable frame state.
- Add restrained leaderboard-offline feedback.
- Add buses, gain tuning, fades, loop ownership, and asset attribution.

Automated acceptance:

- One-shot events fire once per authoritative transition.
- Reset, pause, screen exit, and game over stop owned loops.
- Rapid score awards remain within the configured tick rate.

Manual acceptance:

- No clipping, inaudible cues, accidental overlap, or orphaned loops occur on cabinet
  speakers during repeated full rounds.

### Milestone 19: Cross-Platform Hardening

Implementation:

- Validate and finalize the solo input router's disconnect, reconnect, and explicit handoff
  behavior across every screen.
- Finalize idle timeouts and AGS exit behavior in every state.
- Validate the authoritative pause policy, late HTTP callbacks, and Web-specific composition in
  addition to cabinet behavior.
- Run focused performance, networking, offline, and Durable Object restart checks.
- Fix all cross-platform defects found by those checks before release packaging.

Automated acceptance:

- `just check`, Worker tests, import, Windows export, Web/Wasm export, and package checks pass.
- Session transition tests cover every phase and timeout.
- Supported desktop browser and cabinet input-policy tests pass.

Manual acceptance:

- Validate fresh install, application update, forced exit, controller disconnect, network loss,
  and restart on the target Sente cabinet.
- Validate supported desktop browsers with keyboard and gamepad, including API outage, refresh
  during results and stale asset-cache recovery. Validate the
  explicit unsupported message on touch-only mobile browsers.
- Validate primary and marquee displays at 30, 60, and 120 FPS.

### Milestone 20: Production Release Gate

Implementation:

- Finalize Web/Wasm headers, cache rules, Worker secrets, production deployment, and rollback
  procedures using the staging deployment proven in Milestone 13.
- Make release archives reproducible by documenting and normalizing input ordering, timestamps,
  permissions, and tool versions; add a two-build artifact/checksum comparison.
- Update README, controls, installer, attribution, operations, and release documentation.
- Run the final abuse, recovery, packaging, deployment, and full-round soak checks.

Automated acceptance:

- `just check`, Worker tests, import, Windows export, Web/Wasm export, and package checks pass from
  a clean checkout.
- Production smoke tests fetch the game, call the same-origin API, submit a test score to an
  isolated board, and verify rollback prerequisites.
- Release artifacts and checksums are reproducible by the documented commands.

Manual acceptance:

- Complete at least 20 consecutive three-jump rounds without leaked audio, duplicate scores,
  blocked screens, input crossover, dead-end navigation, or leaderboard errors.
- Validate Durable Object point-in-time recovery separately against the deployed API.
- Perform and record one rollback drill before approving the release.

## Testing Strategy

Every milestone requires automated and manual acceptance before the next milestone begins.

Add focused suites for:

```text
tests/game/test_round_state.gd
tests/game/test_game_session.gd
tests/game/park/test_rider_low_momentum.gd
tests/game/park/test_jump_scorer.gd
tests/services/test_leaderboard_repository.gd
tests/services/test_remote_leaderboard_repository.gd
tests/presentation/test_score_tally_presenter.gd
tests/presentation/test_player_name_entry.gd
tests/app/test_screen_flow_controller.gd
workers/api/test/leaderboard.test.ts
```

Worker tests use isolated Durable Object namespaces through Cloudflare's Workers test
integration and never target the production board.

Standard checks remain:

```sh
just test
just typecheck
just lint-check
just format-check
just actionlint-check
just export
just web-export
just worker-test
just worker-deploy-dry-run
just package
```

The staged Worker package currently exposes its focused checks as:

```sh
just api test
just api typecheck
```

Add the root `worker-test` and `worker-deploy-dry-run` recipes only when their local and CI
semantics are defined; do not imply they exist before then.

## Production Definition Of Complete

The game is production-ready when:

- One round contains one to three independently resolved jumps; a crash ends the round early.
- Stalled, unrecoverable approaches resolve visibly as low momentum and cannot block the cabinet.
- Every jump outcome records once and advances the round, except a crash, which ends it.
- Scoring is deterministic, tested, understandable, and no longer uses legacy zero-score
  scaffolding.
- HUD score and `n / 3` jump count remain correct throughout the round.
- Point animations present resolved scores without owning them.
- Game over, name entry, results, restart, timeout, and attract transitions all work.
- Cabinet and Web/Wasm display the same Cloudflare-authoritative top-10 leaderboard.
- Offline rounds still show complete local results but skip qualification, name entry, and shared
  submission.
- Web and cabinet submissions are idempotent, validated, and visibly identify their platform
  under the documented casual-board threat model.
- Network, Worker, and Durable Object failures degrade safely without preventing gameplay or
  corrupting accepted scores.
- Cloudflare point-in-time recovery has a tested restore procedure.
- Gameplay and UI sounds cover all important actions and state transitions.
- Solo controller ownership and disconnect behavior are reliable on the Sente cabinet.
- All automated checks, Windows and Web/Wasm exports, Worker deployment checks, API tests,
  full-round soak tests, and cabinet/browser acceptance tests pass.
- No known blocker, data-loss issue, dead-end screen, or developer-only navigation remains.
