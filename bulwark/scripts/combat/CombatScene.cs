using System.Collections.Generic;
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
    private static readonly string[] RatFolders =
    {
        "res://assets/sprites/enemies/rat_v1",
        "res://assets/sprites/enemies/rat_v2",
        "res://assets/sprites/enemies/rat_v3",
    };

    private GridOverlay3D _overlay = null!;
    private Node3D _unitLayer = null!;
    private Node3D _popupLayer = null!;
    private GridInput3D _input = null!;
    private OrbitCameraRig _cameraRig = null!;

    private ActionBar _actionBar = null!;
    private CombatLogPanel _log = null!;
    private TurnOrderBar _turnBar = null!;
    private VictoryBanner _victoryBanner = null!;
    private ReactionPromptPanel _reactionPrompt = null!;

    private CombatSession _session = null!;
    private PlayerTurnController _controller = null!;
    private GodotPresenter3D _presenter = null!;

    private readonly Dictionary<int, UnitVisual3D> _visuals = new();
    private int _ratIndex;
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

        _turnBar = GetNode<TurnOrderBar>("%TurnOrderBar");
        _log = GetNode<CombatLogPanel>("%CombatLog");
        _actionBar = GetNode<ActionBar>("%ActionBar");
        _victoryBanner = GetNode<VictoryBanner>("%VictoryBanner");
        _reactionPrompt = GetNode<ReactionPromptPanel>("%ReactionPrompt");
    }

    /// <summary>Entry point: hand an assembled encounter and it plays out.</summary>
    public void StartEncounter(CombatSetup setup)
    {
        _session = new CombatSession();
        _session.Setup(setup);
        _controller = new PlayerTurnController(_session.PlayerActions);
        _presenter = new GodotPresenter3D(_popupLayer);

        _cameraRig.FocusOn(GridSpace.BoardCenter(setup.GridWidth, setup.GridHeight));
        SpawnUnits();

        _session.SetPresenter(_presenter.Present);
        // Interactive reaction prompts: the session suspends combat on this Task until the modal
        // panel resolves Use/Skip (works mid-enemy-turn too — the enemy's strike awaits it).
        _session.ReactionPromptHandler = view => _reactionPrompt.ShowAsync(view);
        _input.Setup(_cameraRig.Camera, setup.GridWidth, setup.GridHeight, OnTileClicked, OnTileHovered, OnCancel);

        WireControllerToView();
        WireActionBar();
        WireSession();

        _logHandler = OnLogEntry;
        CombatLog.OnLogEntry += _logHandler;

        RefreshTurnOrder();
        _actionBar.SetInteractable(false);

        _ = _session.RunAsync();
    }

    public override void _ExitTree()
    {
        if (_logHandler != null)
            CombatLog.OnLogEntry -= _logHandler;
        _session?.Teardown();
    }

    // ---------------------------------------------------------------- Build

    private void SpawnUnits()
    {
        foreach (var unit in _session.Team1) AddUnitVisual(unit);
        foreach (var unit in _session.Team2) AddUnitVisual(unit);
    }

    private void AddUnitVisual(ICharacter character)
    {
        // Heroes (PC sheets) have no CreatureStatBlock; enemies do and get a round-robin rat.
        string? ratFolder = character.CreatureStats != null
            ? RatFolders[_ratIndex++ % RatFolders.Length]
            : null;

        var visual = UnitVisual3D.Create(character, ratFolder);
        visual.Position = GridSpace.GridToWorld(character.GridPosition);
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
        string text = result switch
        {
            PF2e.Core.BattleResult.Team1Wins => "Victory!",
            PF2e.Core.BattleResult.Team2Wins => "Defeat",
            _ => "Draw",
        };
        Color color = result == PF2e.Core.BattleResult.Team1Wins
            ? new Color(1f, 0.9f, 0.4f)
            : new Color(1f, 0.5f, 0.5f);
        _victoryBanner.ShowResult(text, color);
        _actionBar.SetInteractable(false);

        EncounterFinished?.Invoke(result);
    }

    private void OnLogEntry(CombatLogEntry entry)
        => _log.AppendEntry(entry.Message, (int)entry.Severity, entry.IsDetail);
}
