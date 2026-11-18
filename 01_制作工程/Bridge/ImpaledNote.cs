using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.FoolArrows;
using MegaCrit.Sts2.Core.Nodes.Vfx;

namespace Hcxmmx.MikuSkin;

[HarmonyPatch(typeof(NImpaledArrowVfx), nameof(NImpaledArrowVfx._Ready))]
internal static class ImpaledNotePatch
{
    internal const string NoteMeta = "miku_impaled_note";
    private static readonly System.Reflection.FieldInfo Slot = AccessTools.Field(typeof(NImpaledArrowVfx), "_arrowSlot");
    private static readonly System.Reflection.FieldInfo Front = AccessTools.Field(typeof(NImpaledArrowVfx), "_frontArrowVisual");
    private static readonly System.Reflection.FieldInfo Back = AccessTools.Field(typeof(NImpaledArrowVfx), "_backArrowVisual");

    private static void Postfix(NImpaledArrowVfx __instance)
    {
        try
        {
            if (Slot.GetValue(__instance) is not ArrowSlot arrow || Visuals.Skin(arrow.owner.Creature) == null) return;
            if (Front.GetValue(__instance) is not Node2D front || Back.GetValue(__instance) is not Node2D back) return;
            var script = ResourceLoader.Load<GDScript>("res://Miku_Hcxmmx/Runtime/ImpaledNote.gd");
            if (script?.New().AsGodotObject() is not Node2D note) return;
            note.Name = "MikuImpaledNote";
            front.AddChild(note);
            __instance.SetMeta(NoteMeta, true);
            front.SelfModulate = new Color(1, 1, 1, 0);
            back.SelfModulate = new Color(1, 1, 1, 0);
            GD.Print("[MikuSkin] Note attached to native arrow lifetime.");
        }
        catch (Exception ex) { GD.PushWarning("[MikuSkin] Arrow presentation: " + ex); }
    }
}
