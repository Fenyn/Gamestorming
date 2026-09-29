using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

/// <summary>Layout budget for the FFT combat HUD (2026-09-28): the timeline down the left edge,
/// the unit card bottom left, the command menu on the right, the defender card bottom right and
/// the forecast bottom centre. Zone boxes, their share of the 1920x1080 frame, and the board area
/// every zone must leave clear.</summary>
public partial class CombatShotSpike
{
    [Export(PropertyHint.Range, "0,100,0.5")] public float IdleBudgetPercent { get; set; } = 24f;
    [Export(PropertyHint.Range, "0,100,0.5")] public float EnemyBudgetPercent { get; set; } = 26f;
    /// <summary>Cap for the transient H1 hero roll over a player-turn frame with an opened log row.
    /// It lasts about a second.</summary>
    [Export(PropertyHint.Range, "0,100,0.5")] public float HeroTransientBudgetPercent { get; set; } = 32f;
    [Export] public Rect2 IdleClearBox { get; set; } = new(232, 16, 1256, 880);
    [Export] public Rect2 RollClearBox { get; set; } = new(232, 16, 1256, 840);

    private static readonly Rect2 Canvas = new(0, 0, 1920, 1080);

    /// <summary>The FFT command menu and what opens from it float beside the active unit, over
    /// the board, so the clear-box and overlap rules skip them.</summary>
    private static readonly HashSet<string> FloatingZones = new() { "action bar", "signature row", "flyout", "control options" };

    private static List<(string Name, Rect2 Rect)> HudZones(CombatScene scene)
    {
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var zones = new List<(string Name, Rect2 Rect)>();
        void Add(string name, Control control)
        {
            if (control.IsVisibleInTree() && control.Size.X > 0 && control.Size.Y > 0)
                zones.Add((name, control.GetGlobalRect()));
        }
        Add("card slot", scene.GetNode<Control>("%UnitInspect"));
        Add("initiative", scene.GetNode<TurnOrderBar>("%TurnOrderBar").Row);
        Add("log", scene.GetNode<CombatLogPanel>("%CombatLog").GetNode<Control>("%Shell"));
        Add("decision slot", bar.Decision);
        Add("roll row", scene.GetNode<Control>("%DiceRoll"));
        Add("action bar", bar.BarPanel);
        Add("flyout", bar.GetNode<Control>("%Flyout"));
        Add("control options", bar.GetNode<Control>("%ControlOptions"));
        Add("attacker card", scene.GetNode<Control>("%ActorCard"));
        Add("target card", scene.GetNode<Control>("%TargetCard"));
        var signatures = bar.GetNode<Control>("%SignatureActions");
        if (signatures.IsVisibleInTree())
        {
            var chips = signatures.FindChildren("*", nameof(Button), true, false).OfType<Button>().Where(b => b.IsVisibleInTree()).ToArray();
            if (chips.Length > 0)
                zones.Add(("signature row", chips.Skip(1).Aggregate(chips[0].GetGlobalRect(), (r, b) => r.Merge(b.GetGlobalRect()))));
        }
        var prompt = scene.GetNode<ReactionPromptPanel>("%ReactionPrompt");
        if (prompt.Visible) Add("reaction prompt", prompt.Dock);
        return zones;
    }

    /// <summary>The combat HUD zones must not overlap and must sit inside the 1920x1080 canvas.</summary>
    private void AssertZones(CombatScene scene, string shot)
    {
        var zones = HudZones(scene);
        var clashes = new List<string>();
        for (int i = 0; i < zones.Count; i++)
        {
            if (!Canvas.Encloses(zones[i].Rect)) clashes.Add($"{zones[i].Name} leaves the canvas {zones[i].Rect}");
            for (int j = i + 1; j < zones.Count; j++)
                if (zones[i].Rect.Intersects(zones[j].Rect)
                    && FloatingZones.Contains(zones[i].Name) == FloatingZones.Contains(zones[j].Name))
                    clashes.Add($"{zones[i].Name} {zones[i].Rect} overlaps {zones[j].Name} {zones[j].Rect}");
        }
        Check($"{shot}: {zones.Count} HUD zones keep apart at 1920x1080 ({string.Join("; ", clashes)})", clashes.Count == 0);
    }

    /// <summary>Coverage is the summed zone area over the frame; the zones never overlap, so the
    /// sum is their union. Every zone must stay out of <paramref name="clearBox"/>.</summary>
    private void CheckBudget(CombatScene scene, string state, float maxPercent, Rect2? clearBox, (string Name, Rect2 Rect)? transient = null)
    {
        var zones = HudZones(scene);
        if (transient is { } extra) zones.Add(extra);
        float area = zones.Sum(z => z.Rect.Area);
        float percent = 100f * area / Canvas.Area;
        GD.Print($"  [INFO] {state} coverage {percent:0.0}% ({area:0} px): "
            + string.Join(", ", zones.Select(z => $"{z.Name} {z.Rect.Position.X:0},{z.Rect.Position.Y:0} {z.Rect.Size.X:0}x{z.Rect.Size.Y:0}")));
        if (maxPercent > 0)
            Check($"{state}: HUD covers {percent:0.0}% of the frame (budget {maxPercent}%)", percent <= maxPercent);
        if (clearBox is not { } clear) return;
        var intruders = zones.Where(z => !FloatingZones.Contains(z.Name) && z.Rect.Intersects(clear))
            .Select(z => $"{z.Name} {z.Rect}").ToList();
        Check($"{state}: no HUD zone enters the clear board box {clear} ({string.Join("; ", intruders)})", intruders.Count == 0);
    }

    /// <summary>Puts a strike roll on the band when a live Shield Block prompt came without one, so the
    /// enemy-turn budget measures the full band. A Reactive Strike prompt comes before any roll, so the
    /// caller measures it as it stands.</summary>
    private async Task EnsureBandRoll(CombatScene scene)
    {
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        if (dice.Visible) return;
        GD.Print("  [INFO] the prompt came without a roll on screen; a fixture strike roll fills the band");
        dice.ShowRoll(CombatRoll.Parse("d20(14)+7=21 vs AC 19 → Success")! with { EnemyRoll = true }, "Fixture strike");
        // Settled at once: a staged prompt races the enemy's own turn, so the capture must not wait.
        dice.Skip();
        await dice.WaitForResultsAsync();
    }
}
