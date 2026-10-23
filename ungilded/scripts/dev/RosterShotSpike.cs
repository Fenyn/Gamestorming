using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Data;

namespace Ungilded.Dev;

/// <summary>
/// Builds the <see cref="RosterEncounter"/> and checks that every creature has its own sprite
/// (no missing-art placeholder) and that every unit stands on its own open tiles, then prints the
/// board as text with a letter per creature. Rendered, it starts the fight in the combat scene and
/// saves the opening view at the first hero turn (<c>roster_forest.png</c>), the whole roster with
/// the HUD hidden at the board pitch and at a low pitch (<c>roster_forest_overview.png</c>,
/// <c>roster_forest_low.png</c>), and a close-up of each unit (<c>roster_giant_rat.png</c> and on).
/// UNGILDED_MAP_SEED overrides the map seed.
/// </summary>
public partial class RosterShotSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public string ShotDirectory { get; set; } = "res://dev_shots";
    [Export] public Vector2I ShotSize { get; set; } = new(1920, 1080);
    [Export] public Vector2I CloseShotSize { get; set; } = new(800, 450);
    [Export] public int MapSeed { get; set; } = RosterEncounter.DefaultMapSeed;
    [Export] public int CombatSeed { get; set; } = 1337;
    [Export(PropertyHint.Range, "2,4,1")] public int Spacing { get; set; } = RosterEncounter.DefaultSpacing;
    [Export] public float TurnWaitSeconds { get; set; } = 60f;
    [Export] public float SettleSeconds { get; set; } = 2f;
    [Export] public float PollSeconds { get; set; } = 0.1f;

    /// <summary>Yaws of the roster views (the first is also the close-up yaw), and their two pitches.</summary>
    [Export] public float[] ViewYaws { get; set; } = { 45f, 180f, 0f };
    [Export] public float OverviewPitch { get; set; } = 35f;
    [Export] public float LowPitch { get; set; } = 22f;

    /// <summary>The roster views start this far from the roster's centre and back off by
    /// <see cref="FitStep"/> until every unit, feet to <see cref="UnitHeight"/>, sits inside the
    /// viewport with <see cref="FitMargin"/> of its size clear on each side.</summary>
    [Export] public float OverviewMinMetres { get; set; } = 12f;
    [Export] public float FitStep { get; set; } = 1.12f;
    [Export] public float FitMargin { get; set; } = 0.06f;
    [Export] public float UnitHeight { get; set; } = 1.4f;

    /// <summary>Close-ups: camera distance in metres, pitch, and the focus height above the feet.</summary>
    [Export] public float CloseMetres { get; set; } = 4.5f;
    [Export] public float ClosePitch { get; set; } = 18f;
    [Export] public float CloseHeight { get; set; } = 0.5f;

    protected override string Banner => "==================== ROSTER SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (CombatScene == null) { AbortFail("[RosterShot] CombatScene not assigned."); return; }
        if (int.TryParse(OS.GetEnvironment("UNGILDED_MAP_SEED"), out int envSeed)) MapSeed = envSeed;

        var setup = RosterEncounter.Build(data, MapSeed, CombatSeed, Spacing);
        Check("the roster encounter builds", setup != null);
        if (setup == null) return;
        int expected = RosterEncounter.PackCreatures.Length + RosterEncounter.PrologueCreatures.Length;
        Check($"the roster has every creature ({setup.Enemies.Count} of {expected})", setup.Enemies.Count == expected);
        foreach (var (unit, _) in setup.Enemies)
        {
            string folder = EnemySpriteMap.FolderForCreature(unit.Name, unit.CreatureStats?.Size ?? PF2e.Data.CreatureSize.Medium);
            Check($"{unit.Name} has its own sprite ({folder.GetFile()})", !folder.GetFile().StartsWith("placeholder"));
        }
        var corrections = setup.Normalize();
        foreach (string line in corrections) GD.Print($"[roster] moved: {line}");
        Check("every unit stands on its own open tiles", corrections.Count == 0);
        PrintMap(setup);
        if (Headless) return;

        GetWindow().SetFlag(Window.Flags.NoFocus, true);
        var scene = CombatScene.Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(setup);
        for (float waited = 0; !scene.IsPlayerTurn && waited < TurnWaitSeconds; waited += PollSeconds)
            await WaitSeconds(PollSeconds);
        Check("the roster reached a hero turn", scene.IsPlayerTurn);
        if (!scene.IsPlayerTurn) return;
        await WaitSeconds(SettleSeconds);
        Check("opening view saved", Save("roster_forest.png", ShotSize));

        var rig = Rig();
        if (rig == null) { Check("the combat camera is an orbit rig", false); return; }
        var units = setup.Party.Concat(setup.Enemies).Select(e => e.Unit).ToList();
        var visuals = units.Select(scene.UnitVisual).OfType<UnitVisual3D>().ToList();
        Check($"every unit has a token ({visuals.Count} of {units.Count})", visuals.Count == units.Count);
        if (visuals.Count == 0) return;

        // The roster views show the sprites alone: no HUD, no HP plates, no name plates, and no
        // depth of field, so every row reads sharp. The rig only moves the blur distances, so
        // the enabled flags hold until the close-ups put the blur back.
        scene.SetHudVisible(false);
        foreach (var visual in visuals)
        {
            visual.HpPlate.Visible = false;
            visual.Plate.Visible = false;
        }
        var blur = GetViewport().FindWorld3D()?.CameraAttributes as CameraAttributesPractical;
        SetBlur(blur, false);
        var centre = visuals.Aggregate(Vector3.Zero, (sum, v) => sum + v.GlobalPosition) / visuals.Count;
        var points = visuals.SelectMany(v => new[] { v.GlobalPosition, v.GlobalPosition + Vector3.Up * UnitHeight }).ToList();
        rig.FocusForInspection(centre);
        await WaitSeconds(rig.FocusSeconds + PollSeconds);
        foreach (float yaw in ViewYaws)
            foreach (var (pitch, tag) in new[] { (OverviewPitch, "overview"), (LowPitch, "low") })
            {
                rig.SetOrbit(yaw, pitch);
                float distance = FitDistance(rig, points);
                await WaitSeconds(SettleSeconds);
                GD.Print($"[roster] yaw {yaw:0} pitch {pitch:0}: camera {distance:0.0} m from {centre}");
                Check($"roster {tag} at yaw {yaw:0} saved", Save($"roster_forest_{tag}_yaw{yaw:0}.png", ShotSize));
            }
        SetBlur(blur, true);

        var letters = scene.Session!.Letters;
        foreach (var visual in visuals)
        {
            rig.FocusForInspection(visual.GlobalPosition + Vector3.Up * CloseHeight);
            rig.SetOrbit(ViewYaws[0], ClosePitch);
            rig.SetDolly(CloseMetres / rig.Distance);
            await WaitSeconds(rig.FocusSeconds + SettleSeconds * 0.5f);
            string name = visual.Character.CreatureStats != null ? letters.BaseNameFor(visual.Character) : visual.Character.Name;
            string file = $"roster_{CreatureSlug.Normalize(name).Replace('-', '_')}.png";
            Check($"{name} close-up saved", Save(file, CloseShotSize));
        }

        scene.EndHostedEncounter();
        scene.QueueFree();
        await WaitSeconds(PollSeconds);
    }

    private static void SetBlur(CameraAttributesPractical? attributes, bool on)
    {
        if (attributes == null) return;
        attributes.DofBlurNearEnabled = on;
        attributes.DofBlurFarEnabled = on;
    }

    /// <summary>Set the dolly so every point is in frame from the current orbit, starting at
    /// <see cref="OverviewMinMetres"/> and backing off by <see cref="FitStep"/> a pass. Returns
    /// the camera distance in metres.</summary>
    private float FitDistance(OrbitCameraRig rig, IReadOnlyList<Vector3> points)
    {
        var view = GetViewport().GetVisibleRect();
        var clear = view.Grow(-FitMargin * view.Size.Y);
        float distance = OverviewMinMetres;
        for (int pass = 0; pass < 24; pass++, distance *= FitStep)
        {
            rig.SetDolly(distance / rig.Distance);
            var camera = rig.Camera;
            if (points.All(p => !camera.IsPositionBehind(p) && clear.HasPoint(camera.UnprojectPosition(p)))) break;
        }
        return distance;
    }

    /// <summary>The board as text, north row first: H the heroes, A.. the creatures in roster
    /// order, # wall, ~ water, o cover, , difficult, = bridge, . ground at the base level and a
    /// digit for ground raised that many height units (9 and above print 9).</summary>
    private static void PrintMap(CombatSetup setup)
    {
        var layout = setup.Layout!;
        var marks = new Dictionary<(int X, int Y), char>();
        foreach (var (unit, pos) in setup.Party) Mark(marks, pos.x, pos.y, unit.TileWidth, 'H');
        char letter = 'A';
        foreach (var (unit, pos) in setup.Enemies)
        {
            Mark(marks, pos.x, pos.y, unit.TileWidth, letter);
            GD.Print($"[roster] {letter} {unit.Name} ({unit.TileWidth}x{unit.TileWidth}) at ({pos.x},{pos.y})");
            letter++;
        }
        for (int y = layout.Height - 1; y >= 0; y--)
        {
            var row = new StringBuilder();
            for (int x = 0; x < layout.Width; x++)
                row.Append(marks.TryGetValue((x, y), out char mark) ? mark : layout.GetTile(x, y) switch
                {
                    TileRole.Wall => '#',
                    TileRole.Water => '~',
                    TileRole.Cover => 'o',
                    TileRole.DifficultTerrain => ',',
                    TileRole.Bridge => '=',
                    TileRole.Empty => ' ',
                    _ => layout.GetCornerHeights(x, y).MinHeight is > 0 and var h ? (char)('0' + System.Math.Min(h, 9)) : '.',
                });
            GD.Print($"[map] {row}");
        }
    }

    private static void Mark(Dictionary<(int X, int Y), char> marks, int x, int y, int width, char mark)
    {
        for (int dy = 0; dy < width; dy++)
            for (int dx = 0; dx < width; dx++)
                marks[(x + dx, y + dy)] = mark;
    }

    private OrbitCameraRig? Rig()
    {
        Node? node = GetViewport().GetCamera3D();
        while (node != null && node is not OrbitCameraRig) node = node.GetParent();
        return node as OrbitCameraRig;
    }

    private bool Save(string file, Vector2I size) => SaveViewportCapture(ShotDirectory.PathJoin(file), size) == Error.Ok;
}
