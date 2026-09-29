using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Terrain;
using Delve.UI;
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

    /// <summary>Rooms drawn right now, for spikes.</summary>
    public int VisibleRoomCount => _rooms.Values.Count(r => r.Visible);

    private void BuildCorridors()
    {
        foreach (var room in Floor.Rooms)
            foreach (var door in room.Doors.Where(d => d.A == room.Id))
            {
                var av = _rooms[door.A];
                var bv = _rooms[door.B];
                var a = av.Position + av.DoorPosition(door.Side(door.A));
                var b = bv.Position + bv.DoorPosition(door.Side(door.B));
                var view = Scenery.Passage!.Instantiate<Node3D>();
                _world.AddChild(view);
                ((IPassage)view).Build(av, a, b);
                _corridors.Add((view, door.A, door.B));
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
            token.UseExplorationMarkers();
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
        if (Delve.Run.CharacterPromotion.HasPending(State.Party) && DoorTips.NeedsPromotionsFirst(target))
        {
            // The click still does something: it opens the first hero who has a feat to choose.
            var waiting = State.Party.Living().First(c => Delve.Run.CharacterPromotion.For(c).PendingLevels(c) > 0);
            OpenMemberDetails(waiting.UniqueId);
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
                var setup = DungeonEncounters.Build(State, target, nextView, entry, DataManager.Instance!.ResolveCreature, campaign: Hosted, floorId: FloorId);
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
            int wardBefore = State.Wardstone.Ward;
            State.Wardstone.BurnNode();
            AnnounceCrossing(from.Id, target.Id, wardBefore);
            if (State.Wardstone.IsSpent)
            {
                End(false);
                return;
            }

            target.Discovered = true;
            RefreshVisibility();
            nextView.SetDoorsOpen(true, Instant);
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
                    var heading = new Vector2(position.X - last.X, position.Z - last.Z);
                    if (heading.LengthSquared() > 0.01f)
                        _travelTween.TweenCallback(Callable.From(() => token.Facing = heading.Normalized())).SetDelay(delay);
                    double time = Math.Max(0.015, last.DistanceTo(position) * TravelSecondsPerTile);
                    _travelTween.TweenProperty(token, "position", position, time).SetDelay(delay);
                    delay += time;
                    last = position;
                }

                duration = Math.Max(duration, delay);
            }

            LastCrossingSeconds = duration;
            _travelTween.TweenProperty(_camera, "global_position", offset + new Vector3(nextView.Width / 2f, 0, nextView.Width / 2f), Math.Max(0.1, duration)).SetTrans(Tween.TransitionType.Sine);
            if (Instant) SkipBeat();
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
                _hud.ShowNotice("Room preparation failed. Try another door.");
            }
        }
    }

    public override void _Process(double delta)
    {
        if (State == null)
            return;
        // The live camera belongs to the explore rig, the standalone combat scene, or the host's.
        var camera = GetViewport().GetCamera3D();
        if (camera == null)
            return;
        foreach (var room in _rooms.Values)
            if (room.Visible)
                room.Cutaway(camera);
        foreach (var (view, _, _) in _corridors)
            if (view.Visible && view is IPassage passage)
                passage.Cutaway(camera);
        AnchorPartyMenu();
    }

    private Vector2? _doorPress;
    private Vector2? _doorPointer;
    private Vector2? _pendingDoorClick;
    public override void _Input(InputEvent e)
    {
        if (e is InputEventMouse mouse) _doorPointer = mouse.Position;
        if (e is InputEventMouseMotion) _pointerMoved = true;
    }

    public override void _UnhandledInput(InputEvent e)
    {
        if (IsVisibleInTree() && Phase is DungeonPhase.Travel or DungeonPhase.Transition
            && (e.IsActionPressed(InputNames.Confirm) || e is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }))
        {
            SkipBeat();
            GetViewport().SetInputAsHandled();
            return;
        }
        if (!IsVisibleInTree() || _details.Visible || Phase != DungeonPhase.Doors) return;
        if (HandleDoorKeys(e)) { GetViewport().SetInputAsHandled(); return; }
        if (e is not InputEventMouseButton { ButtonIndex: MouseButton.Left } mouse)
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
            _focusedDoor = null;
            _hud.HideDoorTip();
            if (State != null) AnnounceDoorFocus(null);
            return;
        }
        var pointer = _doorPointer ?? GetViewport().GetMousePosition();
        bool overUi = GetViewport().GuiGetHoveredControl() != null;
        var memberHover = overUi ? null : PickPartyMember(pointer);
        SetHoveredPartyMember(memberHover);
        var hovered = overUi || memberHover != null ? null : PickDoor(pointer);
        if (hovered != null && _pointerMoved) _focusedDoor = null;
        _pointerMoved = false;
        ShowDoor(_focusedDoor ?? hovered);
        if (click is { } screen)
        {
            if (PickPartyMember(screen) is { } member) OpenCharacterDetails(member);
            else if (PickDoor(screen) is { } chosen) _ = Travel(chosen);
        }
    }

    /// <summary>Finish the walk or the camera return at once; the code after it runs as normal.</summary>
    public void SkipBeat()
    {
        const double past = 3600;
        if (_travelTween != null && GodotObject.IsInstanceValid(_travelTween) && _travelTween.IsRunning()) _travelTween.CustomStep(past);
        if (_returnTween != null && GodotObject.IsInstanceValid(_returnTween) && _returnTween.IsRunning()) _returnTween.CustomStep(past);
    }

    /// <summary>Length of the last crossing's walk before any skip, in seconds.</summary>
    public double LastCrossingSeconds { get; private set; }

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
