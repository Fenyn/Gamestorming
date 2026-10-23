using System;
using System.Collections.Generic;
using Godot;
using Ungilded.Props;

namespace Ungilded.Story.Cutscene;

/// <summary>The set's small effects: speaker hops, props laid on the floor, splashes on wet tiles,
/// falling dust, the sigil, and creatures darkening past the lit area.</summary>
public partial class CutsceneSet
{
    /// <summary>The actor that speaks each speaker's lines: "The Player" to "player".</summary>
    [Export] public Godot.Collections.Dictionary<string, StringName> Speakers { get; set; } = new();

    /// <summary>One-shot splash, spawned under a walking actor that steps onto a wet tile.</summary>
    [Export] public PackedScene? SplashScene { get; set; }

    /// <summary>One-shot dust fall for <see cref="DropDust"/>.</summary>
    [Export] public PackedScene? DustScene { get; set; }

    /// <summary>Metres above the floor the dust starts.</summary>
    [Export] public float DustHeight { get; set; } = 2.6f;

    /// <summary>Seconds a one-shot effect lives before it is freed.</summary>
    [Export] public float EffectSeconds { get; set; } = 2.5f;

    /// <summary>Fires with the tile of each splash.</summary>
    public event Action<Vector2I>? Splashed;

    /// <summary>Fires with the actor that hops for a line.</summary>
    public event Action<CutsceneActor>? SpeakerHopped;

    /// <summary>The sigil the board's dressing placed, or null.</summary>
    public SewerSigil? Sigil => (Stage.Look?.Dressing as SewerDressing)?.Sigil;

    /// <summary>Board tiles under a puddle or slime decal.</summary>
    public IReadOnlyCollection<Vector2I> WetTiles =>
        (Stage.Look?.Dressing as SewerDressing)?.WetTiles ?? Array.Empty<Vector2I>();

    private Node3D _propLayer = null!;
    private readonly Dictionary<StringName, Node3D> _props = new();
    private readonly Dictionary<CutsceneActor, Vector2I> _feet = new();

    /// <summary>The speaker of <paramref name="line"/> hops when it is an actor standing on the set.
    /// Narration has no speaker.</summary>
    public void HopSpeaker(DialogueLine line)
    {
        if (line.IsNarration || !Speakers.TryGetValue(line.Speaker, out var id)) return;
        if (!_actors.TryGetValue(id, out var actor) || !actor.Visible) return;
        actor.Hop();
        SpeakerHopped?.Invoke(actor);
    }

    public bool HasProp(StringName id) => _props.ContainsKey(id);

    /// <summary>Put <paramref name="sprite"/> at <paramref name="tile"/> under <paramref name="id"/>,
    /// replacing any prop with that id: flat on the floor when the sprite is flat, else standing.</summary>
    public void LayProp(StringName id, DecorSprite sprite, Vector2 tile, int turns)
    {
        TakeProp(id);
        var holder = new Node3D { Name = id };
        _propLayer.AddChild(holder);
        var centre = TileToWorld(tile);
        if (sprite.Flat) FloorClutter.AddDecal(holder, sprite, centre, turns, ShadeAt(centre));
        else FloorClutter.AddStanding(holder, sprite, centre, turns % 2 == 1, ShadeAt(centre));
        _props[id] = holder;
    }

    /// <summary>The dressing shades the skeleton for its halo ring; on a set it takes the
    /// <see cref="LitArea"/> shade, like the floor props beside it.</summary>
    private void ShadeSkeleton()
    {
        if ((Stage.Look?.Dressing as SewerDressing)?.Skeleton is not { } skeleton) return;
        float shade = ShadeAt(skeleton.GlobalPosition);
        skeleton.Modulate = new Color(shade, shade, shade);
    }

    public void TakeProp(StringName id)
    {
        if (!_props.Remove(id, out var holder)) return;
        holder.QueueFree();
    }

    /// <summary>Dust falls from the vault over <paramref name="tile"/>.</summary>
    public void DropDust(Vector2 tile) => SpawnEffect(DustScene, TileToWorld(tile) + Vector3.Up * DustHeight);

    /// <summary>Brightness of the halo terrain at <paramref name="world"/>, 1 inside the lit area.</summary>
    public float ShadeAt(Vector3 world)
    {
        if (Stage.Look is not { HaloOn: true } look) return 1f;
        var lit = LitArea.HasArea() ? LitArea : new Rect2I(0, 0, Stage.Layout?.Width ?? 0, Stage.Layout?.Height ?? 0);
        float dx = Mathf.Max(Mathf.Max(lit.Position.X - world.X, world.X - lit.End.X), 0f);
        float dz = Mathf.Max(Mathf.Max(lit.Position.Y - world.Z, world.Z - lit.End.Y), 0f);
        return look.HaloShade(new Vector2(dx, dz).Length());
    }

    /// <summary>Splash under walking actors that step onto a wet tile, and shade creatures by the
    /// terrain under them.</summary>
    private void TrackFeet()
    {
        var wet = WetTiles;
        foreach (var actor in _actors.Values)
        {
            if (!actor.Visible) continue;
            if (actor.ShadeInDark) actor.SetShade(ShadeAt(actor.Position));
            var tile = actor.TileNow;
            if (_feet.TryGetValue(actor, out var last) && last == tile) continue;
            _feet[actor] = tile;
            if (!actor.IsWalking || !Contains(wet, tile)) continue;
            SpawnEffect(SplashScene, actor.Position);
            Splashed?.Invoke(tile);
        }
    }

    private static bool Contains(IReadOnlyCollection<Vector2I> tiles, Vector2I tile) =>
        tiles is ICollection<Vector2I> set ? set.Contains(tile) : System.Linq.Enumerable.Contains(tiles, tile);

    private void SpawnEffect(PackedScene? scene, Vector3 at)
    {
        if (scene?.Instantiate() is not Node3D effect) return;
        effect.Position = at;
        _propLayer.AddChild(effect);
        GetTree().CreateTimer(EffectSeconds).Timeout += () =>
        {
            if (IsInstanceValid(effect)) effect.QueueFree();
        };
    }
}
