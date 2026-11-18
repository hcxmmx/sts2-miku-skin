param(
    [string]$GodotPath = 'D:\STS2\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe',
    [switch]$Prepare,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'Godot'
$state = Join-Path $PSScriptRoot 'LocalState'
$env:APPDATA = Join-Path $state 'Roaming'
$env:LOCALAPPDATA = Join-Path $state 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
if ($Prepare -or -not (Test-Path -LiteralPath (Join-Path $project 'Miku_Hcxmmx/Assets/actor.json'))) {
    python (Join-Path $PSScriptRoot 'tools/import_miku.py')
    if ($LASTEXITCODE -ne 0) { throw 'Miku actor import failed.' }
    python (Join-Path $PSScriptRoot 'tools/import_effects.py')
    if ($LASTEXITCODE -ne 0) { throw 'Miku effect conversion failed.' }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable missing at $GodotPath" }
if ($Prepare -or -not (Test-Path -LiteralPath (Join-Path $project 'Miku_Hcxmmx/Assets/user_audio.json'))) {
    python (Join-Path $PSScriptRoot 'tools/import_user_audio.py')
    if ($LASTEXITCODE -ne 0) { throw 'User audio import failed.' }
}
if ($Prepare -or -not (Test-Path -LiteralPath (Join-Path $project 'Miku_Hcxmmx/Assets/combat_profiles.json'))) {
    python (Join-Path $PSScriptRoot 'tools/import_combat_preview.py')
    if ($LASTEXITCODE -ne 0) { throw 'Miku combat preview import failed.' }
}
python (Join-Path $PSScriptRoot 'tools/import_action_drafts.py')
if ($LASTEXITCODE -ne 0) { throw 'Miku action draft import failed.' }
if ($Check) {
    $consolePath = $GodotPath -replace '\.exe$', '_console.exe'
    & $consolePath --headless --path $project -- --check
    exit $LASTEXITCODE
}
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $project + '"')) -WorkingDirectory $project
