using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Commands.Builders;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Hooks;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes.Vfx;
using MegaCrit.Sts2.Core.ValueProps;

namespace Hcxmmx.MikuSkin;

internal static class CombatVfx
{
    private sealed class ImpactScope(Node2D skin, string trigger, object targets)
    {
        internal readonly Node2D Skin = skin;
        internal readonly string Trigger = trigger;
        internal readonly object Targets = targets;
        internal bool SoundPlayed;
        internal bool Handled;
    }

    private static readonly AsyncLocal<ImpactScope?> Hitting = new();
    private static readonly ConditionalWeakTable<DamageResult, object> Handled = new();
    private static readonly ConditionalWeakTable<DamageResult, object> Blocked = new();
    private static readonly FieldInfo Animation = AccessTools.Field(typeof(AttackCommand), "_attackerAnimName");
    private static readonly FieldInfo ShouldAnimate = AccessTools.Field(typeof(AttackCommand), "_shouldPlayAnimation");
    private static readonly FieldInfo VisualAttacker = AccessTools.Field(typeof(AttackCommand), "_visualAttacker");

    internal static Node2D? Skin(AttackCommand command)
    {
        if (Animation.GetValue(command) is not ("Attack" or "shootBow") ||
            !(bool)ShouldAnimate.GetValue(command)! ||
            VisualAttacker.GetValue(command) is Creature visual && !ReferenceEquals(visual, command.Attacker)) return null;
        return Visuals.Skin(command.Attacker);
    }

    private static bool GenericSound(string? sound) => sound is
        "slash_attack.mp3" or "blunt_attack.mp3" or "heavy_attack.mp3" or "event:/sfx/characters/fool/fool_shot"
        or "event:/sfx/characters/fugitive/fugitive_joy";

    internal static void Prepare(AttackCommand command)
    {
        if (Skin(command) == null) return;
        // Replace generic effects while preserving card-specific effects.
        foreach (var name in new[] { "_attackerSfx", "_tmpAttackerSfx" })
        {
            var field = AccessTools.Field(typeof(AttackCommand), name);
            if (GenericSound(field.GetValue(command) as string)) field.SetValue(command, null);
        }
        var vfx = command.HitVfx is VfxCmd.slashPath or VfxCmd.bluntPath or VfxCmd.heavyBluntPath ? null : command.HitVfx;
        command.WithHitFx(vfx, GenericSound(command.HitSfx) ? null : command.HitSfx,
            GenericSound(command.TmpHitSfx) ? null : command.TmpHitSfx);
    }

    internal static bool ReplacesCharacterSound(Creature creature, string trigger) =>
        trigger is "Attack" or "Cast" or "PowerUp" && Visuals.Skin(creature) != null;

    internal static async Task TriggerAttack(Creature creature, string trigger, float delay)
    {
        var skin = Visuals.Skin(creature);
        if (skin == null || trigger != "shootBow")
        {
            await CreatureCmd.TriggerAnim(creature, trigger, delay);
            return;
        }
        float hitDelay = skin.Call("hit_delay").AsSingle();
        await CreatureCmd.TriggerAnim(creature, trigger, 0f);
        // Match the accepted wave in Standard and Fast modes. Instant remains native.
        await Cmd.CustomScaledWait(hitDelay, hitDelay);
    }

    internal static async Task<IEnumerable<DamageResult>> DealDamage(PlayerChoiceContext choiceContext,
        IEnumerable<DamageTargetData>? targets, decimal amount, ValueProp props, Creature? dealer,
        CardModel? cardSource, CardPlay? cardPlay, ModifyDamageHookType hookType, AttackCommand command)
    {
        var previous = Hitting.Value;
        var skin = Skin(command);
        Hitting.Value = skin != null && targets != null && props.HasFlag(ValueProp.Move)
            ? new ImpactScope(skin, (string)Animation.GetValue(command)!, targets) : null;
        try { return await CreatureCmd.Damage(choiceContext, targets, amount, props, dealer, cardSource, cardPlay, hookType); }
        finally { Hitting.Value = previous; }
    }

    internal static bool ShouldBlock(DamageResult result, Creature? dealer, ValueProp props) =>
        result.WasFullyBlocked && result.UnblockedDamage == 0 && result.BlockedDamage > 0 &&
        dealer != null && !ReferenceEquals(dealer, result.Receiver) && props.HasFlag(ValueProp.Move) &&
        !props.HasFlag(ValueProp.Unblockable) && !props.HasFlag(ValueProp.SkipHurtAnim);

    internal static bool ObserveResult(DamageResult result, object targets, Creature? dealer, ValueProp props)
    {
        if (ShouldBlock(result, dealer, props) && !Blocked.TryGetValue(result, out _))
        {
            var defender = Visuals.Skin(result.Receiver);
            if (defender != null)
            {
                defender.Call("handle_trigger", "Block");
                Blocked.Add(result, new object());
            }
        }
        var scope = Hitting.Value;
        if (scope == null || !ReferenceEquals(scope.Targets, targets) || Handled.TryGetValue(result, out _) ||
            !(result.UnblockedDamage > 0 || result.OverkillDamage > 0 || result.WasFullyBlocked && result.BlockedDamage > 0))
            return result.WasFullyBlocked;
        try
        {
            var node = result.Receiver.GetCreatureNode();
            var container = result.Receiver.GetVfxContainer();
            if (node == null || container == null || !GodotObject.IsInstanceValid(scope.Skin)) return result.WasFullyBlocked;
            if (!scope.Skin.Call("confirm_hit", scope.Trigger, node.Visuals, node.VfxSpawnPosition,
                container, node.Body, !scope.SoundPlayed, !result.WasFullyBlocked).AsBool()) return result.WasFullyBlocked;
            Handled.Add(result, new object());
            scope.Handled = true;
            scope.SoundPlayed = true;
        }
        catch (Exception ex) { GD.PushWarning("[MikuSkin] Impact notification: " + ex); }
        return result.WasFullyBlocked;
    }

    internal static bool ReplacesSpark(DamageResult result) => Handled.TryGetValue(result, out _);

    internal static bool ReplacesDamageSound(object targets)
    {
        var scope = Hitting.Value;
        return scope != null && ReferenceEquals(scope.Targets, targets) && scope.Handled;
    }

    internal static void Aim(Creature? source, Creature? target)
    {
        var skin = Visuals.Skin(source);
        var node = target?.GetCreatureNode();
        if (skin != null && node != null) skin.Call("aim_at", node.Visuals, node.VfxSpawnPosition);
    }
}

internal static class CombatPatchTargets
{
    internal static LocalBuilder[] SaveArguments(CodeInstruction original, ILGenerator generator, out List<CodeInstruction> saves)
    {
        var method = (MethodInfo)original.operand;
        var types = method.GetParameters().Select(parameter => parameter.ParameterType).ToList();
        if (!method.IsStatic) types.Insert(0, method.DeclaringType!);
        var arguments = types.Select(generator.DeclareLocal).ToArray();
        saves = [];
        for (int index = arguments.Length - 1; index >= 0; index--)
        {
            var save = new CodeInstruction(OpCodes.Stloc, arguments[index]);
            if (index == arguments.Length - 1) save.MoveLabelsFrom(original).MoveBlocksFrom(original);
            saves.Add(save);
        }
        return arguments;
    }

    internal static MethodInfo MoveNext(MethodInfo method) => AccessTools.Method(
        method.GetCustomAttribute<AsyncStateMachineAttribute>()!.StateMachineType, "MoveNext");
    internal static readonly MethodInfo Damage = typeof(CreatureCmd).GetMethods().Single(method =>
        method.Name == nameof(CreatureCmd.Damage) && method.GetParameters().Length == 8 &&
        method.GetParameters()[1].ParameterType == typeof(IEnumerable<DamageTargetData>) &&
        method.GetParameters()[2].ParameterType == typeof(decimal));
}

[HarmonyPatch(typeof(Hook), nameof(Hook.BeforeCardPlayed))]
internal static class CardTargetPatch
{
    private static void Prefix(CardPlay cardPlay) => CombatVfx.Aim(cardPlay.Card.Owner.Creature, cardPlay.Target);
}

[HarmonyPatch(typeof(AttackCommand), "GetPossibleTargets")]
internal static class AttackTargetPatch
{
    private static void Postfix(AttackCommand __instance, IReadOnlyList<Creature> __result)
    {
        if (__result.Count == 1) CombatVfx.Aim(__instance.Attacker, __result[0]);
    }
}

[HarmonyPatch(typeof(AttackCommand), nameof(AttackCommand.Execute))]
internal static class AttackPreparePatch
{
    private static void Prefix(AttackCommand __instance) => CombatVfx.Prepare(__instance);
}

// Run after King's wrappers and retain each existing call as the fallback.
// Harmony reapplies this ordering regardless of which mod initializes first.
[HarmonyPatch]
internal static class AttackDamagePatch
{
    private static MethodBase TargetMethod() => CombatPatchTargets.MoveNext(typeof(AttackCommand).GetMethod(nameof(AttackCommand.Execute))!);

    [HarmonyPriority(Priority.Last)]
    [HarmonyAfter("sts2.hcxmmx.king.visuals")]
    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions, ILGenerator generator, MethodBase __originalMethod)
    {
        var command = AccessTools.Field(__originalMethod.DeclaringType, "<>4__this");
        var trigger = AccessTools.Method(typeof(CreatureCmd), nameof(CreatureCmd.TriggerAnim));
        int damages = 0, animations = 0;
        foreach (var instruction in instructions)
        {
            var method = instruction.operand as MethodInfo;
            bool king = method?.DeclaringType?.FullName == "Hcxmmx.KingMod.Scripts.KingWeaponAudio";
            bool damage = instruction.Calls(CombatPatchTargets.Damage) || king && method!.Name == "DealDamage";
            bool animation = instruction.Calls(trigger) || king && method!.Name == "TriggerAttack";
            if (!damage && !animation)
            {
                yield return instruction;
                continue;
            }
            if (damage) damages++; else animations++;
            var arguments = CombatPatchTargets.SaveArguments(instruction, generator, out var saves);
            foreach (var save in saves) yield return save;
            var original = generator.DefineLabel();
            var end = generator.DefineLabel();
            yield return new CodeInstruction(OpCodes.Ldarg_0);
            yield return new CodeInstruction(OpCodes.Ldfld, command);
            yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(CombatVfx), nameof(CombatVfx.Skin)));
            yield return new CodeInstruction(OpCodes.Brfalse, original);
            int nativeArguments = damage ? 8 : 3;
            foreach (var argument in arguments.Take(nativeArguments)) yield return new CodeInstruction(OpCodes.Ldloc, argument);
            if (damage)
            {
                yield return new CodeInstruction(OpCodes.Ldarg_0);
                yield return new CodeInstruction(OpCodes.Ldfld, command);
            }
            yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(CombatVfx), damage ? nameof(CombatVfx.DealDamage) : nameof(CombatVfx.TriggerAttack)));
            yield return new CodeInstruction(OpCodes.Br, end);
            var reload = arguments.Select(argument => new CodeInstruction(OpCodes.Ldloc, argument)).ToArray();
            reload[0].labels.Add(original);
            foreach (var load in reload) yield return load;
            yield return instruction;
            var tail = new CodeInstruction(OpCodes.Nop);
            tail.labels.Add(end);
            yield return tail;
        }
        if (damages != 1 || animations != 1) throw new InvalidOperationException($"Attack call sites changed ({damages}, {animations}).");
    }
}

[HarmonyPatch]
internal static class CharacterSoundPatch
{
    private static MethodBase TargetMethod() => CombatPatchTargets.MoveNext(AccessTools.Method(typeof(CreatureCmd), nameof(CreatureCmd.TriggerAnim)));

    [HarmonyPriority(Priority.Last)]
    [HarmonyAfter("sts2.hcxmmx.king.visuals")]
    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions, ILGenerator generator, MethodBase __originalMethod)
    {
        var play = AccessTools.Method(typeof(SfxCmd), nameof(SfxCmd.Play), [typeof(string), typeof(float)]);
        int count = 0;
        foreach (var instruction in instructions)
        {
            var method = instruction.operand as MethodInfo;
            bool king = method?.DeclaringType?.FullName == "Hcxmmx.KingMod.Scripts.KingWeaponAudio" && method.Name == "PlayCharacterAttack";
            if (instruction.Calls(play) || king)
            {
                count++;
                var original = generator.DefineLabel();
                var end = generator.DefineLabel();
                yield return new CodeInstruction(OpCodes.Ldarg_0).MoveLabelsFrom(instruction);
                yield return new CodeInstruction(OpCodes.Ldfld, AccessTools.Field(__originalMethod.DeclaringType, "creature"));
                yield return new CodeInstruction(OpCodes.Ldarg_0);
                yield return new CodeInstruction(OpCodes.Ldfld, AccessTools.Field(__originalMethod.DeclaringType, "triggerName"));
                yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(CombatVfx), nameof(CombatVfx.ReplacesCharacterSound)));
                yield return new CodeInstruction(OpCodes.Brfalse, original);
                foreach (var parameter in method!.GetParameters()) yield return new CodeInstruction(OpCodes.Pop);
                yield return new CodeInstruction(OpCodes.Br, end);
                instruction.labels.Add(original);
                yield return instruction;
                var tail = new CodeInstruction(OpCodes.Nop);
                tail.labels.Add(end);
                yield return tail;
            }
            else yield return instruction;
        }
        if (count != 3) throw new InvalidOperationException($"Character sound sites changed ({count}).");
    }
}

[HarmonyPatch]
internal static class DamageResultPatch
{
    private static MethodBase TargetMethod() => CombatPatchTargets.MoveNext(CombatPatchTargets.Damage);

    [HarmonyPriority(Priority.Last)]
    [HarmonyAfter("sts2.hcxmmx.king.visuals")]
    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions, ILGenerator generator, MethodBase __originalMethod)
    {
        var codes = instructions.ToList();
        var blocked = AccessTools.PropertyGetter(typeof(DamageResult), nameof(DamageResult.WasFullyBlocked));
        var targets = AccessTools.Field(__originalMethod.DeclaringType, "targetData");
        var spark = AccessTools.Method(typeof(NHitSparkVfx), nameof(NHitSparkVfx.Create));
        var damageSound = AccessTools.Method(typeof(SfxCmd), nameof(SfxCmd.PlayDamage));
        var resolvedResult = generator.DeclareLocal(typeof(DamageResult));
        int results = 0, sparks = 0, sounds = 0;
        for (int index = 0; index < codes.Count; index++)
        {
            var instruction = codes[index];
            var method = instruction.operand as MethodInfo;
            bool kingObserve = method?.DeclaringType?.FullName == "Hcxmmx.KingMod.Scripts.KingWeaponAudio" && method.Name == "ObserveResult";
            bool observe = kingObserve || instruction.Calls(blocked) && index + 1 < codes.Count &&
                (codes[index + 1].opcode == OpCodes.Brtrue || codes[index + 1].opcode == OpCodes.Brtrue_S);
            bool isSpark = instruction.Calls(spark) || method?.DeclaringType?.FullName == "Hcxmmx.KingMod.Scripts.KingEnemyImpact" && method.Name == "CreateNativeSpark";
            if (observe)
            {
                results++;
                var arguments = CombatPatchTargets.SaveArguments(instruction, generator, out var saves);
                foreach (var save in saves) yield return save;
                yield return new CodeInstruction(OpCodes.Ldloc, arguments[0]);
                yield return new CodeInstruction(OpCodes.Stloc, resolvedResult);
                yield return new CodeInstruction(OpCodes.Ldloc, resolvedResult);
                yield return new CodeInstruction(OpCodes.Ldarg_0);
                yield return new CodeInstruction(OpCodes.Ldfld, targets);
                yield return new CodeInstruction(OpCodes.Ldarg_0);
                yield return new CodeInstruction(OpCodes.Ldfld, AccessTools.Field(__originalMethod.DeclaringType, "dealer"));
                yield return new CodeInstruction(OpCodes.Ldarg_0);
                yield return new CodeInstruction(OpCodes.Ldfld, AccessTools.Field(__originalMethod.DeclaringType, "props"));
                yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(CombatVfx), nameof(CombatVfx.ObserveResult)));
                yield return new CodeInstruction(OpCodes.Pop);
                foreach (var argument in arguments) yield return new CodeInstruction(OpCodes.Ldloc, argument);
                yield return instruction;
            }
            else if (isSpark || instruction.Calls(damageSound))
            {
                if (isSpark) sparks++; else sounds++;
                var original = generator.DefineLabel();
                var end = generator.DefineLabel();
                CodeInstruction first = isSpark ? new CodeInstruction(OpCodes.Ldloc, resolvedResult) : new CodeInstruction(OpCodes.Ldarg_0);
                yield return first.MoveLabelsFrom(instruction);
                if (!isSpark) yield return new CodeInstruction(OpCodes.Ldfld, targets);
                yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(CombatVfx), isSpark ? nameof(CombatVfx.ReplacesSpark) : nameof(CombatVfx.ReplacesDamageSound)));
                yield return new CodeInstruction(OpCodes.Brfalse, original);
                foreach (var parameter in method!.GetParameters()) yield return new CodeInstruction(OpCodes.Pop);
                if (isSpark) yield return new CodeInstruction(OpCodes.Ldnull);
                yield return new CodeInstruction(OpCodes.Br, end);
                instruction.labels.Add(original);
                yield return instruction;
                var tail = new CodeInstruction(OpCodes.Nop);
                tail.labels.Add(end);
                yield return tail;
            }
            else yield return instruction;
        }
        if (results != 1 || sparks != 1 || sounds != 1)
            throw new InvalidOperationException($"Damage result sites changed ({results}, {sparks}, {sounds}).");
    }
}
