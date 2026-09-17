# Plan 02: Gunbarrel 25 mountain world

## Goal

Turn the vertical slice into the attract mode for a future arcade ski game. The primary display introduces `GUNBARREL 25` through a vivid, kinetic Heavenly mountain scene; the optional marquee continuously reports mock lift statuses.

`GUNBARREL 25` refers to Heavenly's extreme spring endurance challenge: 25 laps down the mogul-packed Gunbarrel run. This plan establishes the world, visual identity, and boundaries that gameplay will use later. It does not implement a playable run.

## Visual direction

- Take inspiration from colorful arcade ski attract screens: saturated alpine blue, magenta and warm sunset accents, crisp white snow, bold outlines, and angular highlights.
- Use an included, permissively licensed arcade display font for titles and a highly legible companion face for small status text. Do not depend on fonts installed on the cabinet.
- Make `GUNBARREL 25` the primary lockup, with concise event copy such as `25 LAPS. ONE LEGENDARY RUN.`
- Avoid dashboard panels, cards, glass effects, and generic modern product UI.
- Build at the 1920 x 1080 primary design resolution and retain a dedicated 1920 x 360 marquee composition.

## Primary composition

1. Establish a reusable mountain coordinate system with a foreground Gunbarrel mogul run, a skier or snowboarder attract-mode character, lift routes, trees, stations, terrain layers, and distant Tahoe atmosphere.
2. Place the `GUNBARREL 25` lockup in the upper-right clear of the primary action.
3. Add non-functional game-facing affordances for the future game: a `LAP 01 / 25` placeholder and a subtle `PRESS START` attract prompt.
4. Keep the mountain alive with snow, rider motion, lift movement, and environmental motion even when every lift is closed.
5. Create all visual elements with clear layering so a later playable camera/rider can replace the attract-mode foreground without rebuilding the mountain or the marquee.

## Mock mountain state

Ignore live Liftie responses in this milestone. Use a local normalized `MountainState` source that publishes per-lift records with stable IDs, display names, and `open`, `hold`, or `closed` statuses. It must be replaceable by the existing Liftie adapter later without changing presenter contracts.

Start with this recognizable Heavenly roster:

| ID | Display name | Mock status | Presentation role |
| --- | --- | --- | --- |
| `heavenly-gondola` | Heavenly Gondola | Open | Large recognizable gondola and village-to-mountain route |
| `gunbarrel-express` | Gunbarrel Express | Open | Featured lift beside the Gunbarrel run |
| `powderbowl-express` | Powderbowl Express | Open | Fast moving background chairlift |
| `sky-express` | Sky Express | Hold | Amber weather-hold focal point |
| `dipper-express` | Dipper Express | Closed | Cool, inactive distant lift |

Derive the marquee counts from these records: `3 OPEN`, `1 HOLD`, and `1 CLOSED`. These statuses are authored demo data, not current resort conditions.

Do not add fixtures that imitate the upstream API. Any development scenario must supply the normalized internal model directly.

## Status behavior

| Status | Mountain behavior | Marquee behavior |
| --- | --- | --- |
| Open | Vehicles move, stations glow, and route accents are bright | Included in the persistent open count and eligible for featured rotation |
| Closed | Vehicles stop in place; route and station cool and dim | Included in the closed count; only featured when useful to the composition |
| Hold | Vehicles pause in place; station beacon pulses amber | Short `WIND HOLD` callout with amber treatment |
| Unknown | Neutral inactive treatment without error messaging | Omit from callouts and use a quiet neutral count if needed |

Status changes must interpolate colors, lights, and vehicle speed. They must never snap vehicles back to the beginning of their paths.

## Marquee composition

- Keep `GUNBARREL 25` visible as the marquee identity.
- Maintain a compact, persistent status strip: `3 OPEN · 1 HOLD · 1 CLOSED`.
- Cycle a featured lift callout independently, for example `SKY EXPRESS / WIND HOLD`.
- Use route lines, snowfall, or contour motion as supporting visuals; the marquee must remain readable at a distance.
- The marquee remains optional. Its absence cannot affect state, animation, or timing on the primary display.

## Architecture boundary

Keep these responsibilities separate:

- A mock mountain-state source publishes the normalized per-lift `MountainState` used in this plan.
- The app controller owns the current mountain and game presentation state and publishes changes through direct Godot signals.
- Primary and marquee presenters translate normalized mountain state into visual behavior.
- Individual lift scenes own their route, vehicle drawing, and animation details.
- A minimal game-presentation state (`attract`, `playing`, `results`) defines the future handoff. Only `attract` is implemented in this plan.
- The existing Liftie service stays isolated as a future data source; it does not influence this milestone's visuals.

Avoid a generic event bus unless direct Godot signals become genuinely difficult to manage.

## Verification

1. Confirm the mock roster always produces `3 OPEN`, `1 HOLD`, and `1 CLOSED` on the marquee.
2. Cycle every normalized status without restarting and confirm the corresponding lift alone changes behavior.
3. Confirm open, hold, and closed changes preserve each vehicle's route position while transitioning speed and color.
4. Confirm the primary reads as an arcade game attract screen, not a lift-status dashboard.
5. Confirm the marquee is absent in primary-only mode and remains functional in `--sente` development mode.
6. Confirm all title and status text renders from bundled fonts on a clean Windows export.
7. Profile the cabinet build with every lift, snowfall, and foreground attract animation active.

## Done when

The cabinet presents a coherent `GUNBARREL 25` arcade world with recognizable Heavenly lifts, credible per-lift mock statuses, and an optional status-focused marquee, while preserving a clean boundary for future gameplay and live data.
