using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using Ungilded.Content;
using Ungilded.Data;
using Ungilded.Look;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Story.Cutscene;

/// <summary>
/// A story stage: one Prologue board built through <see cref="TerrainStage"/> with its look, halo and
/// dressing, a camera of its own and the hero actors. No combat runs on it. <see cref="Play"/> runs a
/// line's <see cref="StageCue"/>s. Tiles are board tiles; the halo around the board is walkable
/// scenery too, so a set can use the tunnels that lead off it.
/// </summary>
public partial class CutsceneSet : Node3D
{
    /// <summary>The board this set stands on: <see cref="PrologueMaps.Encounter(int)"/>.</summary>
    [Export(PropertyHint.Range, "1,4,1")] public int Encounter { get; set; } = 1;

    [Export] public PackedScene? ActorScene { get; set; }

    /// <summary>Board tiles the look treats as the board, so its halo darkening starts past them.
    /// Empty keeps the board itself. A set lights the tunnels its actors walk in.</summary>
    [Export] public Rect2I LitArea { get; set; }

    /// <summary>Actor ids that stand for creatures, each mapped to a <see cref="PrologueBestiary"/>
    /// creature id. Such an actor draws the creature's board sprite. Every other id is a hero.</summary>
    [Export] public Godot.Collections.Dictionary<StringName, string> Creatures { get; set; } = new();

    /// <summary>Fires as each cue starts.</summary>
    public event Action<StageCue>? CueStarted;

    public TerrainStage Stage { get; private set; } = null!;
    public CutsceneCamera Camera { get; private set; } = null!;

    public bool IsBuilt => _skirtHeights != null;

    public IEnumerable<CutsceneActor> Actors => _actors.Values;

    private Node3D _actorLayer = null!;
    private readonly Dictionary<StringName, CutsceneActor> _actors = new();
    private TerrainHeightMap? _skirtHeights;
    private int _margin;

    public override void _Ready()
    {
        Stage = GetNode<TerrainStage>("%Stage");
        Camera = GetNode<CutsceneCamera>("%Camera");
        _actorLayer = GetNode<Node3D>("%Actors");
        _propLayer = GetNode<Node3D>("%Props");
        _grade = GetNode<Node2D>("%Grade");
        Camera.ShotStarted += HoldCut;
    }

    /// <summary>Cut the walls for the pose a shot ends on and keep that cut through its blend, so
    /// no wall comes down or back up while the camera swings past an axis.</summary>
    private void HoldCut(CameraShot shot) => Stage.Cutaway?.Hold(shot.Toward);

    /// <summary>Build the board and take the view.</summary>
    public void Build()
    {
        var battle = PrologueMaps.Encounter(Encounter);
        Stage.Build(battle.Layout, battle.BiomeId, battle.Width, battle.Height, battle.Halo);
        if (LitArea.HasArea())
            RenderingServer.GlobalShaderParameterSet(LookScene.BoardRectGlobal,
                new Vector4(LitArea.Position.X, LitArea.Position.Y, LitArea.End.X, LitArea.End.Y));
        if (Stage.Skirt is { } skirt)
        {
            _margin = skirt.Margin;
            _skirtHeights = new TerrainHeightMap(skirt.Layout, Stage.HeightMap.HeightScale);
        }
        ShadeSkeleton();
        DressAir();
        Camera.Current = true;
    }

    /// <summary>Stage the opening of <paramref name="line"/> before the set shows: its actors stand
    /// on their tiles and the camera cuts to its first shot. The line still plays all of its cues
    /// as it starts.</summary>
    public void Frame(DialogueLine line)
    {
        foreach (var place in line.StageCues.OfType<PlaceCue>().Where(c => c.Delay <= 0f)) place.Play(this);
        if (line.StageCues.OfType<ShotCue>().FirstOrDefault(c => c.Delay <= 0f) is { } shot)
            Camera.Blend(shot.ShotOn(this), 0f, shot.Transition, shot.Ease);
    }

    /// <summary>Start every cue in order; a cue with a <see cref="StageCue.Delay"/> starts that much
    /// later. The task ends when the cues marked <see cref="StageCue.Wait"/> do.</summary>
    public Task Play(IEnumerable<StageCue> cues)
    {
        FlushDelayed();
        var waits = new List<Task>();
        foreach (var cue in cues)
        {
            CueStarted?.Invoke(cue);
            var running = cue.Delay > 0f ? PlayLater(cue) : cue.Play(this);
            if (cue.Wait) waits.Add(running);
        }
        return waits.Count == 0 ? Task.CompletedTask : Task.WhenAll(waits);
    }

    /// <summary>Delayed cues not yet played. The next line plays them at once, so a line skipped
    /// early still leaves the stage as authored.</summary>
    private readonly List<StageCue> _delayed = new();

    private async Task PlayLater(StageCue cue)
    {
        _delayed.Add(cue);
        await ToSignal(GetTree().CreateTimer(cue.Delay), SceneTreeTimer.SignalName.Timeout);
        if (_delayed.Remove(cue) && IsInsideTree()) await cue.Play(this);
    }

    private void FlushDelayed()
    {
        var pending = _delayed.ToList();
        _delayed.Clear();
        foreach (var cue in pending) cue.Play(this);
    }

    /// <summary>The actor for a hero id or a <see cref="Creatures"/> id, spawned hidden on first use.</summary>
    public CutsceneActor Actor(StringName id)
    {
        if (_actors.TryGetValue(id, out var actor)) return actor;
        if (ActorScene == null) throw new InvalidOperationException("[CutsceneSet] ActorScene is not assigned.");
        actor = CutsceneActor.Spawn(ActorScene, id, EnemySpriteMap.Definition(SpriteFolder(id)), WidthOf(id));
        actor.ShadeInDark = Creatures.ContainsKey(id);
        _actorLayer.AddChild(actor);
        _actors[id] = actor;
        return actor;
    }

    private string SpriteFolder(StringName id)
    {
        if (!Creatures.TryGetValue(id, out var creatureId)) return HeroSpriteMap.FolderFor(id);
        var creature = PrologueBestiary.Find(creatureId)
            ?? throw new InvalidOperationException($"[CutsceneSet] actor {id}: no creature '{creatureId}'.");
        return EnemySpriteMap.FolderForCreature(creature.CreatureName, creature.StatBlock.CreatureSize);
    }

    /// <summary>Tiles along one side of an actor's square space, from its creature's size; 1 for a hero.</summary>
    private int WidthOf(StringName id) =>
        Creatures.TryGetValue(id, out var creatureId) && PrologueBestiary.Find(creatureId) is { } creature
            ? PF2e.Utilities.CreatureSizeHelper.GetTileWidth(creature.StatBlock.CreatureSize)
            : 1;

    /// <summary>Mean of the named actors' destinations.</summary>
    public Vector3 ActorsCentre(IEnumerable<StringName> ids)
    {
        var points = ids.Select(id => Actor(id).Destination).ToList();
        return points.Aggregate(Vector3.Zero, (sum, p) => sum + p) / points.Count;
    }

    /// <summary>Floor point of a board tile (fractions move within the tile), board or halo.</summary>
    public Vector3 TileToWorld(Vector2 tile)
    {
        var cell = new Vector2I(Mathf.FloorToInt(tile.X), Mathf.FloorToInt(tile.Y));
        return new Vector3(tile.X + 0.5f, SurfaceY(cell), tile.Y + 0.5f);
    }

    /// <summary>Where an actor with a <paramref name="width"/>-tile square space stands with its low
    /// corner on <paramref name="tile"/>: the centre of the space, on the highest floor under it, so
    /// a space across a step stands on the step's edge. Width 1 is <see cref="TileToWorld"/>.</summary>
    public Vector3 StandPoint(Vector2I tile, int width)
    {
        float y = float.NegativeInfinity;
        for (int dy = 0; dy < width; dy++)
            for (int dx = 0; dx < width; dx++)
                y = Mathf.Max(y, SurfaceY(tile + new Vector2I(dx, dy)));
        return new Vector3(tile.X + width * 0.5f, y, tile.Y + width * 0.5f);
    }

    public ActorStep Step(StringName actor, Vector2I tile) => new(tile, StandPoint(tile, Actor(actor).Width));

    /// <summary>Floor height of a board tile, halo tiles included.</summary>
    public float SurfaceY(Vector2I tile) =>
        _skirtHeights?.CenterY(new PF2eVec(tile.X + _margin, tile.Y + _margin)) ?? 0f;

    /// <summary>The terrain role of a board tile, halo tiles included; Empty past the rendered rim.</summary>
    public TileRole RoleAt(Vector2I tile)
    {
        if (Stage.Skirt is not { } skirt) return TileRole.Empty;
        int x = tile.X + skirt.Margin, y = tile.Y + skirt.Margin;
        return skirt.Layout.IsInBounds(x, y) ? skirt.Layout.GetTile(x, y) : TileRole.Empty;
    }

    public override void _Process(double delta)
    {
        TrackFeet();
        if (Stage.Cutaway is not { } cutaway) return;
        cutaway.SetOccupied(_actors.Values.Where(a => a.Visible)
            .SelectMany(a => a.SpaceAt(a.TileNow)).Select(t => (t.X, t.Y)));
    }
}
