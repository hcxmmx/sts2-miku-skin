using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using System.Reflection;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Modding;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes.Combat;
using MegaCrit.Sts2.Core.Saves;

namespace Hcxmmx.MikuSkin;

// Attachment and animation notification follow the series' Entry.cs bridge.
[ModInitializer(nameof(Init))]
public static class Entry
{
    public static void Init()
    {
        UserAudio.Load();
        new Harmony("hcxmmx.miku.visuals").PatchAll(typeof(Entry).Assembly);
        if (Engine.GetMainLoop() is SceneTree tree)
        {
            var script = ResourceLoader.Load<GDScript>("res://Miku_Hcxmmx/Runtime/BattleWarmup.gd");
            if (script?.New().AsGodotObject() is Node warmup)
            {
                warmup.Name = "MikuBattleWarmup";
                tree.Root.CallDeferred(Node.MethodName.AddChild, warmup);
            }
        }
        GD.Print($"[MikuSkin] Initialized {typeof(Entry).Assembly.GetName().Version}, target=FOOL.");
    }
}

[HarmonyPatch(typeof(NCreature), "AnimDie")]
internal static class DeathPatch
{
    private static void Prefix(NCreature __instance) => Visuals.Trigger(__instance, "Dead");
}

[HarmonyPatch(typeof(SfxCmd), nameof(SfxCmd.PlayDeath), new[] { typeof(Player) })]
internal static class DeathSoundPatch
{
    private static bool Prefix(Player player) => Visuals.Skin(player.Creature) == null;
}

[HarmonyPatch(typeof(NCreature), nameof(NCreature.StartReviveAnim))]
internal static class RevivePatch
{
    private static void Prefix(NCreature __instance) => Visuals.Skin(__instance.Entity)?.Call("revive");
}

[HarmonyPatch]
internal static class VictoryPatch
{
    private static MethodBase TargetMethod()
    {
        var turnState = typeof(CombatManager).Assembly.GetType("MegaCrit.Sts2.Core.Combat.CombatTurnState", true)!;
        return AccessTools.DeclaredMethod(typeof(CombatManager), "EndCombatInternal", [turnState]);
    }

    private static void Prefix()
    {
        if (Engine.GetMainLoop() is not SceneTree tree) return;
        foreach (var skin in tree.GetNodesInGroup("miku_battles")) skin.Call("finish_combat");
    }
}

internal static class Visuals
{
    internal const string TargetCharacterId = "FOOL";
    internal const string NodeName = "MikuSkin";
    private static PackedScene? _battle;
    private static int _traceBudget = 24;

    internal static void Trace(string message)
    {
        if (_traceBudget-- > 0) GD.Print("[MikuSkin] " + message);
    }

    internal static bool IsTarget(CharacterModel? character) =>
        string.Equals(character?.Id.Entry, TargetCharacterId, StringComparison.OrdinalIgnoreCase);

    internal static Node2D? Skin(Creature? creature) => IsTarget(creature?.Player?.Character)
        ? creature?.GetCreatureNode()?.Visuals?.GetNodeOrNull<Node2D>(NodeName) : null;

    internal static void Attach(NCreature creature)
    {
        if (!IsTarget(creature.Entity?.Player?.Character)) return;
        var visuals = creature.Visuals;
        if (visuals == null || visuals.GetNodeOrNull(NodeName) != null) return;
        Node2D? skin = null;
        try
        {
            var original = visuals.GetNodeOrNull<Node2D>("%Visuals");
            if (original == null) return;
            _battle ??= ResourceLoader.Load<PackedScene>("res://Miku_Hcxmmx/Battle.tscn");
            skin = _battle?.Instantiate<Node2D>();
            if (skin == null) throw new InvalidOperationException("Battle scene could not load.");
            skin.Name = NodeName;
            visuals.AddChild(skin);
            if (!skin.Call("configure", original, visuals.Bounds.Position, visuals.Bounds.Size,
                !creature.Entity!.IsDead).AsBool())
                throw new InvalidOperationException("Battle actor initialization failed.");
            var settings = SaveManager.Instance.SettingsSave;
            skin.Call("set_audio_policy", settings.VolumeMaster * settings.VolumeSfx,
                SaveManager.Instance.PrefsSave.MuteInBackground, settings.VolumeMaster * settings.VolumeBgm);
            UserAudio.Attach(skin);
            GD.Print($"[MikuSkin] Attached to {creature.Entity.Player?.NetId}, bounds={visuals.Bounds}.");
        }
        catch (Exception ex)
        {
            skin?.QueueFree();
            GD.PushWarning("[MikuSkin] Attachment failed: " + ex);
        }
    }

    internal static void Trigger(NCreature creature, string trigger)
    {
        var skin = Skin(creature.Entity);
        if (skin == null) return;
        Trace("Animation trigger " + trigger);
        skin.Call("handle_trigger", trigger);
    }
}

[HarmonyPatch(typeof(NCreature), nameof(NCreature._Ready))]
internal static class CreatureReadyPatch
{
    private static void Postfix(NCreature __instance) => Visuals.Attach(__instance);
}

[HarmonyPatch(typeof(NCreature), nameof(NCreature.SetAnimationTrigger))]
internal static class AnimationPatch
{
    private static bool Prefix(NCreature __instance, string trigger) =>
        trigger != "Dead" || Visuals.Skin(__instance.Entity) == null;

    private static void Postfix(NCreature __instance, string trigger) => Visuals.Trigger(__instance, trigger);
}
