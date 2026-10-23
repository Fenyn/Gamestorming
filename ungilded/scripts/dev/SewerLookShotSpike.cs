using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Look;
using Ungilded.Props;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// Rendered only. Starts each Prologue board in the combat scene, waits for the first hero turn and
/// saves the default view to <c>sewer_e1.png</c> .. <c>sewer_e4.png</c>, then the whole board from
/// each of the four snapped camera yaws (<c>sewer_e1_yaw45.png</c> ..), then four close-ups: the
/// Encounter 1 channel, the Encounter 4 sludge band, its south culvert and a torch-lit wall. Checks
/// the dressing (torches, the Encounter 4 sigil, sludge pipes and culvert lintels, the marked
/// outfalls, grates and skeleton), the authored halo (passages and channels that reach the rim, the
/// footbridge, the apse steps and the rising entry), and the cutaway: from every snapped yaw, at the
/// default and the lowest pitch, no full-height wall stands between the camera and a unit. Low walls
/// (pillars) are reported apart. From every snapped yaw a culvert arch shows only while every jamb
/// it springs from stands, and shows whenever the camera is on the board side of its mouth.
/// UNGILDED_SEWER_BOARDS ("24") runs only the boards it names.
/// </summary>
public partial class SewerLookShotSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export] public string ShotDirectory { get; set; } = "res://dev_shots";
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);
    [Export] public int CombatSeed { get; set; } = 7;
    [Export] public float TurnWaitSeconds { get; set; } = 30f;
    [Export] public float SettleSeconds { get; set; } = 2f;
    [Export] public float PollSeconds { get; set; } = 0.1f;

    /// <summary>Camera for the close-ups: dolly factor, then yaw and pitch in degrees.</summary>
    [Export] public float CloseDolly { get; set; } = 0.45f;
    [Export] public Vector2 SludgeOrbit { get; set; } = new(60f, 38f);
    [Export] public Vector2 WallOrbit { get; set; } = new(90f, 30f);
    [Export] public Vector2 ChannelOrbit { get; set; } = new(20f, 42f);
    [Export] public Vector2 CulvertOrbit { get; set; } = new(45f, 30f);

    /// <summary>The four snapped yaws, opening view first, and the pitch and dolly of the board views.</summary>
    [Export] public float[] ViewYaws { get; set; } = { 45f, 90f, 135f, 180f, 225f, 270f, 315f, 0f };
    [Export] public float ViewPitch { get; set; } = 35f;

    /// <summary>Board views frame the board's longer side plus this many halo tiles, at this many
    /// metres of camera distance per tile.</summary>
    [Export] public int OverviewRings { get; set; } = 5;

    /// <summary>Dolly of the close framing the sight check also runs from.</summary>
    [Export] public float CloseSightDolly { get; set; } = 0.6f;
    [Export] public float OverviewMetresPerTile { get; set; } = 2.5f;

    /// <summary>Height above a unit's tile the sight check aims at, metres: the back of a rat.</summary>
    [Export] public float SightHeight { get; set; } = 0.3f;

    /// <summary>Sides of each board (E1..E4) whose halo reaches the rim: W, E, S, N.</summary>
    private static readonly string[] RimSides = { "WE", "WESN", "WESN", "ESN" };

    protected override string Banner => "==================== SEWER LOOK SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (Headless)
        {
            Check("the sewer look spike runs rendered", false);
            return;
        }
        GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (CombatScene == null) { Check("CombatScene is assigned", false); return; }

        string boards = System.Environment.GetEnvironmentVariable("UNGILDED_SEWER_BOARDS") ?? "1234";
        for (int n = 1; n <= 4; n++)
        {
            if (!boards.Contains((char)('0' + n))) continue;
            var battle = PrologueMaps.Encounter(n);
            var scene = await Start(battle);
            if (scene == null) continue;
            var dressing = Dressing(scene);
            var stage = scene.GetNode<TerrainStage>("%TerrainStage");
            bool torchesOn = dressing?.TorchesEnabled == true;
            if (torchesOn) Check($"E{n} sewer dressing hung torches", Named(dressing, "WallTorch") > 0);
            else GD.Print($"[torches] E{n}: torches off");
            await WaitSeconds(SettleSeconds);
            Check($"E{n} capture saved", Save($"sewer_e{n}.png"));
            int lit = dressing?.Torches.Count(t => stage.Cutaway?.IsShown(t) ?? true) ?? 0;
            GD.Print($"[torches] E{n}: {lit} of {dressing?.Torches.Count ?? 0} stand in the opening view's cut, "
                + $"{(TorchInView(dressing, stage.Cutaway) != null ? "one in frame" : "none in frame")}");
            if (n == 4 && torchesOn) Check("E4 a torch stands in the opening view's cut", lit > 0);
            await PrintFrameTime(n);
            Check($"E{n} the Friend carries the one lantern", Lanterns(scene) == 1);
            CheckOpeningSight(n, scene, stage);
            CheckHalo(n, battle, stage, dressing);
            if (n == 1)
            {
                scene.SetHudVisible(false);
                if (torchesOn) await CheckFlicker(dressing, stage.Cutaway);
                await FriendCloseUps(scene);
                await LitShots(scene);
            }

            foreach (float yaw in ViewYaws)
                await CheckView(n, scene, stage, battle, yaw);

            if (n == 1)
            {
                await CloseUp(scene, new Vector3(2.5f, 0f, 0.5f), ChannelOrbit);
                Check("channel close-up saved", Save("sewer_channel.png"));
                await FlowFrames(scene, "e1", new Vector3(2.5f, 0f, 0.5f), ChannelOrbit);
                await FlowFrames(scene, "e1_west", new Vector3(0.5f, 0f, 0.5f), ChannelOrbit);
                await FlowFrames(scene, "e1_east", new Vector3(7.5f, 0f, 0.5f), ChannelOrbit);
            }

            if (n == 4)
            {
                Check("E4 has the sigil", Named(dressing, "SewerSigil") == 1);
                Check("E4 has sludge pipes", Named(dressing, "WallPipeSludge") > 0);
                await CloseUp(scene, new Vector3(6.5f, 0f, 6f), SludgeOrbit);
                Check("sludge close-up saved", Save("sewer_sludge.png"));
                await CloseUp(scene, new Vector3(6.5f, 0f, 0.5f), CulvertOrbit);
                Check("culvert close-up saved", Save("sewer_culvert.png"));
                await FlowFrames(scene, "e4", new Vector3(6.5f, 0f, 0.5f), CulvertOrbit);
                await FlowFrames(scene, "e4_north", new Vector3(6.5f, 0f, 11.5f), CulvertOrbit);
                var torch = dressing?.FindChildren("*WallTorch*", "", true, false).OfType<Node3D>()
                    .Where(t => stage.Cutaway?.IsShown(t) ?? true).OrderBy(t => t.GlobalPosition.X).FirstOrDefault();
                if (torch != null)
                {
                    await CloseUp(scene, torch.GlobalPosition with { Y = 0f }, WallOrbit);
                    Check("torch wall close-up saved", Save("sewer_torch.png"));
                }
            }
            scene.EndHostedEncounter();
            scene.QueueFree();
            await WaitSeconds(PollSeconds);
        }
    }

    // ─────────────────────────── torch flicker ───────────────────────────

    /// <summary>Seconds of torch light the flicker check samples.</summary>
    [Export] public float FlickerSampleSeconds { get; set; } = 3f;

    /// <summary>Fastest energy change, as a share of the light's mean energy per second.</summary>
    [Export] public float FlickerMaxRate { get; set; } = 1f;

    /// <summary>Most turns of the energy curve per second (a 1 Hz breath turns twice).</summary>
    [Export] public float FlickerMaxTurnsPerSecond { get; set; } = 2.5f;

    /// <summary>Seconds between frames of the torch sequence UNGILDED_TORCH_FRAMES saves.</summary>
    [Export] public float TorchFrameSeconds { get; set; } = 0.1f;

    /// <summary>Samples the torch light for <see cref="FlickerSampleSeconds"/> and checks that it
    /// breathes: a slow rate of change and few turns. With UNGILDED_TORCH_FRAMES set it
    /// also saves the close-up every <see cref="TorchFrameSeconds"/> as <c>sewer_torch_seq_NN.png</c>.</summary>
    private async Task CheckFlicker(Node? dressing, TerrainCutaway? cutaway)
    {
        var torch = TorchInView(dressing, cutaway);
        if (torch == null) { Check("a torch shows in the opening view", false); return; }
        var light = torch.FindChildren("*", nameof(OmniLight3D), true, false).OfType<FlickerLight>().FirstOrDefault();
        if (light == null) { Check("the torch has a flicker light", false); return; }
        await FaceTorch(torch);
        Check("torch flame close-up saved", Save("sewer_torch_flame.png"));
        bool frames = !string.IsNullOrEmpty(System.Environment.GetEnvironmentVariable("UNGILDED_TORCH_FRAMES"));
        var samples = new List<(float Time, float Energy)>();
        float nextFrame = 0f;
        int frame = 0;
        // Time runs on the process delta, the clock the light advances on. The spike resumes before
        // the light processes the frame, so the next sample holds this frame's step.
        for (float t = 0f; t < FlickerSampleSeconds;)
        {
            samples.Add((t, light.LightEnergy));
            if (frames && t >= nextFrame)
            {
                Save($"sewer_torch_seq_{frame++:00}.png");
                nextFrame += TorchFrameSeconds;
            }
            float step = (float)GetProcessDeltaTime();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            t += step;
        }
        float mean = samples.Average(s => s.Energy);
        float rate = samples.Zip(samples.Skip(1), (a, b) => b.Time > a.Time ? Mathf.Abs(b.Energy - a.Energy) / (b.Time - a.Time) : 0f)
            .DefaultIfEmpty(0f).Max() / mean;
        int turns = 0;
        for (int i = 2; i < samples.Count; i++)
            if ((samples[i - 1].Energy - samples[i - 2].Energy) * (samples[i].Energy - samples[i - 1].Energy) < 0f) turns++;
        float span = samples[^1].Time - samples[0].Time;
        GD.Print($"[flicker] {samples.Count} samples over {span:0.00} s, energy {samples.Min(s => s.Energy):0.000}..{samples.Max(s => s.Energy):0.000}, mean {mean:0.000}, fastest change {rate:P0}/s, {turns} turns");
        Check($"the torch light changes at most {FlickerMaxRate:P0} a second ({rate:P0})", rate <= FlickerMaxRate);
        Check($"the torch light turns at most {FlickerMaxTurnsPerSecond:0.#} times a second ({turns / span:0.0})",
            turns / span <= FlickerMaxTurnsPerSecond);
    }

    /// <summary>Dolly of the flame close-up.</summary>
    [Export] public float FlameDolly { get; set; } = 0.45f;

    /// <summary>The torch nearest the middle of the screen in the current view, or null.</summary>
    private Node3D? TorchInView(Node? dressing, TerrainCutaway? cutaway)
    {
        var camera = GetViewport().GetCamera3D();
        var screen = GetViewport().GetVisibleRect();
        bool OnScreen(Node3D t) => !camera.IsPositionBehind(t.GlobalPosition) && screen.HasPoint(camera.UnprojectPosition(t.GlobalPosition));
        return dressing?.FindChildren("*WallTorch*", "", true, false).OfType<Node3D>()
            .Where(t => (cutaway?.IsShown(t) ?? true) && OnScreen(t))
            .OrderBy(t => camera.UnprojectPosition(t.GlobalPosition).DistanceTo(screen.GetCenter()))
            .FirstOrDefault();
    }

    /// <summary>Close in on the torch from the current yaw and pitch.</summary>
    private async Task FaceTorch(Node3D torch)
    {
        var rig = Rig();
        if (rig == null) return;
        rig.FocusForInspection(torch.GlobalPosition);
        rig.SetDolly(FlameDolly);
        await WaitSeconds(rig.FocusSeconds + SettleSeconds);
    }

    // ─────────────────────────── lantern and frame time ───────────────────────────

    /// <summary>Frames the render time is averaged over.</summary>
    [Export] public int FrameTimeFrames { get; set; } = 120;

    /// <summary>The Friend's step for the mid-walk close-up: metres along X, and seconds out and back.</summary>
    [Export] public Vector2 FriendStep { get; set; } = new(0.6f, 1.2f);

    /// <summary>Prints the mean frame time and the measured render time of the current view.</summary>
    private async Task PrintFrameTime(int n)
    {
        var viewport = GetViewport().GetViewportRid();
        RenderingServer.ViewportSetMeasureRenderTime(viewport, true);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        double cpu = 0, gpu = 0;
        ulong start = Time.GetTicksUsec();
        for (int i = 0; i < FrameTimeFrames; i++)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            cpu += RenderingServer.ViewportGetMeasuredRenderTimeCpu(viewport);
            gpu += RenderingServer.ViewportGetMeasuredRenderTimeGpu(viewport);
        }
        double frame = (Time.GetTicksUsec() - start) / 1000.0 / FrameTimeFrames;
        RenderingServer.ViewportSetMeasureRenderTime(viewport, false);
        GD.Print($"[frame] E{n}: {frame:0.00} ms a frame, render {cpu / FrameTimeFrames:0.00} ms CPU, {gpu / FrameTimeFrames:0.00} ms GPU");
    }

    private static int Lanterns(Node scene)
        => scene.FindChildren("*", nameof(Sprite3D), true, false).OfType<HandLantern>().Count(l => l.Visible);

    /// <summary>Close-ups of the Friend at rest and halfway through a short step, for the lantern.</summary>
    private async Task FriendCloseUps(CombatScene scene)
    {
        var friend = scene.FindChildren("*", nameof(Node3D), true, false).OfType<UnitVisual3D>()
            .FirstOrDefault(u => u.Character.Id == PrologueCast.FriendId);
        var rig = Rig();
        if (friend == null || rig == null) { Check("the Friend's token is on the board", false); return; }
        rig.FocusForInspection(friend.GlobalPosition);
        rig.SetDolly(FlameDolly);
        await WaitSeconds(rig.FocusSeconds + SettleSeconds);
        Check("Friend at rest saved", Save("sewer_friend_rest.png"));
        var lantern = friend.FindChildren("*", nameof(Sprite3D), true, false).OfType<HandLantern>().FirstOrDefault();
        if (lantern != null)
        {
            float flameHeight = lantern.Glow.GlobalPosition.Y - friend.GlobalPosition.Y;
            GD.Print($"[lantern] offset {lantern.Offset}, flame {flameHeight:0.00} m above the feet, light {lantern.Light.GlobalPosition.Y - friend.GlobalPosition.Y:0.00} m");
            Check($"the lantern hangs at hand height ({flameHeight:0.00} m)", flameHeight is > 0.15f and < 0.6f);
        }
        var rest = friend.Position;
        var step = CreateTween();
        step.TweenProperty(friend, "position", rest + Vector3.Right * FriendStep.X, FriendStep.Y * 0.5f);
        step.TweenProperty(friend, "position", rest, FriendStep.Y * 0.5f);
        await WaitSeconds(FriendStep.Y * 0.3f);
        Check("Friend mid-step saved", Save("sewer_friend_walk.png"));
        await ToSignal(step, Tween.SignalName.Finished);
    }

    // ─────────────────────────── halo ───────────────────────────

    private void CheckHalo(int n, PrologueBattle battle, TerrainStage stage, SewerDressing? dressing)
    {
        if (stage.Skirt is not { } skirt) { Check($"E{n} has a skirt", false); return; }
        var layout = skirt.Layout;
        int m = skirt.Margin, w = battle.Width, h = battle.Height;
        Check($"E{n} the camera cuts walls", stage.Cutaway != null);

        foreach (char side in RimSides[n - 1])
        {
            bool open = Enumerable.Range(0, side is 'W' or 'E' ? h : w).Any(a =>
            {
                var (x, y) = side switch { 'W' => (0, a + m), 'E' => (layout.Width - 1, a + m), 'S' => (a + m, 0), _ => (a + m, layout.Height - 1) };
                return layout.GetTile(x, y) != TileRole.Wall;
            });
            Check($"E{n} the halo opens to the rim on side {side}", open);
        }

        int marks = battle.Halo?.Marks.Count(k => k.Kind == SewerBoard.OutfallMark) ?? 0;
        int pipes = Named(dressing, "WallPipeWater");
        if (marks > 0)
            Check($"E{n} has its {marks} outfall pipes ({pipes} water pipes)", pipes >= marks);
        int grates = battle.Halo?.Marks.Count(k => k.Kind == SewerBoard.GrateMark) ?? 0;
        int hung = Named(dressing, "WallGrate");
        if (grates > 0)
            Check($"E{n} has its {grates} wall grates ({hung} hung)", hung == grates);

        if (n is 1 or 2)
        {
            var rimWater = Enumerable.Range(0, layout.Height).Select(y => (x: 0, y))
                .Where(t => layout.GetTile(t.x, t.y) == TileRole.Water).ToList();
            Check($"E{n} the channel runs to the rim at the board's level", rimWater.Count > 0
                && rimWater.All(t => layout.GetCornerHeights(t.x, t.y).MaxHeight == -SewerBoard.ChannelRecessUnits));
        }
        if (n == 2)
            Check("E2 the west tunnel has a footbridge", layout.GetTile(m - 1, m + 1) == TileRole.Bridge);
        if (n == 3)
            Check("E3 the skeleton lies in the entry passage", Named(dressing, "SlumpedSkeleton") == 1);
        if (n == 4)
        {
            Check("E4 the apse steps up twice", layout.GetCornerHeights(m - 1, m + 5).MinHeight == 2
                && layout.GetCornerHeights(m - 2, m + 5).MinHeight == 4);
            Check("E4 the entry passage climbs away", layout.GetCornerHeights(layout.Width - 1, m + 5).MinHeight
                > layout.GetCornerHeights(m + w, m + 5).MinHeight);
            Check("E4 the sludge leaves through culverts on both sides",
                layout.GetTile(m + 6, 0) == TileRole.DifficultTerrain && layout.GetTile(m + 6, layout.Height - 1) == TileRole.DifficultTerrain);
            Check("E4 both culverts are arched", Named(dressing, "CulvertArch") == 2);
        }
        if (n == 3)
            Check("E3 the drain sump empties through an arched culvert", Named(dressing, "CulvertArch") == 1);
        Check($"E{n} water or sludge flows out of every run that leaves the board", Named(dressing, "CulvertFlow")
            == battle.Halo?.Marks.Where(k => k.Kind == SewerBoard.CulvertMark).Select(k => k.Y < 0 ? 0 : k.Y >= h ? 1 : k.X < 0 ? 2 : 3).Distinct().Count());
        if (n is 1 or 2 or 3)
            Check($"E{n} the channels have a stone kerb", Named(dressing, "ChannelKerbs") == 1);
    }

    // ─────────────────────────── views and sight ───────────────────────────

    private void CheckOpeningSight(int n, CombatScene scene, TerrainStage stage)
    {
        var rig = Rig();
        if (rig == null) return;
        SightCheck($"E{n} opening view", scene, stage, rig.Camera);
    }

    private async Task CheckView(int n, CombatScene scene, TerrainStage stage, PrologueBattle battle, float yaw)
    {
        var rig = Rig();
        if (rig == null) return;
        scene.SetHudVisible(false);
        rig.FocusForInspection(new Vector3(battle.Width * 0.5f, 0f, battle.Height * 0.5f));
        await WaitSeconds(rig.FocusSeconds + PollSeconds);
        float overview = (Mathf.Max(battle.Width, battle.Height) + OverviewRings) * OverviewMetresPerTile / rig.Distance;
        foreach (var (framing, dolly) in new[] { ("close", CloseSightDolly), ("whole board", overview) })
        {
            rig.SetDolly(dolly);
            foreach (float pitch in new[] { rig.PitchMinDegrees, ViewPitch })
            {
                rig.SetOrbit(yaw, pitch);
                // One frame for the cutaway to take the camera's quadrant; the check reads that.
                await WaitSeconds(PollSeconds);
                SightCheck($"E{n} yaw {yaw:0} pitch {pitch:0} {framing}", scene, stage, rig.Camera);
            }
        }
        await WaitSeconds(SettleSeconds);
        // On a diagonal the cut must match the camera; on an axis it keeps the side it had.
        if (Mathf.PosMod(yaw, 90f) > 1f)
        {
            int expected = CutawayMap.Quadrant(rig.Camera.GlobalBasis.Z.X, rig.Camera.GlobalBasis.Z.Z);
            Check($"E{n} yaw {yaw:0} cut for quadrant {expected}", stage.Cutaway?.CameraQuadrant == expected);
        }
        CheckSeams(n, yaw, stage);
        CheckArches(n, yaw, scene, stage);
        Check($"E{n} yaw {yaw:0} capture saved", Save($"sewer_e{n}_yaw{yaw:0}.png"));
    }

    /// <summary>Each culvert arch is visible only while every jamb tile it springs from stands, and
    /// is visible whenever the camera sits on the board side of its mouth.</summary>
    private void CheckArches(int n, float yaw, CombatScene scene, TerrainStage stage)
    {
        if (stage.Cutaway is not { Map: { } map } cutaway || stage.Skirt is not { } skirt || stage.Layout is not { } board
            || Dressing(scene) is not { } dressing) return;
        int q = cutaway.CameraQuadrant;
        float hs = stage.HeightMap.HeightScale;
        var context = new DressingContext(board, skirt, new TerrainHeightMap(skirt.Layout, hs), hs, cutaway);
        foreach (var span in CulvertSpans.Find(context))
        {
            if (dressing.FindChild($"CulvertArch_{span.Tiles[0].X}_{span.Tiles[0].Y}", true, false) is not Node3D arch) continue;
            var jambs = span.Jambs(dressing.ArchDepth).Where(t => skirt.Layout.GetTile(t.X, t.Y) == TileRole.Wall).ToList();
            int cut = jambs.Count(t => map.IsCut(t.X, t.Y, q));
            bool shown = arch.IsVisibleInTree();
            Check($"E{n} yaw {yaw:0} {arch.Name} shows only on standing jambs ({cut} of {jambs.Count} cut, {(shown ? "shown" : "hidden")})",
                !shown || cut == 0);
            if (((span.InwardQuadrants() >> q) & 1) != 0)
                Check($"E{n} yaw {yaw:0} {arch.Name} shows from the board side", shown);
        }
    }

    /// <summary>Wherever the cut in force leaves a wall standing beside a cut one, the standing
    /// wall has a masonry end face toward it: no wall ends open or in a dark section.</summary>
    private void CheckSeams(int n, float yaw, TerrainStage stage)
    {
        if (stage.Cutaway is not { Map: { } map } cutaway || stage.Skirt is not { } skirt) return;
        int q = cutaway.CameraQuadrant;
        var faces = map.Seams.Select(s => (s.X, s.Y, s.Toward)).ToHashSet();
        var layout = skirt.Layout;
        int open = 0;
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                if (layout.GetTile(x, y) != TileRole.Wall || map.IsCut(x, y, q)) continue;
                foreach (var (nx, ny, dir) in new[] { (x + 1, y, PF2e.Grid.CardinalDirection.East), (x - 1, y, PF2e.Grid.CardinalDirection.West),
                    (x, y + 1, PF2e.Grid.CardinalDirection.North), (x, y - 1, PF2e.Grid.CardinalDirection.South) })
                    if (layout.IsInBounds(nx, ny) && layout.GetTile(nx, ny) == TileRole.Wall && map.IsCut(nx, ny, q)
                        && !faces.Contains((x, y, dir))) open++;
            }
        Check($"E{n} yaw {yaw:0} every standing wall beside a cut ends in a masonry face ({open} open)", open == 0);
    }

    private void SightCheck(string label, CombatScene scene, TerrainStage stage, Camera3D camera)
    {
        if (stage.Cutaway?.Map is not { } map || stage.Skirt is not { } skirt || scene.Session is not { } session) return;
        int wallHeight = PF2e.MapGen.Biomes.MapGenRegistry.GetBiome(SewerBoard.BiomeId).WallHeight;
        var hidden = CutawaySight.Hidden(skirt, map, stage.HeightMap.HeightScale, stage.HeightMap,
            session.Team1.Concat(session.Team2), camera.GlobalPosition, stage.Cutaway.CameraQuadrant,
            SightHeight, wallHeight);
        var walls = hidden.Where(b => !b.ByPillar).Select(Describe).ToList();
        var pillars = hidden.Where(b => b.ByPillar).Select(Describe).ToList();
        Check($"{label}: no wall hides a unit{(walls.Count > 0 ? " (" + string.Join(", ", walls) + ")" : "")}", walls.Count == 0);
        Check($"{label}: no pillar hides a unit{(pillars.Count > 0 ? " (" + string.Join(", ", pillars) + ")" : "")}", pillars.Count == 0);
    }

    private static string Describe(CutawaySight.Blocked b) => $"{b.Unit} at ({b.Tile.x},{b.Tile.y})";

    private async Task<CombatScene?> Start(PrologueBattle battle)
    {
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(battle.BuildSetup(CombatSeed));
        for (float waited = 0; !scene.IsPlayerTurn && waited < TurnWaitSeconds; waited += PollSeconds)
            await WaitSeconds(PollSeconds);
        Check($"{battle.Id} reached a hero turn", scene.IsPlayerTurn);
        return scene;
    }

    private async Task CloseUp(Node scene, Vector3 focus, Vector2 orbit)
    {
        var rig = Rig();
        if (rig == null) return;
        rig.FocusForInspection(focus);
        rig.SetOrbit(orbit.X, orbit.Y);
        rig.SetDolly(CloseDolly);
        await WaitSeconds(SettleSeconds);
    }

    /// <summary>Seconds between the two frames of each UNGILDED_FLOW_FRAMES pair.</summary>
    [Export] public float FlowFrameSeconds { get; set; } = 0.5f;

    /// <summary>With UNGILDED_FLOW_FRAMES set, saves two close-ups of <paramref name="focus"/>
    /// <see cref="FlowFrameSeconds"/> apart as <c>sewer_flow_{name}_a.png</c> and <c>_b.png</c>.</summary>
    private async Task FlowFrames(Node scene, string name, Vector3 focus, Vector2 orbit)
    {
        if (string.IsNullOrEmpty(System.Environment.GetEnvironmentVariable("UNGILDED_FLOW_FRAMES"))) return;
        await CloseUp(scene, focus, orbit);
        Check($"flow frame {name}_a saved", Save($"sewer_flow_{name}_a.png"));
        await WaitSeconds(FlowFrameSeconds);
        Check($"flow frame {name}_b saved", Save($"sewer_flow_{name}_b.png"));
    }

    private OrbitCameraRig? Rig()
    {
        Node? node = GetViewport().GetCamera3D();
        while (node != null && node is not OrbitCameraRig) node = node.GetParent();
        return node as OrbitCameraRig;
    }

    private static SewerDressing? Dressing(Node scene)
        => scene.GetNode<TerrainStage>("%TerrainStage").Look?.Dressing as SewerDressing;

    /// <summary>Wall props are named after their scene root or art plus their wall tile.</summary>
    private static int Named(Node? root, string name)
        => root?.FindChildren($"*{name}*", "", true, false).Count ?? 0;

    private bool Save(string file) => SaveViewportCapture(ShotDirectory.PathJoin(file), ShotSize) == Error.Ok;
}
