using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    /// <summary>The scenery decides which rooms render and how bright: the current room, visited rooms and
    /// unvisited neighbours each have their own brightness. The floor plan carries the overview, so
    /// the renderer draws a few rooms instead of the whole floor.</summary>
    private void RefreshVisibility()
    {
        int here = Current.Id;
        bool Near(DungeonRoom room) => room.Id == here || room.Doors.Any(d => d.Other(room.Id) == here);
        var lights = new Dictionary<int, float>();
        foreach (var room in Floor.Rooms)
        {
            bool shown = room.Discovered ? Near(room) || Scenery.ShowExplored : Near(room) && Scenery.ShowUnexplored;
            _rooms[room.Id].Visible = shown;
            lights[room.Id] = room.Id == here ? Scenery.CurrentLight : room.Discovered ? Scenery.ExploredLight : Scenery.UnexploredLight;
            var shell = _rooms[room.Id].Shell!;
            FadeRoom(_rooms[room.Id], lights[room.Id], _rooms[room.Id].SetLight);
            if (shown) shell.Focus(new Aabb(Vector3.Down * FocusDepth, new Vector3(CurrentView.Width, FocusHeight, CurrentView.Width)));
        }
        foreach (var (view, a, b) in _corridors)
        {
            view.Visible = _rooms[a].Visible && _rooms[b].Visible;
            FadeRoom(view, Mathf.Max(lights[a], lights[b]), ((IPassage)view).SetLight);
            if (view.Visible) ((IPassage)view).Focus(new Aabb(Vector3.Down * FocusDepth, new Vector3(CurrentView.Width, FocusHeight, CurrentView.Width)));
        }
    }

    /// <summary>A room's fog-of-war brightness target, for spikes.</summary>
    public float RoomLightOf(int id) => _roomLight.TryGetValue(_rooms[id], out float light) ? light : 1f;

    public bool RoomShown(int id) => _rooms[id].Visible;

    /// <summary>World box the tree fade protects in the current room: the ground up to a tall
    /// unit on the highest hill.</summary>
    [Export] public float FocusHeight { get; set; } = 5f;
    [Export] public float FocusDepth { get; set; } = 0.5f;

    private readonly Dictionary<Node3D, float> _roomLight = new();
    private readonly Dictionary<Node3D, Tween> _roomFade = new();

    /// <summary>Ease a room or passage to its fog-of-war brightness. Hidden ones snap.</summary>
    private void FadeRoom(Node3D view, float light, Action<float> apply)
    {
        float from = _roomLight.TryGetValue(view, out float current) ? current : 1f;
        if (Mathf.IsEqualApprox(from, light)) return;
        _roomLight[view] = light;
        if (_roomFade.Remove(view, out var running)) running.Kill();
        if (!view.Visible || Instant || Scenery.LightSeconds <= 0)
        {
            apply(light);
            return;
        }
        _roomFade[view] = CreateTween();
        _roomFade[view].TweenMethod(Callable.From(apply), from, light, Scenery.LightSeconds);
    }
}
