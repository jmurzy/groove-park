# Plan 04: Live data resilience

## Goal

Build resilience around the implemented Liftie adapter while preserving its normalized state contract and arcade presentation.

The initial Liftie endpoint integration is complete in Plan 01. Before adding caching or changing refresh behavior, confirm the current API requirements and representative responses.

## API assessment

Before writing the adapter, record:

- Base URL and endpoint.
- Authentication method.
- Whether credentials may safely ship in a client executable.
- Rate limits and recommended refresh interval.
- Lift identifiers and possible status values.
- Timestamp semantics and resort timezone.
- Error response shape.
- Terms governing caching and redistribution.

If the API requires a secret that must not be distributed, add a small server-side proxy rather than embedding the secret in `HEAVENLY.exe`.

## Data flow

```text
Liftie API or proxy
        |
        v
LiftieStateService
        |
        v
normalized MountainState
        |
        +--> primary presenter
        +--> optional marquee presenter
        +--> last-known-good cache
```

## Runtime behavior

1. Load the last-known-good cache during startup.
2. If no cache exists, publish the existing neutral `unknown` state so rendering starts immediately.
3. Request live data asynchronously after the first frame.
4. Validate and normalize the response before publishing it.
5. Save only valid normalized state to the cache.
6. Refresh no more frequently than the API permits; begin with five minutes unless documentation says otherwise.
7. Add bounded retry delays after failures rather than retrying every frame.
8. Continue displaying the last valid state through network and API failures.
9. Log failures without placing error dialogs or app-style warnings on either display.

## Staleness

Track when the upstream data was observed and when it was fetched. Stale data may receive a subtle in-world treatment, but the application must not turn into an error screen.

## Verification

1. Test valid, malformed, partial, empty, unauthorized, rate-limited, and server-error responses.
2. Test startup online, offline with cache, and offline without cache.
3. Interrupt networking during refresh and confirm animation continues.
4. Confirm invalid responses never overwrite a valid cache.
5. Confirm refreshes do not cause frame hitches or reset animations.
6. Confirm primary-only operation remains unchanged.

## Done when

Live lift changes reach both displays, failures remain invisible to the arcade presentation, and the application can start and run indefinitely without network access.
