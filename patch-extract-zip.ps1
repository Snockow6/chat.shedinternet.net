#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Patch extract-zip to use PowerShell Expand-Archive instead of yauzl.
.DESCRIPTION
    The yauzl npm module (used by extract-zip) hangs during zip extraction
    on some Node.js / Windows configurations.  This script replaces the
    yauzl-based extraction with a call to PowerShell's built-in Expand-Archive,
    which is reliable on Windows 10+.
.PARAMETER TargetDir
    Path to the directory containing node_modules/extract-zip (i.e., the
    stoat-for-desktop checkout root).
#>

param(
    [Parameter(Mandatory)]
    [string]$TargetDir
)

$ErrorActionPreference = "Stop"

$extractZipDir = Join-Path $TargetDir "node_modules\extract-zip"
$indexJs = Join-Path $extractZipDir "index.js"
$backupJs = Join-Path $extractZipDir "index.js.yauzl-backup"

if (-not (Test-Path $extractZipDir)) {
    Write-Error "extract-zip module not found at $extractZipDir"
    exit 1
}

# Back up original if not already backed up
if (-not (Test-Path $backupJs)) {
    Write-Host "   backing up original index.js -> index.js.yauzl-backup"
    Copy-Item $indexJs $backupJs
}

Write-Host "   patching extract-zip to use PowerShell Expand-Archive"

# Single-quoted here-string: everything is literal, no escaping needed
$jsContent = @'
const debug = require('debug')('extract-zip')
const { promises: fs } = require('fs')
const path = require('path')
const { execSync } = require('child_process')

module.exports = async function (zipPath, opts) {
  debug('creating target directory', opts.dir)

  if (!path.isAbsolute(opts.dir)) {
    throw new Error('Target directory is expected to be absolute')
  }

  await fs.mkdir(opts.dir, { recursive: true })
  opts.dir = await fs.realpath(opts.dir)

  const escapedZip = zipPath.replace(/'/g, "''")
  const escapedDir = opts.dir.replace(/'/g, "''")

  debug('extracting', zipPath, 'to', opts.dir, 'via PowerShell Expand-Archive')

  execSync(
    `powershell -NoProfile -NonInteractive -Command "Expand-Archive -Path '${escapedZip}' -DestinationPath '${escapedDir}' -Force"`,
    { stdio: 'inherit', timeout: 180000 }
  )

  debug('zip extraction complete')
}
'@

Set-Content -Path $indexJs -Value $jsContent -NoNewline
Write-Host "   extract-zip patched"

# ---------------------------------------------------------------------------
# Also patch cross-zip — same Node.js 26 compat issue:
# fs.rmdir with { recursive: true } was removed in Node.js 20+.
# Fix: use fs.rm / fs.rmSync instead.
# ---------------------------------------------------------------------------
$crossZipDir = Join-Path $TargetDir "node_modules\cross-zip"
$crossZipJs = Join-Path $crossZipDir "index.js"
$crossZipBackup = Join-Path $crossZipDir "index.js.cross-zip-backup"

if (Test-Path $crossZipJs) {
    if (-not (Test-Path $crossZipBackup)) {
        Write-Host "   backing up cross-zip\index.js → index.js.cross-zip-backup"
        Copy-Item $crossZipJs $crossZipBackup
    }

    Write-Host "   patching cross-zip to use fs.rm instead of fs.rmdir"
    $crossContent = Get-Content $crossZipJs -Raw
    $crossContent = $crossContent -replace 'fs\.rmdir\(', 'fs.rm('
    $crossContent = $crossContent -replace 'fs\.rmdirSync\(', 'fs.rmSync('
    Set-Content -Path $crossZipJs -Value $crossContent -NoNewline
    Write-Host "   cross-zip patched"
} else {
    Write-Host "   cross-zip not found, skipping"
}

Write-Host ":: Patches applied"
