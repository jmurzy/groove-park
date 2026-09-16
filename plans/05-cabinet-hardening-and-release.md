# Plan 05: Cabinet hardening and release

## Goal

Turn the validated application into a repeatable release that behaves predictably under cabinet startup, shutdown, display changes, and network failures.

## Display hardening

1. Detect available screens before creating the marquee window.
2. Keep primary-only startup as a first-class supported mode.
3. Poll or subscribe to display topology changes using the most reliable Godot/Windows mechanism available.
4. If the marquee disconnects while running, remove or hide its window without disturbing the primary scene.
5. For the initial release, wait until the next application launch before restoring a reconnected marquee.
6. Never move the marquee onto the primary display as a fallback.
7. Persist cabinet display assignments only if fixed indices prove unreliable.

## Lifecycle hardening

- Ensure AGS termination closes every window and stops pending requests.
- Ensure closing the primary window quits the process.
- Ensure closing only the marquee does not quit the primary experience.
- Handle Windows sleep, wake, focus loss, and display power cycling.
- Keep controller input scoped to the active game process.
- Prevent duplicate instances if AGS launches twice accidentally.

## Performance and endurance

1. Profile CPU, GPU, and memory use on the Sente PC.
2. Run a minimum eight-hour soak test.
3. Verify frame pacing independently on the 75 Hz primary and 60 Hz marquee.
4. Cap expensive effects rather than scaling work without bounds.
5. Confirm logs and caches have bounded size.

## Release package

Produce:

```text
HEAVENLY/
  HEAVENLY.exe
  HEAVENLY.pck
  ...required runtime files
```

Also produce AGS library artwork in the dimensions and formats required by the installed AGS version. Keep release artifacts out of source control unless the repository later adopts versioned releases.

The GitHub Actions workflow introduced in Plan 00 remains the only canonical release builder. A version tag matching `v*` must create a GitHub Release containing the Windows ZIP and its SHA-256 checksum. Do not commit generated executables to the repository.

## Distribution and updates

1. Document the currently supported update procedure in [WINDOWS-INSTALL.md](WINDOWS-INSTALL.md).
2. Test installation from a workflow artifact for pre-release cabinet checks.
3. Test installation from a tagged GitHub Release for normal use.
4. Verify a clean installation and an in-place upgrade.
5. Keep save data, settings, logs, and cache under `user://` so replacing the application directory does not delete them.
6. Record the release version and Git commit in startup logs.
7. Add Windows code signing later if SmartScreen friction justifies acquiring a trusted signing certificate; never place signing credentials in the repository.

## Release checklist

- Fresh install launches from AGS.
- GitHub Actions can rebuild the package from a clean checkout.
- Tagged builds publish the ZIP and checksum to GitHub Releases.
- The cabinet installation guide matches the released archive layout.
- Upgrade preserves only intentional local settings and cache.
- Both-display and primary-only configurations pass.
- Controller and keyboard exit paths pass.
- Offline, stale-cache, and API-failure cases pass.
- Sleep/wake and display power-cycle cases pass.
- Eight-hour soak test passes.
- No browser chrome, debug overlays, console windows, or settings UI appear.
- No API secrets are present in the package or repository.
- Version and build information are available in logs.

## Done when

A fresh Windows installation can receive the release directory, add HEAVENLY to AGS, and run the intended cabinet experience without developer tools or manual window placement.
