using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;

/// <summary>Exploration beats that presentation components subscribe to. Ward changes come from
/// <see cref="Delve.Run.Wardstone.Changed"/> on the run state.</summary>
public partial class DungeonDirector
{
    /// <summary>The party arrives in a room: the room, the side it entered from, and whether this is
    /// the first arrival on this floor.</summary>
    public event Action<DungeonRoom, DoorSide, bool>? RoomEntered;

    /// <summary>The keyboard or pointer focus moved to another door, or to none.</summary>
    public event Action<DoorSide?>? DoorFocused;

    /// <summary>A crossing was paid for: from room, to room, ward before, ward after.</summary>
    public event Action<int, int, int, int>? CrossingStarted;

    /// <summary>A room finished: its fight was won, its event closed, or its night passed.</summary>
    public event Action<DungeonRoom>? RoomCompleted;

    private readonly HashSet<int> _entered = new();
    private DoorSide? _announcedDoor;

    /// <summary>Beats the director's own HUD shows. Wired once from _Ready.</summary>
    private void WirePresentation()
    {
        RoomEntered += (_, entry, first) =>
        {
            FaceParty(RoomCentre - CurrentView.DoorPosition(entry));
            if (first) _fx.RoomArrived(CurrentView, CurrentView.DoorPosition(entry));
        };
        RoomCompleted += _ =>
        {
            var lamps = CurrentView.LampPositions;
            _fx.RoomCleared(CurrentView, lamps.Count > 0 ? lamps : new[] { RoomCentre });
        };
        // The party turns toward the doorway the player is considering, as followers do in Octopath.
        DoorFocused += side =>
        {
            _hud.Plan.FocusedRoom = side is { } s ? Current.Doors.First(d => d.Side(Current.Id) == s).Other(Current.Id) : null;
            if (side is not { } shown) return;
            foreach (var token in _tokens)
                token.Facing = Flat(CurrentView.DoorPosition(shown) - token.Position);
        };
        // A neighbouring room on the plan is a doorway too: hovering it previews the door, a click travels.
        _hud.Plan.CellPressed += id =>
        {
            var door = Current.Doors.FirstOrDefault(d => d.Other(Current.Id) == id);
            if (door != null) _ = Travel(door.Side(Current.Id));
        };
        _hud.Plan.CellHovered += id =>
        {
            if (Phase != DungeonPhase.Doors) return;
            var door = id is { } room ? Current.Doors.FirstOrDefault(d => d.Other(Current.Id) == room) : null;
            _focusedDoor = door?.Side(Current.Id);
            _pointerMoved = false;
            ShowDoor(_focusedDoor);
        };
    }

    private void FaceParty(Vector3 direction)
    {
        foreach (var token in _tokens) token.Facing = Flat(direction);
    }

    private static Vector2 Flat(Vector3 v) => new Vector2(v.X, v.Z).Normalized();

    private Vector3 RoomCentre => new(CurrentView.Width / 2f, 0, CurrentView.Width / 2f);

    /// <summary>Opens the current room's shutters; the first opening throws dust at each doorway.</summary>
    private void OpenShutters()
    {
        bool opening = !CurrentView.DoorsOpen;
        CurrentView.SetDoorsOpen(true, Instant);
        if (opening)
            _fx.ShuttersOpened(CurrentView, Current.Doors.Select(d => CurrentView.DoorPosition(d.Side(Current.Id))).ToArray(),
                CurrentView.DoorShutterSeconds);
    }

    private Wardstone? _wardSource;

    /// <summary>Follows the run's Wardstone, so every ward change (crossing, rest, room, boss) plays
    /// the ward beat. Called when a floor begins; detaches from the previous run's stone.</summary>
    private void WatchWard()
    {
        if (ReferenceEquals(_wardSource, State.Wardstone)) return;
        if (_wardSource != null) _wardSource.Changed -= OnWardChanged;
        _wardSource = State.Wardstone;
        _wardSource.Changed += OnWardChanged;
    }

    private void OnWardChanged(int before, int after) => _fx.WardChanged();

    private void UnwatchWard()
    {
        if (_wardSource != null) _wardSource.Changed -= OnWardChanged;
        _wardSource = null;
    }

    private void CompleteRoom()
    {
        if (Current.Completed)
            return;
        Current.Resolved = true;
        Current.Completed = true;
        CurrentView.SetResolved();
        RoomCompleted?.Invoke(Current);
    }

    /// <summary>Raises <see cref="RoomEntered"/> and returns whether this is the first arrival.</summary>
    private bool AnnounceEntry(DoorSide entry)
    {
        bool first = _entered.Add(Current.Id);
        RoomEntered?.Invoke(Current, entry, first);
        return first;
    }

    private void AnnounceDoorFocus(DoorSide? side)
    {
        if (side == _announcedDoor)
            return;
        _announcedDoor = side;
        DoorFocused?.Invoke(side);
    }

    private void AnnounceCrossing(int from, int to, int wardBefore) =>
        CrossingStarted?.Invoke(from, to, wardBefore, State.Wardstone.Ward);

    private void ResetAnnouncements()
    {
        _entered.Clear();
        _announcedDoor = null;
    }
}
