using Bulwark.Data;
using Godot;

namespace Bulwark.Dialogue;

/// <summary>Cardinal facing for a cutscene puppet in world space (South = +Z, toward the pitched cozy
/// camera; North = -Z; East = +X; West = -X), mapped to Mana Seed sheet rows through the camera.</summary>
public enum CutsceneFacing
{
    South,
    North,
    East,
    West,
}

/// <summary>
/// A dumb cutscene puppet: a Node3D with a <c>%Sprite</c> billboarded <see cref="Sprite3D"/> child
/// driven by the Mana Seed sheet anatomy (<see cref="ManaSeedSheet"/>), the same 2.5D presentation the
/// cozy avatar and the combat token use. The <see cref="CutsceneDirector"/> poses it —
/// <see cref="SetFacing(CutsceneFacing)"/>, <see cref="StartWalk"/> / <see cref="StopWalk"/> — and it
/// renders the matching stand or walk frame for the facing AS SEEN THROUGH THE ACTIVE CAMERA (the rule
/// in <see cref="Bulwark.Combat.UnitVisual3D"/> and <see cref="Bulwark.Cozy.PlayerController"/>), so a
/// camera pan or a yawed view never leaves a puppet showing the wrong side. No game logic and no
/// movement of its own: positions come from the director's tweens; this node only picks the sprite
/// frame. Placed in scenes (F6/blockout), never spawned in code.
/// </summary>
public partial class CutsceneActor : Node3D
{
    /// <summary>Initial cardinal facing (serialized in the .tscn; the director overrides it at runtime).</summary>
    [Export] public CutsceneFacing Facing { get; set; } = CutsceneFacing.South;

    private Sprite3D? _sprite;
    private bool _walking;
    private float _animTimer;
    private int _animFrame;

    public override void _Ready()
    {
        _sprite = GetNodeOrNull<Sprite3D>("%Sprite");
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
        if (_walking)
        {
            _animTimer += (float)delta;
            if (_animTimer >= ManaSeedSheet.WalkFrameTime)
            {
                _animTimer -= ManaSeedSheet.WalkFrameTime;
                _animFrame = (_animFrame + 1) % ManaSeedSheet.WalkFrames;
            }
        }

        // Re-resolved every frame, not just on a pose change: the sheet row depends on the camera, and
        // a `camera` staging step slides it mid-scene.
        ApplyFrame();
    }

    /// <summary>Select the sheet cell for the current facing and walk/idle state.</summary>
    private void ApplyFrame()
    {
        if (_sprite == null)
            return;
        int row = ScreenFacingRow();
        _sprite.Frame = _walking
            ? (ManaSeedSheet.WalkRowOffset + row) * ManaSeedSheet.Columns + _animFrame
            : row * ManaSeedSheet.Columns; // stand frame is column 0 of the facing row
    }

    /// <summary>
    /// Pick the sheet row from the world facing AS SEEN THROUGH THE ACTIVE CAMERA: project the facing
    /// onto the camera's ground-plane axes and let the dominant screen axis win, so the puppet reads
    /// "toward / away / left / right" from the viewer. With no camera (headless) the world mapping is
    /// used verbatim.
    /// </summary>
    private int ScreenFacingRow()
    {
        int worldRow = WorldRow(Facing);
        Camera3D? camera = GetViewport()?.GetCamera3D();
        if (camera == null || !IsInstanceValid(camera))
            return worldRow;

        Basis basis = camera.GlobalBasis;
        Vector3 fwd = -basis.Z; fwd.Y = 0f;
        fwd = fwd.LengthSquared() > 0.0001f ? fwd.Normalized() : Vector3.Forward;
        Vector3 right = basis.X; right.Y = 0f;
        right = right.LengthSquared() > 0.0001f ? right.Normalized() : Vector3.Right;

        Vector3 facing = WorldDirection(Facing);
        float sx = facing.Dot(right);   // + = screen right
        float sy = facing.Dot(fwd);     // + = into the screen (away from the viewer)
        return Mathf.Abs(sx) >= Mathf.Abs(sy)
            ? (sx >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest)
            : (sy >= 0f ? ManaSeedSheet.RowNorth : ManaSeedSheet.RowSouth);
    }

    /// <summary>The world-space unit vector a cardinal facing points along (South = +Z).</summary>
    private static Vector3 WorldDirection(CutsceneFacing facing) => facing switch
    {
        CutsceneFacing.North => Vector3.Forward, // -Z
        CutsceneFacing.East => Vector3.Right,    // +X
        CutsceneFacing.West => Vector3.Left,     // -X
        _ => Vector3.Back,                       // +Z
    };

    private static int WorldRow(CutsceneFacing facing) => facing switch
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
