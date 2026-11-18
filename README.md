# 初音未来 V4 · 愚者外观

《杀戮尖塔 2》的初音未来愚者外观模组。Hatsune Miku skin for the Fool in Slay the Spire 2.

版本 `0.1.29`。已在 Windows 的游戏 `v0.113.1` 测试，游戏清单最低版本为 `0.113.1`。

- 经典初音动态选人立绘、电子舞台与扫描信息屏。
- 16 项战斗动作演出、常驻音乐舞台、命中与受击反馈。
- 轻攻击歌曲片段、强音人声、三旋律音频，并替换小头像、地图标记、休息房与商店人物外观。
- 选人信息屏右上角的齿轮可以切换「轻攻击音乐片段」。

## 安装与反馈

运行版通过 Steam 创意工坊提供。订阅后完整重启游戏，在选人界面选愚者。同一模组从本地和工坊各安装了一份时，请只启用一份。

欢迎到工坊评论或 [GitHub Issues](https://github.com/hcxmmx/sts2-miku-skin/issues) 反馈。涉及错位、音频叠加或掉帧时，欢迎附上游戏与模组版本、发生场景、触发卡牌和复现步骤。演出与曲目建议也欢迎。

## 源码与构建

- `01_制作工程/Bridge` 是 .NET 9 的 C# 游戏桥接。
- `01_制作工程/Godot` 是 Godot 4.5.1 的运行与预览脚本、场景及着色器。
- `01_制作工程/tools` 包含导入、烘焙和桥接检查工具。
- `00_用户素材/音频/catalog.json` 记录音频素材的路径、来源和使用方式。

拥有本机游戏安装和 .NET 9 SDK 即可单独编译桥接层。项目引用游戏目录中的 `sts2.dll`、`0Harmony.dll` 和 `GodotSharp.dll`。

```powershell
dotnet build ./01_制作工程\Bridge\MikuSkin.csproj -c Release "-p:Sts2Dir=C:\SteamLibrary\steamapps\common\Slay the Spire 2"
```

完整的 PCK 构建需要本地素材工作区。准备 `Godot/Miku_Hcxmmx/Assets` 和同路径替换贴图 `Godot/images`，依据导入工具中的路径准备原始音频、战斗资源、ALICE Fiction 立绘与电子舞台素材。立绘转换另需按上游许可准备 `01_制作工程/tools/vendor/spine38/spine-core.js`。构建使用 Godot 4.5.1 Mono、Node.js 和装有 NumPy 的 Python，原战斗特效的烘焙工具另用 UnityPy。运行 `01_制作工程/build.ps1` 时可通过 `-GameDir`、`-Godot`、`-DotnetQa` 指定本机工具和路径。公开仓库提供代码和素材清单，完整演出的复现依赖这些本地输入。

## 许可与致谢

自有代码使用 [MIT License](LICENSE)。第三方素材及许可边界见 [素材来源](ATTRIBUTION.md) 和 [音频来源与致谢](音频来源与致谢.md)。
