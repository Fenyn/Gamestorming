using System.Threading.Tasks;
using Ungilded.Knowledge;
using Ungilded.Terrain;
using Ungilded.Tutorial;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>
/// The scene side of <see cref="TutorialHooks"/>: the command gate on the menu, the move filter and
/// gold tiles on the board, the move hint, the knowledge rows and callout on the cards, the
/// auto-pass log line, forced reveal order and the lean of a held enemy stride.
/// </summary>
public partial class CombatScene
{
    /// <summary>The tutorial hooks the next <see cref="StartEncounter"/> runs under. Null runs
    /// normal combat. Set before StartEncounter; the running encounter keeps the hooks it started with.</summary>
    public TutorialHooks? Tutorial { get; set; }

    /// <summary>Share of the way to the next tile a held enemy stride leans before it waits.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float StrideHoldFraction { get; set; } = 0.4f;

    /// <summary>Seconds the lean of a held enemy stride takes.</summary>
    [Export(PropertyHint.Range, "0,2,0.05")] public float StrideHoldSeconds { get; set; } = 0.35f;

    private static readonly PF2eVec[] NoTiles = System.Array.Empty<PF2eVec>();

    /// <summary>The hooks whose Changed event this scene listens to. The hooks outlive encounters,
    /// so the subscription follows the object, not the encounter.</summary>
    private TutorialHooks? _listenedTutorial;

    /// <summary>Wire the new encounter's controller and session to its hooks (or to none).</summary>
    private void WireTutorial()
    {
        var hooks = _session.Tutorial;
        Listen(hooks);
        _actionBar.CommandAllowed = hooks == null ? null : hooks.IsCommandAllowed;
        if (hooks != null)
        {
            var session = _session;
            _controller.MoveFilter = hooks.IsMoveAllowed;
            _controller.MoveRefused += hooks.RaiseMoveRefused;
            _controller.AfterAction = session.SettleTutorialAsync;
            session.NarrationLogged += (_, line) =>
            {
                if (ReferenceEquals(_session, session)) _log.AppendEntry(line, (int)CombatLogSeverity.Info, false);
            };
            session.StrideHoldPresenter = HoldStride;
        }
        OnTutorialChanged();
    }

    private void Listen(TutorialHooks? hooks)
    {
        if (ReferenceEquals(_listenedTutorial, hooks)) return;
        if (_listenedTutorial != null) _listenedTutorial.Changed -= OnTutorialChanged;
        _listenedTutorial = hooks;
        if (hooks != null) hooks.Changed += OnTutorialChanged;
    }

    private void OnTutorialChanged()
    {
        if (!IsInsideTree()) return;
        var hooks = _session?.Tutorial;
        _moveBands.SetGuideTiles(hooks?.MoveTiles ?? NoTiles, hooks?.MoveTilesAreHint == true);
        _actionBar.RefreshCommandGate();
        _controller?.RefreshState();
        if (_session != null) RefreshCard();
    }

    private void ResetTutorialPresentation() => _moveBands.SetGuideTiles(NoTiles);

    private void StopListeningToTutorial() => Listen(null);

    private bool _tutorialTipShowing;

    /// <summary>True while a tutorial tip is on screen. The tip carries the move instruction then,
    /// so the forecast slot drops the tutorial's move hint.</summary>
    public bool TutorialTipShowing
    {
        get => _tutorialTipShowing;
        set
        {
            if (_tutorialTipShowing == value) return;
            _tutorialTipShowing = value;
            _controller?.RefreshState();
        }
    }

    /// <summary>The bar state with the tutorial's move hint in place of the engine's, or with no
    /// hint while a tip says it.</summary>
    private ActionBarState WithTutorialHint(ActionBarState state)
    {
        if (_session?.Tutorial?.MoveHint is not { } hint || state.ActionsRemaining <= 0) return state;
        return state with { MoveRestriction = _tutorialTipShowing ? null : hint };
    }

    /// <summary>False when a tutorial restriction refuses the command the current mode belongs to,
    /// so a board click cannot finish an order the menu would not start.</summary>
    private bool TutorialAllowsClick(PlayerTurnMode mode)
    {
        if (_session?.Tutorial is not { CommandsRestricted: true } hooks) return true;
        string? command = mode switch
        {
            PlayerTurnMode.Moving or PlayerTurnMode.SelectingMove => "Move",
            PlayerTurnMode.SelectingStrike => "Strike",
            _ => null,
        };
        return command == null || hooks.IsCommandAllowed(command);
    }

    /// <summary>An enemy card with the knowledge rows and the callout while a tutorial runs.</summary>
    private UnitInspectView WithKnowledgeRows(ICharacter character, UnitInspectView view)
    {
        if (_session?.Tutorial is not { } hooks || character.CreatureStats == null) return view;
        return view with
        {
            KnowledgeRows = UnitInspectFactory.KnowledgeRows(character),
            HiddenCallout = hooks.CalloutShown ? hooks.CalloutText : "",
        };
    }

    /// <summary>Forced fields first, then the journal's own order. Each revealed field reaches the
    /// OnKnowledgeRevealed callbacks at the next pause point.</summary>
    private System.Collections.Generic.IReadOnlyList<CreatureKnowledgeField> RevealFor(
        ICharacter target, DegreeOfSuccess degree, MonsterJournal journal)
    {
        string id = target.CreatureStats!.CreatureId;
        var hooks = _session.Tutorial;
        var forced = hooks?.TakeForcedReveals(id, KnowledgeRevealOrder.RevealCount(degree));
        var fields = journal.Reveal(id, degree, SpeciesName(target), forced);
        if (hooks != null)
            foreach (var field in fields)
            {
                var revealed = field;
                _session.DeferTutorial(() => hooks.RaiseKnowledge(target, revealed));
            }
        return fields;
    }

    /// <summary>Lean the token part of the way toward the next tile, then hold there. The walk
    /// resumes from the lean, and an interrupted stride snaps back to its tile.</summary>
    private async Task HoldStride(ICharacter unit, PF2eVec next)
    {
        if (!_tacticalUnits.TryGetValue(unit.UniqueId, out var visual) || !IsInstanceValid(visual)
            || _encounterCts == null) return;
        var token = _encounterCts.Token;
        visual.Facing = new Vector2(next.x - unit.GridPosition.x, next.y - unit.GridPosition.y);
        var target = GridSpace.CreatureBodyToWorld(next, unit.TileWidth, SurfaceHeights);
        var tween = visual.CreateTween();
        tween.TweenProperty(visual, "position", visual.Position.Lerp(target, StrideHoldFraction), StrideHoldSeconds);
        var done = new TaskCompletionSource<bool>();
        tween.Finished += () => done.TrySetResult(true);
        using (token.Register(static t => ((TaskCompletionSource<bool>)t!).TrySetResult(false), done))
            await done.Task;
        token.ThrowIfCancellationRequested();
    }
}
