using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Knowledge;
using Ungilded.Tutorial;
using Ungilded.UI;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// Checks every <see cref="TutorialHooks"/> control on the <see cref="HarnessEncounter"/> fight (flat
/// board, fixed tiles): command and move restriction, forced dice and <see cref="TutorialHooks.D20For"/>,
/// auto-pass, scripted enemy turns, the stride gate, forced reveal order with the card's ??? rows,
/// an HP threshold, and a party wipe followed by a restart. Initiative is rolled, so each check
/// runs on whichever turn it needs. Rendered, it saves the board with gold tiles and a disabled
/// command to <see cref="ShotPath"/>.
/// </summary>
public partial class TutorialHooksSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export(PropertyHint.Range, "1,10,1")] public int StartLevel { get; set; } = 2;
    [Export] public int CombatSeed { get; set; } = 1337;
    [Export] public Vector2I HeroTile { get; set; } = new(4, 6);
    [Export] public Vector2I FriendTile { get; set; } = new(3, 6);
    [Export] public Vector2I RatATile { get; set; } = new(8, 6);
    [Export] public Vector2I RatBTile { get; set; } = new(9, 8);
    [Export] public string ShotPath { get; set; } = "";
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);
    [Export] public float SettleSeconds { get; set; } = 2f;
    [Export] public float HoldSeconds { get; set; } = 1f;
    [Export] public float TimeoutSeconds { get; set; } = 180f;
    [Export] public float PollSeconds { get; set; } = 0.1f;

    private const string FriendLine = "The Friend holds back.";
    private const string MoveHint = "Click a gold tile.";
    private const string Callout = "Some details are unknown.";

    private readonly TutorialHooks _hooks = new();
    private CombatScene _scene = null!;
    private CombatSetup _setup = null!;
    private ICharacter _hero = null!, _friend = null!, _ratA = null!, _ratB = null!;

    private readonly List<StrikeInfo> _strikes = new();
    private readonly List<CreatureKnowledgeField> _reveals = new();
    private readonly List<string> _turns = new();
    private int _thresholdFires, _wipes, _refusals, _finishes, _ratTurnsSeen;
    private bool _friendHadPlayerTurn, _wipeArmed, _heroRoundOneDone;
    private (ICharacter Rat, PF2eVec Tile)? _scriptedApproach;
    private EnemyStride? _held;
    private TaskCompletionSource? _release;
    private BattleResult _result = BattleResult.InProgress;

    protected override string Banner => "==================== TUTORIAL HOOKS SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (CombatScene == null) { AbortFail("[TutorialHooks] CombatScene not assigned."); return; }

        var built = HarnessEncounter.Build(data, StartLevel, generatedMap: false, HarnessEncounter.SewerBiome, 0, CombatSeed);
        Check("the harness encounter builds", built != null);
        if (built == null) return;
        _hero = built.Party[0].Unit; _friend = built.Party[1].Unit;
        _ratA = built.Enemies[0].Unit; _ratB = built.Enemies[1].Unit;
        _setup = built with
        {
            Party = new() { (_hero, Vec(HeroTile)), (_friend, Vec(FriendTile)) },
            Enemies = new() { (_ratA, Vec(RatATile)), (_ratB, Vec(RatBTile)) },
        };

        CheckMonsterJournalCritical();
        RegisterHooks();

        _scene = CombatScene.Instantiate<CombatScene>();
        AddChild(_scene);
        _scene.Tutorial = _hooks;
        _scene.Journal = new MonsterJournal();
        _scene.StartEncounter(_setup);
        var session = _scene.Session!;
        foreach (var hero in session.Team1) session.SetAutoReactions(hero, true);
        session.EncounterFinished += r => _result = r;

        await RunUntil(() => _result != BattleResult.InProgress);
        CheckFirstFight();
        await CheckRestart();
        _scene.EndHostedEncounter();
    }

    // ---------------------------------------------------------------- Hooks

    private void RegisterHooks()
    {
        _hooks.AutoPass(_friend, FriendLine);
        _hooks.MoveRefused += _ => _refusals++;
        _hooks.OnTurnStarted(OnTurnStarted);
        _hooks.AfterStrikeResolved(s => { _strikes.Add(s); return Task.CompletedTask; });
        _hooks.OnKnowledgeRevealed((_, field) => { _reveals.Add(field); return Task.CompletedTask; });
        _hooks.OnPartyWiped(() =>
        {
            _wipes++;
            _hooks.ForceNextD20(7);
            return Task.CompletedTask;
        });
        _hooks.OnEncounterFinished(_ => { _finishes++; return Task.CompletedTask; });
        _hooks.BeforeEnemyStride(async stride =>
        {
            if (_held != null) return;
            _held = stride;
            _release = new TaskCompletionSource();
            await _release.Task;
        });
    }

    private Task OnTurnStarted(ICharacter unit)
    {
        var session = _scene.Session!;
        int round = session.RoundNumber;
        _turns.Add($"{unit.Name} r{round}");
        if (ReferenceEquals(unit, _friend) && round >= 2) _hooks.ClearAutoPass(_friend);
        if (unit.TeamId == 1) return Task.CompletedTask;

        if (_wipeArmed)
        {
            foreach (var hero in session.Team1) hero.Health.SetCurrentHP(0);
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().EndTurn());
        }
        else if (round == 1 && _ratTurnsSeen++ == 0 && ApproachTile(session, unit) is { } tile)
        {
            // The first rat walks up to the hero and bites; the forced roll keeps the hero standing.
            _scriptedApproach = (unit, tile);
            _hooks.ForceNextD20(TutorialHooks.D20For(unit, _hero, DegreeOfSuccess.Failure));
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().StrideTo(tile).Strike(_hero));
        }
        else if (round == 1)
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().StrideAwayFrom(_hero, 2));
        else
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().EndTurn());
        return Task.CompletedTask;
    }

    /// <summary>A free tile next to the hero that the rat reaches in one Stride.</summary>
    private static PF2eVec? ApproachTile(CombatSession session, ICharacter rat)
    {
        var exec = session.PlayerActions;
        var hero = session.Team1[0];
        return exec.GetReachableTiles(rat)
            .Where(t => Chebyshev(t, hero.GridPosition) == 1)
            .OrderBy(t => Chebyshev(t, rat.GridPosition)).ThenBy(t => t.x).ThenBy(t => t.y)
            .Cast<PF2eVec?>().FirstOrDefault();
    }

    // ---------------------------------------------------------------- Loop

    /// <summary>Poll the fight: release a held stride, play each player turn, stop at the result.</summary>
    private async Task RunUntil(Func<bool> done)
    {
        for (float waited = 0; !done() && waited < TimeoutSeconds; waited += PollSeconds)
        {
            if (_held != null && _release is { Task.IsCompleted: false })
            {
                await CheckHeldStride();
                continue;
            }
            // The player turn is open once the controller takes orders, not when the turn is announced.
            if (_scene.IsPlayerTurn && _scene.Controller is { CanAcceptOrders: true })
                await PlayTurn(_scene.Session!.CurrentActor!);
            await WaitSeconds(PollSeconds);
        }
        Check($"the fight reached a result ({_result})", done());
    }

    private async Task PlayTurn(ICharacter actor)
    {
        var session = _scene.Session!;
        if (ReferenceEquals(actor, _friend) && session.RoundNumber == 1) _friendHadPlayerTurn = true;
        if (ReferenceEquals(actor, _hero) && !_heroRoundOneDone)
        {
            _heroRoundOneDone = true;
            await PlayHeroRoundOne(session);
        }
        else if (session.RoundNumber >= 2 && _reveals.Count < 2 && !_wipeArmed)
            await PlayRecallKnowledge(session, actor);
        if (_reveals.Count >= 2) _wipeArmed = true;
        if (ReferenceEquals(session.CurrentActor, actor) && _scene.IsPlayerTurn) session.RequestEndPlayerTurn();
        await WaitFor(() => !ReferenceEquals(session.CurrentActor, actor) || _result != BattleResult.InProgress);
    }

    // ---------------------------------------------------------------- Hero round 1

    private async Task PlayHeroRoundOne(CombatSession session)
    {
        var bar = _scene.CommandBar;
        var controller = _scene.Controller!;
        var exec = session.PlayerActions;

        _hooks.RestrictCommands("Move");
        Check("restricted: Move stays enabled", bar.IsCommandEnabled("Move"));
        Check("restricted: Strike shows disabled", !bar.IsCommandEnabled("Strike"));
        Check("restricted: End Turn shows disabled", !bar.IsCommandEnabled("End Turn"));
        bool keyRan = bar.HandleCommandKey(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
        await WaitSeconds(PollSeconds);
        Check("restricted: the End Turn hotkey is refused", !keyRan && ReferenceEquals(session.CurrentActor, _hero));
        bool moveKey = bar.HandleCommandKey(new InputEventAction { Action = InputNames.Move, Pressed = true });
        Check("restricted: the Move hotkey still works", moveKey && controller.Mode == PlayerTurnMode.Moving);
        controller.Cancel();

        var reachable = exec.GetReachableTiles(_hero);
        var rats = session.Team2.Where(r => r.Health.IsAlive).ToArray();
        var allowed = reachable.Where(t => rats.Any(r => Chebyshev(t, r.GridPosition) == 1))
            .OrderBy(t => t.x).ThenBy(t => t.y).Cast<PF2eVec?>().FirstOrDefault();
        var refused = reachable.Where(t => !allowed.HasValue || !t.Equals(allowed.Value))
            .OrderBy(t => t.x).ThenBy(t => t.y).Cast<PF2eVec?>().FirstOrDefault();
        Check("a tile next to a rat is in Stride range", allowed != null && refused != null);
        if (allowed is not { } goal || refused is not { } wrong) return;

        _hooks.RestrictMoveTo(new[] { goal }, MoveHint);
        Check("the board shows one gold tile", _scene.GuideTileCount == 1);
        Check($"the forecast slot shows the move hint ('{bar.Decision.HintText}')", bar.Decision.HintText == MoveHint);
        if (!Headless && ShotPath.Length > 0)
        {
            await WaitSeconds(SettleSeconds);
            Check("the board capture saved", SaveViewportCapture(ShotPath, ShotSize) == Error.Ok);
        }

        int actions = _hero.Actions!.TotalActionsRemaining;
        controller.BeginMove();
        _scene.ClickTile(wrong);
        await WaitIdle(controller);
        Check("an unlisted tile is refused with no action spent",
            _refusals == 1 && _hero.GridPosition.Equals(Vec(HeroTile)) && _hero.Actions.TotalActionsRemaining == actions);
        _scene.ClickTile(goal);
        await WaitIdle(controller);
        Check($"the listed tile is accepted ({goal.x},{goal.y})",
            _hero.GridPosition.Equals(goal) && _hero.Actions.TotalActionsRemaining == actions - 1);
        _hooks.ClearMoveRestriction();
        _hooks.ClearCommandRestriction();
        Check("the gold tiles clear", _scene.GuideTileCount == 0);

        var target = session.Team2.First(r => r.Health.IsAlive && Chebyshev(r.GridPosition, goal) == 1);
        await StrikeHitThenMiss(session, controller, target);
    }

    private async Task StrikeHitThenMiss(CombatSession session, PlayerTurnController controller, ICharacter target)
    {
        var preview = session.PlayerActions.GetAttackPreview(_hero, target)!;
        int hit = TutorialHooks.D20For(_hero, target, DegreeOfSuccess.Success);
        Check($"D20For gives a plain hit (d20 {hit}, {preview.TotalAttackBonus:+0} vs AC {preview.TargetAC})",
            DegreeOfSuccessCalculator.Calculate(hit, preview.TargetAC, preview.TotalAttackBonus) == DegreeOfSuccess.Success);
        int mapStep = session.PlayerActions.GetCurrentMap(_hero) - 5;
        int miss = TutorialHooks.D20ForCheck(preview.TotalAttackBonus + mapStep, preview.TargetAC, DegreeOfSuccess.Failure);

        _hooks.OnHpBelow(target, 0.9f, () => { _thresholdFires++; return Task.CompletedTask; });
        _hooks.ClearForcedDice();
        _hooks.ForceNextD20(hit, miss);
        _hooks.ForceNextDice(1);
        int before = _strikes.Count;
        for (int i = 0; i < 2; i++)
        {
            controller.BeginStrike();
            _scene.ClickTile(target.GridPosition);
            await WaitIdle(controller);
        }
        var mine = _strikes.Skip(before).Where(s => ReferenceEquals(s.Attacker, _hero)).ToArray();
        Check($"the forced strikes hit then miss ({string.Join(", ", mine.Select(s => $"d20 {s.D20} {s.Degree}"))})",
            mine.Length == 2 && mine[0].D20 == hit && mine[0].Degree == DegreeOfSuccess.Success
            && mine[1].D20 == miss && mine[1].Degree == DegreeOfSuccess.Failure);
        Check("the forced d20 queue is empty after the strikes", !DiceRoller.HasD20Overrides);
        Check("the HP threshold fired on the hit", _thresholdFires == 1);
    }

    // ---------------------------------------------------------------- Recall Knowledge

    private async Task PlayRecallKnowledge(CombatSession session, ICharacter actor)
    {
        var rat = session.Team2.Where(r => r.Health.IsAlive)
            .OrderBy(r => Chebyshev(r.GridPosition, actor.GridPosition)).FirstOrDefault();
        if (rat == null) return;
        string id = rat.CreatureStats!.CreatureId;
        bool first = _reveals.Count == 0;
        if (first)
        {
            _hooks.ForceNextReveal(id, CreatureKnowledgeField.Name);
            _hooks.ForceNextReveal(id, CreatureKnowledgeField.AC);
            _hooks.ShowHiddenFieldsCallout(true, Callout);
            _scene.HoverTile(rat.GridPosition);
            var card = _scene.TargetCard;
            Check($"the card shows ??? for unrevealed fields ({string.Join(" | ", card.KnowledgeTexts)})",
                card.KnowledgeTexts.Contains("AC ???") && card.KnowledgeTexts.Contains("Weak ???")
                && card.KnowledgeTexts.Contains("Abilities ???") && card.KnowledgeTexts.Contains("Fort ???"));
            Check("the callout shows beside the ??? rows", card.CalloutShown && card.CalloutText == Callout);
            _scene.HoverTile(null);
            _hooks.RestrictCommands("Skills", "Recall Knowledge");
            Check("restricted: Abilities and Recall Knowledge stay enabled",
                _scene.CommandBar.IsCommandEnabled("Abilities") && _scene.CommandBar.IsChipEnabled("Recall Knowledge"));
            Check("restricted: Move shows disabled", !_scene.CommandBar.IsCommandEnabled("Move"));
        }

        var controller = _scene.Controller!;
        _hooks.ClearForcedDice();
        _hooks.ForceNextD20(TutorialHooks.D20ForSkill(actor, rat, "recall-knowledge", DegreeOfSuccess.Success));
        int before = _reveals.Count;
        controller.BeginSkill("recall-knowledge");
        _scene.ClickTile(rat.GridPosition);
        await WaitIdle(controller);
        var expected = first ? CreatureKnowledgeField.Name : CreatureKnowledgeField.AC;
        Check($"Recall Knowledge {(first ? 1 : 2)} reveals {expected} ({string.Join(", ", _reveals.Skip(before))})",
            _reveals.Count == before + 1 && _reveals[^1] == expected);
        if (!first)
        {
            _scene.HoverTile(rat.GridPosition);
            var texts = _scene.TargetCard.KnowledgeTexts;
            Check($"the card shows the revealed AC ({texts.FirstOrDefault(t => t.StartsWith("AC"))})",
                texts.Any(t => t.StartsWith("AC ") && t != "AC ???"));
            _scene.HoverTile(null);
            _hooks.ShowHiddenFieldsCallout(false);
            _hooks.ClearCommandRestriction();
        }
    }

    /// <summary>A Critical Success takes two forced fields; checked on a journal of its own.</summary>
    private void CheckMonsterJournalCritical()
    {
        var journal = new MonsterJournal();
        var fields = journal.Reveal("giant-rat", DegreeOfSuccess.CriticalSuccess, "Giant Rat",
            new[] { CreatureKnowledgeField.Name, CreatureKnowledgeField.Weaknesses, CreatureKnowledgeField.AC });
        Check($"a critical success reveals two forced fields ({string.Join(", ", fields)})",
            fields.SequenceEqual(new[] { CreatureKnowledgeField.Name, CreatureKnowledgeField.Weaknesses }));
    }

    // ---------------------------------------------------------------- Stride gate

    private async Task CheckHeldStride()
    {
        var session = _scene.Session!;
        var held = _held!;
        int turns = _turns.Count;
        await WaitSeconds(HoldSeconds);
        Check($"the stride gate holds {held.Unit.Name} on its tile",
            held.Unit.GridPosition.Equals(held.From) && ReferenceEquals(session.CurrentActor, held.Unit)
            && _turns.Count == turns && Chebyshev(held.From, held.NextTile) == 1);
        _release!.TrySetResult();
    }

    // ---------------------------------------------------------------- Results

    private void CheckFirstFight()
    {
        var log = _scene.LogText;
        Check("auto-pass wrote its log line", log.Contains(FriendLine));
        Check("auto-pass ended the second hero's round 1 turn with no player turn", !_friendHadPlayerTurn);
        if (_scriptedApproach is { } approach)
            Check($"the scripted rat strode to ({approach.Tile.x},{approach.Tile.y}) and struck",
                _strikes.Any(s => ReferenceEquals(s.Attacker, approach.Rat) && ReferenceEquals(s.Target, _hero))
                && (approach.Rat.GridPosition.Equals(approach.Tile) || approach.Rat.Health.IsDead));
        else
            Check("a rat had a scripted approach", false);
        Check("the stride gate ran", _held != null);
        Check("Recall Knowledge ran twice", _reveals.Count >= 2);
        Check("the HP threshold fired once", _thresholdFires == 1);
        Check($"the party wipe fired OnPartyWiped, then OnEncounterFinished ({_result})",
            _wipes == 1 && _finishes == 1 && _result == BattleResult.Team2Wins);
        Check("encounter end emptied the forced d20 queue", !DiceRoller.HasD20Overrides);
        GD.Print($"[TutorialHooks] turns: {string.Join(", ", _turns)}");
    }

    private async Task CheckRestart()
    {
        _hooks.ForceNextD20(9);
        _scene.EndHostedEncounter();
        Check("encounter reset emptied the forced d20 queue", !DiceRoller.HasD20Overrides);

        foreach (var (unit, _) in _setup.Party.Concat(_setup.Enemies))
        {
            unit.Health.ClearPermanentDeath();
            unit.Health.RestoreToFull();
            unit.Conditions?.RemoveAllConditions();
        }
        _hooks.ClearCallbacks();
        _hooks.ClearAutoPass(_friend);
        int turnsBefore = 0;
        _hooks.OnTurnStarted(_ => { turnsBefore++; return Task.CompletedTask; });
        _result = BattleResult.InProgress;
        _scene.SetPresentationVisible(true);
        _scene.StartEncounter(_setup);
        var session = _scene.Session;
        Check("the restart built a new session", session != null && session.Team1.Count == 2 && session.Team2.Count == 2);
        if (session == null) return;
        session.EncounterFinished += r => _result = r;
        await WaitFor(() => turnsBefore > 0);
        Check("the restarted fight began a turn", turnsBefore > 0 && _result == BattleResult.InProgress);
        Check("the restarted fight put the hero back on its tile", _hero.GridPosition.Equals(Vec(HeroTile)));
    }

    // ---------------------------------------------------------------- Helpers

    private async Task WaitIdle(PlayerTurnController controller)
    {
        await WaitSeconds(PollSeconds);
        await WaitFor(() => !controller.Busy);
    }

    private async Task WaitFor(Func<bool> done)
    {
        for (float waited = 0; !done() && waited < TimeoutSeconds; waited += PollSeconds)
        {
            if (_held != null && _release is { Task.IsCompleted: false }) await CheckHeldStride();
            await WaitSeconds(PollSeconds);
        }
    }

    private static int Chebyshev(PF2eVec a, PF2eVec b) => Math.Max(Math.Abs(a.x - b.x), Math.Abs(a.y - b.y));

    private static PF2eVec Vec(Vector2I v) => new(v.X, v.Y);
}
