namespace Delve.UI;

/// <summary>How a roll is staged. Centre stage (H1) plays while the journal has not revealed the
/// defence the roll is checked against; the degree track (H3) plays once it has.</summary>
public enum RollStage { CentreStage, DegreeTrack }

/// <summary>Full: the hero beat. Short: face, total and outcome straight into the row. Settled: the
/// finished row only, with no wait.</summary>
public enum RollPace { Full, Short, Settled }

public sealed record RollBeat(RollStage Stage, RollPace Pace, bool Freeze)
{
    /// <summary>The party's own rolls, natural 20s and 1s, critical results and rolls that trigger a
    /// reaction get the full beat. A critical success adds the freeze. Other enemy rolls get the
    /// short beat, and a disabled dice reveal shows only the settled row.</summary>
    public static RollBeat For(CombatRoll roll, bool reveal, bool reaction = false)
    {
        var stage = roll.DcMasked ? RollStage.CentreStage : RollStage.DegreeTrack;
        if (!reveal) return new(stage, RollPace.Settled, false);
        bool full = !roll.EnemyRoll || roll.Die is 1 or 20 || roll.Critical || reaction;
        return new(stage, full ? RollPace.Full : RollPace.Short, full && roll.Degree == "CriticalSuccess");
    }
}

/// <summary>PF2e's four degrees on a total: critical failure at DC-10 or lower, failure below the DC,
/// success from the DC, critical success from DC+10.</summary>
public static class DegreeZones
{
    public const int CriticalFailure = 0, Failure = 1, Success = 2, CriticalSuccess = 3;

    public static int Of(int total, int dc)
        => total >= dc + 10 ? CriticalSuccess : total >= dc ? Success : total > dc - 10 ? Failure : CriticalFailure;

    public static int Index(string degree) => degree switch
    {
        "CriticalSuccess" => CriticalSuccess,
        "Success" => Success,
        "Failure" => Failure,
        _ => CriticalFailure,
    };

    /// <summary>The zone that is good news for the party: an enemy roll reads mirrored.</summary>
    public static int ForParty(int zone, bool enemyRoll) => enemyRoll ? CriticalSuccess - zone : zone;

    private static readonly string[] AttackLabels = { "Crit miss", "Miss", "Hit", "Critical" };
    private static readonly string[] CheckLabels = { "Crit fail", "Failure", "Success", "Critical" };

    public static string Label(int zone, bool attack) => (attack ? AttackLabels : CheckLabels)[zone];
}
