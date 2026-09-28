using Godot;

namespace Delve.UI;

/// <summary>Roll colours from the party's point of view: a hero's success and an enemy's failure read
/// as good news, an enemy's success as danger. The outcome word and its track zone share one tone.</summary>
public static class RollTone
{
    public static Color For(int zone, bool enemyRoll)
    {
        if (enemyRoll && zone == DegreeZones.Success) return UiColors.Enemy;
        return DegreeZones.ForParty(zone, enemyRoll) switch
        {
            DegreeZones.CriticalSuccess => UiColors.Accent,
            DegreeZones.Success => UiColors.HpHigh,
            DegreeZones.Failure => UiColors.TextDim,
            _ => UiColors.HpLow,
        };
    }

    public static Color For(CombatRoll roll) => For(roll.DegreeIndex, roll.EnemyRoll);

    /// <summary>A natural 20 reads in the accent, a natural 1 in the low tone, other faces in the
    /// label's own colour.</summary>
    public static void PaintFace(Label face, int die)
    {
        if (die == 20) Paint(face, UiColors.Accent);
        else if (die == 1) Paint(face, UiColors.HpLow);
        else face.RemoveThemeColorOverride("font_color");
    }

    public static void Paint(Label label, Color color) => label.AddThemeColorOverride("font_color", color);
}
