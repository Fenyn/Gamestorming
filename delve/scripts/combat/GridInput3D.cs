using System;
using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Translates mouse input into grid coordinates for the 2.5D board. Every physics tick it casts the
/// cursor into the world and reports hover; left-click forwards the hovered tile and both a
/// stationary right-click and Esc (ui_cancel) cancel targeting. Pure input translation — no rules.
/// Middle-drag / wheel are left untouched so the <see cref="OrbitCameraRig"/> can consume them.
/// Right-drag also orbits (handled by the rig), so cancel only fires when the right button is
/// RELEASED after traveling less than <see cref="DragThresholdPixels"/> — a click, not a drag.
///
/// Picking is one physics ray against two layers: the unit click columns
/// (<see cref="UnitPickArea"/>) and the terrain trimesh. A column hit resolves to that unit's tile,
/// so a click anywhere on a drawn sprite targets the unit rather than the ground its body hides
/// behind it. A terrain hit floors to the tile struck. On a flat board (no terrain collider) a ray
/// that misses every column falls through to the analytic y = 0 plane.
///
/// The cast is confined to <c>_PhysicsProcess</c>: touching <c>DirectSpaceState</c> outside the
/// physics step risks a locked space, and a collider is not queryable on the frame it enters. The
/// pointer is cached from motion events in <c>_Input</c>, ahead of the GUI, so it is exact under
/// the HUD too and needs no per-frame poll. Clicks consume the tile the last cast published, so
/// hover and click can never disagree (the cost is that hover resolves one physics tick late,
/// which is imperceptible).
/// </summary>
public partial class GridInput3D : Node3D
{
    /// <summary>A tile was left-clicked.</summary>
    public event Action<PF2eVec>? TileClicked;

    /// <summary>The hovered tile changed. Null means the cursor left the board.</summary>
    public event Action<PF2eVec?>? TileHovered;

    /// <summary>Esc, or a stationary right-click, asked to cancel targeting.</summary>
    public event Action? Cancelled;

    /// <summary>The focus hotkey asked to re-centre the camera on the active unit.</summary>
    public event Action? FocusRequested;

    /// <summary>The rig owns the click-vs-drag gesture threshold; CombatScene pushes the rig's
    /// live value in at Setup so the two stay in agreement.</summary>
    [Export] public float DragThresholdPixels { get; set; } = OrbitCameraRig.DefaultDragThresholdPixels;

    /// <summary>Physics layer the terrain collider sits on. Must match the terrain view's
    /// <see cref="MapView3D.CollisionLayer"/> — both default to layer 1 ("Terrain").</summary>
    [Export] public uint TerrainCollisionMask { get; set; } = 1;

    /// <summary>Physics layer the unit click columns sit on. Must match the token scene's
    /// PickArea — both default to layer 2 ("Units").</summary>
    [Export] public uint UnitCollisionMask { get; set; } = 2;

    /// <summary>How far a picking ray travels. Well past the far side of any board at max zoom.</summary>
    private const float RayLength = 1000f;

    /// <summary>
    /// Distance to advance a terrain hit point ALONG the ray before flooring it to a tile. A ray that
    /// lands exactly on a cliff face sits on the boundary plane between two tile columns; nudging it
    /// forward by a hair resolves it into the column that was actually struck rather than the one in
    /// front of it.
    /// </summary>
    private const float HitNudge = 0.001f;

    private Camera3D _camera = null!;
    private int _gridWidth;
    private int _gridHeight;

    private PF2eVec? _lastHover;
    private Vector2 _rightPressPos;

    private bool _terrain;
    private Vector2 _pointer;

    /// <summary>Idle until an encounter wires this node up: no camera means every per-tick cast
    /// would be a null check and nothing else.</summary>
    public override void _Ready() => SetPhysicsProcess(false);

    public void Setup(Camera3D camera, int gridWidth, int gridHeight, TerrainHeightMap heightMap)
    {
        _camera = camera;
        _gridWidth = gridWidth;
        _gridHeight = gridHeight;
        _terrain = heightMap.HasTerrain;
        SetPhysicsProcess(true);
    }

    /// <summary>Cache the pointer. Runs ahead of the GUI, so motion over a HUD panel counts too.</summary>
    public override void _Input(InputEvent @event)
    {
        if (@event is InputEventMouseMotion motion) _pointer = motion.Position;
    }

    public override void _PhysicsProcess(double delta)
    {
        PF2eVec? cell = PickTile(_pointer);
        if (Equals(cell, _lastHover)) return;

        _lastHover = cell;
        TileHovered?.Invoke(cell);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (_camera == null) return;

        // Esc (ui_cancel) cancels targeting, mirroring the stationary right-click cancel below.
        if (@event.IsActionPressed(Delve.UI.InputNames.UiCancel))
        {
            Cancelled?.Invoke();
            return;
        }

        if (@event.IsActionPressed(Delve.UI.InputNames.Focus))
        {
            FocusRequested?.Invoke();
            GetViewport().SetInputAsHandled();
            return;
        }

        if (@event is not InputEventMouseButton mb) return;

        if (mb.Pressed && mb.ButtonIndex == MouseButton.Left)
        {
            // Consume the published hover rather than casting here: input runs outside the physics
            // step, and re-casting would also risk a click landing on a different tile than the one
            // the player saw highlighted.
            if (_lastHover.HasValue) TileClicked?.Invoke(_lastHover.Value);
        }
        else if (mb.ButtonIndex == MouseButton.Right)
        {
            // Right-drag orbits the camera (OrbitCameraRig); only a stationary right CLICK cancels.
            if (mb.Pressed)
                _rightPressPos = mb.Position;
            else if (mb.Position.DistanceTo(_rightPressPos) <= DragThresholdPixels)
                Cancelled?.Invoke();
        }
    }

    /// <summary>
    /// The tile under a screen point: the unit whose click column the ray strikes first, else the
    /// terrain tile struck, else (flat board only) the floor-plane tile. Null when the ray misses the
    /// board or lands off it. Must only be called from the physics step.
    /// </summary>
    private PF2eVec? PickTile(Vector2 screen)
    {
        var world = GetWorld3D();
        if (world == null) return null;

        Vector3 origin = _camera.ProjectRayOrigin(screen);
        Vector3 dir = _camera.ProjectRayNormal(screen);

        var query = PhysicsRayQueryParameters3D.Create(origin, origin + dir * RayLength);
        query.CollisionMask = TerrainCollisionMask | UnitCollisionMask;
        query.CollideWithAreas = true;
        var hit = world.DirectSpaceState.IntersectRay(query);
        // An empty dictionary is the miss result — indexing it would throw, so bail before reading.
        if (hit.Count > 0)
        {
            if (hit["collider"].AsGodotObject() is UnitPickArea unit)
                return OnBoard(unit.Tile);
            return OnBoard(GridSpace.WorldToGrid((Vector3)hit["position"] + dir * HitNudge));
        }

        if (!_terrain && GridSpace.TryRayToTile(_camera, screen, _gridWidth, _gridHeight, out var tile))
            return tile;
        return null;
    }

    private PF2eVec? OnBoard(PF2eVec cell)
        => cell.x < 0 || cell.y < 0 || cell.x >= _gridWidth || cell.y >= _gridHeight ? null : cell;
}
