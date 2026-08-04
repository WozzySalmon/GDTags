
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
$PackageName = "gameplay_tags-$Version"
$StageDir = Join-Path $DistDir $PackageName
$ZipPath = Join-Path $DistDir "$PackageName.zip"


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

# Remove editor and temporary leftovers that are not needed to use the addon.
Get-ChildItem $StageAddon -Recurse -File | Where-Object {
    $_.Name -like "~*" `
    -or $_.Name -eq ".DS_Store" `
    -or $_.Extension -eq ".tmp"
} | Remove-Item -Force


$LicensePath = Join-Path $Root "LICENSE"
if (Test-Path $LicensePath) {
    Copy-Item $LicensePath (Join-Path $StageDir "LICENSE") -Force
}

Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipPath -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$Archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $EntryNames = @($Archive.Entries | ForEach-Object { $_.FullName.Replace("\", "/") })
    if ($EntryNames -notcontains "addons/gameplay_tags/plugin.cfg") {
        throw "Package validation failed: addon plugin.cfg is missing."
    }
    $ForbiddenEntry = $EntryNames | Where-Object {
        $_ -match '(^|/)(tests|benchmarks|\.godot)(/|$)' `
        -or $_ -match '(^|/)~' `
        -or $_ -match '\.tmp$' `
        -or $_ -match '(^|/)\.DS_Store$'
    } | Select-Object -First 1
    if ($null -ne $ForbiddenEntry) {
        throw "Package validation failed: development artifact included: $ForbiddenEntry"
    }
}
finally {
    $Archive.Dispose()
}

Write-Host ""
Write-Host "Package created and validated:"
Write-Host "  $ZipPath"
Write-Host ""
Write-Host "Install test: unzip it into another Godot project so it contains:"
Write-Host "  addons/gameplay_tags/plugin.cfg"
Write-Host "Then enable Project Settings > Plugins > Gameplay Tags."
