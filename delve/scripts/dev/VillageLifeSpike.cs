using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Run;
using Delve.Village;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The village residents over a simulated minute, at every tier and time. Every resident gets a
/// place, keeps changing what it does, works only at a spot for that work, walks round the town's
/// pieces, and never shares a spot. A resident whose area is not built yet falls back to a built one.
/// The ground checks (spots clear and reachable, work spots facing their prop) are in the .Ground part.
/// </summary>
public partial class VillageLifeSpike : SpikeBase
{
    [Export] public PackedScene VillageScene { get; set; } = null!;
    [Export] public float SimulatedSeconds { get; set; } = 60f;
    [Export] public float Step { get; set; } = 1f / 30f;

    private static readonly string[] Roster =
    {
        "player", "elara", "tharr", "fenwick", "raven", "thistle", "arkus", "aldric", "spore",
        "josen", "grub", "sera", "oskar", "hazel", "wynn", "vasska", "hilde", "flick",
    };

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var layer = new CanvasLayer();
        AddChild(layer);
        var stage = VillageScene.Instantiate<VillageStage>();
        layer.AddChild(stage);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        foreach (var tier in new[] { TownTier.Camp, TownTier.Outpost, TownTier.Hamlet })
            foreach (var time in new[] { CampTimeOfDay.Morning, CampTimeOfDay.Afternoon, CampTimeOfDay.Evening })
                Simulate(stage, tier, time);
        CheckFallback(stage);
        CheckStarters(stage);
        CheckCrowd();

        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void Simulate(VillageStage stage, TownTier tier, CampTimeOfDay time)
    {
        var watch = System.Diagnostics.Stopwatch.StartNew();
        stage.ApplyTier(tier);
        if (time == CampTimeOfDay.Morning)
        {
            GD.Print($"[life] {tier}: walkable ground ready in {watch.ElapsedMilliseconds} ms");
            CheckGround(stage, tier);
        }
        stage.Residents.Place(Roster, time, tier);
        var figures = stage.Residents.Figures;
        string label = $"{tier} {time}";
        GD.Print($"[life] {label}: {figures.Count} placed, unplaced [{string.Join(", ", stage.Residents.Unplaced)}], areas "
            + string.Join(" ", figures.GroupBy(f => f.Area).Select(g => $"{g.Key}:{g.Count()}")));
        Check($"{label}: everyone has a place", stage.Residents.Unplaced.Count == 0);

        var spots = figures.SelectMany(f => f.Routine!.Spots.Select(s => s.At)).ToList();
        Check($"{label}: no two residents share a spot", spots.Distinct().Count() == spots.Count);
        var unequipped = figures.Where(f => VillageActivities.For(VillageSchedule.For(f.Id, time).Activity) is var activity
                && f.Area == VillageSchedule.For(f.Id, time).Area
                && activity.Uses.Any(use => f.Routine!.Spots.All(s => s.Use != use)))
            .Select(f => f.Id).ToList();
        Check($"{label}: every worker owns a spot for each place its work needs [{string.Join(", ", unequipped)}]", unequipped.Count == 0);

        foreach (var figure in figures) figure.SetProcess(false);
        var hens =GetTree().GetNodesInGroup(VillageChicken.Group).OfType<VillageChicken>()
            .Where(h => stage.IsAncestorOf(h) && h.Present).ToList();
        foreach (var hen in hens) hen.SetProcess(false);
        var before = figures.ToDictionary(f => f, f => f.Routine!.Changes);
        var strays = new HashSet<string>();
        var misplaced = new HashSet<string>();
        var bumps = new HashSet<string>();
        var loose = new HashSet<string>();
        int tick = 0;
        for (float t = 0; t < SimulatedSeconds; t += Step, tick++)
        {
            foreach (var figure in figures)
            {
                var routine = figure.Routine!;
                routine.Tick(Step);
                if (routine.WorkAt != "" && (routine.Spot.Use != routine.WorkAt || routine.Position != routine.Spot.At))
                    misplaced.Add($"{figure.Id}@{routine.WorkAt}");
                if (tick % OffMeshSampling == 0 && routine.Pose == ResidentPose.Walk && Astray(stage.Walkable, routine))
                    strays.Add($"{figure.Id}({routine.Position.X:0.0},{routine.Position.Y:0.0})");
            }
            foreach (var hen in hens)
            {
                hen.Tick(Step);
                if (tick % OffMeshSampling == 0 && hen.Walking && HenAstray(stage.Walkable, hen))
                    loose.Add($"{hen.Name}({hen.Ground.X:0.0},{hen.Ground.Y:0.0})");
            }
            if (tick % OffMeshSampling == 0) bumps.UnionWith(Bumps(figures, hens));
        }
        var still = figures.Where(f => f.Routine!.Changes - before[f] < 2).Select(f => f.Id).ToList();
        Check($"{label}: every resident changes what it does at least twice a minute [{string.Join(", ", still)}]", still.Count == 0);
        Check($"{label}: work happens only at a spot for that work [{string.Join(", ", misplaced)}]", misplaced.Count == 0);
        Check($"{label}: walks stay on the walkable ground, round every piece [{string.Join(", ", strays.Take(6))}]", strays.Count == 0);
        Check($"{label}: hens potter on the walkable ground near home [{string.Join(", ", loose.Take(6))}]", loose.Count == 0);
        Check($"{label}: walkers never walk into another mover [{string.Join(", ", bumps.Take(6))}]", bumps.Count == 0);
    }

    /// <summary>The hamlet's forge is not built at the camp, so its smith works somewhere that is.</summary>
    private void CheckFallback(VillageStage stage)
    {
        stage.Residents.Place(Roster, CampTimeOfDay.Morning, TownTier.Camp);
        var hilde = stage.Residents.Figures.FirstOrDefault(f => f.Id == "hilde");
        Check("camp: the smith whose forge is unbuilt falls back to a built area", hilde != null && hilde.Area != "forge");
    }

    /// <summary>A starting party at the camp: all four at their own jobs, none on a fallback.</summary>
    private void CheckStarters(VillageStage stage)
    {
        stage.Residents.Place(new[] { "player", "elara", "tharr", "fenwick" }, CampTimeOfDay.Morning, TownTier.Camp);
        var areas = stage.Residents.Figures.ToDictionary(f => f.Id, f => f.Area);
        Check("camp morning: the player chops at the woodyard", areas.GetValueOrDefault("player") == "woodyard");
        Check("camp morning: tharr keeps watch at the waypost", areas.GetValueOrDefault("tharr") == "waypost");
    }

}
