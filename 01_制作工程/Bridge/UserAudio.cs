using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Nodes.Audio;
using MegaCrit.Sts2.Core.Nodes.Screens.CharacterSelect;
using MegaCrit.Sts2.Core.Nodes.Vfx;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Cards;
using MegaCrit.Sts2.Core.Saves;

namespace Hcxmmx.MikuSkin;

internal static class UserAudio
{
    private const string ConfigPath = "user://MikuSkin.cfg";
    private const string OwnerMeta = "miku_audio_owner";
    private static bool _lightEnabled = true;
    internal static float ClipVolume { get; private set; } = 1f;
    internal static bool ShootingImpactBoost { get; private set; }

    internal static void Load()
    {
        var config = new ConfigFile();
        if (config.Load(ConfigPath) == Error.Ok)
        {
            _lightEnabled = config.GetValue("audio", "light_clips", true).AsBool();
            ClipVolume = Mathf.Clamp(config.GetValue("audio", "clip_volume", 1f).AsSingle(), 0f, 1f);
            ShootingImpactBoost = config.GetValue("audio", "shooting_impact_boost", false).AsBool();
        }
    }

    internal static void SyncMix(string setting, float value)
    {
        if (Engine.GetMainLoop() is not SceneTree tree) return;
        var skins = tree.GetNodesInGroup("miku_battles");
        if (skins.Count == 0) return;
        var settings = SaveManager.Instance.SettingsSave;
        float master = setting == "SetMasterVol" ? value : settings.VolumeMaster;
        float sfx = setting == "SetSfxVol" ? value : settings.VolumeSfx;
        float bgm = setting == "SetBgmVol" ? value : settings.VolumeBgm;
        foreach (var skin in skins)
            skin.Call("set_audio_policy", master * sfx, SaveManager.Instance.PrefsSave.MuteInBackground, master * bgm);
    }

    internal static void Attach(Node2D skin)
    {
        skin.Call("set_light_enabled", _lightEnabled);
        skin.Call("set_clip_mix", ClipVolume, ShootingImpactBoost);
    }

    internal static bool LightClipsEnabled => _lightEnabled;

    internal static void SetLightClipsEnabled(bool enabled)
    {
        _lightEnabled = enabled;
        SaveOptions();
    }

    internal static void SetClipMix(float volume, bool impactBoost)
    {
        ClipVolume = Mathf.Clamp(volume, 0f, 1f);
        ShootingImpactBoost = impactBoost;
        SaveOptions();
    }

    private static void SaveOptions()
    {
        var config = new ConfigFile();
        config.Load(ConfigPath);
        if (config.HasSectionKey("audio", "battle_music"))
            config.EraseSectionKey("audio", "battle_music");
        config.SetValue("audio", "light_clips", _lightEnabled);
        config.SetValue("audio", "clip_volume", ClipVolume);
        config.SetValue("audio", "shooting_impact_boost", ShootingImpactBoost);
        var error = config.Save(ConfigPath);
        if (error != Error.Ok) GD.PushWarning("[MikuSkin] Could not save audio options: " + error);
    }

    internal static void TagMelody(Creature creature, Node2D? effect)
    {
        var skin = Visuals.Skin(creature);
        if (effect != null && skin != null) effect.SetMeta(OwnerMeta, skin.GetInstanceId());
    }

    internal static void Melody(string sound, float volume, Node2D effect)
    {
        if (effect.HasMeta(OwnerMeta) && GodotObject.InstanceFromId(effect.GetMeta(OwnerMeta).AsUInt64()) is Node2D skin)
        {
            var kind = effect switch { NWahVfx => "wah", NChoVfx => "cho", _ => "ki" };
            if (skin.Call("play_melody", kind).AsBool()) return;
        }
        SfxCmd.Play(sound, volume);
    }

    internal static void CardSound(string sound, float volume, CardModel card)
    {
        if (Visuals.Skin(card.Owner.Creature) == null) SfxCmd.Play(sound, volume);
    }

    internal static void RetrieveSound(string sound, float volume, NImpaledArrowVfx effect)
    {
        if (!effect.HasMeta(ImpaledNotePatch.NoteMeta)) SfxCmd.Play(sound, volume);
    }
}

[HarmonyPatch]
internal static class DirectCardSoundPatch
{
    private static IEnumerable<MethodBase> TargetMethods()
    {
        foreach (var type in new[] { typeof(BrightenUp), typeof(Ecstasy), typeof(SelfDeprecate) })
            yield return CombatPatchTargets.MoveNext(AccessTools.DeclaredMethod(type, "OnPlay"));
        var closure = typeof(RainShot).GetNestedTypes(BindingFlags.NonPublic).Single(type =>
            type.GetFields(BindingFlags.Instance | BindingFlags.Public).Any(field => field.FieldType == typeof(RainShot))
            && type.GetMethods(BindingFlags.Instance | BindingFlags.NonPublic).Any(method => method.Name.Contains("g__ActionToPerform|")));
        var action = closure.GetMethods(BindingFlags.Instance | BindingFlags.NonPublic).Single(method =>
            method.Name.Contains("g__ActionToPerform|") && method.GetCustomAttribute<AsyncStateMachineAttribute>() != null);
        yield return CombatPatchTargets.MoveNext(action);
    }

    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions, MethodBase __originalMethod)
    {
        var owner = AccessTools.Field(__originalMethod.DeclaringType, "<>4__this");
        var card = typeof(CardModel).IsAssignableFrom(owner.FieldType) ? null : AccessTools.Field(owner.FieldType, "<>4__this");
        if (!typeof(CardModel).IsAssignableFrom(card?.FieldType ?? owner.FieldType))
            throw new InvalidOperationException("Card sound owner changed: " + __originalMethod);
        var play = AccessTools.Method(typeof(SfxCmd), nameof(SfxCmd.Play), [typeof(string), typeof(float)]);
        int count = 0;
        foreach (var instruction in instructions)
        {
            if (instruction.Calls(play))
            {
                count++;
                yield return new CodeInstruction(OpCodes.Ldarg_0).MoveLabelsFrom(instruction);
                yield return new CodeInstruction(OpCodes.Ldfld, owner);
                if (card != null) yield return new CodeInstruction(OpCodes.Ldfld, card);
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.Method(typeof(UserAudio), nameof(UserAudio.CardSound));
            }
            yield return instruction;
        }
        if (count != 1) throw new InvalidOperationException("Direct card sound site changed: " + __originalMethod);
    }
}

[HarmonyPatch(typeof(NImpaledArrowVfx), "RetrieveAndFree")]
internal static class RetrieveSoundPatch
{
    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
    {
        var play = AccessTools.Method(typeof(SfxCmd), nameof(SfxCmd.Play), [typeof(string), typeof(float)]);
        int count = 0;
        foreach (var instruction in instructions)
        {
            if (instruction.Calls(play))
            {
                count++;
                yield return new CodeInstruction(OpCodes.Ldarg_0).MoveLabelsFrom(instruction);
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.Method(typeof(UserAudio), nameof(UserAudio.RetrieveSound));
            }
            yield return instruction;
        }
        if (count != 1) throw new InvalidOperationException("Arrow retrieval sound site changed: " + count);
    }
}

[HarmonyPatch(typeof(NCharacterSelectScreen), "SelectCharacter")]
internal static class MusicOptionPatch
{
    private static void Postfix(NCharacterSelectScreen __instance, NCharacterSelectButton charSelectButton)
    {
        CharacterSelect.Show(__instance, charSelectButton.Character, charSelectButton.IsLocked || charSelectButton.IsRandom);
    }
}

[HarmonyPatch]
internal static class NativeMusicVolumePatch
{
    private static IEnumerable<MethodBase> TargetMethods() => new[] { "SetMasterVol", "SetSfxVol", "SetBgmVol" }
        .Select(name => AccessTools.Method(typeof(NAudioManager), name));

    private static void Prefix(MethodBase __originalMethod, float volume) =>
        UserAudio.SyncMix(__originalMethod.Name, volume);
}

[HarmonyPatch]
internal static class MelodyOwnerPatch
{
    private static IEnumerable<MethodBase> TargetMethods() => new[] { typeof(NWahVfx), typeof(NChoVfx), typeof(NKiVfx) }
        .Select(type => AccessTools.Method(type, "Create", [typeof(Creature)]));
    private static void Postfix(Creature creature, Node2D? __result) => UserAudio.TagMelody(creature, __result);
}

[HarmonyPatch]
internal static class MelodySoundPatch
{
    private static IEnumerable<MethodBase> TargetMethods() => new[] { typeof(NWahVfx), typeof(NChoVfx), typeof(NKiVfx) }
        .Select(type => AccessTools.Method(type, "_Ready"));

    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
    {
        var play = AccessTools.Method(typeof(SfxCmd), nameof(SfxCmd.Play), [typeof(string), typeof(float)]);
        int count = 0;
        foreach (var instruction in instructions)
        {
            if (instruction.Calls(play))
            {
                count++;
                yield return new CodeInstruction(OpCodes.Ldarg_0).MoveLabelsFrom(instruction);
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.Method(typeof(UserAudio), nameof(UserAudio.Melody));
            }
            yield return instruction;
        }
        if (count != 1) throw new InvalidOperationException("Melody sound call site changed: " + count);
    }
}
