$ErrorActionPreference = 'Stop'
if (Get-Process -Name SlayTheSpire2 -ErrorAction SilentlyContinue) {
    Write-Output '尖塔已在运行，请使用当前游戏窗口。'
    exit 0
}
$env:APPDATA = Join-Path $PSScriptRoot 'LocalState\Roaming'
$env:LOCALAPPDATA = Join-Path $PSScriptRoot 'LocalState\Local'
$game = 'D:\youxi\steamapps\common\Slay the Spire 2'
$log = Join-Path $PSScriptRoot 'LocalState\game_live.log'
Start-Process -FilePath (Join-Path $game 'SlayTheSpire2.exe') -WorkingDirectory $game -ArgumentList @(
    '--rendering-method','forward_plus','--rendering-driver','d3d12','--log-file',('"' + $log + '"')
)
