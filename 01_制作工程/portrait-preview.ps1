param(
    [string]$GodotPath = 'D:\STS2\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe',
    [switch]$StageShow
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'Godot'
$state = Join-Path $PSScriptRoot 'LocalState'
$env:APPDATA = Join-Path $state 'Roaming'
$env:LOCALAPPDATA = Join-Path $state 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$generator = Join-Path $PSScriptRoot 'tools\import_alice_portrait.cjs'
$catalog = Join-Path $project 'Miku_Hcxmmx\Portrait\Assets\portrait.json'
if (-not (Test-Path -LiteralPath $catalog) -or (Get-Item -LiteralPath $generator).LastWriteTimeUtc -gt (Get-Item -LiteralPath $catalog).LastWriteTimeUtc) {
    & node $generator
    if ($LASTEXITCODE -ne 0) { throw 'Portrait conversion failed.' }
}
$scene = 'res://Preview/Portrait/PortraitPreview.tscn'
$logName = 'portrait-preview.log'
if ($StageShow) {
    $scene = 'res://Preview/Portrait/StageShowPreview.tscn'
    $logName = 'stage-show-preview.log'
    $env:MIKU_PREVIEW_GAME_PACK = 'D:\youxi\steamapps\common\Slay the Spire 2\SlayTheSpire2.pck'
}
$stageImport = Get-ChildItem -Path (Join-Path $project '.godot\imported\bg_7396_01*.ctex') -ErrorAction SilentlyContinue
if (-not $StageShow -or -not $stageImport) {
    $consolePath = $GodotPath -replace '\.exe$', '_console.exe'
    & $consolePath --headless --path $project --editor --import --quit *> (Join-Path $state 'portrait-import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Portrait texture import failed.' }
}
$log = Join-Path $state $logName
$preview = Start-Process -FilePath $GodotPath -WindowStyle Normal -ArgumentList @('--path', ('"' + $project + '"'), $scene, '--log-file', ('"' + $log + '"')) -WorkingDirectory $project -PassThru
[void]$preview.WaitForInputIdle(5000)
