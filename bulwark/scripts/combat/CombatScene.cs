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
    private const string ActionBarScene = "res://scenes/ui/action_bar.tscn";
    private const string CombatLogScene = "res://scenes/ui/combat_log_panel.tscn";
    private const string TurnOrderScene = "res://scenes/ui/turn_order_bar.tscn";

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
    private CanvasLayer _hud = null!;

    private ActionBar _actionBar = null!;
    private CombatLogPanel _log = null!;
    private TurnOrderBar _turnBar = null!;
    private Control _victoryOverlay = null!;
    private Label _victoryLabel = null!;

    private CombatSession _session = null!;
    private PlayerTurnController _controller = null!;
    private GodotPresenter3D _presenter = null!;

    private readonly Dictionary<int, UnitVisual3D> _visuals = new();
    private int _ratIndex;
    private System.Action<CombatLogEntry>? _logHandler;

    public override void _Ready()
    {
        _overlay = GetNode<GridOverlay3D>("%GridOverlay");
        _unitLayer = GetNode<Node3D>("%UnitLayer");
        _popupLayer = GetNode<Node3D>("%PopupLayer");
        _input = GetNode<GridInput3D>("%GridInput");
        _cameraRig = GetNode<OrbitCameraRig>("%CameraRig");
        _hud = GetNode<CanvasLayer>("%HUD");

        BuildHud();
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

    private void BuildHud()
    {
        _turnBar = GD.Load<PackedScene>(TurnOrderScene).Instantiate<TurnOrderBar>();
        Anchor(_turnBar, 0, 0, 1, 0, 8, 8, -8, 40);
        _hud.AddChild(_turnBar);

        _log = GD.Load<PackedScene>(CombatLogScene).Instantiate<CombatLogPanel>();
        Anchor(_log, 1, 0, 1, 1, -400, 48, -8, -72);
        _hud.AddChild(_log);

        _actionBar = GD.Load<PackedScene>(ActionBarScene).Instantiate<ActionBar>();
        Anchor(_actionBar, 0, 1, 1, 1, 8, -60, -8, -8);
        _hud.AddChild(_actionBar);

        BuildVictoryOverlay();
    }

    private void BuildVictoryOverlay()
    {
        _victoryOverlay = new Control { Visible = false, MouseFilter = Control.MouseFilterEnum.Stop };
        _victoryOverlay.SetAnchorsPreset(Control.LayoutPreset.FullRect);

        var dim = new ColorRect { Color = new Color(0, 0, 0, 0.55f) };
        dim.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        _victoryOverlay.AddChild(dim);

        var center = new CenterContainer();
        center.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        _victoryOverlay.AddChild(center);

        var box = new VBoxContainer();
        box.AddThemeConstantOverride("separation", 16);
        center.AddChild(box);

        _victoryLabel = new Label { Text = "", HorizontalAlignment = HorizontalAlignment.Center };
        _victoryLabel.AddThemeFontSizeOverride("font_size", 48);
        box.AddChild(_victoryLabel);

        var restart = new Button { Text = "Restart" };
        restart.Pressed += () => GetTree().ReloadCurrentScene();
        box.AddChild(restart);

        _hud.AddChild(_victoryOverlay);
    }

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
        _actionBar.AiToggled += on =>
        {
            var actor = _session.CurrentActor;
            if (actor != null) _session.SetAiToggle(actor, on);
        };
    }

    private void WireSession()
    {
        _session.PlayerTurnStarted += character =>
        {
            _controller.BeginTurn(character);
            _actionBar.SetInteractable(true);
            _actionBar.SetAiToggle(_session.IsAiToggled(character));
        };
        _session.PlayerTurnEnded += () =>
        {
            _controller.EndControl();
            _overlay.SetHighlights(System.Array.Empty<PF2e.Vector2Int>(), HighlightKind.None);
            _overlay.SetPathPreview(null);
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
        _victoryLabel.Text = result switch
        {
            PF2e.Core.BattleResult.Team1Wins => "Victory!",
            PF2e.Core.BattleResult.Team2Wins => "Defeat",
            _ => "Draw",
        };
        _victoryLabel.AddThemeColorOverride("font_color",
            result == PF2e.Core.BattleResult.Team1Wins ? new Color(1f, 0.9f, 0.4f) : new Color(1f, 0.5f, 0.5f));
        _victoryOverlay.Visible = true;
        _actionBar.SetInteractable(false);
    }

    private void OnLogEntry(CombatLogEntry entry)
        => _log.AppendEntry(entry.Message, (int)entry.Severity, entry.IsDetail);

    private static void Anchor(Control c, float al, float at, float ar, float ab,
        float ol, float ot, float or, float ob)
    {
        c.AnchorLeft = al; c.AnchorTop = at; c.AnchorRight = ar; c.AnchorBottom = ab;
        c.OffsetLeft = ol; c.OffsetTop = ot; c.OffsetRight = or; c.OffsetBottom = ob;
    }
}
