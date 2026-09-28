using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Delve.Flow;
using Delve.Run;

namespace Delve.Dungeon;

/// <summary>The doorway hover: destination, its cleared state, the ward the crossing costs and any
/// warning. Godot-free, so the spike reads the same words the tooltip prints.</summary>
public static class DoorTips
{
    public const string UnexploredTitle = "Unexplored room";
    public const string ClearedSubtitle = "Cleared";
    public const string WardOutWarning = "The ward goes out.";
    public const string FeatsFirstWarning = "Choose feats first";

    public static SheetTip For(DungeonRoom destination, Wardstone ward, IEnumerable<string> pendingPromotions)
    {
        string title = destination.Discovered || destination.Completed || destination.Scouted ? StationPlan.Name(destination.Purpose) : UnexploredTitle;
        string subtitle = destination.Completed ? ClearedSubtitle : "";
        int after = System.Math.Max(0, ward.Ward - ward.Rules.NodeBurn);
        var body = new List<string>();
        var pending = pendingPromotions.ToArray();
        if (NeedsPromotionsFirst(destination) && pending.Length > 0)
            body.Add($"{FeatsFirstWarning}: {string.Join(", ", pending)}");
        if (after <= 0) body.Add(WardOutWarning);
        var figures = new List<FigureView> { new("Ward", after.ToString()) { Before = ward.Ward.ToString() } };
        int upshiftAfter = Wardstone.UpshiftAt(after, ward.Rules);
        if (upshiftAfter != ward.Upshift)
            figures.Add(new FigureView("Danger", DangerLabel(upshiftAfter)) { Before = DangerLabel(ward.Upshift) });
        return new SheetTip(title, subtitle, string.Join("\n", body), Figures: figures);
    }

    /// <summary>"normal", or the tiers added to every rolled threat.</summary>
    public static string DangerLabel(int upshift) => upshift <= 0 ? "normal" : $"+{upshift}";

    /// <summary>Pending promotions hold back every room that could start a fight: a known fight room
    /// or any room not yet seen. Holding back only fight rooms would reveal which unseen rooms fight.</summary>
    public static bool NeedsPromotionsFirst(DungeonRoom destination)
        => !destination.Completed && (!(destination.Discovered || destination.Scouted) || IsFight(destination));

    public static bool IsFight(DungeonRoom room)
        => DungeonFloor.Kind(room.Family) is NodeKind.Combat or NodeKind.Elite or NodeKind.Boss;
}
