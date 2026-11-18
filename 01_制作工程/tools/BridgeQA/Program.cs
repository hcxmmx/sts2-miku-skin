using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.Loader;

var gameDir = Path.GetFullPath(args[0]);
var modPath = Path.GetFullPath(args[1]);
AssemblyLoadContext.Default.Resolving += (_, name) =>
{
    var path = Path.Combine(gameDir, name.Name + ".dll");
    return File.Exists(path) ? AssemblyLoadContext.Default.LoadFromAssemblyPath(path) : null;
};
var game = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(gameDir, "sts2.dll"));
var mod = AssemblyLoadContext.Default.LoadFromAssemblyPath(modPath);
const BindingFlags All = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance;
foreach (var type in mod.GetTypes())
foreach (var method in type.GetMethods(All | BindingFlags.DeclaredOnly))
    if (!method.ContainsGenericParameters) RuntimeHelpers.PrepareMethod(method.MethodHandle);

var harmonyAssembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.Combine(gameDir, "0Harmony.dll"));
var harmonyType = harmonyAssembly.GetType("HarmonyLib.Harmony", true)!;
var otherMods = args.Skip(2).Where(value => value != "--miku-first").ToArray();
void PatchOtherMods()
{
    foreach (var path in otherMods)
    {
        var assembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.GetFullPath(path));
        var kingGlobals = assembly.GetType("Hcxmmx.KingMod.Scripts.KingGlobals");
        var id = kingGlobals?.GetField("HarmonyId", All)?.GetRawConstantValue() as string
            ?? "miku.compat." + assembly.GetName().Name;
        var instance = Activator.CreateInstance(harmonyType, id)!;
        harmonyType.GetMethod("PatchAll", [typeof(Assembly)])!.Invoke(instance, [assembly]);
        Console.WriteLine("COMPAT " + assembly.GetName().Name);
    }
}
if (!args.Contains("--miku-first")) PatchOtherMods();
var harmony = Activator.CreateInstance(harmonyType, "miku.bridge.qa")!;
harmonyType.GetMethod("PatchAll", [typeof(Assembly)])!.Invoke(harmony, [mod]);
if (args.Contains("--miku-first")) PatchOtherMods();
var patched = ((IEnumerable<MethodBase>)harmonyType.GetMethod("GetPatchedMethods")!.Invoke(harmony, null)!).ToArray();
foreach (var method in patched) Console.WriteLine("PATCH " + method.DeclaringType!.FullName + "." + method.Name);
if (patched.Length != 31) throw new Exception("Expected thirty-one bridge hooks, found " + patched.Length);
var playerType = game.GetType("MegaCrit.Sts2.Core.Entities.Players.Player", true)!;
if (!patched.Any(method => method.DeclaringType?.FullName == "MegaCrit.Sts2.Core.Commands.SfxCmd"
    && method.Name == "PlayDeath" && method.GetParameters().Select(parameter => parameter.ParameterType).SequenceEqual([playerType])))
    throw new Exception("Expected player death sound hook.");

var command = game.GetType("MegaCrit.Sts2.Core.Commands.Builders.AttackCommand", true)!;
var state = command.GetMethod("Execute")!.GetCustomAttribute<AsyncStateMachineAttribute>()!.StateMachineType;
var moveNext = state.GetMethod("MoveNext", All)!;
var processor = harmonyAssembly.GetType("HarmonyLib.PatchProcessor", true)!;
var instructionsMethod = processor.GetMethods(All).Single(method => method.Name == "GetCurrentInstructions"
    && !method.GetParameters().Any(parameter => parameter.ParameterType.IsByRef));
var values = instructionsMethod.GetParameters().Select(parameter => parameter.ParameterType == typeof(MethodBase)
    ? (object)moveNext : parameter.ParameterType == typeof(int) ? int.MaxValue : null).ToArray();
var instructions = (System.Collections.IEnumerable)instructionsMethod.Invoke(null, values)!;
var calls = instructions.Cast<object>().Select(instruction => instruction.GetType().GetField("operand")!.GetValue(instruction))
    .OfType<MethodInfo>().ToArray();
if (calls.Count(method => method.DeclaringType?.Name == "CombatVfx" && method.Name == "DealDamage") != 1
    || calls.Count(method => method.DeclaringType?.Name == "CombatVfx" && method.Name == "TriggerAttack") != 1)
    throw new Exception("Scoped damage or animation wrapper count mismatch.");
var damage = mod.GetType("Hcxmmx.MikuSkin.CombatPatchTargets", true)!.GetField("Damage", All)!.GetValue(null) as MethodInfo;
var damageState = damage!.GetCustomAttribute<AsyncStateMachineAttribute>()!.StateMachineType;
values = instructionsMethod.GetParameters().Select(parameter => parameter.ParameterType == typeof(MethodBase)
    ? (object)damageState.GetMethod("MoveNext", All)! : parameter.ParameterType == typeof(int) ? int.MaxValue : null).ToArray();
instructions = (System.Collections.IEnumerable)instructionsMethod.Invoke(null, values)!;
calls = instructions.Cast<object>().Select(instruction => instruction.GetType().GetField("operand")!.GetValue(instruction))
    .OfType<MethodInfo>().ToArray();
foreach (var name in new[] { "ObserveResult", "ReplacesSpark", "ReplacesDamageSound" })
    if (calls.Count(method => method.DeclaringType?.Name == "CombatVfx" && method.Name == name) != 1)
        throw new Exception("Expected one resolved-impact wrapper: " + name);
foreach (var target in patched.Where(method => method.Name == "RetrieveAndFree"
    || method.DeclaringType?.FullName?.Contains("Models.Cards.") == true))
{
    values = instructionsMethod.GetParameters().Select(parameter => parameter.ParameterType == typeof(MethodBase)
        ? (object)target : parameter.ParameterType == typeof(int) ? int.MaxValue : null).ToArray();
    instructions = (System.Collections.IEnumerable)instructionsMethod.Invoke(null, values)!;
    var wrappers = instructions.Cast<object>().Select(instruction => instruction.GetType().GetField("operand")!.GetValue(instruction))
        .OfType<MethodInfo>().Count(method => method.DeclaringType?.Name == "UserAudio"
            && method.Name is "CardSound" or "RetrieveSound");
    if (wrappers != 1) throw new Exception("Expected one scoped sound wrapper: " + target);
}
Console.WriteLine("MIKU_BRIDGE_QA PASS JIT, thirty-one hooks, scoped damage, melodies, music option, death/revive/victory, scoped card/retrieval sounds");
var creatureType = game.GetType("MegaCrit.Sts2.Core.Entities.Creatures.Creature", true)!;
var resultType = game.GetType("MegaCrit.Sts2.Core.Entities.Creatures.DamageResult", true)!;
var propsType = game.GetType("MegaCrit.Sts2.Core.ValueProps.ValueProp", true)!;
var receiver = RuntimeHelpers.GetUninitializedObject(creatureType);
var dealer = RuntimeHelpers.GetUninitializedObject(creatureType);
var move = Enum.Parse(propsType, "Move");
var result = Activator.CreateInstance(resultType, [receiver, move])!;
resultType.GetProperty("WasFullyBlocked")!.SetValue(result, true);
resultType.GetProperty("BlockedDamage")!.SetValue(result, 5);
var shouldBlock = mod.GetType("Hcxmmx.MikuSkin.CombatVfx", true)!.GetMethod("ShouldBlock", All)!;
bool Blocks(object? attacker, object props) => (bool)shouldBlock.Invoke(null, [result, attacker, props])!;
if (!Blocks(dealer, move) || Blocks(receiver, move) || Blocks(null, move))
    throw new Exception("Full-block/dealer classification failed.");
resultType.GetProperty("UnblockedDamage")!.SetValue(result, 1);
if (Blocks(dealer, move)) throw new Exception("HP loss must use hurt animation.");
resultType.GetProperty("UnblockedDamage")!.SetValue(result, 0);
foreach (var flag in new[] { "Unblockable", "SkipHurtAnim" })
{
    var combined = Enum.ToObject(propsType, Convert.ToInt64(move) | Convert.ToInt64(Enum.Parse(propsType, flag)));
    if (Blocks(dealer, combined)) throw new Exception("Unexpected block animation for " + flag);
}
Console.WriteLine("MIKU_DEFENSE_QA PASS full block, partial block, self damage, missing dealer, hurt exclusions");
Console.WriteLine("GAME " + game.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion);
