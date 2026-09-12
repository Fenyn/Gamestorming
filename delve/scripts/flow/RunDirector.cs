using System;
using System.Threading.Tasks;
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
    private UnlockState _unlocks => _campaign.Unlocks;
    private readonly List<(RunPhase Phase, Control Panel)> _panels = new();

    /// <summary>The fight scene. One instance serves the whole run - it is never freed.</summary>
    [Export] public PackedScene? CombatScene { get; set; }

    [Export] public PackedScene? HeroSelectScene { get; set; }
    [Export] public PackedScene? RunMapScene { get; set; }
    [Export] public PackedScene? EventScene { get; set; }
    [Export] public PackedScene? RestScene { get; set; }
    [Export] public PackedScene? ShortRestScene { get; set; }
    [Export] public PackedScene? MeetupScene { get; set; }
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
    private bool _shortRestResolved;
    private MeetupPanel _meetupPanel = null!;
    private RunEndPanel _runEndPanel = null!;

    private RunState? _state;
    private EventDefinition? _openEvent;

    /// <summary>XP the fight in progress awards on victory, held from StartFight to the finish.</summary>
    private int _pendingXp;
    private bool _combatWon;

    /// <summary>The Wayfarer fighting in the current encounter, held from StartFight to the finish.</summary>
    private (string Id, PF2eCharacter Character)? _pendingRecruit;

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
            || MeetupScene == null || RestScene == null || ShortRestScene == null || RunEndScene == null)
        {
            GD.PushError("[RunDirector] A screen or the combat scene is not assigned - aborting.");
            return;
        }

        _combat = CombatScene.Instantiate<CombatSceneNode>();
        AddChild(_combat);
        // The run owns the loop, so the banner's scene-reload Restart never applies here.
        _combat.SetVictoryRestartVisible(false);
        _combat.EncounterFinished += OnEncounterFinished;
        _combat.ResultsContinued += ContinueCombatResults;

        LoadCampaign();
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
        _meetupPanel = AddScreen<MeetupPanel>(MeetupScene!, RunPhase.Meetup);
        _meetupPanel.CompanionPicked += ReplaceCompanion;
        _meetupPanel.Declined += DeclineMeetup;
        _runEndPanel = AddScreen<RunEndPanel>(RunEndScene!, RunPhase.RunEnd);

        _heroSelect.Confirmed += ConfirmParty;
        _heroSelect.RecruitmentRequested += BindAtOutpost;
        _map.NodePicked += async id => await TravelToNode(id);
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
        _pendingRecruit = null;
        _pendingXp = 0;
        _combatWon = false;
        _openEvent = null;
        _heroSelect.Setup(_unlocks, _campaign);
        SetPhase(RunPhase.HeroSelect);
    }

    /// <summary>Build the party around the chosen leader, generate the map, and stand at the
    /// entrance. A normal run requires the leader and three companions.</summary>
    public void ConfirmParty(string leaderId, IReadOnlyList<string> memberIds)
    {
        if (Phase != RunPhase.HeroSelect) return;
        if (memberIds.Count != Party.MaxSize - 1)
            throw new ArgumentException("Choose a leader and three companions.", nameof(memberIds));
        int seed = Seed != 0 ? Seed : (int)(GD.Randi() & 0x7FFFFFFF);
        var party = Party.Build(leaderId, memberIds, _unlocks, StartLevel);
        _runId = Guid.NewGuid().ToString("N");
        _campaign.BeginRun();
        _state = RunState.Start(seed, party, new RunMapConfig(), unlocks: _unlocks);
        GD.Print($"[RunDirector] run seed {seed}, party level {StartLevel}, {_state.Map.Floors} floors.");
        GoToMap();
    }

    /// <summary>Move onto a node and dispatch by its kind. Ignores an unreachable id.</summary>
    public async Task TravelToNode(int nodeId)
    {
        if (Phase == RunPhase.Map && await _map.PlayTravel(nodeId) && Phase == RunPhase.Map)
            PickNode(nodeId);
    }

    /// <summary>Resolve travel immediately, also used by headless encounter harnesses.</summary>
    public void PickNode(int nodeId)
    {
        if (_state == null || Phase != RunPhase.Map || !_state.Advance(nodeId)) return;

        // Passive ward burn per node. Inert at the default NodeBurn of 0.
        _state.Wardstone.BurnNode();
        if (EndOnSpentWard()) return;

        var node = _state.CurrentNode!;
        switch (node.Kind)
        {
            case NodeKind.Combat:
            case NodeKind.Elite:
            case NodeKind.Boss:
            case NodeKind.Meeting:
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
        if (result.Resolved) _openEvent = null;
        _eventPanel.ShowResult(result);
    }

    /// <summary>Leave the event and return to the map.</summary>
    public void CloseEvent()
    {
        _openEvent = null;
        GoToMap();
    }

    // ---------------------------------------------------------------- Screens

    /// <summary>Show exactly one screen - or the fight, which is a scene rather than a panel.</summary>
    private void SetPhase(RunPhase phase)
    {
        Phase = phase;
        foreach (var (screen, panel) in _panels)
            panel.Visible = screen == phase;
        _combat.SetPresentationVisible(phase is RunPhase.Combat or RunPhase.CombatResults);
        PhaseChanged?.Invoke(phase);
    }
}
