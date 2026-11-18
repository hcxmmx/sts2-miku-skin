param([string]$GameDir = 'D:\youxi\steamapps\common\Slay the Spire 2')
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\02_构建产物\游戏测试包\MikuSkin'
$destination = Join-Path $GameDir 'mods\MikuSkin'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($name in @('MikuSkin.dll','MikuSkin.json','MikuSkin.pck','音频来源与致谢.md')) {
    Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $destination $name) -Force
    if ((Get-FileHash -LiteralPath (Join-Path $source $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $destination $name)).Hash) {
        throw ('Installed file differs: ' + $name)
    }
}
Write-Output ('Installed and verified: ' + $destination)
