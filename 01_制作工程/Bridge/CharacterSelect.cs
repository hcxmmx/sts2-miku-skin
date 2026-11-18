using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes.Screens.CharacterSelect;

namespace Hcxmmx.MikuSkin;

internal static class CharacterSelect
{
    private static PackedScene? _scene;

    internal static void Show(NCharacterSelectScreen screen, CharacterModel model, bool locked = false)
    {
        try
        {
            var background = Traverse.Create(screen).Field("_bgContainer").GetValue<Control>();
            if (background == null) return;
            var host = background.GetParent<Control>();
            var portrait = host.GetNodeOrNull<Control>("MikuPortrait");
            bool enabled = Visuals.IsTarget(model) && !locked;
            if (portrait == null && enabled)
            {
                _scene ??= ResourceLoader.Load<PackedScene>("res://Miku_Hcxmmx/Portrait.tscn");
                if (_scene == null) return;
                portrait = _scene.Instantiate<Control>();
                portrait.Name = "MikuPortrait";
                host.AddChild(portrait);
                portrait.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
                host.MoveChild(portrait, background.GetIndex() + 1);
                portrait.Connect("light_clips_changed", Callable.From<bool>(UserAudio.SetLightClipsEnabled));
            }
            if (portrait == null) return;
            var backgrounds = new Godot.Collections.Array<Control> { background };
            if (host.GetNodeOrNull<Control>("StaticBg") is { } still) backgrounds.Add(still);
            if (screen.GetNodeOrNull<Control>("InfoPanel") is { } info) backgrounds.Add(info);
            if (enabled)
            {
                portrait.Call("set_character_info", model.StartingHp, model.StartingGold, model.StartingRelics[0].Icon);
                portrait.Call("set_light_clips_enabled", UserAudio.LightClipsEnabled);
            }
            portrait.Call("activate", enabled, backgrounds);
        }
        catch (Exception exception) { GD.PushWarning("[MikuSkin] Character select: " + exception.Message); }
    }
}

[HarmonyPatch(typeof(NCharacterSelectScreen), "DoRandomCharacterChange")]
internal static class RandomCharacterPortraitPatch
{
    private static void Postfix(NCharacterSelectScreen __instance, Player __0, ref Task __result) =>
        __result = RefreshAfter(__result, __instance, __0);

    private static async Task RefreshAfter(Task animation, NCharacterSelectScreen screen, Player player)
    {
        await animation;
        if (GodotObject.IsInstanceValid(screen) && screen.IsInsideTree())
            CharacterSelect.Show(screen, player.Character);
    }
}
