# Plan 01: Live-data vertical slice

## Goal

Replace the Plan 00 diagnostic patterns with a minimal, recognizable HEAVENLY experience driven by the implemented Liftie endpoint. One normalized live state drives both displays without requiring the marquee.

## Expected result

- The primary display presents a simple animated mountain, falling snow, and a moving lift.
- The marquee presents a purpose-built HEAVENLY animation and concise lift status.
- A single Liftie request is normalized once and published to both scenes.
- Primary-only mode remains fully functional when the marquee is disconnected.

## Data boundary

`LiftieStateService` owns the Liftie HTTP request, refresh interval, JSON parsing, and normalization. It publishes only a small state dictionary:

```text
status: open | closed | hold | unknown
open_count, hold_count, closed_count, total_count
```

Rendering code consumes that normalized state and never parses Liftie responses. `open` takes priority when any lift is open; otherwise `hold`, then `closed` when reported lifts exist, with `unknown` as the fallback.

## Primary scene

1. Draw layered mountain silhouettes at the 1920 x 1080 design resolution.
2. Add continuous snowfall.
3. Draw one cable and several chairs moving while the normalized state is `open`.
4. Stop and dim chairs when `closed`.
5. Pulse an amber terminal indicator when `hold`.
6. Use a neutral treatment for `unknown`.
7. Avoid panels, tables, buttons, charts, and dashboard layouts.

## Marquee scene

1. Design directly for 1920 x 360 rather than cropping or mirroring the mountain.
2. Make `HEAVENLY` the dominant element.
3. Show a short phrase derived from the shared normalized state.
4. Add restrained continuous motion and keep content inside a generous safe area.

## Diagnostics

Plan 00 diagnostics remain available only through the `--diagnostics` development argument and are hidden during a normal AGS launch.

## Verification

1. Confirm the endpoint result updates both displays from the same service request.
2. Exercise `open`, `closed`, `hold`, and unavailable/invalid responses.
3. Launch with the marquee connected and disconnected.
4. Confirm controller exit behavior still works.
5. Run from AGS for at least thirty minutes.

## Done when

HEAVENLY is recognizable as a tiny arcade presentation, both scenes react to one live normalized state, and no part of the application requires the marquee to exist.
