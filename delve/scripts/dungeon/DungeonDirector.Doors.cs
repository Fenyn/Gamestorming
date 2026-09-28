using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;

/// <summary>Doorway hover and keyboard focus: the tooltip follows whichever door is shown.</summary>
public partial class DungeonDirector
{
    /// <summary>Height above the threshold where the door tooltip anchors.</summary>
    [Export] public float DoorTipHeight { get; set; } = 2.7f;

    /// <summary>Screen offset of the door tooltip from its anchor, so it never covers the doorway.</summary>
    [Export] public Vector2 DoorTipOffset { get; set; } = new(32, 0);

    private DoorSide? _focusedDoor;
    private bool _pointerMoved;

    public DoorSide? FocusedDoor => _focusedDoor;

    private void ShowDoor(DoorSide? side)
    {
        CurrentView.SetHoveredDoor(side);
        AnnounceDoorFocus(side);
        if (side is not { } shown) { _hud.HideDoorTip(); return; }
        var door = Current.Doors.First(d => d.Side(Current.Id) == shown);
        var destination = Floor.Rooms[door.Other(Current.Id)];
        var pending = State.Party.Living().Where(c => CharacterPromotion.For(c).PendingLevels(c) > 0).Select(c => c.Name);
        var camera = _camera.Camera;
        var world = CurrentView.ToGlobal(CurrentView.DoorPosition(shown) + Vector3.Up * DoorTipHeight);
        if (camera.IsPositionBehind(world)) { _hud.HideDoorTip(); return; }
        _hud.ShowDoorTip(DoorTips.For(destination, State.Wardstone, pending), camera.UnprojectPosition(world) + DoorTipOffset);
    }

    /// <summary>Tab cycles the doors, an arrow picks the door that way on screen, Enter travels.</summary>
    private bool HandleDoorKeys(InputEvent e)
    {
        if (e.IsActionPressed(InputNames.UiFocusNext))
            return CycleDoor(1);
        if (e.IsActionPressed(InputNames.UiFocusPrev))
            return CycleDoor(-1);
        if (e.IsActionPressed(InputNames.UiRight)) return StepDoor(Vector2.Right);
        if (e.IsActionPressed(InputNames.UiLeft)) return StepDoor(Vector2.Left);
        if (e.IsActionPressed(InputNames.UiUp)) return StepDoor(Vector2.Up);
        if (e.IsActionPressed(InputNames.UiDown)) return StepDoor(Vector2.Down);
        if (e.IsActionPressed(InputNames.Confirm) && _focusedDoor is { } side)
        {
            _ = Travel(side);
            return true;
        }
        return false;
    }

    /// <summary>Doors whose screen direction from the focus is within this cosine of the pressed
    /// arrow count as lying that way (0.5 = within 60 degrees).</summary>
    [Export] public float DoorArrowCone { get; set; } = 0.5f;

    /// <summary>Focus the nearest door lying in <paramref name="direction"/> on screen, measured from
    /// the focused door, or from the room's centre when none is focused.</summary>
    public bool StepDoor(Vector2 direction)
    {
        var camera = _camera.Camera;
        Vector2 Screen(Vector3 local) => camera.UnprojectPosition(CurrentView.ToGlobal(local));
        var from = _focusedDoor is { } focused ? Screen(CurrentView.DoorPosition(focused))
            : Screen(new Vector3(CurrentView.Width / 2f, 0, CurrentView.Width / 2f));
        DoorSide? best = null;
        float bestDistance = float.MaxValue;
        foreach (var side in Current.Doors.Select(d => d.Side(Current.Id)))
        {
            if (side == _focusedDoor) continue;
            var offset = Screen(CurrentView.DoorPosition(side)) - from;
            if (offset.Length() < 1 || offset.Normalized().Dot(direction) < DoorArrowCone) continue;
            if (offset.Length() < bestDistance) { bestDistance = offset.Length(); best = side; }
        }
        if (best == null) return _focusedDoor != null;
        _focusedDoor = best;
        _pointerMoved = false;
        ShowDoor(_focusedDoor);
        return true;
    }

    public bool CycleDoor(int step)
    {
        var sides = Current.Doors.Select(d => d.Side(Current.Id)).OrderBy(s => s).ToList();
        if (sides.Count == 0) return false;
        int index = _focusedDoor is { } focused ? sides.IndexOf(focused) : -1;
        index = index < 0 ? (step > 0 ? 0 : sides.Count - 1) : ((index + step) % sides.Count + sides.Count) % sides.Count;
        _focusedDoor = sides[index];
        _pointerMoved = false;
        ShowDoor(_focusedDoor);
        return true;
    }
}
