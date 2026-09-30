using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Terrain;
using Godot;

namespace Delve.Dungeon;

/// <summary>The floor's way in: the entrance's outer mouth, the trail or stair beyond it, and the
/// party walking in from off the floor.</summary>
public partial class DungeonDirector
{
    /// <summary>Seconds between heroes setting off on the walk in.</summary>
    [Export] public double ArrivalStagger { get; set; } = 0.25;

    /// <summary>Metres between the two files of the party at the start of the walk in, and between
    /// its two ranks.</summary>
    [Export] public float ArrivalFileGap { get; set; } = 0.9f;
    [Export] public float ArrivalRankGap { get; set; } = 0.6f;

    /// <summary>Walking pace on the way in, slower than a crossing so the arrival reads.</summary>
    [Export] public double ArrivalSecondsPerTile { get; set; } = 0.12;

    /// <summary>Seconds the camera holds on the arrival mouth before it follows the party in.</summary>
    [Export] public double ArrivalCameraHold { get; set; } = 0.4;

    private Tween? _walkIn;
    private readonly List<(UnitVisual3D Token, Vector3 Final)> _walkInEnds = new();

    /// <summary>The arrival mouth a room is built with: only the entrance has one.</summary>
    private RoomArrival? ArrivalFor(DungeonRoom room, DungeonRoomPrefab prefab)
    {
        if (ComparisonMode || room.Id != Floor.EntranceId) return null;
        int trail = Scenery.ArrivalTrail != null ? Scenery.ArrivalTrailLength : 0;
        return new RoomArrival(Floor.ArrivalSide, Words.ArrivalProp, (prefab.Shell?.Margin ?? 0) + trail + 0.5f);
    }

    /// <summary>The trail beyond the entrance's rim, lit and shown with the entrance.</summary>
    private void BuildArrivalTrail()
    {
        var entrance = _rooms[Floor.EntranceId];
        if (Scenery.ArrivalTrail == null || entrance.Arrival is not { } arrival) return;
        int margin = entrance.Shell?.Margin ?? 0;
        var a = entrance.Position + entrance.DoorPosition(arrival.Side);
        var b = a + DungeonRoomPrefab.Outward(arrival.Side) * (2 * margin + 1 + Scenery.ArrivalTrailLength);
        var view = Scenery.ArrivalTrail.Instantiate<Node3D>();
        _world.AddChild(view);
        ((IPassage)view).Build(entrance, a, b);
        _corridors.Add((view, Floor.EntranceId, Floor.EntranceId));
    }

    /// <summary>The party walks in from off the floor, through the entrance's outer mouth, to where
    /// it stands. The floor's state is already settled; this only moves the tokens and the camera.
    /// Under a floor caption the party waits at the start until the caption clears.</summary>
    private async Task WalkIn()
    {
        FinishWalkIn();
        var view = CurrentView;
        if (Instant || view.Arrival is not { } arrival || _tokens.Count == 0) return;
        int epoch = _epoch;
        var outward = DungeonRoomPrefab.Outward(arrival.Side);
        var across = new Vector3(-outward.Z, 0, outward.X);
        var mouth = view.DoorPosition(arrival.Side);
        var inside = RoomGeneration.Inside(view.Width, arrival.Side);
        var paths = new List<List<Vector3>>();
        for (int i = 0; i < _tokens.Count; i++)
        {
            var token = _tokens[i];
            var final = token.Position;
            _walkInEnds.Add((token, final));
            token.Position = mouth + outward * (Scenery.ArrivalReach + i / 2 * ArrivalRankGap)
                + across * ((i % 2 - 0.5f) * ArrivalFileGap) + Vector3.Up * Scenery.ArrivalRise;
            token.Facing = new Vector2(-outward.X, -outward.Z);
            var path = new List<Vector3> { mouth, GridSpace.GridToWorld(inside, view.Heights) };
            path.AddRange(RoomGeneration.Route(view.Generated.Layout, inside, GridSpace.WorldToGrid(final)).Select(p => GridSpace.GridToWorld(p, view.Heights)));
            path.Add(final);
            paths.Add(path);
        }
        _camera.FocusOn(mouth, 0, false);
        while (_transition.Busy && epoch == _epoch && _walkInEnds.Count > 0 && IsInsideTree())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (epoch != _epoch || _walkInEnds.Count == 0 || !IsInsideTree()) return;

        _walkIn = CreateTween().SetParallel(true);
        double arrived = 0;
        for (int i = 0; i < _walkInEnds.Count; i++)
        {
            var token = _walkInEnds[i].Token;
            token.SetMoving(true);
            double end = QueueWalk(_walkIn, token, token.Position, paths[i], i * ArrivalStagger, ArrivalSecondsPerTile);
            _walkIn.TweenCallback(Callable.From(() => token.SetMoving(false))).SetDelay(end);
            arrived = System.Math.Max(arrived, end);
        }
        // The camera holds on the way in, then follows the party to the middle of the room.
        _walkIn.TweenCallback(Callable.From(() => _camera.FocusOn(RoomCentre, (float)(arrived - ArrivalCameraHold), false)))
            .SetDelay(ArrivalCameraHold);
        _walkIn.TweenCallback(Callable.From(() => _walkInEnds.Clear())).SetDelay(arrived);
    }

    /// <summary>Ends a walk in early, every hero where the walk would have left them.</summary>
    private void FinishWalkIn()
    {
        if (WalkingIn) _camera.FocusOn(RoomCentre, 0, false);
        _walkIn?.Kill();
        _walkIn = null;
        foreach (var (token, final) in _walkInEnds)
            if (GodotObject.IsInstanceValid(token))
            {
                token.Position = final;
                token.SetMoving(false);
            }
        _walkInEnds.Clear();
    }

    /// <summary>True from the floor's start until the party has walked in, for spikes.</summary>
    public bool WalkingIn => _walkInEnds.Count > 0;
}
