using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using Ungilded.Combat;
using Ungilded.Data;
using Ungilded.Look;

namespace Ungilded.Story.Cutscene;

/// <summary>One step of a walk: the board tile and the world point its floor centre sits at.</summary>
public readonly record struct ActorStep(Vector2I Tile, Vector3 World);

/// <summary>
/// A hero or creature standing on a <see cref="CutsceneSet"/>: the billboard sprite and a ground shadow. The set
/// places it and walks it tile by tile; this node moves, never the sprite, whose own position is the
/// foot lift <see cref="BillboardSpriteAnimator.ConfigureEnemy(EnemySpriteDefinition)"/> writes. The
/// sprite sits under a Body node that only the hop moves. Hidden until placed.
/// </summary>
public partial class CutsceneActor : Node3D
{
    /// <summary>Walking pace when a cue gives none.</summary>
    [Export] public float SecondsPerTile { get; set; } = 0.5f;

    /// <summary>Metres above the feet of a carried accessory's glow: satchel height.</summary>
    [Export] public float CarriedGlowHeight { get; set; } = 0.5f;

    /// <summary>Eye height as a share of the sprite's body height, for a worn accessory's glow.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float EyeShareOfBody { get; set; } = 0.85f;

    /// <summary>How far the eyes sit from the sprite's centre line toward the face, as a share of the
    /// body height.</summary>
    [Export(PropertyHint.Range, "0,0.5,0.01")] public float EyeSideShareOfBody { get; set; } = 0.13f;

    private float _glowSide;
    private bool _glowFollows;

    private BillboardSpriteAnimator _sprite = null!;
    private EnemySpriteDefinition? _definition;
    private Tween? _walk;
    private TaskCompletionSource? _walkDone;

    /// <summary>The board tile the actor stands on, or the one it walks to.</summary>
    public Vector2I Tile { get; private set; }

    /// <summary>Where the actor stands, or where its walk ends.</summary>
    public Vector3 Destination { get; private set; }

    /// <summary>Tiles along one side of the actor's square space: 2 for a Large creature.</summary>
    public int Width { get; private set; } = 1;

    /// <summary>The low corner tile of the actor's space right now, mid-walk included.</summary>
    public Vector2I TileNow => new(Mathf.FloorToInt(Position.X - (Width - 1) * 0.5f),
        Mathf.FloorToInt(Position.Z - (Width - 1) * 0.5f));

    /// <summary>The tiles of the actor's space with its low corner on <paramref name="anchor"/>.</summary>
    public IEnumerable<Vector2I> SpaceAt(Vector2I anchor)
    {
        for (int y = 0; y < Width; y++)
            for (int x = 0; x < Width; x++)
                yield return anchor + new Vector2I(x, y);
    }

    public bool IsWalking => _walkDone != null;

    public Vector2 Facing => _sprite.Facing;

    public BillboardSpriteAnimator Sprite => _sprite;

    /// <summary>Instance <paramref name="scene"/> for an actor drawn by <paramref name="definition"/>
    /// on a <paramref name="width"/>-tile square space. The caller adds it to the tree.</summary>
    public static CutsceneActor Spawn(PackedScene scene, StringName id, EnemySpriteDefinition? definition, int width = 1)
    {
        var actor = scene.Instantiate<CutsceneActor>();
        actor.Name = id;
        actor._definition = definition;
        actor.Width = width;
        return actor;
    }

    public override void _Ready()
    {
        _sprite = GetNode<BillboardSpriteAnimator>("%Sprite");
        _body = GetNode<Node3D>("%Body");
        _glow = GetNode<CutsceneGlow>("%Glow");
        _sprite.ConfigureEnemy(_definition);
        var shadow = GetNode<Decal>("%Shadow");
        shadow.Size = shadow.Size with { X = shadow.Size.X * Width, Z = shadow.Size.Z * Width };
        GetNode<HandLantern>("%Lantern").Bind(_sprite, Name);
        _sprite.Modulate = LookScene.ActiveSpriteTint;
        Visible = false;
    }

    public override void _ExitTree() => StopWalk();

    public void Place(Vector2I tile, Vector3 world, Vector2 facing)
    {
        StopWalk();
        Tile = tile;
        Destination = world;
        Position = world;
        Visible = true;
        Face(facing);
    }

    /// <summary>Show an accessory the actor carries or wears as the glow at its satchel or eyes.</summary>
    public void ShowAccessory(AccessoryState state)
    {
        if (!_glowFollows)
        {
            _glowFollows = true;
            GetTree().ProcessFrame += PlaceGlowSide;
            TreeExiting += () => GetTree().ProcessFrame -= PlaceGlowSide;
        }
        _glowSide = AccessoryGlow.Side(state, _sprite.BodyHeight, EyeSideShareOfBody);
        SetGlow(state != AccessoryState.Hidden,
            AccessoryGlow.Height(state, _sprite.BodyHeight, CarriedGlowHeight, EyeShareOfBody, _glow.Position.Y));
    }

    /// <summary>Keep a worn glow toward the face side as the camera moves and the sprite flips.</summary>
    private void PlaceGlowSide()
    {
        if (!_glow.On) return;
        var beside = AccessoryGlow.Beside(this, _sprite.FlipH, _glowSide);
        _glow.Position = new Vector3(beside.X, _glow.Position.Y, beside.Z);
    }

    public void Face(Vector2 facing)
    {
        if (facing == Vector2.Zero) return;
        _sprite.Facing = facing;
        _sprite.ApplyFacing();
    }

    /// <summary>Walk through <paramref name="steps"/> at <paramref name="secondsPerTile"/> (zero uses
    /// <see cref="SecondsPerTile"/>), then face <paramref name="endFacing"/> unless it is zero. With
    /// <paramref name="keepFacing"/> the actor holds its current facing through the steps.</summary>
    public Task Walk(IReadOnlyList<ActorStep> steps, Vector2 endFacing, float secondsPerTile, bool keepFacing = false)
    {
        StopWalk();
        if (steps.Count == 0)
        {
            Face(endFacing);
            return Task.CompletedTask;
        }
        float pace = secondsPerTile > 0f ? secondsPerTile : SecondsPerTile;
        var done = new TaskCompletionSource();
        _walkDone = done;
        var tween = CreateTween();
        _walk = tween;
        var from = Position;
        foreach (var step in steps)
        {
            var heading = new Vector2(step.World.X - from.X, step.World.Z - from.Z);
            float tiles = Mathf.Max(heading.Length(), 0.01f);
            if (!keepFacing) tween.TweenCallback(Callable.From(() => Face(heading)));
            tween.TweenProperty(this, "position", step.World, pace * tiles);
            from = step.World;
        }
        Tile = steps[^1].Tile;
        Destination = steps[^1].World;
        Visible = true;
        _sprite.SetMoving(true);
        tween.Finished += () =>
        {
            if (_walk != tween) return;
            _walk = null;
            _walkDone = null;
            _sprite.SetMoving(false);
            Face(endFacing);
            done.TrySetResult();
        };
        return done.Task;
    }

    private void StopWalk()
    {
        _walk?.Kill();
        _walk = null;
        var done = _walkDone;
        _walkDone = null;
        if (done == null) return;
        _sprite.SetMoving(false);
        done.TrySetResult();
    }
}
