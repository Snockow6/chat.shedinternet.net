#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Stoat for Desktop — Windows targets (Squirrel installer + ZIP).

.DESCRIPTION
    Clones (or uses an existing checkout of) stoatchat/for-desktop, optionally
    patches the server URL, and runs pnpm make to produce Windows distributables.

    Outputs are written to <repo>\out\make\:
      - out\make\squirrel\   (stoat-desktop-setup.exe  — Squirrel installer)
      - out\make\zip\        (stoat-desktop-<version>-win32-<arch>.zip)

.PARAMETER RepoPath
    Path to an existing stoat-for-desktop checkout.  If omitted and no directory
    is found, the repo is cloned into .\stoat-for-desktop.

.PARAMETER Url
    Override the git clone URL  (default: https://github.com/stoatchat/for-desktop.git).

.PARAMETER ServerUrl
    App server URL baked into the build (patches src/native/window.ts).
    Defaults to whatever is in the source (https://stoat.chat/app).

.PARAMETER SkipPull
    If set, skip git pull on the existing checkout.

.PARAMETER NoCi
    By default the script sets PLATFORM=windows-latest which limits makers to
    Squirrel + ZIP (matching CI behaviour).  Pass -NoCi to build all local
    makers (Squirrel + ZIP + AppX).

.EXAMPLE
    .\build-stoat.ps1

.EXAMPLE
    .\build-stoat.ps1 -ServerUrl https://chat.shedinternet.net

.EXAMPLE
    .\build-stoat.ps1 -RepoPath C:\projects\stoat-for-desktop -SkipPull

.EXAMPLE
    .\build-stoat.ps1 -Url https://github.com/your-fork/for-desktop.git
#>

param(
    [Parameter(Position = 0)]
    [string]$RepoPath,

    [string]$Url = "https://github.com/stoatchat/for-desktop.git",

    [Alias("server-url")]
    [string]$ServerUrl,

    [Alias("skip-pull")]
    [switch]$SkipPull,

    [Alias("no-ci")]
    [switch]$NoCi
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $PSCommandPath
$DEFAULT_REPO = Join-Path $SCRIPT_DIR "stoat-for-desktop"

if (-not $RepoPath) {
    $RepoPath = $DEFAULT_REPO
}

# ------------------------------------------------------------------ prereqs
Write-Host ":: Checking prerequisites"

$nodeOk = $null
try { $nodeOk = node --version } catch {}
if (-not $nodeOk) {
    Write-Error "Node.js is required — install from https://nodejs.org"
    exit 1
}
Write-Host "   node $nodeOk"

$pnpmOk = $null
try { $pnpmOk = pnpm --version } catch {}
if (-not $pnpmOk) {
    Write-Host "   pnpm not found — enabling corepack..."
    try {
        corepack enable
        $pnpmOk = pnpm --version
    } catch {
        Write-Error "Could not enable pnpm via corepack.  Install it manually: npm install -g pnpm"
        exit 1
    }
}
Write-Host "   pnpm $pnpmOk"

# --------------------------------------------------------- clone / checkout
if (-not (Test-Path $RepoPath)) {
    Write-Host ":: Cloning $Url → $RepoPath"
    git clone --recursive $Url $RepoPath
    if (-not $?) { exit 1 }
}

Push-Location $RepoPath
try {
    if (-not $SkipPull) {
        Write-Host ":: Pulling latest changes"
        git pull --recurse-submodules
        if (-not $?) { exit 1 }
    }

    Write-Host ":: Initialising submodules"
    git submodule update --init --recursive
    if (-not $?) { exit 1 }

    # --------------------------------------------------------- patch server URL
    $WINDOW_SRC = "src/native/window.ts"

    if ($ServerUrl) {
        Write-Host ":: Patching server URL → $ServerUrl"

        $content = Get-Content $WINDOW_SRC -Raw
        $oldUrl = "https://stoat.chat/app"
        # try to extract the current URL from the source
        if ($content -match '"https?://[^"]+"') {
            $oldUrl = $matches[0] -replace '"', ''
        }
        Write-Host "   (replacing $oldUrl)"
        $content = $content -replace '"https?://[^"]*"', "`"$ServerUrl`""
        Set-Content $WINDOW_SRC -Value $content -NoNewline
    }

    # ---------------------------------------------------------------- install
    Write-Host ":: Installing dependencies (pnpm install)"
    if ($NoCi) {
        pnpm install
    } else {
        pnpm install --frozen-lockfile
    }
    if (-not $?) { exit 1 }

    # ------------------------------------------------------ patch extract-zip
    # yauzl (used by extract-zip) hangs on Node.js >= 26 / Windows.
    # Replace with PowerShell's built-in Expand-Archive.
    Write-Host ":: Patching extract-zip to use PowerShell Expand-Archive"
    & "$SCRIPT_DIR\patch-extract-zip.ps1" -TargetDir (Resolve-Path ".")
    if (-not $?) { exit 1 }

    # ---------------------------------------------------------------  build
    Write-Host ":: Building Windows targets (pnpm make)"
    if ($NoCi) {
        $env:PLATFORM = ""
    } else {
        $env:PLATFORM = "windows-latest"
    }

    pnpm make
    if (-not $?) { exit 1 }

    # -------------------------------------------------------------- summary
    Write-Host ""
    Write-Host "  Build complete!"
    Write-Host "  -> Outputs are in: $RepoPath\out\make"
    Write-Host "    - out\make\squirrel    (stoat-desktop-setup.exe -- Squirrel installer)"
    Write-Host "    - out\make\zip         (stoat-desktop-*-win32-*.zip -- portable ZIP)"

    if ($NoCi) {
        Write-Host "    - out\make\appx         (MSIX/AppX package -- Windows Store)"
    }

}
finally {
    # --------------------------------------------------- restore patched file
    if ($ServerUrl) {
        Write-Host ":: Restoring original server URL"
        git checkout -- $WINDOW_SRC
    }

    # ------------------------------------------------------- restore patches
    $extractBackup = Join-Path (Resolve-Path ".") "node_modules\extract-zip\index.js.yauzl-backup"
    if (Test-Path $extractBackup) {
        Write-Host ":: Restoring original extract-zip"
        Move-Item $extractBackup (Join-Path (Resolve-Path ".") "node_modules\extract-zip\index.js") -Force
    }

    $crossZipBackup = Join-Path (Resolve-Path ".") "node_modules\cross-zip\index.js.cross-zip-backup"
    if (Test-Path $crossZipBackup) {
        Write-Host ":: Restoring original cross-zip"
        Move-Item $crossZipBackup (Join-Path (Resolve-Path ".") "node_modules\cross-zip\index.js") -Force
    }

    Pop-Location
}
