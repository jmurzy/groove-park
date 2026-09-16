<#
.SYNOPSIS
  Installs HEAVENLY into Polycade AGS folders without requiring AGS to run first.

.DESCRIPTION
  Copies the game payload to games\drm-free\HEAVENLY and pre-seeds the
  artwork payload to assets\drm-free\HEAVENLY. Both target folders are
  created up front, so there is no need to start AGS once to discover the
  game and again to drop artwork in.

  Expected ZIP layout (script sits at the ZIP root next to these folders):

    Install.ps1
    game\       # HEAVENLY.exe, HEAVENLY.pck, ...required runtime files
    artwork\    # header.png, hero.png, marquee.png (lowercase)

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install.ps1 -GameName HEAVENLY
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$GameName = "HEAVENLY",

  # Folders next to this script inside the extracted ZIP.
  [string]$GameSource = (Join-Path $PSScriptRoot "game"),
  [string]$ArtSource = (Join-Path $PSScriptRoot "artwork")
)

$ErrorActionPreference = "Stop"

function Resolve-GameSource {
  param([string]$Candidate, [string]$Game)

  if ((Test-Path -LiteralPath $Candidate) -and (Test-Path -LiteralPath (Join-Path $Candidate "$Game.exe"))) {
    return $Candidate
  }

  # Tolerate an old-style payload where the game folder itself was zipped:
  # game\HEAVENLY\HEAVENLY.exe
  $nested = Join-Path $Candidate $Game
  if ((Test-Path -LiteralPath $nested) -and (Test-Path -LiteralPath (Join-Path $nested "$Game.exe"))) {
    Write-Warning "Using nested game folder: $nested"
    return $nested
  }

  throw "Game payload not found. Expected '$Game.exe' under '$Candidate'."
}

if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
  throw "APPDATA is not set. Run this script on the Windows account that runs AGS."
}

$polycadeBase = Join-Path $env:APPDATA "polycade"
$gameDir = Join-Path $polycadeBase (Join-Path "games\drm-free" $GameName)
$artDir = Join-Path $polycadeBase (Join-Path "assets\drm-free" $GameName)

$resolvedGameSource = Resolve-GameSource -Candidate $GameSource -Game $GameName

foreach ($dir in @($gameDir, $artDir)) {
  if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
}

if ($PSCmdlet.ShouldProcess($resolvedGameSource + " -> " + $gameDir, "Copy game files")) {
  Copy-Item -Path (Join-Path $resolvedGameSource "*") -Destination $gameDir -Recurse -Force
}

$exePath = Join-Path $gameDir "$GameName.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Install failed: '$exePath' is missing after copy. Did the game payload extract completely?"
}

# Artwork is optional: older releases may ship no artwork folder or an empty one.
$copiedArt = @()
if (Test-Path -LiteralPath $ArtSource) {
  $artFiles = Get-ChildItem -LiteralPath $ArtSource -File -Include *.png, *.jpg, *.jpeg -Recurse |
    Where-Object { $_.Name -notlike ".gitkeep" }
  foreach ($file in $artFiles) {
    if ($file.Name -cne $file.Name.ToLowerInvariant()) {
      Write-Warning "AGS requires lowercase artwork names; copying '$($file.Name)' as-is will likely be ignored. Rename to '$($file.Name.ToLowerInvariant())'."
    }
    if ($PSCmdlet.ShouldProcess($file.FullName + " -> " + $artDir, "Copy artwork file")) {
      Copy-Item -LiteralPath $file.FullName -Destination $artDir -Force
      $copiedArt += $file.Name
    }
  }
}

Write-Host ""
Write-Host "HEAVENLY installed:"
Write-Host "  game:    $exePath"
Write-Host "  artwork: $artDir"
if ($copiedArt.Count -gt 0) {
  Write-Host ("  art files: " + ($copiedArt -join ", "))
} else {
  Write-Host "  art files: (none shipped in this ZIP; game still runs without them)"
}
Write-Host ""
Write-Host "Next: start or restart AGS so it discovers the game on its next scan."
