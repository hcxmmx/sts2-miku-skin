param(
    [string]$GameDir = 'D:\youxi\steamapps\common\Slay the Spire 2',
    [string]$Godot = 'D:\STS2\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe',
    [string]$DotnetQa = 'D:\Projects\STS2\未锈铠\01_制作工程\LocalState\PublicCompat\Dotnet9\dotnet.exe'
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'Godot'
$output = Join-Path $PSScriptRoot '..\02_构建产物\游戏测试包\MikuSkin'
$env:APPDATA = Join-Path $PSScriptRoot 'LocalState\Roaming'
$env:LOCALAPPDATA = Join-Path $PSScriptRoot 'LocalState\Local'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& node (Join-Path $PSScriptRoot 'tools/import_alice_portrait.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Portrait conversion failed.' }
python (Join-Path $PSScriptRoot 'tools/import_user_audio.py')
if ($LASTEXITCODE -ne 0) { throw 'User audio import failed.' }
python (Join-Path $PSScriptRoot 'tools/import_combat_preview.py')
if ($LASTEXITCODE -ne 0) { throw 'Combat profile import failed.' }
python (Join-Path $PSScriptRoot 'tools/import_action_drafts.py')
if ($LASTEXITCODE -ne 0) { throw 'Action profile import failed.' }
& dotnet build (Join-Path $PSScriptRoot 'Bridge\MikuSkin.csproj') -c Release "-p:Sts2Dir=$GameDir" --nologo -v minimal
if ($LASTEXITCODE -ne 0) { throw 'Bridge build failed.' }
& dotnet build (Join-Path $PSScriptRoot 'tools\BridgeQA\BridgeQA.csproj') -c Release --nologo -v minimal
if ($LASTEXITCODE -ne 0) { throw 'Bridge QA build failed.' }
& $DotnetQa (Join-Path $PSScriptRoot 'tools\BridgeQA\bin\Release\net9.0\BridgeQA.dll') (Join-Path $GameDir 'data_sts2_windows_x86_64') (Join-Path $PSScriptRoot 'Bridge\bin\Release\net9.0\MikuSkin.dll')
if ($LASTEXITCODE -ne 0) { throw 'Harmony bridge check failed.' }
& $Godot --headless --path $project --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $Godot --headless --path $project --script res://CheckIntegration.gd
if ($LASTEXITCODE -ne 0) { throw 'Battle runtime check failed.' }
& $Godot --headless --path $project --script res://PackRuntime.gd
if ($LASTEXITCODE -ne 0) { throw 'Resource packing failed.' }
$packQa = Join-Path $PSScriptRoot 'LocalState\PackQA'
New-Item -ItemType Directory -Force -Path $packQa | Out-Null
'config_version=5' | Set-Content -LiteralPath (Join-Path $packQa 'project.godot') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $project 'CheckIntegration.gd') -Destination $packQa -Force
& $Godot --headless --path $packQa --script res://CheckIntegration.gd -- (Join-Path $output 'MikuSkin.pck')
if ($LASTEXITCODE -ne 0) { throw 'Packed battle runtime check failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Bridge\bin\Release\net9.0\MikuSkin.dll'),(Join-Path $PSScriptRoot 'MikuSkin.json') -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\音频来源与致谢.md') -Destination $output -Force
Get-ChildItem -LiteralPath $output -File | ForEach-Object {
    [ordered]@{ name=$_.Name; bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot '..\02_构建产物\game_package_hashes.json') -Encoding UTF8
Write-Output ('Test package ready: ' + [IO.Path]::GetFullPath($output))
