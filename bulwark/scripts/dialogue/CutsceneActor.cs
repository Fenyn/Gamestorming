using Bulwark.Data;
using Godot;

namespace Bulwark.Dialogue;

/// <summary>Cardinal facing for a cutscene puppet, mapped to Mana Seed sheet rows.</summary>
public enum CutsceneFacing
{
    South,
    North,
    East,
    West,
}

/// <summary>
/// A dumb cutscene puppet: a Node2D with a <c>%Sprite</c> Sprite2D child driven by the Mana Seed
/// sheet anatomy (<see cref="ManaSeedSheet"/>). The <see cref="CutsceneDirector"/> poses it —
/// <see cref="SetFacing(CutsceneFacing)"/>, <see cref="StartWalk"/> / <see cref="StopWalk"/> — and it
/// renders the matching stand or walk frame. No game logic and no movement of its own: positions come
/// from the director's tweens; this node only picks the sprite frame. Placed in scenes (F6/blockout),
/// never spawned in code.
/// </summary>
public partial class CutsceneActor : Node2D
{
    /// <summary>Initial cardinal facing (serialized in the .tscn; the director overrides it at runtime).</summary>
    [Export] public CutsceneFacing Facing { get; set; } = CutsceneFacing.South;

    private Sprite2D _sprite = null!;
    private bool _walking;
    private float _animTimer;
    private int _animFrame;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("%Sprite");
        ApplyFrame();
    }

    /// <summary>Face a cardinal direction and reset the walk cycle to its first frame.</summary>
    public void SetFacing(CutsceneFacing facing)
    {
        Facing = facing;
        _animFrame = 0;
        _animTimer = 0f;
        ApplyFrame();
    }

    /// <summary>Face a cardinal direction given as a string ("south"/"north"/"east"/"west").
    /// An unrecognized value leaves the current facing unchanged.</summary>
    public void SetFacing(string? direction)
    {
        if (TryParseFacing(direction, out CutsceneFacing facing))
            SetFacing(facing);
    }

    /// <summary>Begin advancing the 6-frame walk cycle for the current facing on <see cref="_Process"/>.</summary>
    public void StartWalk() => _walking = true;

    /// <summary>Stop the walk cycle and settle on the standing frame for the current facing.</summary>
    public void StopWalk()
    {
        _walking = false;
        _animFrame = 0;
        _animTimer = 0f;
        ApplyFrame();
    }

    public override void _Process(double delta)
    {
        if (!_walking)
            return;

        _animTimer += (float)delta;
        if (_animTimer >= ManaSeedSheet.WalkFrameTime)
        {
            _animTimer -= ManaSeedSheet.WalkFrameTime;
            _animFrame = (_animFrame + 1) % ManaSeedSheet.WalkFrames;
            ApplyFrame();
        }
    }

    /// <summary>Select the sheet cell for the current facing and walk/idle state.</summary>
    private void ApplyFrame()
    {
        if (_sprite == null)
            return;
        int row = _walking ? ManaSeedSheet.WalkRowOffset + FacingRow(Facing) : FacingRow(Facing);
        int col = _walking ? _animFrame : 0;
        _sprite.Frame = row * ManaSeedSheet.Columns + col;
    }

    private static int FacingRow(CutsceneFacing facing) => facing switch
    {
        CutsceneFacing.North => ManaSeedSheet.RowNorth,
        CutsceneFacing.East => ManaSeedSheet.RowEast,
        CutsceneFacing.West => ManaSeedSheet.RowWest,
        _ => ManaSeedSheet.RowSouth,
    };

    /// <summary>Parse a cardinal string ("south"/"north"/"east"/"west", case-insensitive) into a
    /// <see cref="CutsceneFacing"/>. Returns false (with <paramref name="facing"/> = South) for anything else.</summary>
    public static bool TryParseFacing(string? direction, out CutsceneFacing facing)
    {
        switch (direction?.ToLowerInvariant())
        {
            case "north": facing = CutsceneFacing.North; return true;
            case "east": facing = CutsceneFacing.East; return true;
            case "west": facing = CutsceneFacing.West; return true;
            case "south": facing = CutsceneFacing.South; return true;
            default: facing = CutsceneFacing.South; return false;
        }
    }
}