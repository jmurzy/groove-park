# Plan 02: Mountain world

## Goal

Expand the vertical slice into a coherent mountain world with multiple lifts and data-driven visual behavior using the normalized Liftie state service.

## Scope

- Establish the final coordinate system and composition for the mountain.
- Add all lifts intended for the first release, using stable internal IDs.
- Give each lift a cable path, chair animation, and recognizable location.
- Add terrain layers, trees, buildings, and atmospheric depth.
- Add smooth transitions when lift statuses change.
- Expand marquee compositions to summarize overall mountain activity.

## State scenarios

Exercise the presenter with injected normalized state during development for:

- Normal operating day.
- Most lifts closed.
- Wind holds.
- Unknown or incomplete data.
- Status changes during runtime.
- Stale data.

Do not add fixtures that imitate the upstream API. Test helpers, if needed, must provide the normalized internal model directly.

## Status behavior

| Status | Mountain behavior | Marquee behavior |
| --- | --- | --- |
| Open | Chairs move; station appears active | Included in open count or featured rotation |
| Closed | Chairs stop; colors cool and dim | Shown only when composition calls for closures |
| Hold | Chairs pause; subtle amber signal animates | Short hold callout |
| Unknown | Neutral inactive treatment | No alarming error language |

Status changes should transition rather than abruptly replacing the scene. The mountain remains visually alive even when all lifts are closed.

## Architecture boundary

Keep these responsibilities separate:

- Data sources produce normalized `MountainState` values.
- The app controller owns the current state and publishes changes.
- Primary and marquee presenters translate state into visual behavior.
- Individual lift scenes own path and chair animation details.

Avoid a generic event bus unless direct Godot signals become genuinely difficult to manage.

## Verification

1. Cycle through every normalized state without restarting.
2. Confirm all state transitions are deterministic and recoverable.
3. Confirm unsupported and missing values resolve to `unknown` without crashing.
4. Confirm the marquee remains optional in every scenario.
5. Profile the cabinet build with all lift and snow animation active.

## Done when

The complete mountain reacts coherently to a range of live-data operating conditions and maintains smooth cabinet performance.
