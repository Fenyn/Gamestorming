using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using Ungilded.Autoload;
using Ungilded.Content;
using Ungilded.Props;
using Ungilded.Terrain;

namespace Ungilded.Dev;

/// <summary>
/// Headless. Builds each Prologue board on a terrain stage with the sewer look and checks that every
/// placed prop keeps its rule: torch count per board and spacing, each torch beside a passage mouth
/// or on a long wall, grate spacing, no two decals of a kind side by side, rubble only at a wall's
/// foot, a source for every puddle, the bone and density caps. Prints one count line per board;
/// UNGILDED_DRESSING_MAP also prints each board as text.
/// </summary>
public partial class DressingSpike : SpikeBase
{
    [Export] public TerrainStage? Stage { get; set; }

    /// <summary>Fewest and most torches on E1..E4.</summary>
    [Export] public Godot.Collections.Array<Vector2I> TorchBands { get; set; } = new();

    /// <summary>Halo rings the text map shows.</summary>
    [Export] public int MapRings { get; set; } = 4;

    protected override string Banner => "==================== DRESSING SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (Stage == null) { Check("Stage is assigned", false); return; }
        bool map = !string.IsNullOrEmpty(OS.GetEnvironment("UNGILDED_DRESSING_MAP"));
        for (int n = 1; n <= 4; n++)
        {
            var battle = PrologueMaps.Encounter(n);
            Stage.Build(battle.Layout, battle.BiomeId, battle.Width, battle.Height, battle.Halo);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (Stage.Look?.Dressing is not SewerDressing dressing || Stage.Skirt is not { } skirt)
            {
                Check($"E{n} has a sewer dressing and a skirt", false);
                continue;
            }
            CheckBoard(n, battle, skirt, dressing);
            CheckFlow(n, battle, dressing);
            if (map) PrintMap(n, skirt, dressing);
        }
        Stage.Clear();
    }

    private void CheckBoard(int n, PrologueBattle battle, SkirtResult skirt, SewerDressing dressing)
    {
        var layout = skirt.Layout;
        int m = skirt.Margin;
        var placed = dressing.Placed;
        Vector2I Skirt(Vector2I board) => board + new Vector2I(m, m);
        List<DressPlacement> Of(DressKind kind) => placed.Where(p => p.Kind == kind).ToList();
        var torches = Of(DressKind.Torch);
        var grates = placed.Where(p => p.Kind is DressKind.WallGrate or DressKind.FloorGrate).ToList();
        var puddles = Of(DressKind.Puddle);
        var rubble = Of(DressKind.Rubble);
        var bones = Of(DressKind.Bones);

        GD.Print($"  E{n}: torches {torches.Count}, grates wall {Of(DressKind.WallGrate).Count} / floor {Of(DressKind.FloorGrate).Count}, "
            + $"puddles {puddles.Count} ({string.Join(", ", puddles.GroupBy(p => p.Reason).Select(g => $"{g.Key} {g.Count()}"))}), "
            + $"slime {Of(DressKind.Slime).Count}, bones {bones.Count}, rubble {rubble.Count}");
        foreach (var note in dressing.TorchNotes) GD.Print($"    {note}");
        var band = !dressing.TorchesEnabled ? Vector2I.Zero : n - 1 < TorchBands.Count ? TorchBands[n - 1] : new Vector2I(1, int.MaxValue);
        Check($"E{n} has {band.X} to {band.Y} torches ({torches.Count})", torches.Count >= band.X && torches.Count <= band.Y);
        float nearest = Pairs(torches).Select(p => p.A.At.DistanceTo(p.B.At)).DefaultIfEmpty(float.MaxValue).Min();
        Check($"E{n} no two torches closer than {dressing.TorchMinGap} m (nearest {nearest:0.0})", nearest >= dressing.TorchMinGap);

        int closeGrates = Pairs(grates).Count(p => SewerSites.Chebyshev(SewerDressing.GrateCell(p.A), SewerDressing.GrateCell(p.B)) < dressing.GrateMinGap);
        Check($"E{n} no grate within {dressing.GrateMinGap} tiles of another ({closeGrates} pairs)", closeGrates == 0);

        var floor = placed.Where(p => p.Kind is not (DressKind.Torch or DressKind.WallGrate)).ToList();
        var touching = Pairs(floor).Where(p => p.A.Kind == p.B.Kind && SewerSites.Chebyshev(p.A.Tile, p.B.Tile) <= 1)
            .Select(p => $"{p.A.Kind} {p.A.Tile}/{p.B.Tile}").ToList();
        Check($"E{n} no two floor decals of a kind on neighbouring tiles{List(touching)}", touching.Count == 0);

        var loose = rubble.Where(r => SewerSites.WallSides(layout, Skirt(r.Tile)).Count == 0).Select(r => r.Tile.ToString()).ToList();
        Check($"E{n} all rubble lies at a wall's foot{List(loose)}", loose.Count == 0);

        var dry = puddles.Where(p => !PuddleHasSource(p, skirt, battle, dressing)).Select(p => $"{p.Tile} {p.Reason}").ToList();
        Check($"E{n} every puddle has a source{List(dry)}", dry.Count == 0);

        var stray = torches.Where(t => !TorchHasReason(t, skirt, dressing)).Select(t => $"{t.Wall} {t.Reason}").ToList();
        Check($"E{n} every torch flanks a passage mouth, a culvert or a deep recess, or hangs on a wall of {dressing.TorchMinRun}+ tiles{List(stray)}", stray.Count == 0);

        Check($"E{n} at most {dressing.BoneClusters} bone clusters ({bones.Count})", bones.Count <= dressing.BoneClusters);
        var crowdedBones = bones.SelectMany(b => placed.Where(SewerDressing.KeepsFromBones)
                .Where(p => Math.Min(SewerSites.Chebyshev(p.Tile, b.Tile), SewerSites.Chebyshev(p.Wall, b.Tile)) < dressing.BonePropGap)
                .Select(p => $"{b.Tile} by {p.Kind} {p.Tile}"))
            .ToList();
        Check($"E{n} every bone cluster is {dressing.BonePropGap}+ tiles from torches, grates, rubble and outfalls{List(crowdedBones)}",
            crowdedBones.Count == 0);
        int boardCap = battle.Width * battle.Height / dressing.BoardTilesPerDecal;
        int onBoard = floor.Count(p => SewerSites.Ring(skirt, Skirt(p.Tile)) == 0);
        Check($"E{n} board floor decals at most one per {dressing.BoardTilesPerDecal} tiles ({onBoard} of {boardCap})", onBoard <= boardCap);
        int haloOpen = 0;
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                int ring = SewerSites.Ring(skirt, new Vector2I(x, y));
                if (ring > 0 && ring <= dressing.ClutterRings && layout.GetTile(x, y) == TileRole.Ground) haloOpen++;
            }
        int inHalo = floor.Count - onBoard;
        Check($"E{n} halo floor decals at most one per {dressing.HaloTilesPerDecal} open tiles ({inHalo} of {haloOpen / dressing.HaloTilesPerDecal})",
            inHalo <= haloOpen / dressing.HaloTilesPerDecal);
    }

    /// <summary>Lowest cosine between an effect's direction and the board's flow that counts as the same way.</summary>
    [Export] public float FlowAgreement { get; set; } = 0.9f;

    /// <summary>Every culvert streak emitter drifts along the board's authored flow, and so do the
    /// water scroll and the sludge ripple on the built terrain.</summary>
    private void CheckFlow(int n, PrologueBattle battle, SewerDressing dressing)
    {
        var (fx, fy) = battle.Halo?.Flow ?? default;
        var flow = new Vector3(fx, 0, fy);
        GD.Print($"  E{n}: flow toward {Side(fx, fy)} (world {flow})");
        Check($"E{n} has an authored flow", flow != Vector3.Zero);
        if (flow == Vector3.Zero) return;

        var streaks = dressing.FindChildren("CulvertFlow_*", "", true, false).OfType<GpuParticles3D>().ToList();
        var against = streaks.Where(s => s.ProcessMaterial is ParticleProcessMaterial p
                && (s.GlobalBasis * p.Direction).Normalized().Dot(flow) < FlowAgreement)
            .Select(s => s.Name.ToString()).ToList();
        Check($"E{n} {streaks.Count} culvert streak emitters, all drifting with the flow{List(against)}",
            streaks.Count > 0 && against.Count == 0);

        var materials = Stage!.FindChildren("*", "", true, false).OfType<MeshInstance3D>()
            .Where(mi => mi.Mesh != null)
            .SelectMany(mi => Enumerable.Range(0, mi.Mesh.GetSurfaceCount()).Select(i => mi.Mesh.SurfaceGetMaterial(i)))
            .OfType<ShaderMaterial>().Distinct().ToList();
        CheckUniform(n, "water scroll", materials, MapMaterials.FlowVelocityUniform, flow, Has(battle.Layout, TileRole.Water));
        CheckUniform(n, "sludge ripple", materials, GroundTextureBaker.SludgeFlowUniform, flow, Has(battle.Layout, TileRole.DifficultTerrain));
    }

    private void CheckUniform(int n, string what, List<ShaderMaterial> materials, string uniform, Vector3 flow, bool present)
    {
        if (!present)
        {
            GD.Print($"    E{n} {what}: none on this board");
            return;
        }
        var velocities = materials.Where(mat => Declares(mat, uniform)).Select(mat => mat.GetShaderParameter(uniform)).Select(v => v.VariantType == Variant.Type.Vector2 ? v.AsVector2() : Vector2.Zero).ToList();
        GD.Print($"    E{n} {what}: {string.Join(", ", velocities)}");
        var flat = new Vector2(flow.X, flow.Z);
        Check($"E{n} {what} runs with the flow ({velocities.Count} materials)",
            velocities.Count > 0 && velocities.All(v => v != Vector2.Zero && v.Normalized().Dot(flat) > FlowAgreement));
    }

    private static bool Declares(ShaderMaterial material, string uniform) =>
        material.Shader?.GetShaderUniformList().Any(u => u.AsGodotDictionary()["name"].AsString() == uniform) == true;

    private static bool Has(MapLayout layout, TileRole role)
    {
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
                if (layout.GetTile(x, y) == role) return true;
        return false;
    }

    private static string Side(int x, int y) => (x, y) switch
    {
        (< 0, 0) => "west", (> 0, 0) => "east", (0, < 0) => "south", (0, > 0) => "north", _ => "nowhere",
    };

    /// <summary>A puddle lies beside a channel, around a floor grate, under an outfall or at the
    /// floor side of a culvert.</summary>
    private static bool PuddleHasSource(DressPlacement puddle, SkirtResult skirt, PrologueBattle battle, SewerDressing dressing)
    {
        var layout = skirt.Layout;
        var tile = puddle.Tile + new Vector2I(skirt.Margin, skirt.Margin);
        if (SewerSites.Cardinals.Any(d => SewerSites.Role(layout, tile + d) == TileRole.Water)) return true;
        if (dressing.Placed.Any(g => g.Kind == DressKind.FloorGrate && SewerSites.Chebyshev(g.Tile, puddle.Tile) == 1)) return true;
        var culverts = battle.Halo?.Marks.Where(k => k.Kind == SewerBoard.CulvertMark).Select(k => new Vector2I(k.X, k.Y)) ?? Enumerable.Empty<Vector2I>();
        if (SewerSites.Cardinals.Any(d => SewerSites.Role(layout, tile + d) is TileRole.Water or TileRole.DifficultTerrain
                && culverts.Any(c => SewerSites.Chebyshev(c, puddle.Tile + d) <= 1))) return true;
        var pipes = dressing.FindChildren("WallPipeWater_*", "", true, false).Select(p => p.Name.ToString().Split('_'))
            .Where(parts => parts.Length == 3).Select(parts => new Vector2I(int.Parse(parts[1]), int.Parse(parts[2])));
        return pipes.Any(w => SewerSites.Cardinals.Any(d => w == tile + d));
    }

    /// <summary>The torch hangs beside a passage mouth's flank, or on a wall run long enough.</summary>
    private static bool TorchHasReason(DressPlacement torch, SkirtResult skirt, SewerDressing dressing)
    {
        var wall = torch.Wall + new Vector2I(skirt.Margin, skirt.Margin);
        bool mouth = dressing.Openings.Where(o => o.Lit)
            .Any(o => SewerSites.Chebyshev(o.Flanks.Before, wall) <= 1 || SewerSites.Chebyshev(o.Flanks.After, wall) <= 1);
        bool longWall = dressing.WallRuns.Any(r => r.Length >= dressing.TorchMinRun && r.Faces.Any(f => f.Wall.x == wall.X && f.Wall.y == wall.Y));
        return mouth || longWall;
    }

    private static IEnumerable<(DressPlacement A, DressPlacement B)> Pairs(List<DressPlacement> list)
    {
        for (int i = 0; i < list.Count; i++)
            for (int j = i + 1; j < list.Count; j++)
                yield return (list[i], list[j]);
    }

    private static string List(List<string> items) => items.Count == 0 ? "" : " (" + string.Join(", ", items) + ")";

    /// <summary>The board and its near halo as text, high y at the top: # wall, . floor, ~ water,
    /// % sludge, = bridge; T torch and G wall grate on their wall, g floor grate, o puddle, s slime,
    /// b bones, r rubble.</summary>
    private void PrintMap(int n, SkirtResult skirt, SewerDressing dressing)
    {
        var layout = skirt.Layout;
        int m = skirt.Margin;
        var marks = new Dictionary<Vector2I, char>();
        foreach (var p in dressing.Placed)
        {
            var at = (p.Kind is DressKind.Torch or DressKind.WallGrate ? p.Wall : p.Tile) + new Vector2I(m, m);
            marks[at] = p.Kind switch
            {
                DressKind.Torch => 'T', DressKind.WallGrate => 'G', DressKind.FloorGrate => 'g', DressKind.Puddle => 'o',
                DressKind.Slime => 's', DressKind.Bones => 'b', _ => 'r',
            };
        }
        var text = new StringBuilder($"  E{n} map, {MapRings} halo rings, high y on top\n");
        for (int y = layout.Height - 1; y >= 0; y--)
        {
            if (SewerSites.Ring(skirt, new Vector2I(m, y)) > MapRings) continue;
            text.Append("    ");
            for (int x = 0; x < layout.Width; x++)
            {
                var t = new Vector2I(x, y);
                if (SewerSites.Ring(skirt, t) > MapRings) continue;
                text.Append(marks.TryGetValue(t, out var c) ? c : SewerSites.Role(layout, t) switch
                {
                    TileRole.Wall => '#', TileRole.Water => '~', TileRole.DifficultTerrain => '%', TileRole.Bridge => '=', _ => '.',
                });
            }
            text.Append('\n');
        }
        GD.Print(text.ToString());
    }
}
