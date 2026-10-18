using Godot;

namespace Delve.Village;

/// <summary>Shows its children only while the town is between two tiers (inclusive), and optionally only by day.</summary>
public partial class TierGate : Node3D
{
    public const string Group = "village_tier_gate";

    /// <summary>The first town tier that shows this (1 Camp, 2 Outpost, 3 Hamlet).</summary>
    [Export] public int From { get; set; } = 1;

    /// <summary>The last town tier that shows this. A tent or a tree cleared later stops before 3.</summary>
    [Export] public int To { get; set; } = 3;

    /// <summary>Taken in at dusk, like washing on a line.</summary>
    [Export] public bool DayOnly { get; set; }

    private int _tier = 1;
    private bool _evening;

    public override void _Ready() => AddToGroup(Group);

    public void ApplyTier(int tier)
    {
        _tier = tier;
        Refresh();
    }

    public void SetEvening(bool evening)
    {
        _evening = evening;
        Refresh();
    }

    /// <summary>Whether this stands in the town at a tier, by day or night.</summary>
    public bool Builds(int tier) => tier >= From && tier <= To;

    private void Refresh() => Visible = Builds(_tier) && !(DayOnly && _evening);
}
