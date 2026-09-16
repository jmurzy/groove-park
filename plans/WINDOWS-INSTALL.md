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

After AGS discovers the game, it creates a separate artwork directory at `C:\Users\%USERNAME%\AppData\Roaming\polycade\assets\drm-free\HEAVENLY`. Keep the release files in `games\drm-free\HEAVENLY`; do not put them in the artwork directory.

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
6. Right-click the ZIP, select **Extract All**, and extract it to `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\`. The extraction must create `HEAVENLY` directly inside `drm-free`.
7. Ensure the final layout is `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\HEAVENLY\HEAVENLY.exe`, not an extra nested directory such as `HEAVENLY\HEAVENLY\HEAVENLY.exe`.
8. Start or restart AGS so it discovers the local executable.
9. Confirm HEAVENLY appears in the selector, then launch it with the cabinet A button.

## Option B: Install a test artifact

1. Sign in to GitHub with an account that has read access to the repository.
2. Open the repository's **Actions** tab.
3. Select the **Windows build** workflow.
4. Open the latest successful run for the commit being tested.
5. In the run's **Artifacts** section, download `HEAVENLY-windows-x86_64`.
6. Extract GitHub's outer artifact ZIP.
7. Verify the enclosed `HEAVENLY-windows-x86_64.zip` against its `.sha256` file as described above.
8. Extract the verified game ZIP to `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\` so the executable ends at `...\drm-free\HEAVENLY\HEAVENLY.exe`.
9. Start or restart AGS, confirm it finds HEAVENLY, and launch it.

Workflow artifacts are temporary and may require authentication. They are for development testing, not permanent distribution.

## Update an existing installation

1. Exit HEAVENLY and return to AGS.
2. Download and verify the new release.
3. Keep the existing installation until the new ZIP passes checksum verification.
4. Replace `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\HEAVENLY` with the newly extracted directory.
5. Confirm the path still ends in `drm-free\HEAVENLY\HEAVENLY.exe`.
6. Restart AGS only if it no longer finds the game.
7. Launch HEAVENLY and confirm both primary-only and dual-display behavior as applicable.

Runtime settings and cached lift data will live outside the application directory in Godot's `user://` location, so replacing the release directory should not remove them.

## Windows warnings

Early unsigned builds may trigger Microsoft Defender SmartScreen. Only continue when the ZIP came from this repository's expected Actions run or Release and its SHA-256 checksum matches. Code signing can be added in a later release-hardening milestone.

## Troubleshooting

| Problem | Check |
| --- | --- |
| AGS cannot find the game | Confirm the executable is at `C:\Users\%USERNAME%\AppData\Roaming\polycade\games\drm-free\HEAVENLY\HEAVENLY.exe`; the folder and executable names must be similar |
| Windows says the executable is missing | Re-extract the complete ZIP; do not copy only the `.exe` |
| Marquee does not appear | Confirm Windows detects both extended displays; primary-only mode is valid |
| Marquee appears on the wrong screen | Record Windows and Godot screen mappings in Plan 00's completion record |
| Both windows remain after exit | Record whether Escape and Start + Back behave differently |
| Artifact is unavailable | Artifacts expire; run the workflow again or install a tagged Release |
