using System;
using System.Collections.Generic;
using Delve.Autoload;
using Delve.Run;
using Delve.Run.Events;
using Godot;
using PF2e.Core;
using CombatSceneNode = Delve.Combat.CombatScene;
using RunState = Delve.Run.RunState;

namespace Delve.Flow;

/// <summary>
/// Root of a run. Owns one <see cref="RunState"/>, one combat scene that lives for the whole run,
/// and the screen layer where exactly one panel is visible at a time. Every transition of
/// design/core_concept.md "Run flow" is a public method here, so a headless spike drives the same
/// code path the buttons do; the screens only signal, and the rules run in <c>Delve.Run</c>.
/// </summary>
public partial class RunDirector : Node
{
    private readonly UnlockState _unlocks = new();
    private readonly List<(RunPhase Phase, Control Panel)> _panels = new();

    /// <summary>The fight scene. One instance serves the whole run - it is never freed.</summary>
    [Export] public PackedScene? CombatScene { get; set; }

    [Export] public PackedScene? HeroSelectScene { get; set; }
    [Export] public PackedScene? RunMapScene { get; set; }
    [Export] public PackedScene? EventScene { get; set; }
    [Export] public PackedScene? RestScene { get; set; }
    [Export] public PackedScene? ShortRestScene { get; set; }
    [Export] public PackedScene? RunEndScene { get; set; }

    /// <summary>Level the party is built at. No levelling yet.</summary>
    [Export] public int StartLevel { get; set; } = Party.DefaultLevel;

    /// <summary>Run seed. 0 rolls a fresh one; DELVE_RUN_SEED overrides both.</summary>
    [Export] public int Seed { get; set; }

    /// <summary>Hand every PC to the AI as a fight starts. For the headless flow spike.</summary>
    [Export] public bool AutoPlayCombat { get; set; }

    private CanvasLayer _screenLayer = null!;
    private CombatSceneNode _combat = null!;
    private HeroSelectPanel _heroSelect = null!;
    private RunMapPanel _map = null!;
    private EventPanel _eventPanel = null!;
    private RestPanel _restPanel = null!;
    private ShortRestPanel _shortRestPanel = null!;
    private RunEndPanel _runEndPanel = null!;

    private RunState? _state;
    private EventDefinition? _openEvent;

    /// <summary>XP the fight in progress awards on victory, held from StartFight to the finish.</summary>
    private int _pendingXp;

    /// <summary>Screen the run is on.</summary>
    public RunPhase Phase { get; private set; } = RunPhase.HeroSelect;

    /// <summary>The run in progress, or null before the starting character is confirmed.</summary>
    public RunState? State => _state;

    /// <summary>Raised after every phase change, the new phase carried.</summary>
    public event Action<RunPhase>? PhaseChanged;

    public override void _Ready()
    {
        _screenLayer = GetNode<CanvasLayer>("%Screens");

        if (int.TryParse(OS.GetEnvironment("DELVE_RUN_SEED"), out int envSeed))
        {
            Seed = envSeed;
            GD.Print($"[RunDirector] run seed overridden by DELVE_RUN_SEED: {envSeed}");
        }

        if (DataManager.Instance is not { IsLoaded: true })
        {
            GD.PushError("[RunDirector] DataManager not loaded - aborting.");
            return;
        }
        if (CombatScene == null || HeroSelectScene == null || RunMapScene == null || EventScene == null
            || RestScene == null || ShortRestScene == null || RunEndScene == null)
        {
            GD.PushError("[RunDirector] A screen or the combat scene is not assigned - aborting.");
            return;
        }

        _combat = CombatScene.Instantiate<CombatSceneNode>();
        AddChild(_combat);
        // The run owns the loop, so the banner's scene-reload Restart never applies here.
        _combat.SetVictoryRestartVisible(false);
        _combat.EncounterFinished += OnEncounterFinished;

        BuildScreens();
        NewRun();
    }

    private void BuildScreens()
    {
        _heroSelect = AddScreen<HeroSelectPanel>(HeroSelectScene!, RunPhase.HeroSelect);
        _map = AddScreen<RunMapPanel>(RunMapScene!, RunPhase.Map);
        _eventPanel = AddScreen<EventPanel>(EventScene!, RunPhase.Event);
        _restPanel = AddScreen<RestPanel>(RestScene!, RunPhase.Rest);
        _shortRestPanel = AddScreen<ShortRestPanel>(ShortRestScene!, RunPhase.ShortRest);
        _runEndPanel = AddScreen<RunEndPanel>(RunEndScene!, RunPhase.RunEnd);

        _heroSelect.Confirmed += ConfirmParty;
        _map.NodePicked += PickNode;
        _map.ShortRestPressed += OpenShortRest;
        _eventPanel.OptionPicked += PickEventOption;
        _eventPanel.Continued += CloseEvent;
        _restPanel.RestPressed += Rest;
        _shortRestPanel.ActivityPicked += TakeShortRest;
        _shortRestPanel.Back += CloseShortRest;
        _runEndPanel.NewRunPressed += NewRun;
    }

    private T AddScreen<T>(PackedScene scene, RunPhase phase) where T : Control
    {
        var panel = scene.Instantiate<T>();
        panel.Visible = false;
        _screenLayer.AddChild(panel);
        _panels.Add((phase, panel));
        return panel;
    }

    // ---------------------------------------------------------------- Transitions

    /// <summary>Drop the run and go back to hero select.</summary>
    public void NewRun()
    {
        _state = null;
        _openEvent = null;
        _heroSelect.Setup(_unlocks);
        SetPhase(RunPhase.HeroSelect);
    }

    /// <summary>Build the party around the chosen leader, generate the map, and stand at the
    /// entrance. Companions join later through <see cref="Party.AddMember"/>.</summary>
    public void ConfirmParty(string leaderId, IReadOnlyList<string> memberIds)
    {
        int seed = Seed != 0 ? Seed : (int)(GD.Randi() & 0x7FFFFFFF);
        var party = Party.Build(leaderId, memberIds, _unlocks, StartLevel);
        _state = RunState.Start(seed, party, new RunMapConfig());
        GD.Print($"[RunDirector] run seed {seed}, party level {StartLevel}, {_state.Map.Floors} floors.");
        GoToMap();
    }

    /// <summary>Move onto a node and dispatch by its kind. Ignores an unreachable id.</summary>
    public void PickNode(int nodeId)
    {
        if (_state == null || !_state.Advance(nodeId)) return;

        // Passive ward burn per node. Inert at the default NodeBurn of 0.
        _state.Wardstone.BurnNode();
        var node = _state.CurrentNode!;
        switch (node.Kind)
        {
            case NodeKind.Combat:
            case NodeKind.Elite:
            case NodeKind.Boss:
                StartFight(node);
                break;
            case NodeKind.Event:
                OpenEvent(node);
                break;
            case NodeKind.Rest:
                OpenRest();
                break;
            default:
                GoToMap();
                break;
        }
    }

    /// <summary>Show the map with the party's current position and reachable nodes.</summary>
    public void GoToMap()
    {
        if (_state == null) return;
        _map.Render(_state);
        SetPhase(RunPhase.Map);
    }

    // ---------------------------------------------------------------- Combat

    private void StartFight(MapNode node)
    {
        var data = DataManager.Instance;
        var setup = data == null ? null : EncounterFactory.Build(_state!, node, data.ResolveCreature);
        if (setup == null)
        {
            GD.PushError($"[RunDirector] Could not build the encounter for node {node.Id} - back to the map.");
            GoToMap();
            return;
        }

        _pendingXp = setup.XpAward;
        SetPhase(RunPhase.Combat);
        _combat.StartEncounter(setup);
        if (AutoPlayCombat)
            _combat.SetAllPlayerAi(true);
    }

    /// <summary>
    /// A fight ended. The wipe test reads the party BEFORE the stabilize step, which puts every
    /// downed member back on 1 HP - after it, nobody is ever wiped.
    /// </summary>
    private void OnEncounterFinished(BattleResult result)
    {
        if (_state == null || Phase != RunPhase.Combat) return;

        bool wiped = _state.Party.IsWiped;
        var node = _state.CurrentNode;
        PartyRecovery.CompleteEncounter(_state.Party, result);

        if (wiped || result != BattleResult.Team1Wins)
        {
            _pendingXp = 0;
            EndRun(RunOutcome.Defeat);
        }
        else if (node != null && node.Kind == NodeKind.Boss)
        {
            AwardPendingXp();
            // Beating a floor's boss recharges the stone in full. The last floor's boss is the
            // Depths Warden and ends the run; any other drops the party onto the next floor.
            _state.Wardstone.RefillFull();
            if (_state.OnFinalStratum)
            {
                EndRun(RunOutcome.Victory);
            }
            else
            {
                _state.AdvanceStratum();
                GD.Print($"[RunDirector] floor beaten - descending to floor {_state.Stratum + 1}.");
                GoToMap();
            }
        }
        else
        {
            AwardPendingXp();
            GoToMap();
        }
    }

    /// <summary>Pay out the won fight's XP (stabilized party first) and level in place on a
    /// threshold cross. RAW award, accelerated threshold (design/core_concept.md "Run flow").</summary>
    private void AwardPendingXp()
    {
        if (_state == null || _pendingXp <= 0) return;
        int xp = _pendingXp;
        _pendingXp = 0;
        int gained = PartyLeveling.Award(_state, xp);
        if (gained > 0)
            GD.Print($"[RunDirector] +{xp} XP - the party reaches level {_state.Party.Level}.");
    }

    /// <summary>End the run and show the summary. Public: it is a transition like any other.</summary>
    public void EndRun(RunOutcome outcome)
    {
        if (_state == null) return;
        _state.Outcome = outcome;
        _runEndPanel.Show(_state);
        SetPhase(RunPhase.RunEnd);
    }

    // ---------------------------------------------------------------- Events

    /// <summary>Open a Happenstance for a node. Public so a spike can drive one it did not walk to.</summary>
    public void OpenEvent(MapNode node)
    {
        if (_state == null) return;
        _openEvent = EventCatalog.ForNode(_state.Seed, node.Id);
        _eventPanel.Show(_openEvent, _state);
        SetPhase(RunPhase.Event);
    }

    /// <summary>Resolve one option. The panel then shows the result and offers Continue.</summary>
    public void PickEventOption(int optionIndex, PF2eCharacter? actor)
    {
        if (_state == null || _openEvent == null) return;
        var result = EventResolver.Resolve(_state, _openEvent, optionIndex, actor);
        _eventPanel.ShowResult(result);
    }

    /// <summary>Leave the event and return to the map.</summary>
    public void CloseEvent()
    {
        _openEvent = null;
        GoToMap();
    }

    // ---------------------------------------------------------------- Rest

    /// <summary>Open the Campsite screen. Public so a spike can drive one it did not walk to.</summary>
    public void OpenRest()
    {
        if (_state == null) return;
        _restPanel.Show(_state);
        SetPhase(RunPhase.Rest);
    }

    /// <summary>Take the night's rest at a Campsite: heal, clear Wounded, roll the day over.</summary>
    public void Rest()
    {
        if (_state == null) return;
        PartyRecovery.LongRest(_state.Party, _state.Clock, wardstone: _state.Wardstone);
        GoToMap();
    }

    /// <summary>Open the ten-minute activity screen from the map.</summary>
    public void OpenShortRest()
    {
        if (_state == null) return;
        _shortRestPanel.Show(_state);
        SetPhase(RunPhase.ShortRest);
    }

    /// <summary>Spend one ten-minute block. The panel shows the lines it produced.</summary>
    public void TakeShortRest(ShortRestKind kind, PF2eCharacter? target)
    {
        if (_state == null) return;
        if (Phase != RunPhase.ShortRest)
            OpenShortRest();

        var result = ShortRest.Perform(
            _state.Party, _state.Clock, kind, target, new RecoveryRules(),
            wardstone: _state.Wardstone);
        _shortRestPanel.ShowResult(result);
    }

    /// <summary>Leave the ten-minute screen and return to the map.</summary>
    public void CloseShortRest() => GoToMap();

    // ---------------------------------------------------------------- Screens

    /// <summary>Show exactly one screen - or the fight, which is a scene rather than a panel.</summary>
    private void SetPhase(RunPhase phase)
    {
        Phase = phase;
        foreach (var (screen, panel) in _panels)
            panel.Visible = screen == phase;
        _combat.SetPresentationVisible(phase == RunPhase.Combat);
        PhaseChanged?.Invoke(phase);
    }
}
