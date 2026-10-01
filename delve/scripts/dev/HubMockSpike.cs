using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Storyboard renders of the merged hub concept (scratchpad hub_merged.md) for the mockup sheet.
/// It rearranges the real outpost at runtime: the chapel gate moves up the screen from the fire,
/// props share one pixel scale, residents become crawl-scale billboards busy at activity spots, and
/// the chosen four fill line slots before the gate. Four shots: the overview at the fire, a walk
/// frame, the line-up, and the step into the gate. Each shot also writes the screen positions of the
/// stations so the mockup script can place their tags. Nothing here touches the real camp; rendered only.
/// </summary>
public partial class HubMockSpike : SpikeBase
{
    [Export] public PackedScene CampScene { get; set; } = null!;

    /// <summary>World units per hero sprite pixel: the crawl's scale.</summary>
    [Export] public float HeroPixel { get; set; } = 0.05f;

    /// <summary>World units per prop pixel: one 48 px Winlu tile per unit, as the trees.</summary>
    [Export] public float PropPixel { get; set; } = 1f / 48f;

    [Export] public float SettleSeconds { get; set; } = 0.6f;

    /// <summary>Render the growing camp's three stages (hub_growth.md) instead of the storyboard.</summary>
    [Export] public bool Growth { get; set; } = true;

    private CampStage _stage = null!;

    private const float Yaw = 15f;
    private static readonly Vector3 Fire = new(0, 0, 2.4f);
    private static readonly Vector3 Gate = new(-2.3f, 0, -6.3f);
    private static readonly Vector3[] Slots =
        { new(-5.45f, 0, -2.87f), new(-2.94f, 0, -3.54f), new(-0.42f, 0, -4.22f), new(2.09f, 0, -4.89f) };

    private CampTerrain _terrain = null!;
    private Node3D _outpost = null!;
    private Camera3D _camera = null!;
    private readonly Dictionary<string, Sprite3D> _heroes = new();
    private readonly Dictionary<string, Vector3> _stations = new();
    private readonly List<OmniLight3D> _lanterns = new();

    /// <summary>How far above a resident's sprite centre the painted label anchors.</summary>
    private float _heroLift = 1.7f;

    /// <summary>Where the Delve arch stands; the village mock moves it to the north edge.</summary>
    private Vector3 _gate = Gate;
    private MeshInstance3D? _way;
    private Node3D? _ruin;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (DisplayServer.GetName() == "headless") { AbortFail("[hub] needs a window"); return; }
        var layer = new CanvasLayer();
        AddChild(layer);
        var camp = CampScene.Instantiate<HeroSelectPanel>();
        layer.AddChild(camp);
        var campaign = new CampaignProgress();
        campaign.Unlocks.Unlock(PresetCharacters.RavenId);
        campaign.Unlocks.Unlock(PresetCharacters.ThistleId);
        camp.Setup(campaign.Unlocks, campaign);
        foreach (string chrome in new[] { "Header", "%RecruitmentButton", "%BestiaryButton", "Companion", "%Squad", "Departure", "%RosterList", "Mist" })
            camp.GetNode<Control>(chrome).Hide();

        var stage = camp.GetNode<CampStage>("%CampStage");
        _camera = stage.GetNode<Camera3D>("%CampCamera");
        _terrain = stage.GetNode<CampTerrain>("%CampTerrain");
        _outpost = _camera.GetParent<Node3D>();
        _camera.Projection = Camera3D.ProjectionType.Perspective;
        _camera.Fov = 22f;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        if (Village) PrepareVillage();
        MoveGate();
        AddLanterns();
        _stage = stage;
        if (Village)
        {
            await RunVillage();
        }
        else if (Town)
        {
            await RunTown();
        }
        else if (Growth)
        {
            await RunGrowth();
        }
        else
        {
            ArrangeProps();
            AddHeroes(stage);
            await RunStoryboard();
        }

        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    // ---------------------------------------------------------------- Space

    /// <summary>The ruin group turns into the gate: one pivot, moved up the screen from the fire.</summary>
    private void MoveGate()
    {
        var pivot = new Node3D { Position = new Vector3(-6.2f, 0, -13.8f) };
        _outpost.AddChild(pivot);
        foreach (string name in new[] { "ChapelRemnant", "ChapelReturn", "Rubble0", "Rubble1", "Rubble2", "Rubble3", "Rubble4" })
            if (_outpost.GetNodeOrNull<Node3D>(name) is { } part) part.Reparent(pivot, keepGlobalTransform: true);
        var at = _gate + new Vector3(-3.3f, 0, 0.9f);
        pivot.Position = at with { Y = _terrain.HeightAt(at) };
        _ruin = pivot;
        pivot.RotationDegrees = new Vector3(0, 27, 0);
        // The way down: darkness that thins upward, so the arch reads as a stair into the ground.
        var fade = new Gradient
        {
            Offsets = new[] { 0f, 0.6f, 1f },
            Colors = new[] { new Color(0.02f, 0.03f, 0.04f, 1f), new Color(0.03f, 0.04f, 0.05f, 0.92f), new Color(0.04f, 0.05f, 0.06f, 0f) },
        };
        var way = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = new Vector2(2.1f, 2.2f) },
            MaterialOverride = new StandardMaterial3D
            {
                ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                AlbedoTexture = new GradientTexture2D { Gradient = fade, FillFrom = new Vector2(0, 1), FillTo = new Vector2(0, 0) },
            },
            RotationDegrees = new Vector3(0, 27, 0),
        };
        _outpost.AddChild(way);
        way.Position = _gate + new Vector3(-0.35f, _terrain.HeightAt(_gate) + 1.1f, -0.35f);
        _way = way;
        _stations["delve"] = _gate + new Vector3(0, 2.6f, 0);
    }

    /// <summary>Stations and activity props at the spec's spots, all at one prop pixel scale.</summary>
    private void ArrangeProps()
    {
        foreach (var prop in _outpost.GetChildren().OfType<Sprite3D>().Where(p => !p.Name.ToString().StartsWith("CampGrass")))
            Rescale(prop, prop.Name == "Fire" ? HeroPixel : PropPixel);
        MoveProp("SharedTable", new Vector3(6.3f, 0, -4.9f));
        MoveProp("HerbPots0", new Vector3(7.6f, 0, -4.4f));
        MoveProp("HerbPots1", new Vector3(8.4f, 0, -4.8f));
        MoveProp("TravelSupplies", new Vector3(7.3f, 0, 0.5f));
        MoveProp("Supplies0", new Vector3(-9.1f, 0, -0.8f));
        MoveProp("Woodpile", new Vector3(-8.2f, 0, -3.9f));
        MoveProp("SharedTools", new Vector3(-9.6f, 0, -3.2f));
        MoveProp("Seat2", new Vector3(-3.2f, 0, 2.6f));
        MoveProp("Seat3", new Vector3(3.2f, 0, 2.8f));
        MoveProp("Seat4", new Vector3(-2.2f, 0, 0.2f));
        MoveProp("Seat5", new Vector3(2.4f, 0, 0.4f));
        foreach (string hidden in new[] { "Seat0", "Seat1" })
            if (_outpost.GetNodeOrNull<Node3D>(hidden) is { } node) node.Hide();
        _stations["unlocks"] = new Vector3(-9.1f, 1.2f, -0.8f);
        _stations["bestiary"] = new Vector3(6.3f, 1.0f, -4.9f);
        _stations["stores"] = new Vector3(7.3f, 1.0f, 0.5f);
    }

    private void AddLanterns()
    {
        foreach (var spot in new[] { new Vector3(-4.1f, 0, -5.2f), new Vector3(-0.25f, 0, -6.2f) })
        {
            var light = new OmniLight3D { LightColor = new Color(1.0f, 0.78f, 0.5f), LightEnergy = 0f, OmniRange = 4.5f };
            _outpost.AddChild(light);
            light.Position = spot with { Y = _terrain.HeightAt(spot) + 1.6f };
            _lanterns.Add(light);
        }
    }

    private void Rescale(Sprite3D prop, float pixel)
    {
        float ground = _terrain.HeightAt(prop.Position);
        float lift = (prop.Position.Y - ground) * pixel / Mathf.Max(0.0001f, prop.PixelSize);
        prop.PixelSize = pixel;
        prop.Position = prop.Position with { Y = ground + lift };
    }

    private void MoveProp(string name, Vector3 spot)
    {
        if (_outpost.GetNodeOrNull<Node3D>(name) is not { } prop) return;
        float lift = prop.Position.Y - _terrain.HeightAt(prop.Position);
        prop.Position = spot with { Y = _terrain.HeightAt(spot) + lift };
    }

    // ---------------------------------------------------------------- Residents

    private enum Walk { Stand, Stride }
    private enum Facing { South = 0, North = 1, East = 2, West = 3 }

    /// <summary>The billboard for a resident, made on first use.</summary>
    private Sprite3D Hero(string id)
    {
        if (_heroes.TryGetValue(id, out var existing)) return existing;
        var sprite = new Sprite3D
        {
            PixelSize = HeroPixel,
            Billboard = BaseMaterial3D.BillboardModeEnum.FixedY,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            AlphaCut = SpriteBase3D.AlphaCutMode.Discard,
            Hframes = ManaSeedSheet.Columns,
            Vframes = ManaSeedSheet.Rows,
        };
        _outpost.AddChild(sprite);
        return _heroes[id] = sprite;
    }

    private void AddHeroes(CampStage stage)
    {
        // Everyone busy at a spot that means something (Hades' House).
        Work("player", new Vector3(-7.3f, 0, -3.7f), ManaSeedSheet.AxePage, 0, Facing.West, 2);
        Work("elara", new Vector3(-5.9f, 0, 5.2f), "p2", 4, Facing.East, 1);
        Seated(stage, "tharr", new Vector3(-3.2f, 0, 2.45f));
        Seated(stage, PresetCharacters.ThistleId, new Vector3(3.2f, 0, 2.65f));
        Pose("fenwick", new Vector3(5.4f, 0, -4.2f), Walk.Stand, Facing.North);
        Work(PresetCharacters.RavenId, new Vector3(3.4f, 0, -5.8f), "p2_mine", 0, Facing.North, 2);
    }

    /// <summary>A frame off a work page (chop, throw, mine): row = facing, column = start + step.</summary>
    private void Work(string id, Vector3 spot, string page, int startColumn, Facing facing, int step)
    {
        var sprite = Sheeted(id);
        sprite.Texture = Sheet(id, page);
        sprite.Frame = (int)facing * ManaSeedSheet.Columns + startColumn + step;
        Stand(sprite, spot);
    }

    private void Pose(string id, Vector3 spot, Walk walk, Facing facing)
    {
        var sprite = Sheeted(id);
        sprite.Texture = Sheet(id, ManaSeedSheet.WalkPage);
        int row = (walk == Walk.Stride ? ManaSeedSheet.WalkRowOffset : 0) + (int)facing;
        sprite.Frame = row * ManaSeedSheet.Columns + (walk == Walk.Stride ? 2 : 0);
        Stand(sprite, spot);
    }

    /// <summary>The hero's sprite set back to the 8x8 Mana Seed grid (a seated pose is one frame).</summary>
    private Sprite3D Sheeted(string id)
    {
        var sprite = Hero(id);
        sprite.Hframes = ManaSeedSheet.Columns;
        sprite.Vframes = ManaSeedSheet.Rows;
        return sprite;
    }

    /// <summary>The camp's seated pose, 0.15 u behind the log so the log covers the legs.</summary>
    private void Seated(CampStage stage, string id, Vector3 spot)
    {
        var sprite = Hero(id);
        int seat = stage.SeatFor(id);
        var poses = stage.AppearanceFor(seat < 0 ? 0 : seat).Poses();
        sprite.Hframes = 1;
        sprite.Vframes = 1;
        sprite.Texture = poses.FirstOrDefault();
        Stand(sprite, spot + new Vector3(0, 0, -0.15f));
    }

    private void Stand(Sprite3D sprite, Vector3 spot)
    {
        float frame = sprite.Hframes > 1 ? ManaSeedSheet.CellPx : sprite.Texture?.GetHeight() ?? ManaSeedSheet.CellPx;
        sprite.Position = spot with { Y = _terrain.HeightAt(spot) + frame * HeroPixel * 0.5f };
    }

    private static Texture2D? Sheet(string id, string page)
    {
        string path = ManaSeedSheet.SheetPath(HeroSpriteMap.FolderFor(id), page);
        return ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;
    }

    // ---------------------------------------------------------------- Camera and capture

    private void Orbit(Vector3 target, float pitch, float distance)
    {
        float y = Mathf.DegToRad(Yaw), p = Mathf.DegToRad(pitch);
        var direction = new Vector3(Mathf.Sin(y) * Mathf.Cos(p), Mathf.Sin(p), Mathf.Cos(y) * Mathf.Cos(p));
        _camera.Position = target + direction * distance;
        _camera.LookAt(target);
    }

    private async Task Shot(string name)
    {
        await ToSignal(GetTree().CreateTimer(SettleSeconds), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        Check($"{name} saved", SaveViewportCapture($"user://dev_shots/{name}.png", new Vector2I(1920, 1080)) == Error.Ok);
        // Where each station and hero lands on screen, for the painted tags.
        var viewport = _camera.GetViewport().GetVisibleRect().Size;
        var scale = new Vector2(1920, 1080) / viewport;
        var json = new StringBuilder("{");
        foreach (var (key, point) in _stations.Select(s => (s.Key, s.Value))
                     .Concat(_heroes.Where(h => h.Value.Visible).Select(h => (h.Key, h.Value.GlobalPosition + Vector3.Up * _heroLift))))
        {
            var world = key.Length > 0 && _stations.ContainsKey(key) ? point with { Y = point.Y + _terrain.HeightAt(point) } : point;
            var screen = _camera.UnprojectPosition(world) * scale;
            json.Append($"\"{key}\":[{screen.X:0},{screen.Y:0}],");
        }
        json.Length--;
        json.Append('}');
        string directory = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        if (directory.Length > 0)
            using (var file = FileAccess.Open(directory.PathJoin($"{name}.json"), FileAccess.ModeFlags.Write)) file.StoreString(json.ToString());
    }
}
