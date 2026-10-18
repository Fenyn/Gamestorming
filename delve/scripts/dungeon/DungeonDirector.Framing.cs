using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dungeon;

/// <summary>
/// How the camera shoots a room. Every room is fitted into the part of the screen the HUD leaves
/// clear, so its doorways never sit under the party cards or the floor plan. A first visit pushes in
/// along the trail and pulls back on arrival to reveal the room; an event glides to the thing it is
/// about and sets it beside the event panel.
/// </summary>
public partial class DungeonDirector
{
    /// <summary>Glide time when a room's framing changes without a crossing (an event closing).</summary>
    [Export] public double FramingSeconds { get; set; } = 0.35;

    /// <summary>Dolly at the end of the trail into an unvisited room: below 1 is closer.</summary>
    [Export] public float ArrivalPushIn { get; set; } = 0.8f;

    /// <summary>How long the camera takes to pull back and reveal an unvisited room.</summary>
    [Export] public double ArrivalPullSeconds { get; set; } = 0.9;

    /// <summary>Dolly while an event is open: a little closer to the thing it is about.</summary>
    [Export] public float EventPushIn { get; set; } = 0.85f;

    /// <summary>Glide time onto an event's focal prop.</summary>
    [Export] public double EventFocusSeconds { get; set; } = 0.5;

    private bool _eventFramed;

    /// <summary>Frames the current room: the pivot on its middle, every doorway and corner inside
    /// the HUD's clear view. With seconds, the zoom glides there from <paramref name="fromDistance"/>.</summary>
    private void Frame(double seconds = 0, float? fromDistance = null)
    {
        _camera.ProcessMode = ProcessModeEnum.Inherit;
        _camera.Camera.Current = true;
        _camera.FrameBoard(RoomCentre, CurrentView.Width, CurrentView.Width);
        FitRoom(seconds, fromDistance);
    }

    private void FitRoom(double seconds, float? fromDistance = null)
        => _camera.Fit(FramePoints(), _hud.ClearView(), RoomCentre, Instant ? 0 : seconds, fromDistance);

    /// <summary>The points a room shot keeps clear of the HUD: each doorway, the arrival mouth and
    /// the room's middle. The room's own edges may run under the HUD, as a close shot crops them.</summary>
    private List<Vector3> FramePoints()
    {
        var view = CurrentView;
        var points = Current.Doors.Select(d => view.DoorPosition(d.Side(Current.Id))).ToList();
        if (view.Arrival is { } arrival) points.Add(view.DoorPosition(arrival.Side));
        points.Add(RoomCentre);
        return points;
    }

    /// <summary>MYZ's "investigate" beat: the camera glides to the thing the event is about, pushes
    /// in a little, and sets it in the clear view right of the left-docked event panel.</summary>
    private void FrameEventScenery()
    {
        double seconds = Instant ? 0 : EventFocusSeconds;
        var focus = CurrentView.FocalPosition is { } focal ? focal with { Y = 0 } : RoomCentre;
        _camera.FocusOn(focus, (float)seconds, false);
        var clear = _hud.ClearView(_event.Margin + _event.CompactWidth);
        var view = GetViewport().GetVisibleRect();
        _camera.Compose((clear.GetCenter() - view.GetCenter()) / view.Size.Y, seconds);
        _camera.DollyTo(EventPushIn, seconds);
        _eventFramed = true;
    }

    /// <summary>Back to the room shot after an event.</summary>
    private void UnframeEvent()
    {
        if (!_eventFramed) return;
        _eventFramed = false;
        FitRoom(FramingSeconds);
        _camera.DollyTo(1f, Instant ? 0 : FramingSeconds);
    }
}
