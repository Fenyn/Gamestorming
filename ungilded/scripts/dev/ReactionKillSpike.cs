using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Data;
using Ungilded.Tutorial;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.TurnManagement;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// A rat killed by the hero's Reactive Strike during its own Stride. Fixed order: hero, friend,
/// rats A, B and C, all rats adjacent to the hero. Round 1 rat C (last in the order) flees and
/// dies, so the round wraps to the hero; round 2 rat A flees and dies with rat B next; round 3 rat
/// B flees and dies, which ends the fight. For each kill it checks that the dead rat's turn stays
/// current through the beat, that its TurnEnded and end-of-turn effects come before the next
/// TurnStarted, that no turn is skipped or repeated, and that the command menu shows only during
/// a started player turn. Rendered, it saves the round 1 kill: the prompt, the kill, the beat and
/// the hero's next turn. A second fight kills its only rat with a persistent acid tick at its turn
/// end (ReactionKillSpike.TickKill.cs).
/// </summary>
public partial class ReactionKillSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }
    [Export(PropertyHint.Range, "1,10,1")] public int StartLevel { get; set; } = 2;
    [Export] public int CombatSeed { get; set; } = 1337;
    [Export] public Vector2I HeroTile { get; set; } = new(8, 6);
    [Export] public Vector2I FriendTile { get; set; } = new(9, 6);
    [Export] public Vector2I RatATile { get; set; } = new(7, 5);
    [Export] public Vector2I RatBTile { get; set; } = new(7, 6);
    [Export] public Vector2I RatCTile { get; set; } = new(7, 7);
    /// <summary>Capture paths get "_prompt.png", "_kill.png", "_beat.png" and "_next.png".</summary>
    [Export] public string ShotPrefix { get; set; } = "";
    [Export] public float TimeoutSeconds { get; set; } = 240f;
    /// <summary>Share of the scene's beat the measured beat must reach (timers are not exact).</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float BeatTolerance { get; set; } = 0.8f;

    private const string FriendLine = "The Friend waits.";

    private readonly TutorialHooks _hooks = new();
    private CombatScene _scene = null!;
    private ICharacter _hero = null!, _friend = null!, _ratA = null!, _ratB = null!, _ratC = null!;
    private Dictionary<int, ICharacter> _fleeing = new();

    private readonly List<string> _timeline = new();
    private readonly List<ulong> _stamps = new();
    private readonly List<string> _menuShown = new();
    private readonly List<string> _actorMoved = new();
    private readonly List<string> _promptIssues = new();
    private readonly List<string> _engineStartIssues = new();
    private int _prompts, _playerStartsWithBar, _playerStarts;
    private readonly HashSet<string> _shots = new();
    private BattleResult _result = BattleResult.InProgress;

    protected override string Banner => "==================== REACTION KILL SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (CombatScene == null) { AbortFail("[ReactionKill] CombatScene not assigned."); return; }

        var built = HarnessEncounter.Build(data, StartLevel, generatedMap: false, HarnessEncounter.SewerBiome, 0, CombatSeed);
        var ratDef = data.ResolveCreature(EncounterTables.GiantRat);
        Check("the harness encounter builds", built != null && ratDef != null);
        if (built == null || ratDef == null) return;
        _hero = built.Party[0].Unit; _friend = built.Party[1].Unit;
        _ratA = built.Enemies[0].Unit; _ratB = built.Enemies[1].Unit;
        _ratC = CreatureFactory.Create(ratDef, teamId: 2);
        _fleeing = new() { [1] = _ratC, [2] = _ratA, [3] = _ratB };
        var setup = built with
        {
            FixedInitiative = true,
            Party = new() { (_hero, Vec(HeroTile)), (_friend, Vec(FriendTile)) },
            Enemies = new() { (_ratA, Vec(RatATile)), (_ratB, Vec(RatBTile)), (_ratC, Vec(RatCTile)) },
        };

        _hooks.AutoPass(_friend, FriendLine);
        _hooks.OnTurnStarted(OnTurnStarted);

        _scene = CombatScene.Instantiate<CombatScene>();
        AddChild(_scene);
        _scene.Tutorial = _hooks;
        _scene.StartEncounter(setup);
        var session = _scene.Session!;
        session.EncounterFinished += r => _result = r;
        session.EventPresented += OnEvent;
        session.TurnChanged += () => Note($"changed {session.CurrentActor?.Name}");
        session.PlayerTurnStarted += c =>
        {
            Note($"player {c.Name} r{session.RoundNumber}");
            _playerStarts++;
            if (_scene.CommandBar.Visible) _playerStartsWithBar++;
        };
        var turns = TurnManager.Instance!;
        turns.OnTurnEnd += c => Note($"end {c.Name}");
        turns.OnTurnStart += c =>
        {
            Note($"start {c.Name}");
            if (_scene.CommandBar.Visible) _engineStartIssues.Add($"{c.Name} r{session.RoundNumber}");
        };

        await RunFight(session);
        CheckOrder(session);
        GD.Print($"[ReactionKill] timeline: {string.Join(" | ", _timeline)}");
        await RunTickKill(setup, ratDef);
        _scene.EndHostedEncounter();
    }

    private Task OnTurnStarted(ICharacter unit)
    {
        if (unit.TeamId == 1) return Task.CompletedTask;
        int round = _scene.Session!.RoundNumber;
        if (_fleeing.TryGetValue(round, out var rat) && ReferenceEquals(rat, unit))
        {
            unit.Health.SetCurrentHP(1);
            _hooks.ForceNextD20(TutorialHooks.D20For(_hero, unit, DegreeOfSuccess.Success));
            TurnEndCountdown.Register(unit, untilNextTurn: false, () => Note($"expired {unit.Name}"));
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().StrideAwayFrom(_hero, 2));
        }
        else
            _hooks.ScriptEnemyTurn(unit, round, new ScriptedTurn().EndTurn());
        return Task.CompletedTask;
    }

    private void OnEvent(BattleEvent evt)
    {
        var session = _scene.Session!;
        string? who = evt.Source?.Name;
        switch (evt.Type)
        {
            case BattleEventType.TurnStarted: Note($"TurnStarted {who} r{session.RoundNumber}"); break;
            case BattleEventType.TurnEnded:
                Note($"TurnEnded {who}");
                if (!ReferenceEquals(session.CurrentActor, evt.Source)) _actorMoved.Add($"at TurnEnded {who}: {session.CurrentActor?.Name}");
                break;
            case BattleEventType.CreatureDied:
                string dead = (evt.Target ?? evt.Source)?.Name ?? "?";
                Note($"Died {dead}");
                if (session.CurrentActor?.Name != dead || !session.CurrentTurnRemoved)
                    _actorMoved.Add($"at Died {dead}: {session.CurrentActor?.Name} removed {session.CurrentTurnRemoved}");
                break;
            case BattleEventType.EncounterEnded: Note("EncounterEnded"); break;
        }
    }

    // ---------------------------------------------------------------- Loop

    private async Task RunFight(CombatSession session)
    {
        float beat = _scene.RemovedTurnBeatSeconds * _scene.PresentationPace;
        ulong deadline = Time.GetTicksMsec() + (ulong)(TimeoutSeconds * 1000);
        while (_result == BattleResult.InProgress && Time.GetTicksMsec() < deadline)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            var actor = session.CurrentActor;
            bool commanding = session.PlayerTurnActive && actor is { TeamId: 1 } && actor.Health?.IsAlive == true
                && !session.CurrentTurnRemoved && !_scene.ReactionPromptOpen;
            if (_scene.CommandBar.Visible && !commanding)
                _menuShown.Add($"{actor?.Name} r{session.RoundNumber} player {session.PlayerTurnActive} removed {session.CurrentTurnRemoved} prompt {_scene.ReactionPromptOpen}");
            if (session.CurrentTurnRemoved && !_fleeing.ContainsValue(actor!))
                _actorMoved.Add($"removed turn on {actor?.Name}");

            if (_scene.ReactionPromptOpen)
            {
                _prompts++;
                if (_scene.CommandBar.Visible || actor is not { TeamId: 2 })
                    _promptIssues.Add($"{actor?.Name} bar {_scene.CommandBar.Visible}");
                await Shot("prompt");
                _scene.ChooseReaction(true);
                continue;
            }
            if (session.CurrentTurnRemoved && ReferenceEquals(actor, _ratC) && Since($"Died {_ratC.Name}") is { } since)
            {
                await Shot("kill");
                if (since >= beat / 2) await Shot("beat");
            }
            if (session.PlayerTurnActive && ReferenceEquals(actor, _hero) && _scene.Controller is { CanAcceptOrders: true })
            {
                if (session.RoundNumber == 2) await Shot("next");
                session.RequestEndPlayerTurn();
            }
        }
        Check($"the fight reached a result ({_result})", _result == BattleResult.Team1Wins);
    }

    // ---------------------------------------------------------------- Checks

    private void CheckOrder(CombatSession session)
    {
        string a = _ratA.Name, b = _ratB.Name, c = _ratC.Name, h = _hero.Name, f = _friend.Name;
        var started = _timeline.Where(e => e.StartsWith("TurnStarted ")).ToArray();
        var expected = new[]
        {
            $"{h} r1", $"{f} r1", $"{a} r1", $"{b} r1", $"{c} r1",
            $"{h} r2", $"{f} r2", $"{a} r2", $"{b} r2",
            $"{h} r3", $"{f} r3", $"{b} r3",
        }.Select(s => "TurnStarted " + s).ToArray();
        Check($"every turn started once, in initiative order ({string.Join(", ", started.Select(s => s[12..]))})",
            started.SequenceEqual(expected));

        float beat = _scene.RemovedTurnBeatSeconds * _scene.PresentationPace;
        CheckKill("round 1, last in the order", c, $"TurnStarted {h} r2", beat);
        CheckKill("round 2, rat B next", a, $"TurnStarted {b} r2", beat);

        int died = _timeline.LastIndexOf($"Died {b}");
        int ended = _timeline.LastIndexOf($"TurnEnded {b}");
        int over = _timeline.IndexOf("EncounterEnded");
        Check("the last kill ends the fight: TurnEnded, its end of turn, then EncounterEnded, no new turn",
            died >= 0 && died < ended && ended < _timeline.LastIndexOf($"end {b}") && ended < over
            && !_timeline.Skip(died).Any(e => e.StartsWith("TurnStarted ") || e.StartsWith("start ")));

        Check($"the dead rat stayed the current actor until its TurnEnded ({string.Join("; ", _actorMoved)})", _actorMoved.Count == 0);
        Check($"the command menu showed only during a started player turn ({_menuShown.Count} frames: {string.Join("; ", _menuShown.Distinct().Take(5))})",
            _menuShown.Count == 0);
        Check($"the command menu was hidden when the engine started each turn ({string.Join(", ", _engineStartIssues)})",
            _engineStartIssues.Count == 0);
        Check($"the command menu showed at every player turn start ({_playerStartsWithBar} of {_playerStarts})",
            _playerStarts == 3 && _playerStartsWithBar == _playerStarts);
        Check($"three Reactive Strike prompts, each on the rat's turn with the menu hidden ({_prompts} frames; {string.Join("; ", _promptIssues)})",
            _prompts >= 3 && _promptIssues.Count == 0);
    }

    /// <summary>One mid-turn kill that does not end the fight.</summary>
    private void CheckKill(string label, string rat, string next, float beat)
    {
        int died = _timeline.IndexOf($"Died {rat}");
        int ended = died < 0 ? -1 : _timeline.FindIndex(died, e => e == $"TurnEnded {rat}");
        int engineEnd = ended < 0 ? -1 : _timeline.FindIndex(ended, e => e == $"end {rat}");
        int expired = _timeline.IndexOf($"expired {rat}");
        int nextStart = _timeline.IndexOf(next);
        int engineNext = nextStart < 0 ? -1 : _timeline.FindLastIndex(nextStart, e => e.StartsWith("start "));
        bool between = died >= 0 && ended > died
            && !_timeline.Skip(died).Take(ended - died).Any(e => e.StartsWith("start ") || e.StartsWith("TurnStarted ") || e.StartsWith("changed "));
        Check($"{label}: {rat} dies, its turn holds, TurnEnded, its end of turn, then {next}",
            between && ended < engineEnd && engineEnd < engineNext && engineNext < nextStart);
        Check($"{label}: the 'until the end of {rat}'s turn' effect expired at its turn end",
            expired > ended && expired < nextStart);
        float held = between ? (_stamps[ended] - _stamps[died]) / 1000f : -1;
        Check($"{label}: the turn stayed current for the beat ({held:0.00}s of {beat:0.00}s)", held >= beat * BeatTolerance);
    }

    // ---------------------------------------------------------------- Helpers

    private void Note(string entry)
    {
        _timeline.Add(entry);
        _stamps.Add(Time.GetTicksMsec());
    }

    private float? Since(string entry)
    {
        int at = _timeline.IndexOf(entry);
        return at < 0 ? null : (Time.GetTicksMsec() - _stamps[at]) / 1000f;
    }

    private async Task Shot(string name)
    {
        if (Headless || ShotPrefix.Length == 0 || !_shots.Add(name)) return;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check($"the {name} capture saved", SaveViewportCapture($"{ShotPrefix}_{name}.png") == Error.Ok);
    }

    private static PF2eVec Vec(Vector2I v) => new(v.X, v.Y);
}
