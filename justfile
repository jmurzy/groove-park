# Override this when Godot is installed somewhere other than the standard
# Homebrew cask location, for example: GODOT_BIN=godot just run.
godot_bin := env_var_or_default("GODOT_BIN", "/Applications/Godot 4.6.3.app/Contents/MacOS/Godot")
# GDScript lint/format tools from gdtoolkit 4.x (pipx install "gdtoolkit==4.*").
gdformat_bin := env_var_or_default("GDFORMAT_BIN", "gdformat")
gdlint_bin := env_var_or_default("GDLINT_BIN", "gdlint")
# GitHub Actions workflow linter (brew install actionlint).
actionlint_bin := env_var_or_default("ACTIONLINT_BIN", "actionlint")

[default]
[doc("List available development commands.")]
help:
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
    "{{ godot_bin }}" --path . -- {{ quote(args) }}

[doc("Run Sente-sized windows at a capped render rate. Physics remains at the project's fixed rate.")]
sente-rate rate: version
    "{{ godot_bin }}" --disable-vsync --max-fps "{{ rate }}" --path .

[doc("Run the low (30 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-low: version
    "{{ godot_bin }}" --disable-vsync --max-fps 30 --path .

[doc("Run the target (60 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-target: version
    "{{ godot_bin }}" --disable-vsync --max-fps 60 --path .

[doc("Run the high (120 FPS) cabinet render-rate check with Sente-sized dev windows.")]
sente-high: version
    "{{ godot_bin }}" --disable-vsync --max-fps 120 --path .

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

[doc("Discover and run all headless test scripts in isolated Godot processes.")]
[script]
test: import
    files=$(git ls-files --cached --others --exclude-standard -- 'tests/**/test_*.gd')
    if [ -z "$files" ]; then
        printf 'No tests found.\n' >&2
        exit 1
    fi

    log=$(mktemp)
    trap 'rm -f "$log"' EXIT
    for f in $files; do
        status=0
        "{{ godot_bin }}" --headless --path . --script "res://$f" >"$log" 2>&1 || status=$?
        cat "$log"
        if [ "$status" -ne 0 ]; then
            exit "$status"
        fi
        if grep -q '^SCRIPT ERROR:' "$log"; then
            printf 'Script error in %s\n' "$f" >&2
            exit 1
        fi
    done

[doc("Check GitHub Actions workflows")]
actionlint-check:
    "{{ actionlint_bin }}"

[doc("Run game, API, web, and GitHub Actions checks.")]
check: format-check lint-check actionlint-check typecheck test

[doc("Export the same game for same-origin Web/Wasm hosting.")]
export-web: import
    rm -rf build/web
    mkdir -p build/web
    "{{ godot_bin }}" --headless --path . --export-release "Web"
    just audit-pck build/web/index.pck
    # Godot writes the resolved configuration to its HTML entry document.
    mv build/web/index.html build/web/release_config.json

[doc("Create a local Windows package for inspection. CI is the canonical cabinet build.")]
export-ags: import
    rm -rf build/ags
    mkdir -p build/ags
    "{{ godot_bin }}" --headless --path . --export-release "Windows Desktop"
    just audit-pck build/ags/HEAVENLY.pck

[doc("Audit an exported PCK for credentials, private endpoints, and development-only files.")]
audit-pck pck: version
    test -f "{{ pck }}"
    "{{ godot_bin }}" --headless --path "$(dirname "$(realpath "{{ pck }}")")" --main-pack "$(realpath "{{ pck }}")" --script "$(pwd)/tools/audit_pck.gd"

[doc("Zip the installer payload and create its SHA-256 checksum. The installer pre-creates both AGS folders, so AGS does not need to run first.")]
package-ags: export-ags
    rm -f HEAVENLY-windows-x86_64.zip HEAVENLY-windows-x86_64.zip.sha256
    # Ship game.cfg without dev comments: only section/key lines go to the cabinet.
    grep -v '^[[:space:]]*;' game.cfg.example > build/ags/game.cfg
    bsdtar --format=zip -cf HEAVENLY-windows-x86_64.zip -s '|^build/ags|game|' -s '|^tools/Install.ps1|Install.ps1|' -s '|^images/ags|artwork|' build/ags tools/Install.ps1 images/ags/header.png images/ags/hero.png images/ags/marquee.png
    if command -v sha256sum >/dev/null 2>&1; then sha256sum HEAVENLY-windows-x86_64.zip; else shasum -a 256 HEAVENLY-windows-x86_64.zip; fi > HEAVENLY-windows-x86_64.zip.sha256

[doc("Run an API Worker command. For example: just api check.")]
api *args:
    just --justfile workers/api/justfile {{ args }}

[doc("Run an Web Worker command. For example: just web check.")]
web *args:
    just --justfile workers/web/justfile {{ args }}
