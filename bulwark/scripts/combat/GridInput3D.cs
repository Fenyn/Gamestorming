using System;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Translates mouse input into grid coordinates for the 2.5D board. Per-frame it ray-casts the
/// cursor onto the floor plane and reports hover; left-click forwards a tile click and both a
/// stationary right-click and Esc (ui_cancel) cancel targeting. Pure input translation — no rules.
/// Middle-drag / wheel are left untouched so
/// the <see cref="OrbitCameraRig"/> can consume them. Right-drag also orbits (handled by the rig),
/// so cancel only fires when the right button is RELEASED after traveling less than
/// <see cref="DragThresholdPixels"/> — a click, not a drag.
/// </summary>
public partial class GridInput3D : Node3D
{
    /// <summary>The rig owns the click-vs-drag gesture threshold; CombatScene pushes the rig's
    /// live value in at Setup so the two stay in agreement.</summary>
    [Export] public float DragThresholdPixels { get; set; } = OrbitCameraRig.DefaultDragThresholdPixels;

    private Camera3D _camera = null!;
    private int _gridWidth;
    private int _gridHeight;
    private Action<PF2eVec>? _onClick;
    private Action<PF2eVec?>? _onHover;
    private Action? _onCancel;

    private PF2eVec? _lastHover;
    private Vector2 _rightPressPos;

    public void Setup(Camera3D camera, int gridWidth, int gridHeight,
        Action<PF2eVec> onClick, Action<PF2eVec?> onHover, Action onCancel)
    {
        _camera = camera;
        _gridWidth = gridWidth;
        _gridHeight = gridHeight;
        _onClick = onClick;
        _onHover = onHover;
        _onCancel = onCancel;
    }

    public override void _Process(double delta)
    {
        if (_camera == null) return;

        var screen = GetViewport().GetMousePosition();
        PF2eVec? cell = GridSpace.TryRayToTile(_camera, screen, _gridWidth, _gridHeight, out var tile) ? tile : null;

        if (!Equals(cell, _lastHover))
        {
            _lastHover = cell;
            _onHover?.Invoke(cell);
        }
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
            var screen = mb.Position;
            if (GridSpace.TryRayToTile(_camera, screen, _gridWidth, _gridHeight, out var tile))
                _onClick?.Invoke(tile);
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
}
