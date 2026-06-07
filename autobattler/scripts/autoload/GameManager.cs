using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public partial class GameManager : Control
{
    public enum Phase { Loading, Shop, Positioning, Combat, Result, GameOver }

    private DataManager _dataManager;
    private PlayerState _player;
    private ShopSystem _shop;
    private EncounterScaler _scaler;
    private CombatOrchestrator _orchestrator;
    private GodotPresenter _presenter;

    private Phase _currentPhase = Phase.Loading;
    private float _combatSpeed = 1.0f;

    // UI containers
    private VBoxContainer _rootLayout;
    private HBoxContainer _topBar;
    private Label _goldLabel;
    private Label _hpLabel;
    private Label _roundLabel;
    private Label _levelLabel;
    private Label _phaseLabel;

    private HBoxContainer _shopContainer;
    private HBoxContainer _benchContainer;
    private Node2D _boardContainer;
    private GridVisual _gridVisual;
    private Node2D _unitLayer;
    private Node2D _popupLayer;
    private RichTextLabel _combatLog;

    private HBoxContainer _actionButtons;
    private Button _fightButton;
    private Button _refreshButton;
    private Button _speedButton;

    private Panel _gameOverPanel;

    // Tracking visuals for combat
    private readonly Dictionary<int, UnitVisual> _combatVisuals = new();

    public override void _Ready()
    {
        _dataManager = GetNode<DataManager>("/root/DataManager");
        BuildFullUI();

        if (_dataManager.IsLoaded)
            OnDataReady();
        else
            _dataManager.DataLoaded += _ => OnDataReady();

        _dataManager.CombatLogReceived += OnCombatLogEntry;
    }

    private void OnDataReady()
    {
        _player = new PlayerState();
        _shop = new ShopSystem(_dataManager);
        _scaler = new EncounterScaler(_dataManager);
        _orchestrator = new CombatOrchestrator();

        TransitionTo(Phase.Shop);
    }

    private void TransitionTo(Phase phase)
    {
        _currentPhase = phase;
        _phaseLabel.Text = phase.ToString().ToUpper();

        _shopContainer.Visible = phase == Phase.Shop;
        _benchContainer.Visible = phase == Phase.Shop || phase == Phase.Positioning;
        _fightButton.Visible = phase == Phase.Positioning;
        _refreshButton.Visible = phase == Phase.Shop;
        _speedButton.Visible = phase == Phase.Combat;
        _combatLog.Visible = phase == Phase.Combat || phase == Phase.Result;
        _gridVisual.Visible = phase == Phase.Positioning || phase == Phase.Combat || phase == Phase.Result;
        _unitLayer.Visible = phase == Phase.Combat || phase == Phase.Result;
        _popupLayer.Visible = phase == Phase.Combat || phase == Phase.Result;
        _gameOverPanel.Visible = phase == Phase.GameOver;

        switch (phase)
        {
            case Phase.Shop:
                EnterShop();
                break;
            case Phase.Positioning:
                EnterPositioning();
                break;
            case Phase.Combat:
                _ = EnterCombat();
                break;
            case Phase.Result:
                break;
            case Phase.GameOver:
                EnterGameOver();
                break;
        }

        UpdateHUD();
    }

    // ========== SHOP PHASE ==========

    private void EnterShop()
    {
        _shop.GenerateOfferings(_player.Level, _player.RoundNumber);
        _gridVisual.SetShowZones(false);
        RefreshShopUI();
        RefreshBenchUI();
    }

    private void RefreshShopUI()
    {
        foreach (var child in _shopContainer.GetChildren())
            child.QueueFree();

        for (int i = 0; i < _shop.CurrentOfferings.Count; i++)
        {
            var def = _shop.CurrentOfferings[i];
            if (def == null)
            {
                var empty = CreateEmptyShopSlot();
                _shopContainer.AddChild(empty);
                continue;
            }

            int tier = DataManager.GetTier(def.StatBlock.CreatureLevel);
            int cost = DataManager.GetCost(tier);
            var card = CreateShopCard(def, tier, cost, i);
            _shopContainer.AddChild(card);
        }
    }

    private void RefreshBenchUI()
    {
        foreach (var child in _benchContainer.GetChildren())
            child.QueueFree();

        foreach (var unit in _player.Bench)
        {
            var card = CreateBenchCard(unit);
            _benchContainer.AddChild(card);
        }

        for (int i = _player.Bench.Count; i < _player.MaxBenchSlots; i++)
        {
            var empty = CreateEmptyBenchSlot();
            _benchContainer.AddChild(empty);
        }
    }

    private Panel CreateShopCard(EnemyDefinition def, int tier, int cost, int slotIndex)
    {
        var panel = new Panel();
        panel.CustomMinimumSize = new Vector2(140, 120);

        var bg = new StyleBoxFlat();
        bg.BgColor = CreatureColors.GetCreatureColor(def) * 0.4f;
        bg.BorderColor = new Color(0.5f, 0.5f, 0.5f);
        bg.SetBorderWidthAll(1);
        bg.SetCornerRadiusAll(4);
        bg.SetContentMarginAll(6);
        panel.AddThemeStyleboxOverride("panel", bg);

        var vbox = new VBoxContainer();
        vbox.SetAnchorsPreset(LayoutPreset.FullRect);
        vbox.AddThemeConstantOverride("separation", 2);
        panel.AddChild(vbox);

        var nameLabel = new Label();
        nameLabel.Text = def.CreatureName;
        nameLabel.AddThemeFontSizeOverride("font_size", 12);
        nameLabel.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        vbox.AddChild(nameLabel);

        string stars = new string('★', tier);
        var tierLabel = new Label();
        tierLabel.Text = $"Lv{def.StatBlock.CreatureLevel} {stars}";
        tierLabel.AddThemeFontSizeOverride("font_size", 10);
        tierLabel.AddThemeColorOverride("font_color", new Color(1, 0.85f, 0.3f));
        vbox.AddChild(tierLabel);

        var traitLabel = new Label();
        traitLabel.Text = CreatureColors.GetPrimaryTrait(def);
        traitLabel.AddThemeFontSizeOverride("font_size", 10);
        traitLabel.AddThemeColorOverride("font_color", new Color(0.7f, 0.7f, 0.7f));
        vbox.AddChild(traitLabel);

        var statsLabel = new Label();
        statsLabel.Text = $"HP:{def.StatBlock.MaxHP}  AC:{def.StatBlock.AC}";
        statsLabel.AddThemeFontSizeOverride("font_size", 10);
        vbox.AddChild(statsLabel);

        if (def.StatBlock.Strikes != null && def.StatBlock.Strikes.Length > 0)
        {
            var strike = def.StatBlock.Strikes[0];
            var strikeLabel = new Label();
            strikeLabel.Text = $"{strike.StrikeName}: +{strike.AttackBonus}";
            strikeLabel.AddThemeFontSizeOverride("font_size", 10);
            vbox.AddChild(strikeLabel);
        }

        int idx = slotIndex;
        var buyButton = new Button();
        buyButton.Text = $"Buy ({cost}g)";
        buyButton.Pressed += () => OnBuyPressed(idx);
        vbox.AddChild(buyButton);

        return panel;
    }

    private Panel CreateEmptyShopSlot()
    {
        var panel = new Panel();
        panel.CustomMinimumSize = new Vector2(140, 120);
        var bg = new StyleBoxFlat();
        bg.BgColor = new Color(0.1f, 0.1f, 0.1f, 0.5f);
        bg.SetBorderWidthAll(1);
        bg.BorderColor = new Color(0.3f, 0.3f, 0.3f);
        bg.SetCornerRadiusAll(4);
        panel.AddThemeStyleboxOverride("panel", bg);

        var label = new Label();
        label.Text = "SOLD";
        label.HorizontalAlignment = HorizontalAlignment.Center;
        label.VerticalAlignment = VerticalAlignment.Center;
        label.SetAnchorsPreset(LayoutPreset.FullRect);
        label.AddThemeColorOverride("font_color", new Color(0.3f, 0.3f, 0.3f));
        panel.AddChild(label);

        return panel;
    }

    private Panel CreateBenchCard(OwnedUnit unit)
    {
        var panel = new Panel();
        panel.CustomMinimumSize = new Vector2(90, 60);

        var bg = new StyleBoxFlat();
        bg.BgColor = CreatureColors.GetCreatureColor(unit.Definition) * 0.5f;
        bg.BorderColor = CreatureColors.PlayerOutline;
        bg.SetBorderWidthAll(1);
        bg.SetCornerRadiusAll(4);
        bg.SetContentMarginAll(4);
        panel.AddThemeStyleboxOverride("panel", bg);

        var vbox = new VBoxContainer();
        vbox.SetAnchorsPreset(LayoutPreset.FullRect);
        vbox.AddThemeConstantOverride("separation", 1);
        panel.AddChild(vbox);

        var nameLabel = new Label();
        nameLabel.Text = unit.Definition.CreatureName;
        nameLabel.AddThemeFontSizeOverride("font_size", 10);
        nameLabel.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        vbox.AddChild(nameLabel);

        var hbox = new HBoxContainer();
        hbox.AddThemeConstantOverride("separation", 4);
        vbox.AddChild(hbox);

        var sellBtn = new Button();
        sellBtn.Text = $"Sell ({DataManager.GetSellPrice(unit.Tier)}g)";
        sellBtn.AddThemeFontSizeOverride("font_size", 9);
        var u = unit;
        sellBtn.Pressed += () => OnSellPressed(u);
        hbox.AddChild(sellBtn);

        return panel;
    }

    private Panel CreateEmptyBenchSlot()
    {
        var panel = new Panel();
        panel.CustomMinimumSize = new Vector2(90, 60);
        var bg = new StyleBoxFlat();
        bg.BgColor = new Color(0.08f, 0.08f, 0.08f, 0.3f);
        bg.SetBorderWidthAll(1);
        bg.BorderColor = new Color(0.2f, 0.2f, 0.2f);
        bg.SetCornerRadiusAll(4);
        panel.AddThemeStyleboxOverride("panel", bg);
        return panel;
    }

    private void OnBuyPressed(int slotIndex)
    {
        var unit = _shop.BuyUnit(slotIndex, _player);
        if (unit != null)
        {
            RefreshShopUI();
            RefreshBenchUI();
            UpdateHUD();
        }
    }

    private void OnSellPressed(OwnedUnit unit)
    {
        _player.SellUnit(unit);
        RefreshBenchUI();
        UpdateHUD();
    }

    private void OnRefreshPressed()
    {
        if (_shop.Refresh(_player))
        {
            RefreshShopUI();
            UpdateHUD();
        }
    }

    // ========== POSITIONING PHASE ==========

    private void EnterPositioning()
    {
        _gridVisual.SetShowZones(true);
        RefreshBenchUI();

        // Auto-place bench units that aren't already on board
        AutoPlaceBenchUnits();
        RefreshBoardPreview();
    }

    private void AutoPlaceBenchUnits()
    {
        var unplaced = _player.Bench.ToList();
        int placed = _player.Board.Count;

        foreach (var unit in unplaced)
        {
            if (placed >= _player.MaxBoardUnits) break;

            int x = (placed * 2) % GridVisual.GridWidth;
            int y = placed / (GridVisual.GridWidth / 2);
            var pos = new PF2eVec(x, y);

            _player.PlaceOnBoard(unit, pos);
            placed++;
        }
    }

    private void RefreshBoardPreview()
    {
        foreach (var child in _unitLayer.GetChildren())
            child.QueueFree();

        foreach (var placement in _player.Board)
        {
            var visual = UnitVisual.Create(null, placement.Unit.Definition, 1);
            visual.Position = GridVisual.GridToWorld(placement.Position);
            _unitLayer.AddChild(visual);
        }

        _unitLayer.Visible = true;
    }

    // ========== COMBAT PHASE ==========

    private async Task EnterCombat()
    {
        _combatLog.Clear();
        _combatVisuals.Clear();

        foreach (var child in _unitLayer.GetChildren())
            child.QueueFree();
        foreach (var child in _popupLayer.GetChildren())
            child.QueueFree();

        _presenter = new GodotPresenter(_boardContainer, _popupLayer);
        _presenter.SetSpeed(_combatSpeed);

        var playerUnits = new List<(EnemyDefinition def, PF2eVec position)>();
        foreach (var p in _player.Board)
            playerUnits.Add((p.Unit.Definition, p.Position));

        var enemyUnits = _scaler.GenerateEnemyTeam(_player.RoundNumber, playerUnits.Count);

        AppendCombatLog("[color=lime]═══ YOUR TEAM ═══[/color]");
        foreach (var (def, pos) in playerUnits)
            AppendCombatLog($"  [color=cyan]{def.CreatureName}[/color] (Lv{def.StatBlock.CreatureLevel})");
        AppendCombatLog("[color=red]═══ ENEMY TEAM ═══[/color]");
        foreach (var (def, pos) in enemyUnits)
            AppendCombatLog($"  [color=orange]{def.CreatureName}[/color] (Lv{def.StatBlock.CreatureLevel})");

        // Run combat — the orchestrator creates ICharacter instances internally.
        // We use a two-phase approach: first run headless to get characters placed,
        // then we could animate. But AIBattleSimulator runs the full encounter in one call.
        // So we spawn visuals as soon as the orchestrator has created the characters,
        // which happens inside RunCombat before the encounter loop starts.
        //
        // To achieve this, we split orchestrator setup from execution:
        _orchestrator.SetupEncounter(playerUnits, enemyUnits,
            seed: _player.RoundNumber * 1000 + (int)(Time.GetTicksMsec() % 1000));

        // Now characters exist — spawn visuals and register with presenter
        SpawnCombatVisuals();

        // Wire presenter and run
        var result = await _orchestrator.RunEncounterWithPresenter(_presenter.Present);

        AppendCombatLog($"\n[color=yellow]═══ ROUND {_player.RoundNumber} RESULT ═══[/color]");

        bool won = result == BattleResult.Team1Wins;
        int surviving = _orchestrator.CountSurvivingEnemies();
        int incomePreview = _player.CalculateIncome();
        int damagePreview = won ? 0 : _player.CalculateDamageOnLoss(surviving);

        _player.ApplyRoundResult(won, surviving);

        if (won)
            AppendCombatLog("[color=lime]VICTORY![/color]");
        else if (result == BattleResult.Draw)
            AppendCombatLog($"[color=yellow]DRAW! Lost {damagePreview} HP[/color]");
        else
            AppendCombatLog($"[color=red]DEFEAT! Lost {damagePreview} HP[/color]");

        AppendCombatLog($"Gold earned: +{incomePreview}g");
        UpdateHUD();

        await Task.Delay(1500);

        if (_player.IsGameOver)
            TransitionTo(Phase.GameOver);
        else
            TransitionTo(Phase.Shop);
    }

    private void SpawnCombatVisuals()
    {
        foreach (var c in _orchestrator.Team1)
        {
            var def = FindDefForCharacter(c, _player.Board.Select(p => p.Unit.Definition));
            if (def == null) continue;
            var visual = UnitVisual.Create(c, def, 1);
            visual.Position = GridVisual.GridToWorld(c.GridPosition);
            _unitLayer.AddChild(visual);
            _presenter.RegisterUnit(c, visual);
        }

        foreach (var c in _orchestrator.Team2)
        {
            var def = FindDefForCharacter(c, null);
            if (def == null) continue;
            var visual = UnitVisual.Create(c, def, 2);
            visual.Position = GridVisual.GridToWorld(c.GridPosition);
            _unitLayer.AddChild(visual);
            _presenter.RegisterUnit(c, visual);
        }
    }

    private EnemyDefinition FindDefForCharacter(ICharacter character, IEnumerable<EnemyDefinition> candidates)
    {
        if (candidates != null)
        {
            foreach (var def in candidates)
            {
                if (def.CreatureName == character.Name)
                    return def;
            }
        }

        foreach (var tier in _dataManager.CreaturesByTier.Values)
        {
            foreach (var def in tier)
            {
                if (def.CreatureName == character.Name)
                    return def;
            }
        }

        return null;
    }

    // ========== GAME OVER ==========

    private void EnterGameOver()
    {
        var label = _gameOverPanel.GetNodeOrNull<Label>("Label");
        if (label != null)
            label.Text = $"GAME OVER\nYou survived {_player.RoundNumber - 1} rounds\nLevel {_player.Level}";
    }

    // ========== HUD ==========

    private void UpdateHUD()
    {
        _goldLabel.Text = $"Gold: {_player?.Gold ?? 0}";
        _hpLabel.Text = $"HP: {_player?.HP ?? 0}/{_player?.MaxHP ?? 100}";
        _roundLabel.Text = $"Round: {_player?.RoundNumber ?? 1}";
        _levelLabel.Text = $"Lv{_player?.Level ?? 1} ({_player?.XP ?? 0}xp) | Units: {_player?.Board.Count ?? 0}/{_player?.MaxBoardUnits ?? 3}";
    }

    private void OnCombatLogEntry(string message, int severity)
    {
        if (_currentPhase == Phase.Combat)
        {
            string color = (CombatLogSeverity)severity switch
            {
                CombatLogSeverity.CriticalHit => "red",
                CombatLogSeverity.Hit => "orange",
                CombatLogSeverity.Miss => "gray",
                CombatLogSeverity.CriticalMiss => "dark_gray",
                CombatLogSeverity.Healing => "green",
                CombatLogSeverity.ConditionApplied => "yellow",
                CombatLogSeverity.ConditionRemoved => "cyan",
                CombatLogSeverity.ActionHeader => "white",
                CombatLogSeverity.Reaction => "purple",
                _ => "white"
            };
            AppendCombatLog($"[color={color}]{message}[/color]");
        }
    }

    private void AppendCombatLog(string bbcode)
    {
        _combatLog.AppendText(bbcode + "\n");
    }

    private void OnSpeedPressed()
    {
        if (_combatSpeed < 2f) _combatSpeed = 2f;
        else if (_combatSpeed < 4f) _combatSpeed = 4f;
        else _combatSpeed = 1f;

        _speedButton.Text = $"Speed: {_combatSpeed}x";
        _presenter?.SetSpeed(_combatSpeed);
    }

    // ========== UI CONSTRUCTION ==========

    private void BuildFullUI()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);

        var bgColor = new StyleBoxFlat();
        bgColor.BgColor = new Color(0.08f, 0.08f, 0.1f);
        AddThemeStyleboxOverride("panel", bgColor);

        _rootLayout = new VBoxContainer();
        _rootLayout.SetAnchorsPreset(LayoutPreset.FullRect);
        _rootLayout.AddThemeConstantOverride("separation", 6);
        AddChild(_rootLayout);

        var topMargin = new MarginContainer();
        topMargin.AddThemeConstantOverride("margin_left", 10);
        topMargin.AddThemeConstantOverride("margin_right", 10);
        topMargin.AddThemeConstantOverride("margin_top", 6);
        _rootLayout.AddChild(topMargin);

        _topBar = new HBoxContainer();
        _topBar.AddThemeConstantOverride("separation", 20);
        topMargin.AddChild(_topBar);

        _phaseLabel = new Label();
        _phaseLabel.Text = "LOADING";
        _phaseLabel.AddThemeFontSizeOverride("font_size", 18);
        _phaseLabel.AddThemeColorOverride("font_color", new Color(1, 0.85f, 0.3f));
        _topBar.AddChild(_phaseLabel);

        _goldLabel = new Label();
        _goldLabel.Text = "Gold: 0";
        _goldLabel.AddThemeFontSizeOverride("font_size", 14);
        _goldLabel.AddThemeColorOverride("font_color", new Color(1f, 0.85f, 0.2f));
        _topBar.AddChild(_goldLabel);

        _hpLabel = new Label();
        _hpLabel.Text = "HP: 100/100";
        _hpLabel.AddThemeFontSizeOverride("font_size", 14);
        _hpLabel.AddThemeColorOverride("font_color", new Color(0.3f, 1f, 0.3f));
        _topBar.AddChild(_hpLabel);

        _roundLabel = new Label();
        _roundLabel.Text = "Round: 1";
        _roundLabel.AddThemeFontSizeOverride("font_size", 14);
        _topBar.AddChild(_roundLabel);

        _levelLabel = new Label();
        _levelLabel.Text = "Lv1 (0xp)";
        _levelLabel.AddThemeFontSizeOverride("font_size", 14);
        _topBar.AddChild(_levelLabel);

        // Main content area
        var contentSplit = new HSplitContainer();
        contentSplit.SizeFlagsVertical = SizeFlags.ExpandFill;
        _rootLayout.AddChild(contentSplit);

        // Left: board area
        var boardPanel = new PanelContainer();
        boardPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        boardPanel.SizeFlagsStretchRatio = 2f;
        contentSplit.AddChild(boardPanel);

        var boardMargin = new MarginContainer();
        boardMargin.AddThemeConstantOverride("margin_left", 10);
        boardMargin.AddThemeConstantOverride("margin_top", 10);
        boardPanel.AddChild(boardMargin);

        _boardContainer = new Node2D();
        var boardSub = new SubViewportContainer();
        boardSub.CustomMinimumSize = new Vector2(
            GridVisual.GridWidth * GridVisual.TileSize + 20,
            GridVisual.GridHeight * GridVisual.TileSize + 40);
        boardMargin.AddChild(boardSub);

        var viewport = new SubViewport();
        viewport.Size = new Vector2I(
            GridVisual.GridWidth * GridVisual.TileSize + 20,
            GridVisual.GridHeight * GridVisual.TileSize + 40);
        viewport.TransparentBg = true;
        boardSub.AddChild(viewport);

        _gridVisual = new GridVisual();
        _gridVisual.Position = new Vector2(10, 10);
        viewport.AddChild(_gridVisual);

        _unitLayer = new Node2D();
        _unitLayer.Position = new Vector2(10, 10);
        viewport.AddChild(_unitLayer);

        _popupLayer = new Node2D();
        _popupLayer.Position = new Vector2(10, 10);
        viewport.AddChild(_popupLayer);

        // Right: combat log + controls
        var rightPanel = new VBoxContainer();
        rightPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        rightPanel.SizeFlagsStretchRatio = 1f;
        rightPanel.AddThemeConstantOverride("separation", 6);
        contentSplit.AddChild(rightPanel);

        _combatLog = new RichTextLabel();
        _combatLog.SizeFlagsVertical = SizeFlags.ExpandFill;
        _combatLog.BbcodeEnabled = true;
        _combatLog.ScrollFollowing = true;
        _combatLog.Visible = false;
        rightPanel.AddChild(_combatLog);

        // Shop container
        var shopScroll = new ScrollContainer();
        shopScroll.SizeFlagsVertical = SizeFlags.ExpandFill;
        rightPanel.AddChild(shopScroll);

        _shopContainer = new HBoxContainer();
        _shopContainer.AddThemeConstantOverride("separation", 8);
        shopScroll.AddChild(_shopContainer);

        // Bottom area: bench + buttons
        var bottomMargin = new MarginContainer();
        bottomMargin.AddThemeConstantOverride("margin_left", 10);
        bottomMargin.AddThemeConstantOverride("margin_right", 10);
        bottomMargin.AddThemeConstantOverride("margin_bottom", 6);
        _rootLayout.AddChild(bottomMargin);

        var bottomVbox = new VBoxContainer();
        bottomVbox.AddThemeConstantOverride("separation", 4);
        bottomMargin.AddChild(bottomVbox);

        var benchLabel = new Label();
        benchLabel.Text = "BENCH";
        benchLabel.AddThemeFontSizeOverride("font_size", 12);
        benchLabel.AddThemeColorOverride("font_color", new Color(0.6f, 0.6f, 0.6f));
        bottomVbox.AddChild(benchLabel);

        _benchContainer = new HBoxContainer();
        _benchContainer.AddThemeConstantOverride("separation", 6);
        bottomVbox.AddChild(_benchContainer);

        _actionButtons = new HBoxContainer();
        _actionButtons.AddThemeConstantOverride("separation", 10);
        bottomVbox.AddChild(_actionButtons);

        var doneShoppingBtn = new Button();
        doneShoppingBtn.Text = "Done Shopping →";
        doneShoppingBtn.Pressed += () =>
        {
            if (_currentPhase == Phase.Shop)
                TransitionTo(Phase.Positioning);
        };
        _actionButtons.AddChild(doneShoppingBtn);

        _refreshButton = new Button();
        _refreshButton.Text = $"Refresh ({ShopSystem.RefreshCost}g)";
        _refreshButton.Pressed += OnRefreshPressed;
        _actionButtons.AddChild(_refreshButton);

        _fightButton = new Button();
        _fightButton.Text = "FIGHT!";
        _fightButton.AddThemeFontSizeOverride("font_size", 18);
        _fightButton.Pressed += () =>
        {
            if (_currentPhase == Phase.Positioning && _player.Board.Count > 0)
                TransitionTo(Phase.Combat);
        };
        _fightButton.Visible = false;
        _actionButtons.AddChild(_fightButton);

        _speedButton = new Button();
        _speedButton.Text = "Speed: 1x";
        _speedButton.Pressed += OnSpeedPressed;
        _speedButton.Visible = false;
        _actionButtons.AddChild(_speedButton);

        // Game over overlay
        _gameOverPanel = new Panel();
        _gameOverPanel.SetAnchorsPreset(LayoutPreset.FullRect);
        _gameOverPanel.Visible = false;
        var goBg = new StyleBoxFlat();
        goBg.BgColor = new Color(0, 0, 0, 0.85f);
        _gameOverPanel.AddThemeStyleboxOverride("panel", goBg);
        AddChild(_gameOverPanel);

        var goVbox = new VBoxContainer();
        goVbox.SetAnchorsPreset(LayoutPreset.Center);
        goVbox.GrowHorizontal = GrowDirection.Both;
        goVbox.GrowVertical = GrowDirection.Both;
        goVbox.AddThemeConstantOverride("separation", 20);
        _gameOverPanel.AddChild(goVbox);

        var goLabel = new Label();
        goLabel.Name = "Label";
        goLabel.Text = "GAME OVER";
        goLabel.HorizontalAlignment = HorizontalAlignment.Center;
        goLabel.AddThemeFontSizeOverride("font_size", 32);
        goLabel.AddThemeColorOverride("font_color", new Color(1, 0.3f, 0.3f));
        goVbox.AddChild(goLabel);

        var restartBtn = new Button();
        restartBtn.Text = "New Game";
        restartBtn.Pressed += () =>
        {
            _player = new PlayerState();
            _shop = new ShopSystem(_dataManager);
            TransitionTo(Phase.Shop);
        };
        goVbox.AddChild(restartBtn);
    }
}
