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

# Import resources headlessly, matching the CI pre-export check.
import: version
    "{{ godot_bin }}" --headless --path . --import

# Create a local Windows package for inspection. CI is the canonical cabinet build.
export: import
    mkdir -p build/HEAVENLY
    "{{ godot_bin }}" --headless --path . --export-release "Windows Desktop" build/HEAVENLY/HEAVENLY.exe

# Zip the exported game folder and create its SHA-256 checksum.
package: export
    rm -f HEAVENLY-windows-x86_64.zip HEAVENLY-windows-x86_64.zip.sha256
    (cd build && zip -r ../HEAVENLY-windows-x86_64.zip HEAVENLY)
    if command -v sha256sum >/dev/null 2>&1; then sha256sum HEAVENLY-windows-x86_64.zip; else shasum -a 256 HEAVENLY-windows-x86_64.zip; fi > HEAVENLY-windows-x86_64.zip.sha256
