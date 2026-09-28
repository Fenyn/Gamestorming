using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>HUD zone wiring: the initiative list, the card slot, the board plates and badges, and
/// the action bar's visibility around enemy turns and the reaction prompt.</summary>
public partial class CombatScene
{
    [Godot.Export] public int PlateNudgeSteps { get; set; } = 6;
    private int? _hoveredId;
    private int? _playerTargetId;
    private int? _actionTargetId;
    private int? _reactorId;
    private bool _promptOpen;

    private void RefreshTurnOrder()
    {
        var order = _session.TurnOrder;
        if (order == null) return;

        var current = _session.CurrentActor;
        var delayed = _session.DelayedEntries ?? System.Array.Empty<PF2e.TurnManagement.TurnEntry>();
        var views = new List<UnitView>(order.Count + delayed.Count);
        foreach (var entry in order)
        {
            views.Add(UnitViewFor(entry, current));
            // A delayer shows at the slot it returns to, right after its anchor.
            foreach (var waiting in delayed)
                if (waiting.ReturnAfter == entry.Character)
                    views.Add(UnitViewFor(waiting, current, delayed: true));
        }
        // The strip starts at the actor; the combatants before it act next round.
        int currentIndex = views.FindIndex(v => v.IsCurrent);
        int wrapIndex = -1;
        if (currentIndex > 0)
        {
            views = views.Skip(currentIndex).Concat(views.Take(currentIndex)).ToList();
            wrapIndex = views.Count - currentIndex;
        }
        _turnWrap = wrapIndex;
        _turnRound = _session.RoundNumber + 1;
        _turnSignature = RowSignature(views);
        _turnBar.Render(views, _turnWrap, _turnRound);
        _tacticalOrder = views;
        ClearStagedOrder();

        bool playerTurn = current != null && _session.IsPlayerControlled(current);
        _actionBar.SetInteractable(playerTurn);
        _actionBar.SetControlOptionsEnabled(current != null && _session.CanCommand(current));
        if (current != null)
        {
            _actionBar.SetAiToggle(_session.IsAiToggled(current));
            _actionBar.SetAutoReactToggle(_session.IsAutoReactions(current));
        }
        RefreshBarVisibility();
        RefreshCard();
        RefreshPlates();
    }

    private UnitView UnitViewFor(PF2e.TurnManagement.TurnEntry entry, ICharacter? current, bool delayed = false)
    {
        var c = entry.Character;
        return new UnitView
        {
            Name = c.Name,
            Letter = _session.Letters.LetterFor(c),
            BaseName = _session.Letters.BaseNameFor(c),
            Id = c.UniqueId,
            TeamId = c.TeamId,
            IsCurrent = c == current,
            IsDead = c.Health != null && c.Health.IsDead,
            IsDelayed = delayed,
            IsPickable = _delayPickIds.Contains(c.UniqueId),
            Initiative = entry.Initiative,
            Hp = c.Health?.CurrentHP ?? 0,
            MaxHp = c.Health?.MaxHP ?? 0,
            Conditions = ConditionMarks.For(c),
        };
    }

    private int _turnWrap = -1;
    private int _turnRound;
    private string _turnSignature = "";

    /// <summary>Conditions and HP change inside a turn; the rows follow them without rebuilding the order.</summary>
    private void RefreshTurnRows()
    {
        if (_tacticalOrder.Count == 0) return;
        var views = _tacticalOrder.Select(v => _tacticalUnits.TryGetValue(v.Id, out var unit)
            ? v with { Conditions = ConditionMarks.For(unit.Character), Hp = unit.Character.Health?.CurrentHP ?? v.Hp }
            : v).ToList();
        string signature = RowSignature(views);
        if (signature == _turnSignature) return;
        _turnSignature = signature;
        _tacticalOrder = views;
        _turnBar.Render(views, _turnWrap, _turnRound);
    }

    private static string RowSignature(IEnumerable<UnitView> views)
        => string.Join("|", views.Select(v => $"{v.Id}:{v.Hp}:" + string.Join(",", v.Conditions.Select(c => $"{c.IconKey}{c.Value}"))));

    /// <summary>Inspect view with the encounter letter. Party members keep their HP number on the party column only.</summary>
    private UnitInspectView InspectFor(ICharacter character)
    {
        var view = UnitInspectFactory.BuildInspectView(character) with
        {
            Letter = _session.Letters.LetterFor(character),
            BaseName = _session.Letters.BaseNameFor(character),
        };
        return _partyMembers.Contains(character) ? view with { HpText = "" } : view;
    }

    /// <summary>The card slot under the party column shows the hovered unit, else the focused party
    /// member, else an acting guest ally. The acting enemy and its target take the band cards.</summary>
    private void RefreshCard()
    {
        if (_session == null) { _inspectPanel.Render(null); ClearBand(); return; }
        ICharacter? shown = null;
        if (_hoveredId is { } hovered && _tacticalUnits.TryGetValue(hovered, out var hoveredUnit))
            shown = hoveredUnit.Character;
        else if (_focusedMember is { } focused && _tacticalUnits.TryGetValue(focused, out var focusedUnit))
            shown = focusedUnit.Character;
        else if (_session.CurrentActor is { TeamId: 1 } actor && !_session.IsPlayerControlled(actor)
                 && !_partyMembers.Contains(actor) && actor.Health?.IsAlive == true)
            shown = actor;
        _inspectPanel.Render(shown == null ? null : InspectFor(shown));
        RefreshBand();
    }

    /// <summary>The bar and its signature row hide on enemy turns and while the reaction prompt
    /// holds the bottom centre.</summary>
    private void RefreshBarVisibility()
    {
        var current = _session?.CurrentActor;
        bool enemyTurn = current != null && current.TeamId != 1;
        _actionBar.Visible = !enemyTurn && !_promptOpen && !_tacticalFinished && !_introPlaying;
        RefreshBand();
    }

    private void NoteBoardTarget(ICharacter target)
    {
        _actionTargetId = target.UniqueId;
        RefreshPlates();
        RefreshBand();
    }

    private void NotePlayerTarget(bool previewing)
    {
        _playerTargetId = previewing ? _hoveredId : null;
        RefreshPlates();
    }

    private void ClearBoardTargets()
    {
        _playerTargetId = null;
        _actionTargetId = null;
    }

    /// <summary>Name plates for the actor, the target and the reactor; letter badges for the
    /// hovered, active or targeted enemy.</summary>
    private void RefreshPlates()
    {
        if (_session == null) return;
        int? actor = _session.CurrentActor?.UniqueId;
        foreach (var (id, visual) in _tacticalUnits)
        {
            bool target = id == _playerTargetId || id == _actionTargetId;
            bool plate = id == actor || target || id == _reactorId;
            bool badge = visual.Character.TeamId != 1 && (id == _hoveredId || id == actor || target);
            var lane = id == actor ? PlateLane.Head : id == _reactorId && !target ? PlateLane.Crown : PlateLane.Foot;
            visual.Plate.SetMode(plate && !_tacticalFinished, badge && !_tacticalFinished, lane);
        }
        LayoutPlates();
    }

    /// <summary>Each visible plate keeps its lane; one that would cover an earlier plate or a Dying
    /// badge moves further along its lane until it is clear.</summary>
    private void LayoutPlates()
    {
        var camera = _cameraRig.Camera;
        var tokens = _unitLayer.GetChildren().OfType<UnitVisual3D>().ToList();
        var taken = tokens.Select(v => v.Dying.ScreenRect(camera)).OfType<Godot.Rect2>().ToList();
        var plates = tokens.Select(v => v.Plate).Where(p => p.PlateVisible)
            .OrderBy(p => p.Lane).ToList();
        foreach (var plate in plates)
        {
            plate.SetNudge(0);
            var rect = plate.PlateRect(camera);
            for (int step = 1; step <= PlateNudgeSteps && taken.Any(r => r.Intersects(rect)); step++)
            {
                plate.SetNudge(step * rect.Size.Y);
                rect = plate.PlateRect(camera);
            }
            taken.Add(rect);
        }
    }

    private async Task<bool> ShowReactionPrompt(ReactionPromptView view)
    {
        _reactorId = view.ReactorId;
        _promptOpen = true;
        RefreshBarVisibility();
        RefreshPlates();
        _squad.Render(SquadViews());
        try
        {
            return await _reactionPrompt.ShowAsync(view);
        }
        finally
        {
            _reactorId = null;
            _promptOpen = false;
            RefreshBarVisibility();
            RefreshPlates();
            if (_session != null) _squad.Render(SquadViews());
        }
    }
}
