using System;
using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Translates mouse input into grid coordinates for the 2.5D board. Every physics tick it casts the
/// cursor into the world and reports hover; left-click resolves its own position, and both a
/// stationary right-click and Esc (ui_cancel) cancel targeting. Pure input translation — no rules.
/// Middle-drag / wheel are left untouched so the <see cref="OrbitCameraRig"/> can consume them.
/// Right-drag also orbits (handled by the rig), so cancel only fires when the right button is
/// RELEASED after traveling less than <see cref="DragThresholdPixels"/> — a click, not a drag.
///
/// Picking intersects the visible billboard pixels and the terrain. Transparent sprite padding
/// does not steal a neighboring target. Mouse presses retain their own screen coordinates and are
/// resolved at the next physics step, even if no motion event preceded the press.
/// </summary>
public partial class GridInput3D : Node3D
{
    /// <summary>A tile was left-clicked.</summary>
    public event Action<PF2eVec>? TileClicked;

    /// <summary>The hovered tile changed. Null means the cursor left the board.</summary>
    public event Action<PF2eVec?>? TileHovered;

    /// <summary>Esc, or a stationary right-click, asked to cancel targeting.</summary>
    public event Action? Cancelled;

    /// <summary>Whether Esc has something to cancel. Null treats every Esc as a cancel.</summary>
    public Func<bool>? HasCancellable { get; set; }

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
    private readonly System.Collections.Generic.Queue<Vector2> _clicks = new();

    /// <summary>Idle until an encounter wires this node up: no camera means every per-tick cast
    /// would be a null check and nothing else.</summary>
    public override void _Ready() => SetPhysicsProcess(false);

    public void Setup(Camera3D camera, int gridWidth, int gridHeight, TerrainHeightMap heightMap)
    {
        _camera = camera;
        _gridWidth = gridWidth;
        _gridHeight = gridHeight;
        _terrain = heightMap.HasTerrain;
        _clicks.Clear();
        _lastHover = null;
        _pointer = GetViewport().GetMousePosition();
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
        if (!Equals(cell, _lastHover))
        {
            _lastHover = cell;
            TileHovered?.Invoke(cell);
        }
        while (_clicks.TryDequeue(out var click))
        {
            var clicked = PickTile(click);
            if (clicked.HasValue) TileClicked?.Invoke(clicked.Value);
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (_camera == null) return;

        // Esc (ui_cancel) cancels targeting, mirroring the stationary right-click cancel below.
        if (@event.IsActionPressed(Delve.UI.InputNames.UiCancel))
        {
            // Esc with nothing to cancel falls through to the pause menu.
            if (HasCancellable?.Invoke() == false) return;
            Cancelled?.Invoke();
            GetViewport().SetInputAsHandled();
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
            // Resolve the actual button position at the next safe physics step.
            _pointer = mb.Position;
            _clicks.Enqueue(mb.Position);
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
    /// The tile under a screen point: the nearest opaque unit pixel, else the
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
        query.CollisionMask = TerrainCollisionMask;
        query.CollideWithAreas = true;
        var hit = world.DirectSpaceState.IntersectRay(query);
        float terrainDistance = hit.Count > 0 ? origin.DistanceTo((Vector3)hit["position"]) : RayLength;
        float distance = RayLength;
        UnitPickArea? picked = null;
        foreach (var node in GetTree().GetNodesInGroup(UnitPickArea.PickGroup))
        {
            if (node is not UnitPickArea candidate || candidate.GetWorld3D() != world
                || (candidate.CollisionLayer & UnitCollisionMask) == 0) continue;
            if (!candidate.HitSprite(_camera, origin, dir, out float depth) || depth >= distance) continue;
            if (!candidate.PickThroughTerrain && depth >= terrainDistance) continue;
            distance = depth;
            picked = candidate;
        }
        if (picked != null) return OnBoard(picked.Tile);
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
