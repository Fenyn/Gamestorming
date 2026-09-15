using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dungeon;
public partial class DungeonDirector
{
    private void Rebase()
    {
        _world.Position = -CurrentView.Position;
        RefreshVisibility();
    }

    private void Frame()
    {
        _camera.ProcessMode = ProcessModeEnum.Inherit;
        _camera.Camera.Current = true;
        _camera.FrameBoard(new(CurrentView.Width / 2f, 0, CurrentView.Width / 2f), CurrentView.Width, CurrentView.Width);
    }

    private void RefreshVisibility()
    {
        foreach (var room in Floor.Rooms)
            _rooms[room.Id].Visible = room.Discovered;
        foreach (var(view, a, b)in _corridors)
            view.Visible = Floor.Rooms[a].Discovered && Floor.Rooms[b].Discovered;
    }

    private void BuildCorridors()
    {
        foreach (var room in Floor.Rooms)
            foreach (var door in room.Doors.Where(d => d.A == room.Id))
            {
                var av = _rooms[door.A];
                var bv = _rooms[door.B];
                var a = av.Position + av.DoorPosition(door.Side(door.A));
                var b = bv.Position + bv.DoorPosition(door.Side(door.B));
                var prop = new DungeonPassage { Palette = av.Palette };
                _world.AddChild(prop);
                prop.Build(a, b);
                _corridors.Add((prop, door.A, door.B));
            }
    }

    private void SpawnTravelParty(bool useCombatPositions = false)
    {
        SetHoveredPartyMember(null);
        Clear(_partyLayer);
        _tokens.Clear();
        _partyLayer.Visible = true;
        int i = 0, n = CurrentView.Width;
        foreach (var member in State.Party.Living())
        {
            var token = UnitVisual3D.Spawn(UnitPrefab, member);
            _partyLayer.AddChild(token);
            token.GetNode<UnitPickArea>("%PickArea").SetPickable(true);
            var tile = useCombatPositions ? member.GridPosition : new PF2eVec(n / 2 + i % 2, n / 2 + i / 2);
            token.Position = GridSpace.GridToWorld(tile, CurrentView.Heights);
            _tokens.Add(token);
            i++;
        }
    }

    public async Task Travel(DoorSide side)
    {
        if (_details.Visible || Phase != DungeonPhase.Doors)
            return;
        var from = Current;
        var door = from.Doors.FirstOrDefault(d => d.Side(from.Id) == side);
        if (door == null)
            return;
        int epoch = _epoch;
        var target = Floor.Rooms[door.Other(from.Id)];
        if (!target.Completed && Delve.Run.CharacterPromotion.HasPending(State.Party)
            && DungeonFloor.Kind(target.Family) is Delve.Run.NodeKind.Combat or Delve.Run.NodeKind.Elite or Delve.Run.NodeKind.Boss)
        {
            _hud.ShowNotice("Promotion available. Click each character to open their sheet and confirm before the next encounter.");
            return;
        }
        var oldView = CurrentView;
        var nextView = _rooms[target.Id];
        var entry = door.Side(target.Id);
        Phase = DungeonPhase.Travel;
        RefreshHud();
        var history = State.RecentTemplates.ToArray();
        try
        {
            if (!target.Completed && DungeonFloor.Kind(target.Family)is Delve.Run.NodeKind.Combat or Delve.Run.NodeKind.Elite or Delve.Run.NodeKind.Boss)
            {
                var setup = DungeonEncounters.Build(State, target, nextView, entry, DataManager.Instance!.ResolveCreature, campaign: Hosted);
                if (setup == null)
                    throw new InvalidOperationException("Unable to prepare encounter.");
                _encounters[target.Id] = setup;
            }

            var offset = nextView.Position - oldView.Position;
            var exitTile = RoomGeneration.Inside(oldView.Width, side);
            var endTile = RoomGeneration.Inside(nextView.Width, entry);
            var paths = new List<List<Vector3>>();
            for (int i = 0; i < _tokens.Count; i++)
            {
                var path = RoomGeneration.Route(oldView.Generated.Layout, GridSpace.WorldToGrid(_tokens[i].Position), exitTile).Select(p => GridSpace.GridToWorld(p, oldView.Heights)).ToList();
                path.Add(oldView.DoorPosition(side));
                path.Add(offset + nextView.DoorPosition(entry));
                path.Add(offset + GridSpace.GridToWorld(endTile, nextView.Heights));
                var final = new PF2eVec(nextView.Width / 2 + i % 2, nextView.Width / 2 + i / 2);
                path.AddRange(RoomGeneration.Route(nextView.Generated.Layout, endTile, final).Select(p => offset + GridSpace.GridToWorld(p, nextView.Heights)));
                paths.Add(path);
            }

            // All failure-prone preparation precedes the one crossing charge.
            State.Wardstone.BurnNode();
            if (State.Wardstone.IsSpent)
            {
                End(false);
                return;
            }

            target.Discovered = true;
            RefreshVisibility();
            nextView.SetDoorsOpen(true);
            _camera.FocusOn(_camera.GlobalPosition, 0, true);
            _camera.ProcessMode = ProcessModeEnum.Disabled;
            _travelTween = CreateTween().SetParallel(true);
            double duration = 0;
            for (int i = 0; i < _tokens.Count; i++)
            {
                var token = _tokens[i];
                token.SetMoving(true);
                double delay = i * 0.08;
                var last = token.Position;
                foreach (var position in paths[i])
                {
                    double time = Math.Max(0.015, last.DistanceTo(position) * TravelSecondsPerTile);
                    _travelTween.TweenProperty(token, "position", position, time).SetDelay(delay);
                    delay += time;
                    last = position;
                }

                duration = Math.Max(duration, delay);
            }

            _travelTween.TweenProperty(_camera, "global_position", offset + new Vector3(nextView.Width / 2f, 0, nextView.Width / 2f), Math.Max(0.1, duration)).SetTrans(Tween.TransitionType.Sine);
            while (epoch == _epoch && IsInsideTree() && GodotObject.IsInstanceValid(_travelTween) && _travelTween.IsRunning())
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (epoch != _epoch || !IsInsideTree())
                return;
            foreach (var token in _tokens)
            {
                token.SetMoving(false);
                token.Position -= offset;
            }

            _camera.GlobalPosition -= offset;
            if (!State.Advance(target.Id))
                throw new InvalidOperationException("Dungeon connection is not in navigation graph.");
            Rebase();
            Frame();
            Enter(entry);
        }
        catch (Exception e)
        {
            GD.PushError($"[Dungeon] Travel failed: {e}");
            State.RecentTemplates.Clear();
            State.RecentTemplates.AddRange(history);
            if (epoch == _epoch)
            {
                Frame();
                SpawnTravelParty();
                ShowDoors();
                _hud.ShowNotice("Room preparation failed. Try another door or restart this seed.");
            }
        }
    }

    public override void _Process(double delta)
    {
        if (State == null)
            return;
        var camera = Phase is DungeonPhase.Combat or DungeonPhase.Results ? _combat.ActiveCamera : _camera.Camera;
        foreach (var room in _rooms.Values)
            if (room.Visible)
                room.Cutaway(camera);
        foreach (var (view, _, _) in _corridors)
            if (view.Visible && view is DungeonPassage passage)
                passage.Cutaway(camera);
    }

    private Vector2? _doorPress;
    private Vector2? _doorPointer;
    private Vector2? _pendingDoorClick;
    public override void _Input(InputEvent e)
    {
        if (e is InputEventMouse mouse) _doorPointer = mouse.Position;
    }

    public override void _UnhandledInput(InputEvent e)
    {
        if (!IsVisibleInTree() || _details.Visible || Phase != DungeonPhase.Doors || e is not InputEventMouseButton { ButtonIndex: MouseButton.Left } mouse)
            return;
        if (mouse.Pressed)
        {
            _doorPress = mouse.Position;
            return;
        }

        var press = _doorPress;
        _doorPress = null;
        if (press == null || mouse.Position.DistanceTo(press.Value) > 8)
            return;
        _pendingDoorClick = mouse.Position;
        GetViewport().SetInputAsHandled();
    }

    public override void _PhysicsProcess(double delta)
    {
        var click = _pendingDoorClick;
        _pendingDoorClick = null;
        if (!IsVisibleInTree() || _details.Visible || Phase != DungeonPhase.Doors || State == null)
        {
            SetHoveredPartyMember(null);
            return;
        }
        var pointer = _doorPointer ?? GetViewport().GetMousePosition();
        bool overUi = GetViewport().GuiGetHoveredControl() != null;
        var memberHover = overUi ? null : PickPartyMember(pointer);
        SetHoveredPartyMember(memberHover);
        var hovered = overUi || memberHover != null ? null : PickDoor(pointer);
        string hint = "";
        if (hovered is { } side)
        {
            var door = Current.Doors.First(d => d.Side(Current.Id) == side);
            var destination = Floor.Rooms[door.Other(Current.Id)];
            hint = $"{(destination.Completed ? "Cleared room" : "Unexplored")}\nClick to enter - {State.Wardstone.Rules.NodeBurn} ward";
        }
        CurrentView.SetHoveredDoor(hovered, hint);
        if (click is { } screen)
        {
            if (PickPartyMember(screen) is { } member) OpenCharacterDetails(member);
            else if (PickDoor(screen) is { } chosen) _ = Travel(chosen);
        }
    }

    private DoorSide? PickDoor(Vector2 screen)
    {
        var camera = _camera.Camera;
        var start = camera.ProjectRayOrigin(screen);
        var query = PhysicsRayQueryParameters3D.Create(start, start + camera.ProjectRayNormal(screen) * 300, 4);
        query.CollideWithAreas = true;
        var hit = GetWorld3D().DirectSpaceState.IntersectRay(query);
        if (hit.Count == 0 || hit["collider"].AsGodotObject() is not Area3D area || !CurrentView.IsAncestorOf(area))
            return null;
        return (DoorSide)(int)area.GetMeta("door_side");
    }
}
