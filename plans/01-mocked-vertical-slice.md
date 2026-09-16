# Plan 01: Mocked vertical slice

## Goal

Replace the diagnostic test patterns with a minimal but recognizable HEAVENLY experience. Prove that one mocked lift response can drive both displays without adding live networking.

## Expected result

- The primary display presents a simple animated mountain, falling snow, and one moving lift.
- The marquee presents a purpose-built HEAVENLY animation and concise lift status.
- Changing the bundled JSON fixture visibly changes both scenes.
- Primary-only mode remains fully functional when the marquee is disconnected.

## Data boundary

Add a bundled fixture at `data/mock_heavenly.json` with a stable, intentionally small schema:

```json
{
  "resort": "Heavenly",
  "updated_at": "2026-09-16T15:00:00Z",
  "lifts": [
    { "id": "tram", "name": "Aerial Tram", "status": "open" },
    { "id": "gunbarrel", "name": "Gunbarrel Express", "status": "closed" },
    { "id": "tamarack", "name": "Tamarack Express", "status": "hold" }
  ]
}
```

Normalize statuses to `open`, `closed`, `hold`, and `unknown`. Rendering code must consume normalized state rather than parsing JSON itself.

## Suggested file shape

```text
data/
  mock_heavenly.json
src/
  app.gd
  data/
    lift_data_source.gd
    mock_lift_data_source.gd
  model/
    mountain_state.gd
  primary/
    mountain.tscn
    mountain.gd
  marquee/
    marquee.tscn
    marquee.gd
```

Keep `LiftDataSource` as a small contract that returns normalized state. Do not design the live HTTP implementation yet.

## Primary scene

1. Draw a layered mountain silhouette at the 1920 x 1080 design resolution.
2. Add a looping snow particle effect.
3. Add one lift cable and several chairs moving along it.
4. Animate chairs normally when the mocked lift is open.
5. Stop chairs and dim the lift when closed.
6. Pulse an amber indicator when on hold.
7. Use `unknown` as a neutral fallback rather than treating it as open.
8. Avoid panels, tables, buttons, charts, and dashboard layouts.

## Marquee scene

1. Design directly for 1920 x 360 rather than cropping or mirroring the mountain.
2. Make `HEAVENLY` the dominant element.
3. Show a short status phrase derived from the same mountain state.
4. Add restrained continuous motion so the marquee feels alive at a glance.
5. Keep essential content inside a generous safe area for physical cabinet masking.

## Diagnostics

Keep the Plan 00 screen diagnostics available behind a development flag or command-line argument. They must be hidden during a normal AGS launch.

## Verification

1. Run with the fixture's lift set to `open`, `closed`, `hold`, and an unsupported value.
2. Confirm both displays reflect each normalized status.
3. Launch with the marquee connected and disconnected.
4. Confirm controller exit behavior still works.
5. Run from AGS for at least thirty minutes.

## Done when

HEAVENLY is recognizable as a tiny arcade presentation, both scenes react to the same mocked state, and no part of the application requires the marquee to exist.
