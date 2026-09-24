# Override this when Godot is installed somewhere other than the standard
# Homebrew cask location, for example: GODOT_BIN=godot just run.
godot_bin := env_var_or_default("GODOT_BIN", "/Applications/Godot 4.6.3.app/Contents/MacOS/Godot")
# GDScript lint/format tools from gdtoolkit 4.x (pipx install "gdtoolkit==4.*").
gdformat_bin := env_var_or_default("GDFORMAT_BIN", "gdformat")
gdlint_bin := env_var_or_default("GDLINT_BIN", "gdlint")
# GitHub Actions workflow linter (brew install actionlint).
actionlint_bin := env_var_or_default("ACTIONLINT_BIN", "actionlint")

[doc("List available development commands.")]
default:
    @just --list

[doc("Confirm the selected Godot executable matches the project's pinned version.")]
version:
    @expected=$(tr -d '[:space:]' < .godot-version); actual=$("{{ godot_bin }}" --version); case "$actual" in "$expected".*) ;; *) printf 'Expected Godot %s, found %s\n' "$expected" "$actual" >&2; exit 1 ;; esac
    @"{{ godot_bin }}" --version

[doc("Open the project in the Godot editor.")]
dev: version
    "{{ godot_bin }}" --path . --editor

[doc("Run the project locally. Extra arguments are forwarded to Godot.")]
run *args: version
    "{{ godot_bin }}" --path . {{ quote(args) }}

[doc("Run with Sente-sized dev windows (primary 1920x1080 + marquee 1920x360), even on a single display. Forwards extra args to Godot.")]
sente *args: version
    "{{ godot_bin }}" --path . -- --sente {{ quote(args) }}

[doc("Run Sente-sized windows at a capped render rate. Physics remains at the project's fixed rate.")]
sente-rate rate: version
    "{{ godot_bin }}" --disable-vsync --max-fps "{{ rate }}" --path . -- --sente

[doc("Run the low (30 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-low: version
    "{{ godot_bin }}" --disable-vsync --max-fps 30 --path . -- --sente

[doc("Run the target (60 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-target: version
    "{{ godot_bin }}" --disable-vsync --max-fps 60 --path . -- --sente

[doc("Run the high (120 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-high: version
    "{{ godot_bin }}" --disable-vsync --max-fps 120 --path . -- --sente

[doc("Import resources headlessly, matching the CI pre-export check.")]
import: version
    "{{ godot_bin }}" --headless --path . --import

[doc("One-time developer setup: Homebrew bundle, gdtoolkit, and git hooks for just check.")]
install:
    brew bundle
    pipx list --short 2>/dev/null | grep -q gdtoolkit || pipx install "gdtoolkit==4.*"
    pre-commit install --hook-type pre-commit

[doc("Check GDScript formatting without modifying files (gdtoolkit).")]
format-check:
    "{{ gdformat_bin }}" --check src/ tests/

[doc("Format GDScript files in place (gdtoolkit).")]
format:
    "{{ gdformat_bin }}" src/ tests/

[doc("Lint GDScript files, including the formatting check (gdtoolkit).")]
lint-check:
    "{{ gdlint_bin }}" src/ tests/

[doc("Static typecheck each GDScript file. Runs import first to refresh the global class cache; strict warnings are errors (see project.godot [debug]).")]
typecheck: import
    for f in $(git ls-files --cached --others --exclude-standard -- '*.gd'); do [ -f "$f" ] || continue; "{{ godot_bin }}" --headless --path . --check-only --script "res://$f" || exit $?; done

[doc("Run headless park simulation checks.")]
test: import
    "{{ godot_bin }}" --headless --path . --script res://tests/game/park/test_park_course.gd
    "{{ godot_bin }}" --headless --path . --script res://tests/game/park/test_rider_run_state.gd
    "{{ godot_bin }}" --headless --path . --script res://tests/game/park/test_rider_simulation.gd
    "{{ godot_bin }}" --headless --path . --script res://tests/game/park/test_rider_grabs.gd

[doc("Check GitHub Actions workflows")]
actionlint-check:
    "{{ actionlint_bin }}"

[doc("Run formatting, lint, type, simulation, and GitHub Actions checks.")]
check: format-check lint-check actionlint-check typecheck test

[doc("Create a local Windows package for inspection. CI is the canonical cabinet build.")]
export: import
    mkdir -p build/HEAVENLY
    "{{ godot_bin }}" --headless --path . --export-release "Windows Desktop" build/HEAVENLY/HEAVENLY.exe

[doc("Zip the installer payload (Install.ps1 + game + artwork) and create its SHA-256 checksum. The installer pre-creates both AGS folders, so AGS does not need to run first.")]
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
