using System.Collections.Generic;
using Godot;

namespace Delve.Dungeon;

/// <summary>A sign floats over each doorway of the current room while the party picks a door: the
/// floor plan's icon for the room beyond, so the way on reads in the scene and not only on the plan.</summary>
public partial class DungeonDirector
{
    [Export] public PackedScene? DoorSignScene { get; set; }

    /// <summary>Height of a sign over its threshold, under the door tooltip's anchor.</summary>
    [Export] public float DoorSignHeight { get; set; } = 2.1f;

    private readonly Dictionary<DoorSide, DoorSign> _signs = new();
    private DungeonRoomPrefab? _signRoom;

    /// <summary>The current room's signs, by doorway, for spikes.</summary>
    public IReadOnlyDictionary<DoorSide, DoorSign> DoorSigns => _signs;

    /// <summary>Signs show only while the party is choosing a door; they follow the plan's reveal.</summary>
    private void RefreshDoorSigns()
    {
        bool show = DoorSignScene != null && Phase == DungeonPhase.Doors;
        if (!show || !ReferenceEquals(_signRoom, CurrentView)) ClearDoorSigns();
        if (!show) return;
        _signRoom = CurrentView;
        foreach (var door in Current.Doors)
        {
            var side = door.Side(Current.Id);
            if (!_signs.TryGetValue(side, out var sign))
            {
                sign = DoorSignScene!.Instantiate<DoorSign>();
                CurrentView.AddChild(sign);
                sign.Position = CurrentView.DoorPosition(side) + Vector3.Up * DoorSignHeight;
                _signs[side] = sign;
            }
            var beyond = Floor.Rooms[door.Other(Current.Id)];
            sign.Show(FloorPlan.IconKey(Floor, State, beyond), beyond.Completed);
            sign.SetFocused(side == _focusedDoor);
        }
    }

    private void ClearDoorSigns()
    {
        foreach (var sign in _signs.Values)
            if (GodotObject.IsInstanceValid(sign)) sign.QueueFree();
        _signs.Clear();
        _signRoom = null;
    }

    private void FocusDoorSign(DoorSide? side)
    {
        foreach (var (each, sign) in _signs) sign.SetFocused(each == side);
    }
}
