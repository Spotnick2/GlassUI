<#
    deploy.ps1 - Copy GlassUI (and optionally SkinProbe) into the Forever AddOns folder.

    The repo keeps "## Version: @project-version@" for the packager; the deployed
    copy gets "dev". The repo copy is never modified.

    The glass material is the embedded LibGlass-1.0. The packager fetches it
    into Libs\LibGlass-1.0 (.pkgmeta externals); for a dev copy this script
    hands that job to the LibGlass checkout's own deploy.ps1, which checks the
    checkout, copies only the shipped files and prints its commit. The checkout
    is $env:LIBGLASS, else ..\LibGlass. (GlassChat's deploy, trimmed.)

    SkinProbe is a ForeverProbe module, so -Probe and -ProbeOnly deploy the
    ForeverProbe checkout first ($env:FOREVERPROBE, else ..\ForeverProbe).

    Usage:
        pwsh Tools/deploy.ps1               # GlassUI
        pwsh Tools/deploy.ps1 -Probe        # ...and SkinProbe
        pwsh Tools/deploy.ps1 -ProbeOnly    # just SkinProbe
        pwsh Tools/deploy.ps1 -AddOnsPath "D:\...\_forever_\Interface\AddOns"
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns",
    [switch]$Probe,
    [switch]$ProbeOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $AddOnsPath)) { Write-Error "AddOns path not found: $AddOnsPath"; exit 1 }
# Absolute, as LibGlass's deploy does: the stale-file sweep compares against
# Get-ChildItem's absolute FullName, and a relative $dest made it delete
# everything it had just copied, the library included (Codex, PR #8).
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath

. (Join-Path $PSScriptRoot "LibGlassPin.ps1")
$LibGlass = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
$ForeverProbe = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else { Join-Path (Split-Path -Parent $RepoRoot) "ForeverProbe" }

function Deploy-Addon {
    $dest = Join-Path $AddOnsPath "GlassUI"
    if (-not (Test-Path -LiteralPath (Join-Path $LibGlass "Tools\deploy.ps1"))) {
        Write-Error "LibGlass checkout not found at $LibGlass (clone github.com/Spotnick2/LibGlass there, or set `$env:LIBGLASS)"
        exit 1
    }
    Write-LibGlassPinStatus $RepoRoot $LibGlass "this deploy tests a library the release won't ship"
    # The library first: its deploy checks the checkout and may refuse, and a
    # refusal must leave the deployed addon as it was.
    & pwsh -NoProfile -File (Join-Path $LibGlass "Tools\deploy.ps1") -Addon GlassUI -AddOnsPath $AddOnsPath
    if ($LASTEXITCODE -ne 0) { Write-Error "LibGlass deploy refused; GlassUI was not touched"; exit 1 }
    Write-Host "Deploying GlassUI -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # The TOC is the list of what ships (subfolders included, e.g. Core\).
    $lua = @(Get-Content -LiteralPath (Join-Path $RepoRoot "GlassUI.toc") | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch "^#" -and $_ -match "[.]lua$" })
    # The glass is LibGlass's; our own textures are Tools\make_media.py's (Media\*.tga, #56).
    $media = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Media") -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq ".tga" } | ForEach-Object { "Media\" + $_.Name })
    $files = @("GlassUI.toc", "LICENSE") + $lua + $media
    foreach ($f in $files) {
        $src = Join-Path $RepoRoot $f
        $to = Join-Path $dest $f
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
        if ($f -like "*.toc") {
            (Get-Content -LiteralPath $src -Raw) -replace '## Version: @project-version@', '## Version: dev' |
                Set-Content -LiteralPath $to -NoNewline
        } else {
            Copy-Item -LiteralPath $src -Destination $to -Force
        }
        Write-Host "  $f"
    }
    # A Lua file removed from the repo must not linger where the client finds it.
    $keep = $files | ForEach-Object { $_.Replace("/", "\") }
    Get-ChildItem -LiteralPath $dest -File -Recurse | Where-Object { $_.FullName -notlike (Join-Path $dest "Libs\*") } |
        ForEach-Object {
            $rel = $_.FullName.Substring($dest.Length + 1)
            if ($keep -notcontains $rel) {
                Write-Host "  removing stale $rel" -ForegroundColor DarkYellow
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
}

function Deploy-Probe {
    # The host first: SkinProbe has ## Dependencies: ForeverProbe, so without
    # it the client loads no SkinProbe at all (GlassChat's ChatProbe deploy).
    if (-not (Test-Path -LiteralPath (Join-Path $ForeverProbe "Tools\deploy.ps1"))) {
        Write-Error "ForeverProbe checkout not found at $ForeverProbe (clone github.com/Spotnick2/ForeverProbe there, or set `$env:FOREVERPROBE)"
        exit 1
    }
    & pwsh -NoProfile -File (Join-Path $ForeverProbe "Tools\deploy.ps1") -AddOnsPath $AddOnsPath
    if ($LASTEXITCODE -ne 0) { Write-Error "ForeverProbe deploy refused; SkinProbe was not touched"; exit 1 }
    $dest = Join-Path $AddOnsPath "SkinProbe"
    Write-Host "Deploying SkinProbe -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # The TOC and Lua only.
    Get-ChildItem -LiteralPath $ProbeDir -File |
        Where-Object { $_.Extension -in ".toc", ".lua" } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dest $_.Name) -Force
        Write-Host "  $($_.Name)"
    }
}

# Before anything is copied: a probe switch that can't succeed must not leave
# the addon, the library or ForeverProbe half-deployed (Codex, PR #14).
$ProbeDir = Join-Path $RepoRoot "Tools\SkinProbe"
if ($Probe -or $ProbeOnly) {
    $probeToc = Join-Path $ProbeDir "SkinProbe.toc"
    if (-not (Test-Path -LiteralPath $probeToc)) {
        Write-Host "SkinProbe isn't in this revision yet (milestone 2, #2). Nothing was deployed." -ForegroundColor Red
        exit 1
    }
    $missing = @(Get-Content -LiteralPath $probeToc | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch "^#" -and $_ -match "[.]lua$" } |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProbeDir $_)) })
    if ($missing.Count -gt 0) {
        Write-Host "SkinProbe.toc lists files that don't exist: $($missing -join ', '). Nothing was deployed." -ForegroundColor Red
        exit 1
    }
}

if (-not $ProbeOnly) { Deploy-Addon }
if ($Probe -or $ProbeOnly) { Deploy-Probe }

Write-Host ""
Write-Host "Changed or new files, a brand-new addon folder included: /reload is enough (porting guide, 2026-10-09)." -ForegroundColor Yellow
$probeHint = if ($Probe -or $ProbeOnly) { "   (probe: /fp skin, its lines in /fp)" } else { "" }
Write-Host "In game:  /console scriptErrors 1   then   /glassui help$probeHint" -ForegroundColor Green
