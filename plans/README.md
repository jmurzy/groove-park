# HEAVENLY implementation plans

Implement these plans in numerical order. Each plan ends with a usable milestone and has an explicit stop point for testing before more scope is added.

| Order | Plan | Result |
| --- | --- | --- |
| 00 | [Launch compatibility spike](00-launch-compatibility-spike.md) | The smallest Windows build that AGS can launch on the cabinet |
| 01 | [Mocked vertical slice](01-mocked-vertical-slice.md) | A recognizable tiny arcade experience driven by fixture data |
| 02 | [Mountain world](02-mountain-world.md) | A complete stylized mountain with multiple animated lifts |
| 03 | [Ambient presentation](03-ambient-presentation.md) | A polished, continuously changing attract-mode experience |
| 04 | [Live lift data](04-live-lift-data.md) | Resilient live updates with caching and offline fallback |
| 05 | [Cabinet hardening and release](05-cabinet-hardening-and-release.md) | A repeatable, cabinet-ready release package |

## Fixed decisions

- Use Godot 4.6, GDScript, and the Compatibility renderer.
- Use macOS as the primary development environment.
- Keep the Godot editor and export-template patch version identical locally and in CI.
- Build canonical Windows packages with GitHub Actions.
- Publish short-lived test builds as workflow artifacts and tagged builds as GitHub Releases.
- Export one Windows process named `HEAVENLY.exe`.
- Render the game and marquee in independent native windows.
- Target the primary game display at 1920 x 1080 and 75 Hz.
- Target the optional marquee at 1920 x 360 and 60 Hz.
- Treat the marquee as an enhancement, never a requirement.
- If only one display is connected, do not create a marquee window.
- Never place marquee content on the primary display as a fallback.
- Exit with Escape or by holding controller Start and Back for two seconds.
- Keep settings, diagnostics, and network failures out of the presentation.

## Working rule

Do not begin the next plan until the current plan's acceptance checks pass on the Polycade. Record cabinet-specific findings in the completed plan before continuing.

Use [WINDOWS-INSTALL.md](WINDOWS-INSTALL.md) when transferring a CI build to the Polycade PC.
