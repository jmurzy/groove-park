# Override this when Godot is installed somewhere other than the standard
# Homebrew cask location, for example: GODOT_BIN=godot just run.
godot_bin := env_var_or_default("GODOT_BIN", "/Applications/Godot 4.6.3.app/Contents/MacOS/Godot")

# List available development commands.
default:
    @just --list

# Confirm the selected Godot executable matches the project's pinned version.
version:
    @expected=$(tr -d '[:space:]' < .godot-version); actual=$("{{ godot_bin }}" --version); case "$actual" in "$expected".*) ;; *) printf 'Expected Godot %s, found %s\n' "$expected" "$actual" >&2; exit 1 ;; esac
    @"{{ godot_bin }}" --version

# Open the project in the Godot editor.
dev: version
    "{{ godot_bin }}" --path . --editor

# Run the project locally. Extra arguments are forwarded to Godot.
run *args: version
    "{{ godot_bin }}" --path . {{ quote(args) }}

# Run with Sente-sized dev windows (primary 1920x1080 + marquee 1920x360),
# even on a single display. Forwards extra args to Godot.
sente *args: version
    "{{ godot_bin }}" --path . -- --sente {{ quote(args) }}

# Import resources headlessly, matching the CI pre-export check.
import: version
    "{{ godot_bin }}" --headless --path . --import

# Create a local Windows package for inspection. CI is the canonical cabinet build.
export: import
    mkdir -p build/HEAVENLY
    "{{ godot_bin }}" --headless --path . --export-release "Windows Desktop" build/HEAVENLY/HEAVENLY.exe

# Zip the installer payload (Install.ps1 + game + artwork) and create its SHA-256 checksum.
# The installer pre-creates both AGS folders, so AGS does not need to run first.
package: export
    rm -rf dist HEAVENLY-windows-x86_64.zip HEAVENLY-windows-x86_64.zip.sha256
    mkdir -p dist/game dist/artwork
    cp -R "build/HEAVENLY/." "dist/game/"
    cp "tools/Install.ps1" "dist/Install.ps1"
    # Ship heavenly.cfg without dev comments: only section/key lines go to the cabinet.
    grep -v '^[[:space:]]*;' "heavenly.cfg.example" > "dist/game/heavenly.cfg"
    if [ -d "artwork/ags/export" ]; then for f in artwork/ags/export/*.png artwork/ags/export/*.jpg artwork/ags/export/*.jpeg; do [ -e "$f" ] || continue; cp "$f" "dist/artwork/"; done; fi
    (cd dist && zip -r ../HEAVENLY-windows-x86_64.zip Install.ps1 game artwork)
    if command -v sha256sum >/dev/null 2>&1; then sha256sum HEAVENLY-windows-x86_64.zip; else shasum -a 256 HEAVENLY-windows-x86_64.zip; fi > HEAVENLY-windows-x86_64.zip.sha256
