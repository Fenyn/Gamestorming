using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.UI;
using Godot;
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
        foreach (var (id, visual) in _tacticalUnits)
            visual.SetTimelineNumber(_turnBar.Numbers.TryGetValue(id, out int number) ? number : 0);
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
            HeroId = c.CreatureStats == null ? c.Id : "",
            SpriteFolder = EnemyFolderFor(c) ?? "",
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

    private TileReadout? _tileReadout;

    /// <summary>The FFT height readout for the hovered tile: its surface height in feet (one
    /// elevation step is 5 ft) and its surface name.</summary>
    private void RefreshTileReadout(PF2e.Vector2Int? tile)
    {
        var readout = _tileReadout ??= GetNode<TileReadout>("%TileReadout");
        if (tile is not { } p || _session?.MapLayout is not { } layout || !layout.IsInBounds(p.x, p.y))
        {
            readout.Render(null, "");
            return;
        }
        float units = layout.GetCornerHeights(p.x, p.y).SampleSurfaceHeight(0.5f, 0.5f);
        int feet = Mathf.RoundToInt(units / PF2e.Grid.TileCornerHeights.UnitsPerElevation * PF2e.Grid.TileCornerHeights.FeetPerElevation);
        readout.Render(feet, layout.GetSurface(p.x, p.y).ToString());
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

    /// <summary>Inspect view with the encounter letter, the portrait source and, for the acting
    /// hero, the action economy.</summary>
    private UnitInspectView InspectFor(ICharacter character)
    {
        var view = UnitInspectFactory.BuildInspectView(character) with
        {
            Letter = _session.Letters.LetterFor(character),
            BaseName = _session.Letters.BaseNameFor(character),
            SpriteFolder = EnemyFolderFor(character) ?? "",
        };
        // The acting hero's card carries the action economy, as FFT's card carries CT and MP.
        if (character == _session.CurrentActor && character.CreatureStats == null)
            view = view with
            {
                ActionsRemaining = character.Actions?.TotalActionsRemaining ?? 0,
                MaxActions = character.Actions?.MaxBaseActions ?? 0,
            };
        return view;
    }

    /// <summary>The FFT unit card bottom left shows the focused party member, else the ally whose
    /// turn it is, so the actor's pips never leave the screen; a hovered unit goes to the card
    /// bottom right (<see cref="RefreshBand"/>). On an enemy turn the band's attacker card takes
    /// the left corner, so this card stays hidden.</summary>
    private void RefreshCard()
    {
        if (_session == null) { _inspectPanel.Render(null); ClearBand(); return; }
        ICharacter? shown = null;
        if (_focusedMember is { } focused && _tacticalUnits.TryGetValue(focused, out var focusedUnit))
            shown = focusedUnit.Character;
        else if (_session.CurrentActor is { TeamId: 1 } actor && actor.Health?.IsAlive == true)
            shown = actor;
        _inspectPanel.Render(shown == null || EnemyTurnShowing || _promptOpen ? null : InspectFor(shown));
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
        RefreshCommandPrompt();
    }

    /// <summary>FFT style: the command menu is open only while the player is choosing, never while
    /// a tile or target is being picked or an action plays out.</summary>
    private void RefreshMenuShown() =>
        _actionBar.SetMenuShown(_controller.Mode == PlayerTurnMode.Idle && !_controller.Busy);

    private CommandPromptView? _commandPrompt;

    /// <summary>The FFT instruction pill and button hints follow the player's turn mode, and hide
    /// with the command menu.</summary>
    private void RefreshCommandPrompt()
    {
        _commandPrompt ??= GetNode<CommandPromptView>("%CommandPrompt");
        _commandPrompt.Render(_actionBar.Visible && _controller is { Busy: false } ? CommandPrompts.For(_controller.Mode) : null);
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
        RefreshBand();
    }

    private void ClearBoardTargets()
    {
        _playerTargetId = null;
        _actionTargetId = null;
    }

    /// <summary>Name plates for the target and the reactor; a letter badge on every living enemy,
    /// so the board matches the log ("Goblin B") while the timeline numbers change each turn.</summary>
    private void RefreshPlates()
    {
        if (_session == null) return;
        int? actor = _session.CurrentActor?.UniqueId;
        foreach (var (id, visual) in _tacticalUnits)
        {
            bool target = id == _playerTargetId || id == _actionTargetId;
            // FFT style: the crystal, the card and the timeline mark the actor, so only a target or
            // a reactor carries its name over the board.
            bool plate = target || id == _reactorId;
            bool badge = visual.Character.TeamId != 1 && visual.Character.Health?.IsAlive == true;
            var lane = id == actor ? PlateLane.Head : id == _reactorId && !target ? PlateLane.Crown : PlateLane.Foot;
            visual.Plate.SetMode(plate && !_tacticalFinished, badge && !_tacticalFinished, lane);
        }
        LayoutPlates();
    }

    /// <summary>Each visible plate keeps its lane; one that would cover an earlier plate or a Dying
    /// badge moves further along its lane until it is clear.</summary>
    private readonly List<Godot.Rect2> _takenPlateRects = new();
    private readonly List<NamePlate3D> _visiblePlates = new();

    private void LayoutPlates()
    {
        var camera = _cameraRig.Camera;
        _takenPlateRects.Clear();
        _visiblePlates.Clear();
        foreach (var visual in _tacticalUnits.Values)
        {
            if (visual.Dying.ScreenRect(camera) is { } badge) _takenPlateRects.Add(badge);
            if (visual.Plate.PlateVisible) _visiblePlates.Add(visual.Plate);
        }
        if (_visiblePlates.Count == 0) return;
        _visiblePlates.Sort((a, b) => a.Lane.CompareTo(b.Lane));
        foreach (var plate in _visiblePlates)
        {
            // Measure each candidate nudge without moving the plate; move it once, only on change.
            float nudge = 0;
            var rect = plate.PlateRect(camera, nudge);
            for (int step = 1; step <= PlateNudgeSteps && Overlaps(rect); step++)
            {
                nudge = step * rect.Size.Y;
                rect = plate.PlateRect(camera, nudge);
            }
            if (!Mathf.IsEqualApprox(plate.Nudge, nudge)) plate.SetNudge(nudge);
            _takenPlateRects.Add(rect);
        }
    }

    private bool Overlaps(Godot.Rect2 rect)
    {
        foreach (var taken in _takenPlateRects)
            if (taken.Intersects(rect)) return true;
        return false;
    }

    private async Task<bool> ShowReactionPrompt(ReactionPromptView view)
    {
        _reactorId = view.ReactorId;
        _reactionSourceId = view.SourceId;
        _promptOpen = true;
        RefreshBarVisibility();
        RefreshPlates();
        RefreshCard();
        try
        {
            return await _reactionPrompt.ShowAsync(view);
        }
        finally
        {
            _reactorId = null;
            _reactionSourceId = null;
            _promptOpen = false;
            RefreshBarVisibility();
            RefreshPlates();
            if (_session != null) RefreshCard();
        }
    }
}
