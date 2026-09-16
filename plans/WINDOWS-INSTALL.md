# Install HEAVENLY on the Polycade PC

Use a tagged GitHub Release for normal installation. Use a GitHub Actions artifact only when testing an unreleased change.

## AGS location and DRM status

Install the complete game directory here, replacing `%USERNAME%` with the Windows account that runs AGS:

```text
C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\HEAVENLY\HEAVENLY.exe
```

The required final layout is:

```text
C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\
  HEAVENLY\
    HEAVENLY.exe
    HEAVENLY.pck
    ...other files from the release ZIP...
```

Polycade documents this as the location for [DRM-free games or any Windows executable](https://help.apphq.co/api/articles/30281). The HEAVENLY GitHub Release ZIP is a DRM-free installation: it runs from its extracted files, does not require a Polycade store entitlement or Polycade sign-in, and should not be copied into Steam, GOG, or Itch.io directories. AGS may still offer optional account and store features; those do not apply to this local installation.

The installer writes to both locations in one run and pre-creates them, so AGS does not need to run first. `Install.ps1` copies `game\` to `games\drm-free\HEAVENLY` and `artwork\` to `assets\drm-free\HEAVENLY`. Do not copy game files into the artwork directory or artwork files into the game directory.

Supported artwork names are lowercase (per [Polycade's official guide](https://polycade.gorgias.help/en-US/adding-custom-images-for-games-1106271); each can be jpg or png — close AGS before copying files in):

| file | use | size (official) |
|---|---|---|
| `header` | library tile | `460x215` |
| `hero` | detail view after selection | `1200x675` |
| `logo` | logo overlay (transparent) | variable size |
| `marquee` | digital marquee screen | `1920x360` |
| `instructions` | controls/how-to overlay (png) | `1920x846` |

Note: community reports mention `1920x1080` for hero working too, but the official spec is `1200x675` — prefer the official size. `background.png` / `icon.png` appear only in forum posts, not in the official guide, so treat them as unconfirmed. AGS may append a hash suffix to artwork filenames after its first scan (for example `headerabc123.png`); ship clean names and let AGS rename them.

## Option A: Install a release

1. On the Polycade Windows PC, open this repository's GitHub page.
2. Open **Releases** and select the latest intended HEAVENLY version.
3. Download `HEAVENLY-windows-x86_64.zip` and `HEAVENLY-windows-x86_64.zip.sha256` from the release assets.
4. Open PowerShell in the Downloads directory and run:

```powershell
Get-FileHash .\HEAVENLY-windows-x86_64.zip -Algorithm SHA256
Get-Content .\HEAVENLY-windows-x86_64.zip.sha256
```

5. Confirm the two displayed hashes match. Do not install the archive if they differ.
6. Right-click the ZIP, select **Extract All**, and extract it to any temporary folder (for example Downloads). The extracted folder contains `Install.ps1` next to `game\` and `artwork\`.
7. In the extracted folder, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

8. Confirm the script reports both `games\drm-free\HEAVENLY\HEAVENLY.exe` and `assets\drm-free\HEAVENLY\`, not an extra nested directory such as `HEAVENLY\HEAVENLY\HEAVENLY.exe`.
9. Start or restart AGS so it discovers the local executable.
10. Confirm HEAVENLY appears in the selector, then launch it with the cabinet A button.

## Option B: Install a test artifact

1. Sign in to GitHub with an account that has read access to the repository.
2. Open the repository's **Actions** tab.
3. Select the **Windows build** workflow.
4. Open the latest successful run for the commit being tested.
5. In the run's **Artifacts** section, download `HEAVENLY-windows-x86_64`.
6. Extract GitHub's outer artifact ZIP.
7. Verify the enclosed `HEAVENLY-windows-x86_64.zip` against its `.sha256` file as described above.
8. Extract the verified game ZIP to a temporary folder and run `powershell -ExecutionPolicy Bypass -File .\Install.ps1` from the extracted folder, so the executable ends at `...\games\drm-free\HEAVENLY\HEAVENLY.exe` and artwork is pre-seeded under `...\assets\drm-free\HEAVENLY\`.
9. Start or restart AGS, confirm it finds HEAVENLY, and launch it.

Workflow artifacts are temporary and may require authentication. They are for development testing, not permanent distribution.

## Update an existing installation

1. Exit HEAVENLY and return to AGS.
2. Download and verify the new release.
3. Keep the existing installation until the new ZIP passes checksum verification.
4. Extract the new ZIP to a temporary folder and re-run `Install.ps1`; it overwrites the game files and merges artwork in place.
5. Confirm the path still ends in `games\drm-free\HEAVENLY\HEAVENLY.exe` and artwork is under `assets\drm-free\HEAVENLY\`.
6. Restart AGS only if it no longer finds the game.
7. Launch HEAVENLY and confirm both primary-only and dual-display behavior as applicable.

Runtime settings and cached lift data will live outside the application directory in Godot's `user://` location, so replacing the release directory should not remove them.

## Windows warnings

Early unsigned builds may trigger Microsoft Defender SmartScreen. Only continue when the ZIP came from this repository's expected Actions run or Release and its SHA-256 checksum matches. Code signing can be added in a later release-hardening milestone.

## Troubleshooting

| Problem | Check |
| --- | --- |
| AGS cannot find the game | Confirm the executable is at `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\HEAVENLY\HEAVENLY.exe`; the folder and executable names must be similar |
| Windows says the executable is missing | Re-run `Install.ps1` from the fully extracted ZIP; do not copy only the `.exe` |
| PowerShell blocks Install.ps1 | Run it as `powershell -ExecutionPolicy Bypass -File .\Install.ps1` from the extracted folder |
| Artwork does not appear | Confirm lowercase names (`header.png`, `hero.png`, `marquee.png`) under `assets\drm-free\HEAVENLY\`; uppercase names are ignored by AGS |
| Marquee does not appear | Confirm Windows detects both extended displays; primary-only mode is valid |
| Marquee appears on the wrong screen | Record Windows and Godot screen mappings in Plan 00's completion record |
| Both windows remain after exit | Record whether Escape and Start + Back behave differently |
| Artifact is unavailable | Artifacts expire; run the workflow again or install a tagged Release |
