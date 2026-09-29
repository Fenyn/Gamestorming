using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Delve.Data;
using Delve.Terrain;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// Node3D root that assembles a 2.5D tactical combat: builds the <see cref="CombatSession"/>, spawns
/// billboard-sprite unit tokens on the 3D board, instances the 2D CanvasLayer HUD scenes, and wires
/// controller &lt;-&gt; UI &lt;-&gt; session together, then starts the encounter loop. Thin adapter — all rules
/// live in the plain-C# session/controller; this only owns node types and grid&lt;-&gt;world coordinates.
/// </summary>
public partial class CombatScene : Node3D
{
    [Export] public bool EncounterIntroEnabled { get; set; } = true;
    /// <summary>False when the host shows its own defeat screen (the run end).</summary>
    [Export] public bool DefeatBannerEnabled { get; set; } = true;
    private Tween? _introFade;
    [Export(PropertyHint.Range, "0,2,0.05")] public float AiActionDelaySeconds { get; set; } = 0.6f;
    private DiceRollPanel _dice = null!;
    /// <summary>The unit token (scenes/combat/unit_token.tscn); each unit is an instance whose
    /// per-unit visuals are applied by UnitVisual3D.Spawn.</summary>
    [Export] public PackedScene UnitTokenScene { get; set; } = null!;

    private GridOverlay3D _overlay = null!;
    private MoveBandOverlay3D _moveBands = null!;
    private Node3D _unitLayer = null!;
    private Node3D _popupLayer = null!;
    private GridInput3D _input = null!;
    private OrbitCameraRig _cameraRig = null!;
    private CanvasLayer _hud = null!;

    /// <summary>
    /// The ground under the fight: terrain view, backdrop and placeholder floor. Owns the board's
    /// surface heights, which every elevation-aware view piece reads (unit spawn, presenter tweens,
    /// overlay, input, camera pivot).
    /// </summary>
    private TerrainStage _terrain = null!;
    private TerrainHeightMap? _borrowedHeights;
    private TerrainHeightMap SurfaceHeights => _borrowedHeights ?? _terrain.HeightMap;
    public Camera3D ActiveCamera => _cameraRig.Camera;

    private ActionBar _actionBar = null!;
    private CombatLogPanel _log = null!;
    private TurnOrderBar _turnBar = null!;
    private VictoryBanner _victoryBanner = null!;
    private ReactionPromptPanel _reactionPrompt = null!;
    private HelpOverlay _help = null!;
    private UnitInspectPanel _inspectPanel = null!;

    private CombatSession _session = null!;
    private PlayerTurnController _controller = null!;
    private GodotPresenter3D _presenter = null!;

    // Cancels the fire-and-forget encounter loop on scene exit. Shared with the presenter so its paced
    // Pacing delays and tween waits observe the same signal (see _ExitTree for the cancel-then-teardown order).
    private CancellationTokenSource? _encounterCts;

    private CombatLogBridge? _logBridge;

    /// <summary>Combatant ids the turn order bar offers while the player picks a Delay slot.</summary>
    private HashSet<int> _delayPickIds = new();

    /// <summary>The Idle bands last pushed by the controller (empty while hidden). Dev captures read it.</summary>
    private IReadOnlyDictionary<PF2e.Vector2Int, MoveOption> _lastBands =
        new Dictionary<PF2e.Vector2Int, MoveOption>();

    /// <summary>
    /// True once the persistent scene nodes (input, action bar) are subscribed. Those nodes outlive
    /// every encounter, so their handlers are wired exactly once — a second StartEncounter would
    /// otherwise stack a duplicate handler per encounter. Handlers that hang off the per-encounter
    /// session / controller are wired again each time, because those objects are new.
    /// </summary>
    private bool _viewWired;

    /// <summary>
    /// Raised once when the encounter result is known (relays the session's EncounterFinished).
    /// No subscriber in the combat proof; a future meta-layer host scores the result from here.
    /// </summary>
    public event System.Action<PF2e.Core.BattleResult>? EncounterFinished;

    public override void _Ready()
    {
        _overlay = GetNode<GridOverlay3D>("%GridOverlay");
        _moveBands = GetNode<MoveBandOverlay3D>("%MoveBands");
        _unitLayer = GetNode<Node3D>("%UnitLayer");
        _popupLayer = GetNode<Node3D>("%PopupLayer");
        _input = GetNode<GridInput3D>("%GridInput");
        _cameraRig = GetNode<OrbitCameraRig>("%CameraRig");
        _terrain = GetNode<TerrainStage>("%TerrainStage");
        _hud = GetNode<CanvasLayer>("%HUD");

        _turnBar = GetNode<TurnOrderBar>("%TurnOrderBar");
        _log = GetNode<CombatLogPanel>("%CombatLog");
        _dice = GetNode<DiceRollPanel>("%DiceRoll");
        _log.RollObserved += _dice.ShowRoll;
        ApplyUserSettings();
        Delve.Settings.UserSettings.Changed += ApplyUserSettings;
        _actionBar = GetNode<ActionBar>("%ActionBar");
        _victoryBanner = GetNode<VictoryBanner>("%VictoryBanner");
        _victoryBanner.Continued += () => ResultsContinued?.Invoke();
        _reactionPrompt = GetNode<ReactionPromptPanel>("%ReactionPrompt");
        _help = GetNode<HelpOverlay>("%HelpOverlay");
        _inspectPanel = GetNode<UnitInspectPanel>("%UnitInspect");
        BuildJournal();
        BuildTacticalPresentation();
        // Modal blocking needs no wiring here: the reaction prompt pushes HudRoot's modal state
        // and the action bar's hotkeys query it directly through their shared parent.
    }

    /// <summary>
    /// Opt in to the victory banner's Restart button (hidden by default — see
    /// <see cref="VictoryBanner.SetRestartVisible"/>). Call before or after StartEncounter; the
    /// host decides, this scene doesn't know which flow it's running in.
    /// </summary>
    public void SetVictoryRestartVisible(bool visible) => _victoryBanner.SetRestartVisible(visible);

    public event System.Action? ResultsContinued;

    public void ShowRewards(Delve.Flow.CombatResultsView results) => _victoryBanner.ShowRewards(results);

    /// <summary>
    /// Show or hide the whole fight - the 3D board and the HUD CanvasLayer, which visibility does not
    /// reach on its own. A run host parks the scene here between fights instead of freeing it: the
    /// encounter loop keeps its process mode, so a fight that is still unwinding finishes normally.
    /// </summary>
    public void SetPresentationVisible(bool visible)
    {
        Visible = visible;
        _hud.Visible = visible;
    }

    /// <summary>
    /// Toggle AI control for every player unit of the CURRENT encounter. The session hands off a
    /// turn that is already parked, so this works whenever it is called. Headless spikes use it to
    /// play a fight through with no input.
    /// </summary>
    public void SetAllPlayerAi(bool aiControlled)
    {
        if (_session == null) return;
        foreach (var unit in _session.Team1)
        {
            if (_session.IsAlly(unit)) continue;
            _session.SetAiToggle(unit, aiControlled);
        }
    }

    /// <summary>True while the current actor is under player control (its bands are showing).</summary>
    public bool IsPlayerTurn =>
        _session != null && _session.CurrentActor is { } actor && _session.IsPlayerControlled(actor);

    /// <summary>
    /// Entry point: hand an assembled encounter and it plays out. Callable again on the same scene —
    /// the roguelite loop runs encounter after encounter through one CombatScene — because
    /// <see cref="ResetEncounter"/> drops everything the previous encounter owned first.
    /// </summary>
    public void StartEncounter(CombatSetup setup, TerrainHeightMap? borrowedHeights = null)
    {
        var outgoingCamera = GetViewport().GetCamera3D();
        Transform3D? outgoingPose = outgoingCamera != _cameraRig.Camera || _session != null
            ? outgoingCamera?.GlobalTransform : null;
        float outgoingFov = outgoingCamera?.Fov ?? _cameraRig.Camera.Fov;
        ResetEncounter();
        _borrowedHeights = borrowedHeights;
        ProcessMode = ProcessModeEnum.Inherit;
        _cameraRig.Camera.Current = true;

        _session = new CombatSession();
        _session.Setup(setup);
        foreach (string correction in _session.SetupCorrections)
            GD.PushWarning($"[CombatScene] {correction}");
        _controller = new PlayerTurnController(_session.PlayerActions);

        // A restart reuses this scene, so the previous encounter's history must not bleed through.
        _log.ClearLog();

        // Board surface first: everything below is positioned against it.
        _terrain.Visible = borrowedHeights == null;
        if (borrowedHeights == null)
            _terrain.Build(_session.MapLayout, setup.BiomeId, setup.GridWidth, setup.GridHeight);
        else
            _terrain.SetLookActive(false);

        _presenter = new GodotPresenter3D(_popupLayer, SurfaceHeights);
        // Crits and deaths kick the camera through the rig's shake seam (rig > ShakePivot > Camera3D);
        // turn starts and walks move the rig itself through its focus seam.
        _presenter.Shake = _cameraRig.Shake;
        _presenter.Focus = _cameraRig;
        _overlay.SetHeightMap(SurfaceHeights);
        _moveBands.SetHeightMap(SurfaceHeights);

        _cameraRig.FrameBoard(GridSpace.BoardCenter(setup.GridWidth, setup.GridHeight, SurfaceHeights),
            setup.GridWidth, setup.GridHeight);
        SpawnUnits();
        _partyMembers = setup.Party.Select(p => p.Unit).ToArray();
        NoteEncountered();

        var logBridge = new CombatLogBridge(_log, _session.Team1, _session.Team2);
        logBridge.AttackTargetNamed += NoteBoardTarget;
        _logBridge = logBridge;
        var presenter = _presenter;
        var session = _session;
        var tree = GetTree();
        _session.SetPresenter(async evt =>
        {
            if (evt.Source != null)
                await AiActionPacing.Wait(tree, evt, session.IsPlayerControlled(evt.Source), AiActionDelaySeconds, presenter.CancellationToken);
            await _dice.WaitForResultsAsync(presenter.CancellationToken);
            logBridge.Present(evt);
            if (evt.Type is BattleEventType.AttackRolled or BattleEventType.SpellCast
                && evt.Source != null && evt.Target != null)
            {
                NoteBoardTarget(evt.Target);
                _cameraRig.FrameAction(GridSpace.CreatureToWorld(evt.Source.GridPosition, evt.Source.TileWidth, SurfaceHeights),
                    GridSpace.CreatureToWorld(evt.Target.GridPosition, evt.Target.TileWidth, SurfaceHeights));
            }
            await presenter.Present(evt);
            if (evt.Type is BattleEventType.DamageDealt or BattleEventType.Healed
                or BattleEventType.CreatureDied
                || evt.Type == BattleEventType.AttackRolled && evt.Degree < PF2e.Data.DegreeOfSuccess.Success)
                _cameraRig.RestorePlanningView();
            RefreshCard();
        });
        // Interactive reaction prompts: the session suspends combat on this Task until the modal
        // panel resolves (works mid-enemy-turn too — the enemy's strike awaits it). The roll that
        // raised the prompt plays the full beat.
        _session.ReactionPromptHandler = async view =>
        {
            _dice.PromoteLatest();
            await _dice.WaitForResultsAsync(presenter.CancellationToken);
            return await ShowReactionPrompt(view);
        };
        _input.Setup(_cameraRig.Camera, setup.GridWidth, setup.GridHeight, SurfaceHeights);
        // One click-vs-drag threshold for the whole gesture: the rig's value wins.
        _input.DragThresholdPixels = _cameraRig.DragThresholdPixels;

        // Per-encounter objects: wire every time.
        WireControllerToView();
        WireSession();
        // Persistent scene nodes: wire once (see _viewWired). Their handlers read the CURRENT
        // controller / session fields, so they stay correct across encounters.
        if (!_viewWired)
        {
            _viewWired = true;
            _input.TileClicked += OnTileClicked;
            _input.TileHovered += OnTileHovered;
            _input.Cancelled += OnCancel;
            _input.HasCancellable = () => _stagedTile != null
                || _controller != null && _controller.Mode != PlayerTurnMode.Idle;
            _input.FocusRequested += () => { ClearPartyFocus(); RefreshCard(); _cameraRig.FocusOnActive(); };
            _turnBar.ChipPressed += id => _controller.DelayAnchorClicked(id);
            _turnBar.UnitPressed += FocusPartyMember;
            WireActionBar();
        }

        RefreshTurnOrder();
        _actionBar.SetInteractable(false);

        _encounterCts = new CancellationTokenSource();
        _presenter.CancellationToken = _encounterCts.Token;
        _controller.CancellationToken = _encounterCts.Token;

        // Fire-and-forget encounter loop. RunAsync owns its own error/cancellation handling — it logs
        // faults through the engine Log and routes to an abort finish, and treats cancellation as a clean
        // stop — so this continuation is only a last backstop: surface anything that still escapes as a
        // loud editor error instead of a silent unobserved-Task soft-lock. Faulted path only.
        RunIntroAndEncounter(session, setup, outgoingPose, outgoingFov, _encounterCts.Token).ContinueWith(
            t => GD.PushError($"[CombatScene] Encounter loop faulted unexpectedly: {t.Exception}"),
            TaskContinuationOptions.OnlyOnFaulted);
    }

    private void ApplyUserSettings() => _dice.AnimationsEnabled = Delve.Settings.UserSettings.DiceReveal;

    public override void _Process(double delta)
    {
        _session?.ReconcileOccupancy();
        RefreshTurnRowsThrottled(delta);
        LayoutBand();
        if (_session != null) LayoutPlates();
        AnchorCommandMenu();
    }

    private void SpawnUnits()
    {
        foreach (var unit in _session.Team1) AddUnitVisual(unit);
        foreach (var unit in _session.Team2) AddUnitVisual(unit);
    }

    private void AddUnitVisual(ICharacter character)
    {
        var visual = UnitVisual3D.Spawn(UnitTokenScene, character, EnemyFolderFor(character), _session.Letters.LetterFor(character));
        visual.Position = GridSpace.CreatureToWorld(character.GridPosition, character.TileWidth, SurfaceHeights);
        _unitLayer.AddChild(visual);
        visual.PlaceOnGround(character.GridPosition, SurfaceHeights);
        _presenter.RegisterUnit(character, visual);
        _tacticalUnits[character.UniqueId] = visual;
    }

    /// <summary>Heroes (PC sheets) have no CreatureStatBlock and resolve their sheet from
    /// HeroSpriteMap, so they get null. Enemies get their sprite folder by creature from
    /// EnemySpriteMap: real art or the size-matched missing-art placeholder.</summary>
    private string? EnemyFolderFor(ICharacter character) => character.CreatureStats != null
        ? EnemySpriteMap.FolderForCreature(_session.Letters.BaseNameFor(character), character.CreatureStats.Size)
        : null;

}
