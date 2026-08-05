using System;
using Bulwark.Combat.Map;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Translates mouse input into grid coordinates for the 2.5D board. Per-frame it ray-casts the
/// cursor onto the board and reports hover; left-click forwards a tile click and both a
/// stationary right-click and Esc (ui_cancel) cancel targeting. Pure input translation — no rules.
/// Middle-drag / wheel are left untouched so
/// the <see cref="OrbitCameraRig"/> can consume them. Right-drag also orbits (handled by the rig),
/// so cancel only fires when the right button is RELEASED after traveling less than
/// <see cref="DragThresholdPixels"/> — a click, not a drag.
///
/// Two picking modes, chosen once per encounter by <see cref="Setup"/>:
/// <list type="bullet">
/// <item><b>Flat</b> (no terrain) — analytic intersection with the y = 0 plane in <c>_Process</c>, and
/// the click resolves its own ray from the event position. Unchanged, and physics processing is
/// switched OFF so the frame does exactly what it always did.</item>
/// <item><b>Terrain</b> — a physics ray against the terrain trimesh. The cast is confined to
/// <c>_PhysicsProcess</c>: touching <c>DirectSpaceState</c> outside the physics step risks a locked
/// space, and the first frame's collider is not queryable yet. <c>_Process</c> only caches the pointer
/// position; clicks consume the tile the last cast published, so hover and click can never disagree
/// (the cost is that hover resolves one physics tick late, which is imperceptible).</item>
/// </list>
/// </summary>
public partial class GridInput3D : Node3D
{
    /// <summary>The rig owns the click-vs-drag gesture threshold; CombatScene pushes the rig's
    /// live value in at Setup so the two stay in agreement.</summary>
    [Export] public float DragThresholdPixels { get; set; } = OrbitCameraRig.DefaultDragThresholdPixels;

    /// <summary>How far a picking ray travels. Well past the far side of any board at max zoom.</summary>
    private const float RayLength = 1000f;

    /// <summary>
    /// Distance to advance the hit point ALONG the ray before flooring it to a tile. A ray that lands
    /// exactly on a cliff face sits on the boundary plane between two tile columns; nudging it forward
    /// by a hair resolves it into the column that was actually struck rather than the one in front of it.
    /// </summary>
    private const float HitNudge = 0.001f;

    private Camera3D _camera = null!;
    private int _gridWidth;
    private int _gridHeight;
    private Action<PF2eVec>? _onClick;
    private Action<PF2eVec?>? _onHover;
    private Action? _onCancel;

    private PF2eVec? _lastHover;
    private Vector2 _rightPressPos;

    private bool _terrain;
    private Vector2 _pointer;

    public void Setup(Camera3D camera, int gridWidth, int gridHeight,
        Action<PF2eVec> onClick, Action<PF2eVec?> onHover, Action onCancel,
        TerrainHeightMap heightMap)
    {
        _camera = camera;
        _gridWidth = gridWidth;
        _gridHeight = gridHeight;
        _onClick = onClick;
        _onHover = onHover;
        _onCancel = onCancel;
        _terrain = heightMap.HasTerrain;
        // A flat board must not merely skip the raycast, it must not tick physics at all: leaving the
        // callback enabled would add a per-frame call the flat path never had.
        SetPhysicsProcess(_terrain);
    }

    public override void _Process(double delta)
    {
        if (_camera == null) return;

        var screen = GetViewport().GetMousePosition();
        if (_terrain)
        {
            // Cache only. The cast itself belongs to the physics step (see the type doc).
            _pointer = screen;
            return;
        }

        PF2eVec? cell = GridSpace.TryRayToTile(_camera, screen, _gridWidth, _gridHeight, out var tile) ? tile : null;

        if (!Equals(cell, _lastHover))
        {
            _lastHover = cell;
            _onHover?.Invoke(cell);
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!_terrain || _camera == null) return;

        PF2eVec? cell = RaycastTile(_pointer);
        if (Equals(cell, _lastHover)) return;

        _lastHover = cell;
        _onHover?.Invoke(cell);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (_camera == null) return;

        // Esc (ui_cancel) cancels targeting, mirroring the stationary right-click cancel below.
        if (@event.IsActionPressed("ui_cancel"))
        {
            _onCancel?.Invoke();
            return;
        }

        if (@event is not InputEventMouseButton mb) return;

        if (mb.Pressed && mb.ButtonIndex == MouseButton.Left)
        {
            if (_terrain)
            {
                // Consume the published hover rather than casting here: input runs outside the physics
                // step, and re-casting would also risk a click landing on a different tile than the one
                // the player saw highlighted.
                if (_lastHover.HasValue) _onClick?.Invoke(_lastHover.Value);
            }
            else
            {
                var screen = mb.Position;
                if (GridSpace.TryRayToTile(_camera, screen, _gridWidth, _gridHeight, out var tile))
                    _onClick?.Invoke(tile);
            }
        }
        else if (mb.ButtonIndex == MouseButton.Right)
        {
            // Right-drag orbits the camera (OrbitCameraRig); only a stationary right CLICK cancels.
            if (mb.Pressed)
                _rightPressPos = mb.Position;
            else if (mb.Position.DistanceTo(_rightPressPos) <= DragThresholdPixels)
                _onCancel?.Invoke();
        }
    }

    /// <summary>
    /// Physics ray from the cursor onto the terrain collider, floored to a grid tile. Null when the ray
    /// misses the terrain entirely or lands off the board. Must only be called from the physics step.
    /// </summary>
    private PF2eVec? RaycastTile(Vector2 screen)
    {
        var world = GetWorld3D();
        if (world == null) return null;

        Vector3 origin = _camera.ProjectRayOrigin(screen);
        Vector3 dir = _camera.ProjectRayNormal(screen);

        var query = PhysicsRayQueryParameters3D.Create(origin, origin + dir * RayLength);
        query.CollisionMask = Map.MapView3D.TerrainCollisionLayer;
        var hit = world.DirectSpaceState.IntersectRay(query);
        // An empty dictionary is the miss result — indexing it would throw, so bail before reading.
        if (hit.Count == 0) return null;

        Vector3 point = (Vector3)hit["position"] + dir * HitNudge;
        var cell = GridSpace.WorldToGrid(point);
        if (cell.x < 0 || cell.y < 0 || cell.x >= _gridWidth || cell.y >= _gridHeight) return null;
        return cell;
    }
}
