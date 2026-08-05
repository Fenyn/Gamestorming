using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Bulwark.Combat.Map;
using Bulwark.Data;
using Bulwark.UI;
using Godot;
using PF2e.Core;

namespace Bulwark.Combat;

/// <summary>
/// Node3D root that assembles a 2.5D tactical combat: builds the <see cref="CombatSession"/>, spawns
/// billboard-sprite unit tokens on the 3D board, instances the 2D CanvasLayer HUD scenes, and wires
/// controller &lt;-&gt; UI &lt;-&gt; session together, then starts the encounter loop. Thin adapter — all rules
/// live in the plain-C# session/controller; this only owns node types and grid&lt;-&gt;world coordinates.
/// </summary>
public partial class CombatScene : Node3D
{
    // Preloaded token blockout (static subtree authored in the scene); each unit is an instance whose
    // per-unit visuals are applied via UnitVisual3D.Configure.
    private static readonly PackedScene UnitTokenScene =
        GD.Load<PackedScene>("res://scenes/combat/unit_token.tscn");

    private GridOverlay3D _overlay = null!;
    private Node3D _unitLayer = null!;
    private Node3D _popupLayer = null!;
    private GridInput3D _input = null!;
    private OrbitCameraRig _cameraRig = null!;
    private Node3D _mapRoot = null!;
    private MeshInstance3D _floor = null!;

    /// <summary>Generated terrain for this encounter, added under %MapRoot. Null on a flat board.</summary>
    private MapView3D? _mapView;

    /// <summary>
    /// The board's surface heights — the one instance every elevation-aware view piece reads (unit
    /// spawn, presenter tweens, overlay, input, camera pivot). <see cref="TerrainHeightMap.Flat"/> on a
    /// flat board, which makes both paths run the same code with all-zero heights.
    /// </summary>
    private TerrainHeightMap _heightMap = TerrainHeightMap.Flat;

    private ActionBar _actionBar = null!;
    private CombatLogPanel _log = null!;
    private TurnOrderBar _turnBar = null!;
    private VictoryBanner _victoryBanner = null!;
    private ReactionPromptPanel _reactionPrompt = null!;
    private InputLegend _legend = null!;

    /// <summary>
    /// Upper-left controls legend rows — render data only, mirroring the actual bindings in
    /// <see cref="OrbitCameraRig"/> (MMB/RMB-drag orbit, wheel zoom, WASD pan) and
    /// <see cref="GridInput3D"/> (LMB click, Esc / stationary RMB click cancel).
    /// </summary>
    private static readonly (string Keys, string Action)[] LegendRows =
    {
        ("LMB", "Select · Confirm"),
        ("Esc / RMB", "Cancel targeting"),
        ("MMB / RMB drag", "Orbit camera"),
        ("Wheel / WASD", "Zoom · Pan camera"),
        ("End Turn", "Button on action bar"),
    };

    private CombatSession _session = null!;
    private PlayerTurnController _controller = null!;
    private GodotPresenter3D _presenter = null!;

    // Cancels the fire-and-forget encounter loop on scene exit. Shared with the presenter so its paced
    // Task.Delay / tween waits observe the same signal (see _ExitTree for the cancel-then-teardown order).
    private CancellationTokenSource? _encounterCts;

    private readonly Dictionary<int, UnitVisual3D> _visuals = new();
    private System.Action<CombatLogEntry>? _logHandler;

    /// <summary>
    /// Raised once when the encounter result is known (relays the session's EncounterFinished).
    /// The scene assembler forwards this to GameState.CompleteEncounter for squad attrition/XP.
    /// </summary>
    public event System.Action<PF2e.Core.BattleResult>? EncounterFinished;

    public override void _Ready()
    {
        _overlay = GetNode<GridOverlay3D>("%GridOverlay");
        _unitLayer = GetNode<Node3D>("%UnitLayer");
        _popupLayer = GetNode<Node3D>("%PopupLayer");
        _input = GetNode<GridInput3D>("%GridInput");
        _cameraRig = GetNode<OrbitCameraRig>("%CameraRig");
        _mapRoot = GetNode<Node3D>("%MapRoot");
        _floor = GetNode<MeshInstance3D>("%PlaceholderFloor");

        _turnBar = GetNode<TurnOrderBar>("%TurnOrderBar");
        _log = GetNode<CombatLogPanel>("%CombatLog");
        _actionBar = GetNode<ActionBar>("%ActionBar");
        _victoryBanner = GetNode<VictoryBanner>("%VictoryBanner");
        _reactionPrompt = GetNode<ReactionPromptPanel>("%ReactionPrompt");
        _legend = GetNode<InputLegend>("%ControlsLegend");
        _legend.SetRows(LegendRows);
    }

    /// <summary>Entry point: hand an assembled encounter and it plays out.</summary>
    public void StartEncounter(CombatSetup setup)
    {
        _session = new CombatSession();
        _session.Setup(setup);
        foreach (string correction in _session.SetupCorrections)
            GD.PushWarning($"[CombatScene] {correction}");
        _controller = new PlayerTurnController(_session.PlayerActions);

        // Board surface first: everything below is positioned against it.
        BuildBoard(setup);

        _presenter = new GodotPresenter3D(_popupLayer, _heightMap);
        _overlay.SetHeightMap(_heightMap);

        _cameraRig.FocusOn(GridSpace.BoardCenter(setup.GridWidth, setup.GridHeight, _heightMap));
        SpawnUnits();

        _session.SetPresenter(_presenter.Present);
        // Interactive reaction prompts: the session suspends combat on this Task until the modal
        // panel resolves Use/Skip (works mid-enemy-turn too — the enemy's strike awaits it).
        _session.ReactionPromptHandler = view => _reactionPrompt.ShowAsync(view);
        _input.Setup(_cameraRig.Camera, setup.GridWidth, setup.GridHeight,
            OnTileClicked, OnTileHovered, OnCancel, _heightMap);
        // One click-vs-drag threshold for the whole gesture: the rig's value wins.
        _input.DragThresholdPixels = _cameraRig.DragThresholdPixels;

        WireControllerToView();
        WireActionBar();
        WireSession();

        _logHandler = OnLogEntry;
        CombatLog.OnLogEntry += _logHandler;

        RefreshTurnOrder();
        _actionBar.SetInteractable(false);

        _encounterCts = new CancellationTokenSource();
        _presenter.CancellationToken = _encounterCts.Token;

        // Fire-and-forget encounter loop. RunAsync owns its own error/cancellation handling — it logs
        // faults through the engine Log and routes to an abort finish, and treats cancellation as a clean
        // stop — so this continuation is only a last backstop: surface anything that still escapes as a
        // loud editor error instead of a silent unobserved-Task soft-lock. Faulted path only.
        _session.RunAsync(_encounterCts.Token).ContinueWith(
            t => GD.PushError($"[CombatScene] Encounter loop faulted unexpectedly: {t.Exception}"),
            TaskContinuationOptions.OnlyOnFaulted);
    }

    public override void _ExitTree()
    {
        if (_logHandler != null)
            CombatLog.OnLogEntry -= _logHandler;
        // Cancel BEFORE teardown: the loop may be parked in a presenter Task.Delay / tween wait or on the
        // player-turn TCS. Cancelling releases those so it unwinds without resuming on freed nodes;
        // Teardown then clears the engine statics/delegates and completes any still-pending player turn.
        _encounterCts?.Cancel();
        _session?.Teardown();
        _encounterCts?.Dispose();
        _encounterCts = null;

        // Terrain last, after the loop is released and the session is unwired: nothing may still be
        // resolving a position against the map when its meshes and collider go away.
        _mapView?.Clear();
        _mapView = null;
        _heightMap = TerrainHeightMap.Flat;
    }

    // ---------------------------------------------------------------- Build

    /// <summary>
    /// Put a surface under the fight and publish its heights into <see cref="_heightMap"/>.
    ///
    /// With a generated layout: build the terrain mesh + trimesh collider under %MapRoot and hide the
    /// placeholder floor. Without one: the original flat board, byte for byte — the checker plane is
    /// sized and centred exactly as before and the height map is the all-zeros null object, so every
    /// downstream call resolves to the same Y = 0 it always did.
    /// </summary>
    private void BuildBoard(CombatSetup setup)
    {
        var layout = _session.MapLayout;
        if (layout == null)
        {
            // The floor mesh is sized from the setup so every board dimension renders correctly —
            // grid tile (x, y) spans world x..x+1 / y..y+1, so a WxH plane sits at BoardCenter.
            // The checker shader works in world space and follows automatically.
            if (_floor.Mesh is PlaneMesh floorPlane)
                floorPlane.Size = new Vector2(setup.GridWidth, setup.GridHeight);
            _floor.Position = GridSpace.BoardCenter(setup.GridWidth, setup.GridHeight);
            _heightMap = TerrainHeightMap.Flat;
            return;
        }

        // A biome with no theme is a content bug (DataValidation covers it), not a reason to lose the
        // encounter — say so loudly and dress the map in the fallback palette.
        string biomeId = setup.BiomeId ?? MapThemes.Forest.BiomeId;
        if (!MapThemes.TryGet(biomeId, out var theme))
            GD.PushWarning($"[CombatScene] No map theme for biome '{biomeId}'; using '{theme.BiomeId}'.");

        _mapView = new MapView3D { Name = "MapView" };
        _mapRoot.AddChild(_mapView);
        _mapView.Build(layout, theme);
        _floor.Visible = false;

        _heightMap = new TerrainHeightMap(layout, theme.HeightScale);
    }

    private void SpawnUnits()
    {
        foreach (var unit in _session.Team1) AddUnitVisual(unit);
        foreach (var unit in _session.Team2) AddUnitVisual(unit);
    }

    private void AddUnitVisual(ICharacter character)
    {
        // Heroes (PC sheets) have no CreatureStatBlock and resolve their sheet from HeroSpriteMap;
        // enemies do, and get their sprite folder by creature from EnemySpriteMap (all rats today).
        string? enemyFolder = character.CreatureStats != null
            ? EnemySpriteMap.FolderForCreature(character.Name)
            : null;

        var visual = UnitTokenScene.Instantiate<UnitVisual3D>();
        visual.Configure(character, enemyFolder);
        visual.Position = GridSpace.GridToWorld(character.GridPosition, _heightMap);
        _unitLayer.AddChild(visual);
        visual.SetCamera(_cameraRig.Camera);
        _visuals[character.UniqueId] = visual;
        _presenter.RegisterUnit(character, visual);
    }

    // ---------------------------------------------------------------- Wiring

    private void WireControllerToView()
    {
        _controller.HighlightsChanged += (tiles, kind) => _overlay.SetHighlights(tiles, kind);
        _controller.PathPreviewChanged += path => _overlay.SetPathPreview(path);
        _controller.AreaPreviewChanged += tiles => _overlay.SetAreaPreview(tiles);
        _controller.AttackPreviewChanged += preview => _actionBar.ShowAttackPreview(preview);
        _controller.ButtonStateChanged += state => _actionBar.Render(state);
        _controller.ModeChanged += mode => _actionBar.SetTargetingHint(mode != PlayerTurnMode.Idle);
        _controller.EndTurnRequested += () => _session.RequestEndPlayerTurn();
    }

    private void WireActionBar()
    {
        _actionBar.MovePressed += () => _controller.BeginMove();
        _actionBar.StepPressed += () => _controller.BeginStep();
        _actionBar.StrikePressed += () => _controller.BeginStrike();
        _actionBar.RaiseShieldPressed += () => _controller.RaiseShield();
        _actionBar.EndTurnPressed += () => _controller.EndTurn();
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
        _session.PlayerTurnStarted += character =>
        {
            _controller.BeginTurn(character);
            _actionBar.SetInteractable(true);
            _actionBar.SetAiToggle(_session.IsAiToggled(character));
            _actionBar.SetAutoReactToggle(_session.IsAutoReactions(character));
        };
        _session.PlayerTurnEnded += () =>
        {
            _controller.EndControl();
            _overlay.SetHighlights(System.Array.Empty<PF2e.Vector2Int>(), HighlightKind.None);
            _overlay.SetPathPreview(null);
            _overlay.SetAreaPreview(System.Array.Empty<PF2e.Vector2Int>());
            _actionBar.SetInteractable(false);
        };
        _session.TurnChanged += RefreshTurnOrder;
        _session.EncounterFinished += ShowResult;
    }

    // ---------------------------------------------------------------- Input handlers

    private void OnTileClicked(PF2e.Vector2Int pos) => _controller.TileClicked(pos);
    private void OnTileHovered(PF2e.Vector2Int? pos) => _controller.TileHovered(pos);
    private void OnCancel() => _controller.Cancel();

    // ---------------------------------------------------------------- View refresh

    private void RefreshTurnOrder()
    {
        var order = _session.TurnOrder;
        if (order == null) return;

        var current = _session.CurrentActor;
        var views = new List<UnitView>(order.Count);
        foreach (var entry in order)
        {
            var c = entry.Character;
            views.Add(new UnitView
            {
                Name = c.Name,
                TeamId = c.TeamId,
                IsCurrent = c == current,
                IsDead = c.Health != null && c.Health.IsDead,
                Initiative = entry.Initiative,
            });
        }
        _turnBar.Render(views);

        bool playerTurn = current != null && _session.IsPlayerControlled(current);
        _actionBar.SetInteractable(playerTurn);
    }

    private void ShowResult(PF2e.Core.BattleResult result)
    {
        // Only a Team1 win is a victory; everything else (loss OR draw) is scored as a defeat downstream
        // — penalty + day advance — so the banner reads "Defeat" for a draw too rather than lying "Draw".
        string text = result == PF2e.Core.BattleResult.Team1Wins ? "Victory!" : "Defeat";
        Color color = result == PF2e.Core.BattleResult.Team1Wins
            ? UiPalette.VictoryGold
            : UiPalette.DefeatRed;
        _victoryBanner.ShowResult(text, color);
        _actionBar.SetInteractable(false);

        EncounterFinished?.Invoke(result);
    }

    private void OnLogEntry(CombatLogEntry entry)
        => _log.AppendEntry(entry.Message, (int)entry.Severity, entry.IsDetail);
}
