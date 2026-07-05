param(
    [ValidateSet("gdscript")]
    [string] $Variant = "gdscript",

    [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"

$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path (Join-Path $ToolDir "..\..")
$PluginCfg = Join-Path $Root "addons\gameplay_tags\plugin.cfg"
$DistDir = Join-Path $Root "dist"

if (-not (Test-Path $PluginCfg)) {
    throw "Could not find plugin.cfg at $PluginCfg"
}

$VersionLine = Select-String -Path $PluginCfg -Pattern '^version="([^\"]+)"' | Select-Object -First 1
if ($null -eq $VersionLine) {
    throw "Could not read addon version from $PluginCfg"
}

$Version = $VersionLine.Matches[0].Groups[1].Value
$PackageName = "gameplay_tags-$Version-$Variant"
$StageDir = Join-Path $DistDir $PackageName
$ZipPath = Join-Path $DistDir "$PackageName.zip"

if (-not $SkipBuild) {
    Write-Host "GDScript-only addon package: no native build step."
}

if (Test-Path $StageDir) {
    Remove-Item $StageDir -Recurse -Force
}
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
# Prevent Godot from scanning staged packages as duplicate addon scripts/classes.
New-Item -ItemType File -Path (Join-Path $DistDir ".gdignore") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $StageDir "addons") -Force | Out-Null

Copy-Item `
    -Path (Join-Path $Root "addons\gameplay_tags") `
    -Destination (Join-Path $StageDir "addons") `
    -Recurse `
    -Force

$StageAddon = Join-Path $StageDir "addons\gameplay_tags"

# Remove build/linker/editor leftovers that are not needed to use the addon.
Get-ChildItem $StageAddon -Recurse -File | Where-Object {
    $_.Name -like "~*" `
    -or $_.Extension -in @(".exp", ".lib", ".pdb", ".ilk", ".obj", ".tmp", ".TMP")
} | Remove-Item -Force

# GDScript-only package works on every Godot desktop platform and avoids native binary errors.
Remove-Item (Join-Path $StageAddon "bin") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StageAddon "gameplay_tags.gdextension") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StageAddon "gameplay_tags.gdextension.uid") -Force -ErrorAction SilentlyContinue

$LicensePath = Join-Path $Root "LICENSE"
if (Test-Path $LicensePath) {
    Copy-Item $LicensePath (Join-Path $StageDir "LICENSE") -Force
}

Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "Package created:"
Write-Host "  $ZipPath"
Write-Host ""
Write-Host "Install test: unzip it into another Godot project so it contains:"
Write-Host "  addons/gameplay_tags/plugin.cfg"
Write-Host "Then enable Project Settings > Plugins > Gameplay Tags."
