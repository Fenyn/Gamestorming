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
    private Tween? _introFade;
    [Export(PropertyHint.Range, "0,2,0.05")] public float AiActionDelaySeconds { get; set; } = 0.6f;
    private DiceRollPanel _dice = null!;
    // Preloaded token blockout (static subtree authored in the scene); each unit is an instance whose
    // per-unit visuals are applied by UnitVisual3D.Spawn.
    private static readonly PackedScene UnitTokenScene =
        GD.Load<PackedScene>("res://scenes/combat/unit_token.tscn");

    private GridOverlay3D _overlay = null!;
    private MoveBandOverlay3D _moveBands = null!;
    private Node3D _unitLayer = null!;
    private Node3D _popupLayer = null!;
    private GridInput3D _input = null!;
    private OrbitCameraRig _cameraRig = null!;
    private WorldEnvironment _worldEnvironment = null!;
    private DirectionalLight3D _sun = null!;
    private CanvasLayer _hud = null!;

    /// <summary>
    /// The ground under the fight: terrain view, backdrop and placeholder floor. Owns the board's
    /// surface heights, which every elevation-aware view piece reads (unit spawn, presenter tweens,
    /// overlay, input, camera pivot).
    /// </summary>
    private TerrainStage _terrain = null!;
    private TerrainHeightMap? _borrowedHeights;
    private Godot.Environment? _ownedEnvironment;
    private TerrainHeightMap SurfaceHeights => _borrowedHeights ?? _terrain.HeightMap;
    public Camera3D ActiveCamera => _cameraRig.Camera;

    /// <summary>Release combat-owned objects without touching terrain supplied by a dungeon.</summary>
    public void EndHostedEncounter()
    {
        ResetEncounter();
        SetPresentationVisible(false);
        ProcessMode = ProcessModeEnum.Disabled;
        _worldEnvironment.Environment = null;
        _sun.Visible = false;
    }

    private ActionBar _actionBar = null!;
    private ActiveCharacterPanel _activeCharacter = null!;
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
    // Task.Delay / tween waits observe the same signal (see _ExitTree for the cancel-then-teardown order).
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

    /// <summary>
    /// Re-raised from the session when a Recall Knowledge check taught the party something:
    /// (species slug, degree of success as int). A future meta-layer journal subscribes here;
    /// unsubscribed, knowledge simply is not recorded.
    /// </summary>
    public event System.Action<string, int>? RecallKnowledgeLearned;

    public override void _Ready()
    {
        _overlay = GetNode<GridOverlay3D>("%GridOverlay");
        _moveBands = GetNode<MoveBandOverlay3D>("%MoveBands");
        _unitLayer = GetNode<Node3D>("%UnitLayer");
        _popupLayer = GetNode<Node3D>("%PopupLayer");
        _input = GetNode<GridInput3D>("%GridInput");
        _cameraRig = GetNode<OrbitCameraRig>("%CameraRig");
        _terrain = GetNode<TerrainStage>("%TerrainStage");
        _worldEnvironment = GetNode<WorldEnvironment>("WorldEnvironment");
        _ownedEnvironment = _worldEnvironment.Environment;
        _sun = GetNode<DirectionalLight3D>("DirectionalLight3D");
        _hud = GetNode<CanvasLayer>("%HUD");

        _turnBar = GetNode<TurnOrderBar>("%TurnOrderBar");
        _log = GetNode<CombatLogPanel>("%CombatLog");
        _dice = GetNode<DiceRollPanel>("%DiceRoll");
        _log.RollObserved += _dice.ShowRoll;
        _actionBar = GetNode<ActionBar>("%ActionBar");
        _activeCharacter = GetNode<ActiveCharacterPanel>("%ActiveCharacter");
        _victoryBanner = GetNode<VictoryBanner>("%VictoryBanner");
        _victoryBanner.Continued += () => ResultsContinued?.Invoke();
        _reactionPrompt = GetNode<ReactionPromptPanel>("%ReactionPrompt");
        _help = GetNode<HelpOverlay>("%HelpOverlay");
        _inspectPanel = GetNode<UnitInspectPanel>("%UnitInspect");
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

    public void ShowResultParty(System.Collections.Generic.IReadOnlyList<PF2e.Core.PF2eCharacter> party)
        => _victoryBanner.ShowParty(party);

    public void ShowRewards(string rewards, string progressText, double progress)
        => _victoryBanner.ShowRewards(rewards, progressText, progress);

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
    /// Capture/dev use — the combat shot spike photographs the route preview with it. Hovers the
    /// farthest tile in the band that costs <paramref name="actions"/>, as if the mouse were there.
    /// False when no such tile is showing. Pass through <see cref="ClearHover"/> afterwards.
    /// </summary>
    public bool HoverBandTile(int actions)
    {
        var from = _session?.CurrentActor?.GridPosition;
        if (from == null) return false;
        PF2e.Vector2Int? best = null;
        int bestDistance = -1;
        foreach (var (tile, option) in _lastBands)
        {
            if (option.Kind != MoveKind.Stride || option.Actions != actions) continue;
            int distance = System.Math.Abs(tile.x - from.Value.x) + System.Math.Abs(tile.y - from.Value.y);
            if (distance > bestDistance) { bestDistance = distance; best = tile; }
        }
        if (best == null) return false;
        OnTileHovered(best);
        return true;
    }

    /// <summary>
    /// Capture/dev use — photographs the markers on a slope. Hovers the band tile whose corners
    /// differ most in height and returns its world centre; false on a flat board or flat bands.
    /// </summary>
    public bool HoverSteepestBandTile(out Vector3 world)
    {
        world = Vector3.Zero;
        var heights = SurfaceHeights;
        if (!heights.HasTerrain) return false;
        PF2e.Vector2Int? best = null;
        int bestSpan = 0;
        foreach (var (tile, _) in _lastBands)
        {
            int span = heights.Corners(tile).HeightSpan;
            if (span > bestSpan) { bestSpan = span; best = tile; }
        }
        if (best == null) return false;
        OnTileHovered(best);
        world = GridSpace.GridToWorld(best.Value, heights);
        return true;
    }

    /// <summary>Capture/dev use: end a <see cref="HoverBandTile"/> hover.</summary>
    public void ClearHover() => OnTileHovered(null);

    /// <summary>
    /// How many unit visuals the presenter holds. Equals the encounter's unit count while an
    /// encounter runs, and 0 between encounters — the reset spike asserts on it.
    /// </summary>
    public int RegisteredUnitCount => _presenter?.UnitCount ?? 0;

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
        _sun.Visible = borrowedHeights == null;
        if (borrowedHeights == null)
        {
            _worldEnvironment.Environment = _ownedEnvironment;
            _terrain.Build(_session.MapLayout, setup.BiomeId,
                setup.GridWidth, setup.GridHeight, _worldEnvironment, _sun);
        }
        else
        {
            _terrain.Visible = false;
            _worldEnvironment.Environment = null;
            _sun.Visible = false;
        }

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
        _squad.Setup(SquadViews());

        var logBridge = new CombatLogBridge(_log, _session.Team1, _session.Team2);
        _logBridge = logBridge;
        var presenter = _presenter;
        var session = _session;
        _session.SetPresenter(async evt =>
        {
            if (evt.Source != null)
                await AiActionPacing.Wait(evt, session.IsPlayerControlled(evt.Source), AiActionDelaySeconds, presenter.CancellationToken);
            await _dice.WaitForResultsAsync(presenter.CancellationToken);
            logBridge.Present(evt);
            if (evt.Type is BattleEventType.AttackRolled or BattleEventType.SpellCast
                && evt.Source != null && evt.Target != null)
                _cameraRig.FrameAction(GridSpace.CreatureToWorld(evt.Source.GridPosition, evt.Source.TileWidth, SurfaceHeights),
                    GridSpace.CreatureToWorld(evt.Target.GridPosition, evt.Target.TileWidth, SurfaceHeights));
            await presenter.Present(evt);
            if (evt.Type is BattleEventType.DamageDealt or BattleEventType.Healed
                or BattleEventType.CreatureDied
                || evt.Type == BattleEventType.AttackRolled && evt.Degree < PF2e.Data.DegreeOfSuccess.Success)
                _cameraRig.RestorePlanningView();
            _activeCharacter.Render(ActiveCharacterView.From(session.CurrentActor));
        });
        // Interactive reaction prompts: the session suspends combat on this Task until the modal
        // panel resolves Use/Skip (works mid-enemy-turn too — the enemy's strike awaits it).
        _session.ReactionPromptHandler = async view =>
        {
            await _dice.WaitForResultsAsync(presenter.CancellationToken);
            return await _reactionPrompt.ShowAsync(view);
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
            _input.FocusRequested += () => { ClearPartyFocus(); _inspectPanel.Render(null); _cameraRig.FocusOnActive(); };
            _turnBar.ChipPressed += id => _controller.DelayAnchorClicked(id);
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

    private async Task RunIntroAndEncounter(CombatSession session, CombatSetup setup,
        Transform3D? outgoingPose, float outgoingFov, CancellationToken token)
    {
        try
        {
            // Headless simulations retain their immediate turn-start contract.
            if (EncounterIntroEnabled && DisplayServer.GetName() != "headless")
            {
                var intro = GetNode<Control>("%EncounterIntro");
                GetNode<Label>("%EncounterSubtitle").Text = $"{setup.Enemies.Count} {(setup.Enemies.Count == 1 ? "foe" : "foes")} ahead"
                    + (setup.Allies.Count > 0 ? $"\n{setup.Allies[0].Unit.Name} fights beside you as an ally." : "");
                intro.Modulate = Colors.Transparent;
                intro.Show();
                _input.ProcessMode = ProcessModeEnum.Disabled;
                _introFade = CreateTween();
                _introFade.TweenProperty(intro, "modulate", Colors.White, 0.2);
                _introFade.TweenInterval(1.05);
                _introFade.TweenProperty(intro, "modulate", Colors.Transparent, 0.3);
                await _cameraRig.PlayIntro(outgoingPose ?? _cameraRig.Camera.GlobalTransform, outgoingFov, token);
                token.ThrowIfCancellationRequested();
                intro.Hide();
                _input.ProcessMode = ProcessModeEnum.Inherit;
            }
            await session.RunAsync(token);
        }
        catch (System.OperationCanceledException) { }
    }

    public override void _ExitTree() => StopEncounter();

    /// <summary>
    /// Stop the encounter loop and unwire everything it owns: log subscription, cancellation source,
    /// and the session (engine globals). Node children are NOT touched — the scene may be leaving
    /// the tree, where re-parenting children is unsafe; <see cref="ResetEncounter"/> adds that step,
    /// terrain included.
    /// Null-tolerant and idempotent, so it is safe before the first encounter and twice in a row.
    /// </summary>
    private void StopEncounter()
    {
        _logBridge?.Dispose();
        // Cancel the awaited pipeline before clearing dice can release its presentation gate.
        _encounterCts?.Cancel();
        _cameraRig?.CancelIntro();
        _cameraRig?.RestorePlanningView(true);
        _introFade?.Kill();
        _introFade = null;
        GetNodeOrNull<Control>("%EncounterIntro")?.Hide();
        if (_input != null) _input.ProcessMode = ProcessModeEnum.Inherit;
        _dice?.ClearRoll();
        _activeCharacter?.Render(null);
        _logBridge = null;
        // Cancel BEFORE teardown: the loop may be parked in a presenter Task.Delay / tween wait or on the
        // player-turn TCS. Cancelling releases those so it unwinds without resuming on freed nodes;
        // Teardown then clears the engine statics/delegates and completes any still-pending player turn.
        _session?.Teardown();
        _encounterCts?.Dispose();
        _encounterCts = null;
    }

    /// <summary>
    /// Put the scene back in the state <see cref="StartEncounter"/> expects. On top of
    /// <see cref="StopEncounter"/> it frees the previous encounter's unit tokens, damage popups and
    /// effect nodes, drops the presenter's unit registry (which would otherwise hold freed visuals),
    /// releases the controller, and clears the terrain back to the flat placeholder board. Called at
    /// the top of every StartEncounter, so the first call runs against an empty scene and does nothing.
    /// </summary>
    private void ResetEncounter()
    {
        StopEncounter();
        ResetTacticalPresentation();

        _controller?.EndControl();
        _controller = null!;
        _session = null!;

        // Registrations first, nodes second: the map must never hand out a freed visual.
        _presenter?.ClearUnits();
        _presenter = null!;

        FreeChildren(_unitLayer);
        FreeChildren(_popupLayer);

        // Terrain last, after the loop is released and the session is unwired: nothing may still be
        // resolving a position against the map when its meshes and collider go away. Clear also shows
        // the checker plane again, which a generated map hid.
        _terrain.Clear();
        _borrowedHeights = null;

        _victoryBanner.HideResult();
    }

    /// <summary>
    /// Free every child of <paramref name="parent"/> NOW. RemoveChild before QueueFree, because
    /// QueueFree alone leaves the node in the tree until the end of the frame, and the caller
    /// (and its tests) reads the child count immediately after.
    /// </summary>
    private static void FreeChildren(Node parent)
    {
        foreach (var child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }

    // ---------------------------------------------------------------- Build

    public override void _Process(double delta)
    {
        _session?.ReconcileOccupancy();
        RefreshSquad(delta);
    }

    private void SpawnUnits()
    {
        foreach (var unit in _session.Team1) AddUnitVisual(unit);
        foreach (var unit in _session.Team2) AddUnitVisual(unit);
    }

    private void AddUnitVisual(ICharacter character)
    {
        // Heroes (PC sheets) have no CreatureStatBlock and resolve their sheet from HeroSpriteMap;
        // enemies do, and get their sprite folder by creature from EnemySpriteMap (real art or the
        // size-matched missing-art placeholder).
        string? enemyFolder = character.CreatureStats != null
            ? EnemySpriteMap.FolderForCreature(character.Name, character.CreatureStats.Size)
            : null;

        var visual = UnitVisual3D.Spawn(UnitTokenScene, character, enemyFolder);
        visual.Position = GridSpace.CreatureToWorld(character.GridPosition, character.TileWidth, SurfaceHeights);
        _unitLayer.AddChild(visual);
        visual.PlaceOnGround(character.GridPosition, SurfaceHeights);
        _presenter.RegisterUnit(character, visual);
        _tacticalUnits[character.UniqueId] = visual;
    }

    // ---------------------------------------------------------------- Wiring

    private void WireControllerToView()
    {
        _session.CombatantRemoved += character =>
        {
            _tacticalUnits.Remove(character.UniqueId);
            if (_focusedMember == character.UniqueId) _focusedMember = null;
            _presenter.RetireUnit(character);
        };
        _controller.HighlightsChanged += (tiles, kind) => _overlay.SetHighlights(tiles, kind);
        _controller.MoveBandsChanged += bands =>
        {
            _lastBands = bands;
            _moveBands.SetBands(bands);
            _overlay.SetPathBands(bands);
        };
        _controller.HoverTileChanged += tile => _moveBands.SetHoverTile(tile);
        _controller.MoveHoverChanged += hover => _actionBar.SetMoveHint(hover);
        _controller.PathPreviewChanged += path => { _overlay.SetPathPreview(path); PreviewDestination(path); };
        _controller.AreaPreviewChanged += tiles => _overlay.SetAreaPreview(tiles);
        _controller.AttackPreviewChanged += preview => _actionBar.ShowAttackPreview(preview);
        _controller.ButtonStateChanged += state => _actionBar.Render(state);
        _controller.ButtonStateChanged += _ =>
            _activeCharacter.Render(ActiveCharacterView.From(_session.CurrentActor));
        _controller.SpellTargetsChanged += _actionBar.SetSpellTargetSelection;
        _actionBar.ConfirmTargetsPressed += () => _controller.ConfirmSpellTargets();
        _controller.ModeChanged += _ => { ClearStagedOrder(); ClearPartyFocus(); };
        _controller.ActionCompleted += () => _cameraRig.RestorePlanningView();
        _controller.ModeChanged += mode => _actionBar.SetTargetingHint(
            mode != PlayerTurnMode.Idle, mode == PlayerTurnMode.SelectingDelaySlot);
        _controller.EndTurnRequested += () => _session.RequestEndPlayerTurn();
        _controller.DelayBlockedReason = character => _session.DelayBlockedReason(character);
        _controller.DelayAnchors = _ => _session.GetDelayAnchors();
        _controller.DelayAnchorsChanged += ids =>
        {
            _delayPickIds = new HashSet<int>(ids);
            RefreshTurnOrder();
        };
        _controller.DelayRequested += (_, after) => _session.RequestDelay(after);
    }

    private void WireActionBar()
    {
        _actionBar.StrikePressed += () => _controller.BeginStrike();
        _actionBar.RaiseShieldPressed += () => _controller.RaiseShield();
        _actionBar.EndTurnPressed += () => _controller.EndTurn();
        _actionBar.DelayPressed += () => _controller.BeginDelay();
        _actionBar.SpellChipPressed += (spellId, variant) => _controller.BeginSpell(spellId, variant);
        _actionBar.SkillChipPressed += actionId => _controller.BeginSkill(actionId);
        _actionBar.AiToggled += on =>
        {
            var actor = _session.CurrentActor;
            if (actor != null) _session.SetAiToggle(actor, on);
        };
        _actionBar.AutoReactToggled += on =>
        {
            var actor = _session.CurrentActor;
            if (actor != null) _session.SetAutoReactions(actor, on);
        };
    }

    private void WireSession()
    {
        var session = _session;
        _session.PlayerTurnStarted += character =>
        {
            if (!ReferenceEquals(_session, session)) return;
            _controller.BeginTurn(character);
            _actionBar.SetInteractable(true);
            _actionBar.SetAiToggle(_session.IsAiToggled(character));
            _actionBar.SetAutoReactToggle(_session.IsAutoReactions(character));
        };
        _session.PlayerTurnEnded += () =>
        {
            if (!ReferenceEquals(_session, session)) return;
            // EndControl clears the overlay through the controller's own transient reset.
            _controller.EndControl();
            _actionBar.SetInteractable(false);
        };
        _session.TurnChanged += () => { if (ReferenceEquals(_session, session)) { ClearPartyFocus(); RefreshTurnOrder(); } };
        _session.EncounterFinished += result => { if (ReferenceEquals(_session, session)) ShowResult(result); };
        // Recall Knowledge that actually taught the party something: re-raise for a hosting scene's
        // monster journal. No subscriber in the combat proof — the executor falls back to
        // all-creature-info-known.
        _session.RecallKnowledgeLearned += (creatureId, degree) =>
            RecallKnowledgeLearned?.Invoke(creatureId, (int)degree);
    }

    // ---------------------------------------------------------------- Input handlers

    private void OnTileClicked(PF2e.Vector2Int pos) => HandleTacticalClick(pos);

    /// <summary>Forwards hover to the targeting controller (path/attack preview) AND, independently,
    /// to the always-on inspect card — the two coexist in every mode, per CLAUDE.md's passive-UI
    /// wiring: this Node3D reads engine occupancy and hands the UI a view model, nothing more.</summary>
    private void OnTileHovered(PF2e.Vector2Int? pos)
    {
        if (_stagedTile == null) _controller.TileHovered(pos);
        var inspected = pos.HasValue ? _session.PlayerActions.GetUnitInspect(pos.Value) : null;
        if (inspected == null && _focusedMember is { } id && _tacticalUnits.TryGetValue(id, out var focused))
            inspected = UnitInspectFactory.BuildInspectView(focused.Character);
        _inspectPanel.Render(inspected);
    }

    private void OnCancel() { ClearStagedOrder(); _controller.Cancel(); }

    // ---------------------------------------------------------------- View refresh

    private void RefreshTurnOrder()
    {
        var order = _session.TurnOrder;
        if (order == null) return;

        var current = _session.CurrentActor;
        _activeCharacter.Render(ActiveCharacterView.From(current));
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
        _turnBar.Render(views);
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
    }

    private UnitView UnitViewFor(PF2e.TurnManagement.TurnEntry entry, PF2e.Core.ICharacter? current, bool delayed = false)
    {
        var c = entry.Character;
        return new UnitView
        {
            Name = c.Name,
            Id = c.UniqueId,
            TeamId = c.TeamId,
            IsCurrent = c == current,
            IsDead = c.Health != null && c.Health.IsDead,
            IsDelayed = delayed,
            IsPickable = _delayPickIds.Contains(c.UniqueId),
            Initiative = entry.Initiative,
            Hp = c.Health?.CurrentHP ?? 0,
            MaxHp = c.Health?.MaxHP ?? 0,
        };
    }

    private void ShowResult(PF2e.Core.BattleResult result)
    {
        // Only a Team1 win is a victory; everything else (loss OR draw) is scored as a defeat downstream
        // — penalty + day advance — so the banner reads "Defeat" for a draw too rather than lying "Draw".
        string text = result == PF2e.Core.BattleResult.Team1Wins ? "Victory!" : "Defeat";
        Color color = result == PF2e.Core.BattleResult.Team1Wins
            ? UiColors.Victory
            : UiColors.Defeat;
        _tacticalFinished = true;
        ClearStagedOrder();
        _victoryBanner.ShowResult(text, color);
        _actionBar.SetInteractable(false);

        EncounterFinished?.Invoke(result);
    }

}
