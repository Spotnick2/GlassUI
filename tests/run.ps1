<#
    run.ps1 - Syntax-check the addon and the probe, and run every tests\test_*.lua under Lua 5.1,
    through WowTestKit at the commit tests\kit.pin names (its scripts\run.ps1).

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -KitDev      # the ..\WowTestKit working copy, not the pin
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe",
    [switch]$KitDev
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

# The TOC is the list the kit's runner checks, so a new file cannot go
# unchecked; the probe's TOC is handed over as extra files. The embedded
# library is checked in its own repo.
$probeToc = Join-Path $RepoRoot "Tools\SkinProbe\SkinProbe.toc"
$probeFiles = @()
if (Test-Path $probeToc) {
    $probeFiles = @(Get-Content $probeToc | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch "^#" -and $_ -match "[.]lua$" } | ForEach-Object { "Tools\SkinProbe\$_" })
}

# The tests load the LibGlass checkout as it is; CI loads the .pkgmeta pin.
$libGlass = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
. (Join-Path $RepoRoot "Tools\LibGlassPin.ps1")
if (Test-Path -LiteralPath $libGlass) { Write-LibGlassPinStatus $RepoRoot $libGlass "CI tests the pin" }

. (Join-Path $PSScriptRoot "kit.ps1")
$kit = Get-WowTestKit -RepoRoot $RepoRoot -KitDev:$KitDev
& (Join-Path $kit "scripts\run.ps1") -RepoRoot $RepoRoot -Toc "GlassUI.toc" -Extra $probeFiles -Lua $Lua
exit $LASTEXITCODE
