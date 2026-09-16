# Plan 00: Launch compatibility spike

## Goal

Produce the smallest possible Windows build that can be installed in Polycade AGS and proves the cabinet integration works. This is a diagnostic spike, not the first version of the actual mountain.

Stop after this plan and test it on the Polycade before implementing any game systems, mocked API model, or production visuals.

## Expected result

- AGS launches `HEAVENLY.exe` like any other game.
- The primary display shows a moving blue test scene with `HEAVENLY` in large type.
- When the marquee is connected, it shows a separate moving gold test scene.
- When the marquee is absent, the primary experience runs normally by itself.
- Both windows close when Escape is pressed or Start and Back are held for two seconds.
- A GitHub Actions run produces a downloadable Windows ZIP that contains the game folder.

## Deliberate non-goals

- No Heavenly API or mock API response.
- No mountain, lifts, snow, audio, or final artwork.
- No visible settings screen.
- No automatic hot-plug recovery.
- No generalized display configuration system.
- No tests beyond what is needed to prove launch and window behavior.

## Project setup

1. Install the pinned Godot 4.6 patch release and its export templates on the Mac.
2. Create a Godot project using GDScript and the Compatibility renderer.
3. Set the application name to `HEAVENLY`.
4. Set the primary design size to 1920 x 1080.
5. Disable embedded subwindows so a child `Window` becomes a native operating-system window.
6. Configure input actions for Escape, controller Start, and controller Back.
7. Add a Windows Desktop export preset targeting `build/HEAVENLY/HEAVENLY.exe`.
8. Ignore generated `.godot/` and `build/` directories in Git.

Commit the exact Godot patch version to a small text file or workflow environment variable. Do not develop against one patch release and export from another without intentionally testing that combination.

## macOS development loop

1. Open and run the project in the macOS Godot editor for normal development.
2. On a one-display Mac, run only the primary scene; absence of a marquee is normal behavior.
3. On a multi-display Mac, allow the diagnostic marquee to open, but treat Windows cabinet results as authoritative.
4. Run a headless import check before pushing when practical.
5. Push the branch and let GitHub Actions create the Windows build used for cabinet testing.

Godot can cross-export Windows packages from macOS when Windows export templates are installed. That is useful for local inspection, but the GitHub Actions output is the canonical cabinet build so packaging is repeatable.

## Minimal file shape

Keep the spike small. Suggested files:

```text
project.godot
export_presets.cfg
.github/
  workflows/
    windows-build.yml
src/
  main.tscn
  main.gd
```

`main.gd` may own display setup, diagnostic rendering, and exit input for this spike. Do not introduce services or abstractions yet.

## GitHub Actions Windows build

Create `.github/workflows/windows-build.yml` as part of this plan.

1. Trigger it on pull requests, pushes to the default branch, version tags matching `v*`, and manual `workflow_dispatch` runs.
2. Use a pinned Ubuntu runner image and a pinned Godot 4.6 editor release.
3. Install the matching official Windows export templates in Godot's expected Linux template directory.
4. Run a headless project import/check before export.
5. Export with `godot --headless --path . --export-release "Windows Desktop" build/HEAVENLY/HEAVENLY.exe`.
6. Archive the complete `HEAVENLY` directory as `HEAVENLY-windows-x86_64.zip`.
7. Generate `HEAVENLY-windows-x86_64.zip.sha256`.
8. Upload both files with `actions/upload-artifact`, using a short retention period such as 14 days.
9. Give ordinary build jobs only `contents: read` permission.
10. On `v*` tags, give a separate release job `contents: write` permission and attach the ZIP and checksum to a GitHub Release.

Pin third-party actions to immutable commit SHAs where practical. Prefer official Godot downloads and official GitHub actions over an opaque Godot-export action so the exact editor and template versions are visible in the workflow.

Workflow artifacts require GitHub read access and expire. GitHub Release assets are the durable installation and update path for the Polycade machine.

## Display behavior

1. Read `DisplayServer.get_screen_count()` during startup.
2. If two or more screens exist, put the primary window on Godot screen index 1 and create the marquee on screen index 0.
3. If only one screen exists, put the primary window on screen index 0 and do not create the marquee.
4. Make each created window borderless and size it to its selected screen's position and dimensions.
5. Render separate content in each window so mirroring is immediately obvious.
6. Temporarily show the selected Godot screen index, detected resolution, and screen position in each scene.
7. Log all detected screen information at startup.

Windows Display #1 is expected to correspond to Godot index 0 and Windows Display #2 to Godot index 1, but that mapping must be verified on the cabinet. If it is reversed, change the two constants rather than adding a settings UI.

## Visual behavior

Primary scene:

- Solid dark-blue background.
- Large centered `HEAVENLY` title.
- A rectangle moving horizontally to prove continuous rendering.
- Small temporary text identifying the window as `PRIMARY`.

Marquee scene:

- Solid dark-gold background.
- Wide `HEAVENLY` title sized for 1920 x 360.
- A line or rectangle moving in the opposite direction.
- Small temporary text identifying the window as `MARQUEE`.

Use built-in shapes and a bundled font or Godot's default font. Do not spend time on art.

## Exit behavior

1. Escape exits immediately.
2. Holding controller Start and Back together begins a two-second timer.
3. Releasing either button resets the timer.
4. Reaching two seconds quits the scene tree so the process and both windows close together.
5. Closing the primary native window also exits the process.

## Build and install

1. Push the implementation branch or manually dispatch the Windows build workflow.
2. Wait for the workflow's import and export steps to pass.
3. Download the `HEAVENLY-windows-x86_64` artifact on the Polycade machine.
4. Verify and extract the packaged ZIP using [WINDOWS-INSTALL.md](WINDOWS-INSTALL.md).
5. Confirm the package contains `HEAVENLY.exe` and any required Godot `.pck` file.
6. Confirm the folder and executable are both named exactly `HEAVENLY`.
7. Add or rescan the game in AGS using its local-game workflow.
8. Launch it from the AGS selector with the cabinet A button.

Do not optimize for a single-file executable during this spike. AGS only needs a stable executable entry point; required sidecar files can remain beside it.

## Cabinet test matrix

Run every case before proceeding:

| Case | Expected behavior |
| --- | --- |
| Both displays connected | Primary and marquee content appear on the correct displays |
| Only primary connected | Primary launches; no second window or visible error appears |
| Launch from AGS | Starts without desktop interaction or browser chrome |
| CI artifact install | Downloaded ZIP extracts with the expected folder and executable names |
| Escape pressed | Both windows and the process close |
| Start + Back held | Both windows and the process close after two seconds |
| Start + Back tapped | Application continues running |
| Thirty-minute run | Motion continues without sleep, crash, or window movement |
| Relaunch after exit | Both windows return to the expected displays |

Also check Windows taskbar visibility, focus behavior, scaling, and whether the marquee window steals controller input from the primary.

## Completion record

Fill this in after testing:

```text
Date tested:
AGS version:
Git commit and Actions run:
Godot patch version:
Godot-to-Windows display mapping:
Primary detected resolution and position:
Marquee detected resolution and position:
Controller name reported by Godot:
Exit combination result:
Taskbar/focus observations:
Changes required before Plan 01:
```

## Done when

The spike passes the cabinet test matrix and any discovered display mapping is recorded. Remove no diagnostics yet; they remain useful while implementing Plan 01.
