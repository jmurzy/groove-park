#!/usr/bin/env bash
# Called by mise after installing Godot. Download templates only when the
# Web or Windows release template needed by this project is missing.
set -euo pipefail

# Each supported Godot release needs its own trusted archive checksum.
# Update this mapping when changing the Godot version in mise.toml.
release=${MISE_TOOL_VERSION:?This script must run as the Godot mise postinstall hook}
case "$release" in
  4.6.3-stable) checksum=3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8 ;;
  *) printf 'No export template checksum configured for Godot %s\n' "$release" >&2; exit 1 ;;
esac
# Godot uses dots in the template directory, for example 4.6.3.stable.
version=${release//-/.}

# Locate Godot's editor data directory for the current host platform.
case "$(uname -s)" in
  Darwin) data_dir="$HOME/Library/Application Support/Godot" ;;
  Linux|FreeBSD|OpenBSD|NetBSD) data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
  MINGW*|MSYS*|CYGWIN*) data_dir="${APPDATA:?APPDATA is required}/Godot" ;;
  *) printf 'Unsupported host platform: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

target="$data_dir/export_templates/$version"
# These are the release templates used by this project's two export presets.
if [ -f "$target/web_nothreads_release.zip" ] && [ -f "$target/windows_release_x86_64.exe" ]; then
  printf 'Using existing Godot export templates: %s\n' "$target"
  exit 0
fi

# Stage the download separately and remove it on success or failure.
mkdir -p "$data_dir/export_templates"
staging=$(mktemp -d "$data_dir/export_templates/.install.XXXXXXXX")
trap 'rm -rf "$staging"' EXIT
archive="$staging/templates.tpz"
curl --fail --location --retry 3 --output "$archive" \
  "https://github.com/godotengine/godot-builds/releases/download/$release/Godot_v${release}_export_templates.tpz"
# Verify the full archive before extracting anything. Support both common
# SHA-256 utilities, and compare only the hash from their output.
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$archive")
else
  actual=$(shasum -a 256 "$archive")
fi
if [ "${actual%% *}" != "$checksum" ]; then
  printf 'Godot export template checksum mismatch\n' >&2
  exit 1
fi
mkdir -p "$target"
# The pinned archive is flat under templates/. Strip that prefix (-j) and
# skip existing files (-n), so a partial installation can be filled safely.
unzip -n -j -q "$archive" 'templates/*' -d "$target"
# Fail if the archive did not provide the templates our exports require.
test -f "$target/web_nothreads_release.zip"
test -f "$target/windows_release_x86_64.exe"
printf 'Installed Godot export templates: %s\n' "$target"
