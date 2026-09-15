using System.Collections.Generic;
using System.Linq;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

public partial class CombatScene
{
    private HudRoot _tacticalHud = null!;
    private SquadPanel _squad = null!;
    private DestinationPreview _destination = null!;
    private readonly Dictionary<int, UnitVisual3D> _tacticalUnits = new();
    private IReadOnlyList<UnitView> _tacticalOrder = System.Array.Empty<UnitView>();
    private int? _focusedMember;
    private PF2eVec? _stagedTile;
    private PlayerTurnMode _stagedMode;
    private bool _tacticalFinished;
    private ICharacter[] _partyMembers = System.Array.Empty<ICharacter>();
    private double _squadRefresh;

    private void BuildTacticalPresentation()
    {
        _tacticalHud = GetNode<HudRoot>("%HudRoot");
        _squad = GetNode<SquadPanel>("%SquadPanel");
        _destination = GetNode<DestinationPreview>("%DestinationPreview");
        _squad.FocusRequested += FocusPartyMember;
        _squad.OverviewRequested += () => { if (!_tacticalHud.ModalActive && !_tacticalFinished) _cameraRig.ToggleOverview(); };
        _squad.StagingChanged += () => ClearStagedOrder();
        _squad.ConfirmRequested += ConfirmStagedOrder;
    }

    public void FocusPartyMember(int id)
    {
        if (_session == null || _tacticalFinished || _tacticalHud.ModalActive || !_tacticalUnits.TryGetValue(id, out var unit)
            || !_session.CanCommand(unit.Character)) return;
        ClearStagedOrder();
        _focusedMember = id;
        foreach (var (key, visual) in _tacticalUnits) visual.SetFocused(key == id);
        _cameraRig.RestorePlanningView(true);
        _cameraRig.FocusForInspection(unit.GlobalPosition);
        _inspectPanel.Render(UnitInspectFactory.BuildInspectView(unit.Character));
    }

    private void RefreshSquad(double delta)
    {
        if (_session == null) return;
        _squadRefresh -= delta;
        if (_squadRefresh > 0) return;
        _squadRefresh = 0.1;
        _squad.Render(SquadViews());
    }

    private IEnumerable<SquadMemberView> SquadViews()
    {
        foreach (var member in _partyMembers)
        {
            bool active = member == _session.CurrentActor;
            int index = -1;
            for (int i = 0; i < _tacticalOrder.Count; i++)
                if (_tacticalOrder[i].Id == member.UniqueId) { index = i; break; }
            string state = member.Health?.IsAlive != true ? "Down" : active ? "Acting"
                : index < 0 ? "Waiting" : _tacticalOrder[index].IsDelayed ? "Delayed" : $"#{index + 1}";
            string conditions = string.Join(", ", member.Conditions?.GetAllConditions().Select(c => c.DisplayLabel).Distinct()
                ?? System.Array.Empty<string>());
            yield return new(member.UniqueId, member.Id, member.Name, member.Health?.CurrentHP ?? 0,
                member.Health?.MaxHP ?? 0, active, _focusedMember == member.UniqueId, state, conditions);
        }
    }

    private void ClearPartyFocus()
    {
        _focusedMember = null;
        foreach (var visual in _tacticalUnits.Values) visual.SetFocused(false);
    }

    private void PreviewDestination(IReadOnlyList<PF2eVec>? path)
    {
        _destination.Hide();
        if (path == null || path.Count == 0 || _session?.CurrentActor is not { } actor
            || !_tacticalUnits.TryGetValue(actor.UniqueId, out var unit)) return;
        var tile = path[^1];
        if (tile.Equals(actor.GridPosition) || !_lastBands.TryGetValue(tile, out var option)) return;
        var view = DestinationTactics.Read(_session.Grid, actor, tile, path, option.Kind, _session.Team2);
        _destination.Render(unit, tile, SurfaceHeights, view.Targets, view.Caption);
    }

    private void HandleTacticalClick(PF2eVec tile)
    {
        if (_session == null || _controller == null || _tacticalFinished || _tacticalHud.ModalActive) return;
        var mode = _controller.Mode;
        if (mode == PlayerTurnMode.Idle)
        {
            var member = _tacticalUnits.Values.FirstOrDefault(u => _session.CanCommand(u.Character)
                && u.Character.GridPosition.Equals(tile));
            if (member != null) { FocusPartyMember(member.Character.UniqueId); return; }
        }
        bool canStage = _controller.CanStageOrder(tile);
        if (_squad.StageOrders && canStage)
        {
            if (_stagedTile is { } previous && previous.Equals(tile) && _stagedMode == mode) { ConfirmStagedOrder(); return; }
            _stagedTile = tile;
            _stagedMode = mode;
            _squad.SetStaged(true);
            _controller.TileHovered(tile);
            if (mode != PlayerTurnMode.Idle && _session.CurrentActor is { } actor)
                _cameraRig.FrameAction(Delve.Terrain.GridSpace.GridToWorld(actor.GridPosition, SurfaceHeights),
                    Delve.Terrain.GridSpace.GridToWorld(tile, SurfaceHeights));
            return;
        }
        _controller.TileClicked(tile);
    }

    public void ConfirmStagedOrder()
    {
        if (_stagedTile is not { } tile || _controller == null || _controller.Mode != _stagedMode
            || _tacticalHud.ModalActive || !_controller.CanAcceptOrders) return;
        ClearStagedOrder(restoreCamera: false);
        _controller.TileClicked(tile);
    }

    private void ClearStagedOrder(bool restoreCamera = true)
    {
        _stagedTile = null;
        _squad.SetStaged(false);
        _destination.Hide();
        if (restoreCamera) _cameraRig.RestorePlanningView();
    }

    private void ResetTacticalPresentation()
    {
        ClearStagedOrder();
        _cameraRig.RestorePlanningView(true);
        _tacticalUnits.Clear();
        _tacticalOrder = System.Array.Empty<UnitView>();
        _focusedMember = null;
        _tacticalFinished = false;
        _partyMembers = System.Array.Empty<ICharacter>();
        _squad.Setup(System.Array.Empty<SquadMemberView>());
    }
}
