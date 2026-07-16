using System;
using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Data.Dialogues;
using Bulwark.Territory;
using Bulwark.UI;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Shared "cozy world host" layer for the walkable Node2D scenes (outpost, territories). Still a
/// thin adapter per CLAUDE.md — written once: it instances the player / HUD / squad panel, wires
/// the common GameState events, pushes view-model data into the passive HUD, and owns the
/// freeze → toast → scene-swap hand-off pacing. Scene-specific world content (farm plots,
/// resource nodes, roamers, triggers) stays in the subclasses, which must still run standalone
/// (F6) with null-safe fallbacks.
/// </summary>
public abstract partial class CozyWorldScene : Node2D
{
    /// <summary>Seconds the departure/encounter toast stays visible during a hand-off.</summary>
    protected const float HandOffToastSeconds = 1.2f;

    /// <summary>Delay before the hand-off routes — shorter than the toast so it stays readable.</summary>
    protected const double HandOffDelaySeconds = 0.9;

    /// <summary>Thickness (px) of the programmatic perimeter walls placed just outside the map.</summary>
    private const float BarrierThickness = 48f;

    /// <summary>Minimum ms between rejection toasts, so a mashed/held interact never spams the HUD.</summary>
    private const ulong RejectionToastCooldownMs = 800;

    /// <summary>
    /// TileMapLayers (by unique name) whose every painted cell must block movement — the
    /// layer-is-the-law rule. Cells whose tile already carries physics polygons keep them; cells
    /// without get a full-cell rect baked at runtime (see <see cref="BuildWorldCollision"/>).
    /// Props stays decorative (tileset per-tile physics only) unless a scene adds it here.
    /// </summary>
    [Export] public string[] BlockingLayers { get; set; } = { "Walls" };

    /// <summary>
    /// Case-insensitive substrings matched against a Ground-layer atlas source's TEXTURE FILE NAME
    /// to identify water sources, whose cells block movement (baked like walls — water autotiles
    /// carry no tileset physics by design). Texture path is the identifier because it is the only
    /// stable, runtime-queryable name on a TileSetAtlasSource: generated sources ship no
    /// ResourceName, and the water terrain names vary per pack ("water", "bog", "cavewater", …) —
    /// while every generated water autotile atlas is <c>generated/water_a1*.png</c> in the territory
    /// biomes (keyword <c>water_a1</c>), and the outpost's pre-expanded liquid sources are the Winlu
    /// Godot-native <c>a1_liquids*.png</c> sheets (keyword <c>a1_liquids</c>) — so the two default
    /// keywords together cover outpost + every territory biome.
    /// </summary>
    [Export] public string[] WaterSourceKeywords { get; set; } = { "water_a1", "a1_liquids" };

    /// <summary>
    /// Bridge contract: a tile painted on any of these overlay layers at a water cell's coords
    /// marks a passable crossing, so that cell is NOT water-baked. To let the player cross water,
    /// paint a bridge/plank tile on GroundDecor (or Props) over the water — no code needed.
    /// </summary>
    [Export] public string[] BridgeOverlayLayers { get; set; } = { "GroundDecor", "Props" };

    private readonly Dictionary<string, (int Native, int Baked)> _bakeReport = new();
    private ulong _lastRejectionToastMs;
    private Camera2D? _playerCamera;

    /// <summary>Per blocking layer (plus the "Water" pass over Ground): painted cells that had
    /// tileset physics vs cells that got a baked runtime rect. Diagnostic — spikes and logs read
    /// it, gameplay does not.</summary>
    public IReadOnlyDictionary<string, (int Native, int Baked)> BakeReport => _bakeReport;

    /// <summary>Water cells skipped by the water baker because an overlay layer tile marks them
    /// as a crossing (see <see cref="BridgeOverlayLayers"/>). Diagnostic.</summary>
    public int WaterBridgedCells { get; private set; }

    /// <summary>The instanced avatar (null until <see cref="SpawnPlayer"/>, or when player.tscn is missing).</summary>
    protected PlayerController? Player { get; private set; }

    /// <summary>The instanced cozy HUD (null when cozy_hud.tscn is missing — standalone F6 safety).</summary>
    protected CozyHud? Hud { get; private set; }

    /// <summary>The instanced squad panel (null when squad_panel.tscn is missing).</summary>
    protected SquadPanel? SquadPanel { get; private set; }

    /// <summary>The instanced planning-table build panel (null when build_panel.tscn is missing or the
    /// scene didn't spawn it — only the outpost does).</summary>
    protected BuildPanel? BuildPanel { get; private set; }

    /// <summary>The instanced end-of-day summary panel (null when day_summary_panel.tscn is missing).</summary>
    protected DaySummaryPanel? DaySummaryPanel { get; private set; }

    /// <summary>The instanced inventory / warehouse panel (null when inventory_panel.tscn is missing).</summary>
    protected InventoryPanel? InventoryPanel { get; private set; }

    /// <summary>The instanced smithy panel (null when smithy_panel.tscn is missing or not spawned).</summary>
    protected SmithyPanel? SmithyPanel { get; private set; }

    /// <summary>The instanced crafting-bench panel (null when crafting_panel.tscn is missing or not spawned).</summary>
    protected CraftingPanel? CraftingPanel { get; private set; }

    /// <summary>The instanced Trading Post panel (null when trading_post_panel.tscn is missing or not spawned).</summary>
    protected TradingPostPanel? TradingPostPanel { get; private set; }

    /// <summary>The instanced friendship panel (null when friendship_panel.tscn is missing or not spawned).</summary>
    protected FriendshipPanel? FriendshipPanel { get; private set; }

    /// <summary>The instanced quest panel (null when quest_panel.tscn is missing or not spawned).</summary>
    protected QuestPanel? QuestPanel { get; private set; }

    /// <summary>The instanced calendar panel (null when calendar_panel.tscn is missing or not spawned).</summary>
    protected CalendarPanel? CalendarPanel { get; private set; }

    /// <summary>The instanced Esc pause menu (null when pause_menu.tscn is missing or not spawned).</summary>
    protected PauseMenu? PauseMenu { get; private set; }

    /// <summary>The instanced dialogue box (null when dialogue_box.tscn is missing or not spawned).</summary>
    protected DialogueBox? DialogueBox { get; private set; }

    /// <summary>The cutscene director (null when not spawned).</summary>
    protected CutsceneDirector? Director { get; private set; }

    /// <summary>Scene hand-off pending (travel or encounter): world input is ignored and the
    /// deliberately frozen player must NOT be unfrozen (e.g. by the squad-panel toggle).</summary>
    protected bool IsTransitioning { get; set; }

    /// <summary>Cadence (seconds) between interaction-hint polls — cheap proximity checks, no need
    /// for per-frame precision.</summary>
    private const double InteractionHintPollInterval = 0.15;

    private double _interactionHintPollAccumulator;

    /// <summary>
    /// Poll <see cref="GetInteractionHint"/> on <see cref="InteractionHintPollInterval"/> and push the
    /// result to the HUD's floating "E — …" prompt (null hides it) — suppressed while a modal is open
    /// or a hand-off is mid-flight, same guard as the interact input itself.
    /// </summary>
    public override void _Process(double delta)
    {
        if (Hud == null)
            return;

        _interactionHintPollAccumulator += delta;
        if (_interactionHintPollAccumulator < InteractionHintPollInterval)
            return;
        _interactionHintPollAccumulator = 0.0;

        Hud.SetInteractionPrompt(IsTransitioning || AnyModalOpen ? null : GetInteractionHint());
    }

    /// <summary>
    /// What an E/LMB/RMB interact press would do right now, for the HUD's floating prompt
    /// ("E — Talk"). Null hides the prompt. Default: nothing — the outpost/territory scenes override
    /// with proximity checks that mirror their own <see cref="OnInteractRequested"/> logic exactly
    /// (same distance constants/helpers, no duplication) so the hint never promises an action
    /// interact wouldn't actually take. Cheap — proximity checks over small collections.
    /// </summary>
    protected virtual string? GetInteractionHint() => null;

    public override void _ExitTree()
    {
        // GameState is an autoload that outlives this scene, so drop our subscriptions on scene swap.
        var gs = GameState.Instance;
        if (gs == null)
            return;

        gs.MinuteChanged -= RefreshHudTime;
        gs.InventoryChanged -= OnInventoryChanged;
        gs.GameLoaded -= RefreshHudAll;
        gs.SquadChanged -= RefreshSquadPanel;
        gs.SquadChanged -= RefreshInventoryPanel;
        gs.GoldChanged -= OnGoldChanged;
        gs.SmithyChanged -= RefreshSmithyPanel;
        gs.TradingPostChanged -= RefreshTradingPostPanel;
        gs.RecipeCrafted -= OnRecipeCrafted;
        gs.TreatWoundsResolved -= OnTreatWoundsResolved;
        gs.SquadStatusNotice -= OnSquadStatusNotice;
        gs.DayStarted -= TryShowDaySummary;
        gs.BuildingChanged -= OnBuildingChanged;
        gs.ConstructionCompleted -= OnConstructionCompleted;
        gs.FriendshipChanged -= OnFriendshipChanged;
        gs.GiftGiven -= OnGiftGiven;
        gs.QuestStarted -= OnQuestChanged;
        gs.QuestStarted -= OnQuestStartedBanner;
        gs.QuestCompleted -= OnQuestChanged;
        gs.QuestCompleted -= OnQuestCompletedBanner;
        gs.QuestObjectiveProgressed -= OnQuestObjectiveChanged;
        gs.Inventory.ItemAdded -= OnItemAddedForFeed;
        UnwireExtraStateEvents(gs);
    }

    // ------------------------------------------------------------------ Instancing

    /// <summary>Instance the avatar at <see cref="GetPlayerSpawnPosition"/>, apply the scene's
    /// <see cref="ConfigurePlayer"/> hook, and wire the shared interact/tool seams.</summary>
    protected void SpawnPlayer()
    {
        var scene = GD.Load<PackedScene>("res://scenes/cozy/player.tscn");
        if (scene == null)
            return;

        var player = scene.Instantiate<PlayerController>();
        player.Name = "Player";
        player.ZIndex = 5; // between the z=0 world layers and the z=10 Overhead layer
        AddChild(player);
        Player = player;
        player.GlobalPosition = GetPlayerSpawnPosition();
        ConfigurePlayer(player);
        player.InteractRequested += OnInteractRequested;
        player.Tools.Changed += RefreshHudTool;

        // Session view preference: keep the chosen zoom stable across scene swaps (not saved).
        _playerCamera = player.GetNodeOrNull<Camera2D>("Camera2D");
        ApplyZoom();
    }

    /// <summary>World-space position the avatar spawns at.</summary>
    protected abstract Vector2 GetPlayerSpawnPosition();

    /// <summary>Scene-specific avatar setup (farm world injection, sleep seam). Default: none.</summary>
    protected virtual void ConfigurePlayer(PlayerController player)
    {
    }

    /// <summary>Interact press with the active tool — each world scene resolves it its own way.</summary>
    protected abstract void OnInteractRequested(ToolKind tool);

    protected void SpawnHud()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/cozy_hud.tscn");
        if (scene == null)
            return;

        Hud = scene.Instantiate<CozyHud>();
        AddChild(Hud);
        Hud.ZoomInRequested += () => { ViewPreferences.ZoomIn(); ApplyZoom(); };
        Hud.ZoomOutRequested += () => { ViewPreferences.ZoomOut(); ApplyZoom(); };
        Hud.ClockClicked += () => CalendarPanel?.Toggle();
    }

    protected void ApplyZoom()
    {
        if (_playerCamera != null)
            _playerCamera.Zoom = new Vector2(ViewPreferences.CozyZoom, ViewPreferences.CozyZoom);
    }

    protected void SpawnSquadPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/squad_panel.tscn");
        if (scene == null)
            return;

        SquadPanel = scene.Instantiate<SquadPanel>();
        AddChild(SquadPanel);
        SquadPanel.TreatWoundsRequested += OnTreatWoundsRequested;
        SquadPanel.Toggled += OnSquadPanelToggled;
    }

    /// <summary>Instance the planning-table build panel (mirrors <see cref="SpawnSquadPanel"/>). The
    /// panel toggles on the "toggle_build_panel" action (B), freezes the world while open, and raises
    /// commission/contribute/upgrade intents forwarded to GameState commands. Called by the outpost.</summary>
    protected void SpawnBuildPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/build_panel.tscn");
        if (scene == null)
            return;

        BuildPanel = scene.Instantiate<BuildPanel>();
        AddChild(BuildPanel);
        BuildPanel.Toggled += OnBuildPanelToggled;
        BuildPanel.CommissionRequested += OnCommissionRequested;
        BuildPanel.ContributeRequested += OnContributeRequested;
        BuildPanel.UpgradeRequested += OnUpgradeRequested;
    }

    /// <summary>Instance the inventory / warehouse panel (mirrors <see cref="SpawnBuildPanel"/>). Toggles
    /// on "toggle_inventory_panel" (I), freezes the world while open, and raises deposit/withdraw intents
    /// forwarded to GameState. The warehouse half renders only when accessible (outpost).</summary>
    protected void SpawnInventoryPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/inventory_panel.tscn");
        if (scene == null)
            return;

        InventoryPanel = scene.Instantiate<InventoryPanel>();
        AddChild(InventoryPanel);
        InventoryPanel.Toggled += OnInventoryPanelToggled;
        InventoryPanel.DepositRequested += OnDepositRequested;
        InventoryPanel.WithdrawRequested += OnWithdrawRequested;
    }

    /// <summary>Instance the smithy panel (buy weapons, apply runes, sell surplus). Toggles on
    /// "toggle_smithy_panel" (G). Outpost-only station — call from the outpost scene.</summary>
    protected void SpawnSmithyPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/smithy_panel.tscn");
        if (scene == null)
            return;

        SmithyPanel = scene.Instantiate<SmithyPanel>();
        AddChild(SmithyPanel);
        SmithyPanel.Toggled += OnSmithyPanelToggled;
        SmithyPanel.ApplyRuneRequested += OnApplyRuneRequested;
        SmithyPanel.BuyWeaponRequested += OnBuyWeaponRequested;
    }

    /// <summary>Instance the Trading Post panel (buy catalog goods for gold, sell surplus). Toggles on
    /// "toggle_trading_post_panel" (T). Outpost-only station — call from the outpost scene.</summary>
    protected void SpawnTradingPostPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/trading_post_panel.tscn");
        if (scene == null)
            return;

        TradingPostPanel = scene.Instantiate<TradingPostPanel>();
        AddChild(TradingPostPanel);
        TradingPostPanel.Toggled += OnTradingPostPanelToggled;
        TradingPostPanel.BuyRequested += OnBuyGoodRequested;
        TradingPostPanel.SellRequested += OnSellRequested;
    }

    /// <summary>Instance the friendship panel (heart pips per befriendable present character + the
    /// near-a-villager gift flow). Toggles on "toggle_friendship_panel" (F), freezes the world while
    /// open, and raises gift intents forwarded to GameState.GiveGift. Called by the outpost.</summary>
    protected void SpawnFriendshipPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/friendship_panel.tscn");
        if (scene == null)
            return;

        FriendshipPanel = scene.Instantiate<FriendshipPanel>();
        AddChild(FriendshipPanel);
        FriendshipPanel.Toggled += OnFriendshipPanelToggled;
        FriendshipPanel.GiftRequested += OnGiftRequested;
    }

    /// <summary>Instance the quest log panel. Toggles on "toggle_quest_panel" (J). Available in all
    /// cozy world scenes (outpost + territory).</summary>
    protected void SpawnQuestPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/quest_panel.tscn");
        if (scene == null)
            return;

        QuestPanel = scene.Instantiate<QuestPanel>();
        AddChild(QuestPanel);
        QuestPanel.Toggled += OnQuestPanelToggled;
    }

    /// <summary>Instance the calendar panel (mirrors <see cref="SpawnQuestPanel"/>). Toggles on
    /// "toggle_calendar_panel" (N) or the HUD's clock-click, freezes the world while open, and
    /// re-renders from <see cref="Bulwark.Autoload.GameState.GetCalendarView"/>. Available in every
    /// cozy world scene (outpost + territory).</summary>
    protected void SpawnCalendarPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/calendar_panel.tscn");
        if (scene == null)
            return;

        CalendarPanel = scene.Instantiate<CalendarPanel>();
        AddChild(CalendarPanel);
        CalendarPanel.Toggled += OnCalendarPanelToggled;
    }

    /// <summary>Instance the Esc pause menu (Resume/Save/Options/Quit to Title). Available in every
    /// cozy world scene — call alongside the other panel spawns.</summary>
    protected void SpawnPauseMenu()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/pause_menu.tscn");
        if (scene == null)
            return;

        PauseMenu = scene.Instantiate<PauseMenu>();
        AddChild(PauseMenu);
        PauseMenu.Toggled += OnPauseMenuToggled;
        PauseMenu.SaveRequested += OnPauseSaveRequested;
        PauseMenu.QuitToTitleRequested += OnQuitToTitleRequested;
    }

    /// <summary>Instance the crafting-bench panel. Toggles on "toggle_crafting_panel" (K). Outpost-only
    /// station — call from the outpost scene.</summary>
    protected void SpawnCraftingPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/crafting_panel.tscn");
        if (scene == null)
            return;

        CraftingPanel = scene.Instantiate<CraftingPanel>();
        AddChild(CraftingPanel);
        CraftingPanel.Toggled += OnCraftingPanelToggled;
        CraftingPanel.CraftRequested += OnCraftRequested;
    }

    /// <summary>Instance the dialogue box and cutscene director. The dialogue box is a modal that
    /// freezes the world while visible. Call from the scene's _Ready alongside other panel spawns.</summary>
    protected void SpawnDialogueBox()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/dialogue_box.tscn");
        if (scene == null)
            return;

        DialogueBox = scene.Instantiate<DialogueBox>();
        AddChild(DialogueBox);
        DialogueBox.Opened += () => SetModalFreeze(true);
        DialogueBox.Closed += () =>
        {
            SetModalFreeze(false);
            GameState.Instance?.EndDialogue();
        };

        Director = new CutsceneDirector { Name = "CutsceneDirector" };
        AddChild(Director);
    }

    /// <summary>
    /// Play a dialogue sequence through the dialogue box. Builds a <see cref="DialogueRunner"/>,
    /// binds it to the box and director, and starts it. Returns false if the box is not spawned
    /// or the steps are null/empty.
    /// </summary>
    protected bool PlayDialogueSteps(List<DialogueStep> steps, string? dialogueId = null, bool once = false)
    {
        if (DialogueBox == null || steps == null || steps.Count == 0)
            return false;

        var gs = GameState.Instance;
        var handler = new GameStateEffectHandler(gs);
        var runner = new DialogueRunner(steps, handler, dialogueId, once);
        DialogueBox.Bind(runner);
        Director?.Bind(runner);
        CloseOtherModals(DialogueBox);
        runner.Start();
        return true;
    }

    /// <summary>
    /// Play a list of <see cref="DialogueLine"/>s (from a talk pool) as simple sequential lines.
    /// Converts them to DialogueStep format and plays them.
    /// </summary>
    protected bool PlayTalkLines(List<DialogueLine> lines)
    {
        if (lines == null || lines.Count == 0)
            return false;

        var steps = new List<DialogueStep>();
        foreach (var line in lines)
        {
            steps.Add(new DialogueStep
            {
                Type = "line",
                Speaker = line.Speaker,
                Text = line.Text,
                Emotion = line.Emotion ?? "neutral",
            });
        }
        return PlayDialogueSteps(steps);
    }

    /// <summary>Instance the end-of-day summary modal and schedule a deferred consume for
    /// post-scene-swap arrivals (e.g. the defeat wake staged a summary before routing to the
    /// outpost, and the sleepless hand-off case leaves DayStarted's summary to the NEXT scene).
    /// Call from the scene's _Ready alongside <see cref="SpawnSquadPanel"/>.</summary>
    protected void SpawnDaySummaryPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/day_summary_panel.tscn");
        if (scene == null)
            return;

        DaySummaryPanel = scene.Instantiate<DaySummaryPanel>();
        AddChild(DaySummaryPanel);
        DaySummaryPanel.Closed += OnDaySummaryClosed;

        // Deferred: let the scene finish _Ready (HUD, wiring) before the modal takes the screen.
        Callable.From(TryShowDaySummary).CallDeferred();
    }

    /// <summary>Blockout-grade travel affordance: a visible signpost placed at a trigger's position
    /// (programmatic — the world .tscn stays hand-painted by the user). With
    /// <paramref name="trackPlayer"/> the sign raises PlayerApproached proximity hints; without it
    /// the sign is purely visual. Null when the trigger (or tracked player) is missing.</summary>
    protected TransitionSign? SpawnTransitionSign(string nodeName, string text, Area2D? trigger, bool trackPlayer)
    {
        if (trigger == null || (trackPlayer && Player == null))
            return null;

        var scene = GD.Load<PackedScene>("res://scenes/territory/transition_sign.tscn");
        if (scene == null)
            return null;

        var sign = scene.Instantiate<TransitionSign>();
        sign.Name = nodeName;
        sign.ZIndex = 1;
        AddChild(sign);
        sign.GlobalPosition = trigger.GlobalPosition;
        sign.Bind(text, trackPlayer ? Player : null);
        return sign;
    }

    // ------------------------------------------------------------------ World collision (paint-safe)

    /// <summary>
    /// Runtime "world rules" collision pass — nothing is written to the hand-painted .tscn:
    /// a perimeter barrier just outside the Ground layer's used rect (the player can never walk
    /// off the painted map, and it adapts as the user paints the map bigger), plus a full-cell
    /// collision bake for every <see cref="BlockingLayers"/> cell whose tile ships no physics
    /// polygons (manually placed object-sheet wall tiles block by layer membership, not per-tile
    /// physics luck). Call from the scene's _Ready after the layers exist.
    /// </summary>
    protected void BuildWorldCollision(TileMapLayer? ground)
    {
        SpawnPerimeterBarrier(ground);
        foreach (string layerName in BlockingLayers)
            BakeBlockingLayer(GetNodeOrNull<TileMapLayer>($"%{layerName}"), layerName);
        BakeWaterCollision(ground);
    }

    /// <summary>Four StaticBody2D border walls just outside the Ground used rect (one unique
    /// runtime shape per differently-sized wall, per the collision-shape convention).</summary>
    private void SpawnPerimeterBarrier(TileMapLayer? ground)
    {
        if (ground?.TileSet == null)
            return;

        Rect2I used = ground.GetUsedRect();
        if (used.Size.X <= 0 || used.Size.Y <= 0)
            return;

        // World-space outer edges of the painted map (MapToLocal returns cell centers).
        Vector2 tile = ground.TileSet.TileSize;
        Vector2 topLeft = ground.ToGlobal(ground.MapToLocal(used.Position) - tile * 0.5f);
        Vector2 bottomRight = ground.ToGlobal(ground.MapToLocal(used.End - Vector2I.One) + tile * 0.5f);
        Vector2 size = bottomRight - topLeft;
        Vector2 center = (topLeft + bottomRight) * 0.5f;
        float t = BarrierThickness;

        var barrier = new Node2D { Name = "PerimeterBarrier" };
        AddChild(barrier);
        AddBorderWall(barrier, "North", new Vector2(center.X, topLeft.Y - t / 2f), new Vector2(size.X + 2f * t, t));
        AddBorderWall(barrier, "South", new Vector2(center.X, bottomRight.Y + t / 2f), new Vector2(size.X + 2f * t, t));
        AddBorderWall(barrier, "West", new Vector2(topLeft.X - t / 2f, center.Y), new Vector2(t, size.Y + 2f * t));
        AddBorderWall(barrier, "East", new Vector2(bottomRight.X + t / 2f, center.Y), new Vector2(t, size.Y + 2f * t));
    }

    private static void AddBorderWall(Node2D parent, string name, Vector2 center, Vector2 size)
    {
        var body = new StaticBody2D { Name = name, Position = center };
        parent.AddChild(body);
        body.AddChild(new CollisionShape2D { Shape = new RectangleShape2D { Size = size } });
    }

    /// <summary>
    /// Layer-is-the-law bake: every painted cell of a blocking layer must stop bodies. Cells whose
    /// TileData already has physics polygons are left to the tileset (no double bodies); the rest
    /// get a full-cell rect on one runtime StaticBody2D under the layer. All baked cells share one
    /// tile-sized RectangleShape2D (identical runtime rects — the unique-shape convention concerns
    /// differently-sized nodes in .tscn files).
    /// </summary>
    private void BakeBlockingLayer(TileMapLayer? layer, string layerName)
    {
        if (layer?.TileSet == null || layer.TileSet.GetPhysicsLayersCount() == 0)
            return;

        var body = new StaticBody2D { Name = "BakedWallCollision" };
        layer.AddChild(body);

        var cellShape = new RectangleShape2D { Size = layer.TileSet.TileSize };
        int native = 0, baked = 0;
        foreach (Vector2I cell in layer.GetUsedCells())
        {
            TileData? tileData = layer.GetCellTileData(cell);
            if (tileData == null)
                continue;

            if (tileData.GetCollisionPolygonsCount(0) > 0)
            {
                native++;
                continue;
            }

            body.AddChild(new CollisionShape2D { Shape = cellShape, Position = layer.MapToLocal(cell) });
            baked++;
        }

        _bakeReport[layerName] = (native, baked);
        GD.Print($"[WallBaker] {layerName}: {native} tile-physics, {baked} baked");
    }

    /// <summary>
    /// Water-is-solid bake over the GROUND layer (user decision: water blocks movement). Every
    /// cell whose tile comes from a water atlas source (see <see cref="WaterSourceKeywords"/>)
    /// gets a full-cell rect on a "BakedWaterCollision" StaticBody2D — same default layer/mask as
    /// the wall baker, so player and roamers alike are stopped. Cells covered by a tile on a
    /// <see cref="BridgeOverlayLayers"/> layer are skipped (paint a bridge on GroundDecor/Props to
    /// cross water), and cells whose water tile somehow carries physics keep the no-double-bake
    /// guarantee. Counts land in <see cref="BakeReport"/> under "Water".
    /// </summary>
    private void BakeWaterCollision(TileMapLayer? ground)
    {
        if (ground?.TileSet == null || ground.TileSet.GetPhysicsLayersCount() == 0)
            return;

        var overlays = new List<TileMapLayer>();
        foreach (string layerName in BridgeOverlayLayers)
        {
            if (GetNodeOrNull<TileMapLayer>($"%{layerName}") is { } overlay)
                overlays.Add(overlay);
        }

        var body = new StaticBody2D { Name = "BakedWaterCollision" };
        ground.AddChild(body);

        var waterBySource = new Dictionary<int, bool>();
        var cellShape = new RectangleShape2D { Size = ground.TileSet.TileSize };
        int native = 0, baked = 0, bridged = 0;
        foreach (Vector2I cell in ground.GetUsedCells())
        {
            int sourceId = ground.GetCellSourceId(cell);
            if (!waterBySource.TryGetValue(sourceId, out bool isWater))
                waterBySource[sourceId] = isWater = IsWaterSource(ground.TileSet, sourceId);
            if (!isWater)
                continue;

            bool overlaid = false;
            foreach (TileMapLayer overlay in overlays)
            {
                if (overlay.GetCellSourceId(cell) != -1)
                {
                    overlaid = true;
                    break;
                }
            }
            if (overlaid)
            {
                bridged++;
                continue;
            }

            if (ground.GetCellTileData(cell) is not { } tileData)
                continue;
            if (tileData.GetCollisionPolygonsCount(0) > 0)
            {
                native++;
                continue;
            }

            body.AddChild(new CollisionShape2D { Shape = cellShape, Position = ground.MapToLocal(cell) });
            baked++;
        }

        WaterBridgedCells = bridged;
        _bakeReport["Water"] = (native, baked);
        GD.Print($"[WaterBaker] {ground.Name}: {native} tile-physics, {baked} baked, {bridged} bridged");
    }

    /// <summary>True when the atlas source's texture file name contains a
    /// <see cref="WaterSourceKeywords"/> keyword (case-insensitive). Public so tools/spikes can
    /// query the same water identity the baker uses.</summary>
    public bool IsWaterSource(TileSet tileSet, int sourceId)
    {
        if (sourceId < 0 || !tileSet.HasSource(sourceId))
            return false;
        if (tileSet.GetSource(sourceId) is not TileSetAtlasSource atlas || atlas.Texture == null)
            return false;

        string file = System.IO.Path.GetFileName(atlas.Texture.ResourcePath);
        foreach (string keyword in WaterSourceKeywords)
        {
            if (!string.IsNullOrEmpty(keyword) && file.Contains(keyword, StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    // ------------------------------------------------------------------ State events

    /// <summary>Subscribe the shared GameState events (HUD time/inventory, squad panel, loaded-game
    /// refresh) plus the scene's <see cref="WireExtraStateEvents"/>. Unsubscribed in _ExitTree.</summary>
    protected void WireStateEvents()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        gs.MinuteChanged += RefreshHudTime;
        gs.InventoryChanged += OnInventoryChanged;
        gs.GameLoaded += RefreshHudAll;
        gs.SquadChanged += RefreshSquadPanel;
        gs.SquadChanged += RefreshInventoryPanel; // deposit/withdraw shift Bulk/encumbrance
        gs.GoldChanged += OnGoldChanged;
        gs.SmithyChanged += RefreshSmithyPanel;
        gs.TradingPostChanged += RefreshTradingPostPanel;
        gs.RecipeCrafted += OnRecipeCrafted;
        gs.TreatWoundsResolved += OnTreatWoundsResolved;
        gs.SquadStatusNotice += OnSquadStatusNotice;
        gs.DayStarted += TryShowDaySummary;
        gs.BuildingChanged += OnBuildingChanged;
        gs.ConstructionCompleted += OnConstructionCompleted;
        gs.FriendshipChanged += OnFriendshipChanged;
        gs.GiftGiven += OnGiftGiven;
        gs.QuestStarted += OnQuestChanged;
        gs.QuestStarted += OnQuestStartedBanner;
        gs.QuestCompleted += OnQuestChanged;
        gs.QuestCompleted += OnQuestCompletedBanner;
        gs.QuestObjectiveProgressed += OnQuestObjectiveChanged;
        gs.Inventory.ItemAdded += OnItemAddedForFeed;
        WireExtraStateEvents(gs);
    }

    /// <summary>Scene-specific subscriptions (paired with <see cref="UnwireExtraStateEvents"/>).</summary>
    protected virtual void WireExtraStateEvents(GameState gs)
    {
    }

    /// <summary>Must drop exactly what <see cref="WireExtraStateEvents"/> subscribed.</summary>
    protected virtual void UnwireExtraStateEvents(GameState gs)
    {
    }

    // ------------------------------------------------------------------ HUD wiring (passive push)

    private void OnInventoryChanged(string itemId)
    {
        RefreshHudInventory();
        RefreshInventoryPanel();
        RefreshSmithyPanel();      // forge material affordability tracks carried stacks
        RefreshCraftingPanel();    // recipe have/need tracks carried stacks
        RefreshTradingPostPanel(); // buy fit + sell shelf track carried stacks
        RefreshFriendshipPanel();  // gift options track carried stacks
    }

    protected void RefreshHudAll()
    {
        RefreshHudTime();
        RefreshHudTool();
        RefreshHudInventory();
    }

    protected void RefreshHudTime()
    {
        var gs = GameState.Instance;
        if (Hud == null || gs == null)
            return;
        Hud.SetTimeDate(gs.Clock.TimeString(), gs.Clock.DateString());
    }

    protected void RefreshHudTool()
    {
        var gs = GameState.Instance;
        if (Hud == null || Player == null || gs == null)
            return;

        ItemDefinition? seed = Player.Tools.SelectedSeed;
        Hud.SetTool(
            Player.Tools.CurrentIndex,
            Player.Tools.CurrentDisplayName,
            seed?.DisplayName,
            seed == null ? 0 : gs.Inventory.Count(seed.Id));
    }

    protected void RefreshHudInventory()
    {
        var gs = GameState.Instance;
        if (Hud == null || gs == null)
            return;

        var list = new List<(string Name, int Count)>();
        foreach (var (id, qty) in gs.Inventory.Stacks)
            if (qty > 0 && Items.TryGet(id, out ItemDefinition def))
                list.Add((def.DisplayName, qty));
        list.Sort((a, b) => string.CompareOrdinal(a.Name, b.Name));

        Hud.SetInventory(list);
        RefreshHudTool(); // a spent/gained seed changes the tool-belt count too
    }

    // ------------------------------------------------------------------ Squad panel (passive push)

    private void OnSquadPanelToggled(bool open)
    {
        // Freeze the world while the panel is modal: no avatar input/motion, no clock ticks
        // (same seam SceneRouter uses for combat — Clock.IsPaused). During a hand-off the player
        // is already deliberately frozen — closing the panel must not walk them mid-scene-swap.
        if (Player != null && !IsTransitioning)
            Player.ProcessMode = open ? ProcessModeEnum.Disabled : ProcessModeEnum.Inherit;

        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = open;

        if (open)
        {
            CloseOtherModals(SquadPanel); // the economy modals never share the screen
            RefreshSquadPanel();
        }
    }

    // ------------------------------------------------------------------ Build panel (passive push)

    private void OnBuildPanelToggled(bool open)
    {
        // Same freeze seam as the squad panel: no avatar input, no clock ticks while modal.
        if (Player != null && !IsTransitioning)
            Player.ProcessMode = open ? ProcessModeEnum.Disabled : ProcessModeEnum.Inherit;

        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = open;

        if (open)
        {
            CloseOtherModals(BuildPanel); // the economy modals never share the screen
            RefreshBuildPanel();
        }
    }

    private void OnCommissionRequested(string buildingId)
        => GameState.Instance?.CommissionBuilding(buildingId);

    private void OnContributeRequested(string buildingId, string itemId, int qty)
        => GameState.Instance?.ContributeBundle(buildingId, itemId, qty);

    private void OnUpgradeRequested(string buildingId)
        => GameState.Instance?.UpgradeBuilding(buildingId);

    /// <summary>Building state changed (commission/contribute/upgrade): re-render the open panel so
    /// have/need + affordability stay live. The outpost's loader handles the world visual separately.</summary>
    private void OnBuildingChanged(string buildingId) => RefreshBuildPanel();

    /// <summary>A building's construction timer completed: a regular toast (distinct from the quest
    /// banner) announcing it — "«Name» is complete."</summary>
    private void OnConstructionCompleted(string buildingId)
    {
        string name = Buildings.TryGet(buildingId, out var def) ? def.DisplayName : buildingId;
        Hud?.ShowToast($"{name} is complete.", 3f);
    }

    private void RefreshBuildPanel()
    {
        if (BuildPanel == null || !BuildPanel.Visible)
            return;
        var view = GameState.Instance?.GetPlanningTableView();
        if (view != null)
            BuildPanel.Render(view);
    }

    // ------------------------------------------------------------------ Economy panels (inventory/smithy/crafting)

    /// <summary>Close every hotkey modal except <paramref name="keep"/> so only one is ever open
    /// (each Close is a no-op when already closed).</summary>
    private void CloseOtherModals(Node? keep)
    {
        if (SquadPanel != null && SquadPanel != keep) SquadPanel.Close();
        if (BuildPanel != null && BuildPanel != keep) BuildPanel.Close();
        if (InventoryPanel != null && InventoryPanel != keep) InventoryPanel.Close();
        if (SmithyPanel != null && SmithyPanel != keep) SmithyPanel.Close();
        if (CraftingPanel != null && CraftingPanel != keep) CraftingPanel.Close();
        if (TradingPostPanel != null && TradingPostPanel != keep) TradingPostPanel.Close();
        if (FriendshipPanel != null && FriendshipPanel != keep) FriendshipPanel.Close();
        if (QuestPanel != null && QuestPanel != keep) QuestPanel.Close();
        if (CalendarPanel != null && CalendarPanel != keep) CalendarPanel.Close();
        if (DialogueBox != null && DialogueBox != keep) DialogueBox.Close();
        if (PauseMenu != null && PauseMenu != keep) PauseMenu.Close();
    }

    /// <summary>True while any modal panel — including the pause menu and the one-shot day summary
    /// — is showing. The Esc handler below uses this so it never opens the pause menu over another
    /// modal (those panels already consume Esc to close themselves; this is the belt-and-suspenders
    /// check on top of that input-ordering guarantee, and the one the AnyModalOpen-logic spike
    /// exercises directly).</summary>
    protected bool AnyModalOpen =>
        (SquadPanel?.Visible ?? false)
        || (BuildPanel?.Visible ?? false)
        || (InventoryPanel?.Visible ?? false)
        || (SmithyPanel?.Visible ?? false)
        || (CraftingPanel?.Visible ?? false)
        || (TradingPostPanel?.Visible ?? false)
        || (FriendshipPanel?.Visible ?? false)
        || (QuestPanel?.Visible ?? false)
        || (CalendarPanel?.Visible ?? false)
        || (DialogueBox?.Visible ?? false)
        || (DaySummaryPanel?.Visible ?? false)
        || (PauseMenu?.Visible ?? false);

    /// <summary>
    /// Esc-to-open the pause menu. Only fires when no modal is open and no hand-off is mid-flight —
    /// every other modal's own _UnhandledInput consumes "ui_cancel" itself while visible (children
    /// process before this parent node per Godot's input propagation), so in practice this only
    /// ever runs on a genuinely unhandled Esc; AnyModalOpen is the explicit backstop.
    /// </summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (PauseMenu != null && !IsTransitioning && !AnyModalOpen && @event.IsActionPressed("ui_cancel"))
        {
            PauseMenu.Open();
            GetViewport().SetInputAsHandled();
        }
    }

    // ------------------------------------------------------------------ Pause menu (passive push)

    private void OnPauseMenuToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
            CloseOtherModals(PauseMenu);
    }

    private void OnPauseSaveRequested() => GameState.Instance?.SaveGame();

    /// <summary>Quit to title: mark the scene transitioning FIRST so nothing else (freeze toggles,
    /// other panels) reacts mid-swap, then route through SceneRouter (which pauses the day clock).</summary>
    private void OnQuitToTitleRequested()
    {
        IsTransitioning = true;
        SceneRouter.Instance?.GoToTitleScreen();
    }

    /// <summary>Shared modal freeze seam (same as the squad/build toggles): no avatar input, no clock
    /// ticks while a panel is open. Never unfreezes a deliberately frozen hand-off.</summary>
    private void SetModalFreeze(bool frozen)
    {
        if (Player != null && !IsTransitioning)
            Player.ProcessMode = frozen ? ProcessModeEnum.Disabled : ProcessModeEnum.Inherit;
        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = frozen;
    }

    private void OnInventoryPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(InventoryPanel);
            RefreshInventoryPanel();
        }
    }

    private void OnSmithyPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(SmithyPanel);
            RefreshSmithyPanel();
        }
    }

    private void OnCraftingPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(CraftingPanel);
            RefreshCraftingPanel();
        }
    }

    private void OnTradingPostPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(TradingPostPanel);
            RefreshTradingPostPanel();
        }
    }

    private void OnFriendshipPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(FriendshipPanel);
            RefreshFriendshipPanel();
        }
    }

    private void OnQuestPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(QuestPanel);
            RefreshQuestPanel();
        }
    }

    private void OnCalendarPanelToggled(bool open)
    {
        SetModalFreeze(open);
        if (open)
        {
            CloseOtherModals(CalendarPanel);
            RefreshCalendarPanel();
        }
    }

    private void OnDepositRequested(string memberId, string itemId, int qty)
        => GameState.Instance?.DepositToWarehouse(memberId, itemId, qty);

    private void OnWithdrawRequested(string memberId, string itemId, int qty)
        => GameState.Instance?.WithdrawFromWarehouse(memberId, itemId, qty);

    private void OnApplyRuneRequested(string memberId, RuneKind kind)
        => GameState.Instance?.ApplyWeaponRune(memberId, kind);

    private void OnBuyWeaponRequested(string memberId, string weaponSlug)
        => GameState.Instance?.BuyWeapon(memberId, weaponSlug);

    private void OnSellRequested(string itemId, int qty)
        => GameState.Instance?.SellItem(itemId, qty);

    private void OnBuyGoodRequested(string itemId, int count)
        => GameState.Instance?.BuyGood(itemId, count);

    private void OnCraftRequested(string recipeId, int count)
        => GameState.Instance?.Craft(recipeId, count);

    private void OnGiftRequested(string charId, string itemId)
        => GameState.Instance?.GiveGift(charId, itemId);

    /// <summary>Friendship points changed (gift/talk/award): re-render the open panel so pips and
    /// counters stay live.</summary>
    private void OnFriendshipChanged(string charId) => RefreshFriendshipPanel();

    /// <summary>Quest started/completed: re-render the open quest panel.</summary>
    private void OnQuestChanged(string questId) => RefreshQuestPanel();

    /// <summary>Quest objective progressed: re-render the open quest panel.</summary>
    private void OnQuestObjectiveChanged(string questId, int objectiveIndex) => RefreshQuestPanel();

    /// <summary>Quest started: flash the "New Quest" banner with the quest's title.</summary>
    private void OnQuestStartedBanner(string questId) => Hud?.ShowQuestBanner("New Quest", TitleOf(questId));

    /// <summary>Quest completed: flash the "Quest Complete" banner with the quest's title.</summary>
    private void OnQuestCompletedBanner(string questId) => Hud?.ShowQuestBanner("Quest Complete", TitleOf(questId));

    private static string TitleOf(string questId) => Quests.TryGet(questId, out var def) ? def.Title : questId;

    /// <summary>An inventory gain flowed through the party-level choke point (farm harvest, territory
    /// node yield, combat loot) — never fires during save-restore or the starter-inventory seed (see
    /// <see cref="Bulwark.Cozy.Inventory.ItemAdded"/>'s contract). Stacks a "+N Name" row into the
    /// HUD's item pickup feed.</summary>
    private void OnItemAddedForFeed(string itemId, int qty)
    {
        string name = Items.TryGet(itemId, out var def) ? def.DisplayName : itemId;
        Hud?.ShowItemGain(name, qty);
    }

    /// <summary>Gift resolved: flash the reaction toast (positive or negative delta).</summary>
    private void OnGiftGiven(string charId, string itemId, int delta)
    {
        string name = GameState.Instance?.GetFriendshipView()
            .Characters.Find(c => c.CharacterId == charId)?.DisplayName ?? charId;
        Hud?.ShowToast(delta >= 0
            ? $"{name} accepts your gift. (+{delta} friendship)"
            : $"{name} does not care for that. ({delta} friendship)", 2f);
    }

    private void OnGoldChanged(int gold)
    {
        RefreshInventoryPanel();
        RefreshSmithyPanel();
        RefreshTradingPostPanel();
    }

    private void OnRecipeCrafted(string recipeId) => RefreshCraftingPanel();

    protected void RefreshInventoryPanel()
    {
        if (InventoryPanel == null || !InventoryPanel.Visible)
            return;
        var gs = GameState.Instance;
        if (gs == null)
            return;
        InventoryPanel.Render(gs.GetInventoryView(), gs.Inventory.WarehouseAccessible);
    }

    protected void RefreshSmithyPanel()
    {
        if (SmithyPanel == null || !SmithyPanel.Visible)
            return;
        var gs = GameState.Instance;
        var view = gs?.GetSmithyView();
        if (gs == null || view == null)
            return;
        SmithyPanel.Render(view);
    }

    protected void RefreshTradingPostPanel()
    {
        if (TradingPostPanel == null || !TradingPostPanel.Visible)
            return;
        var view = GameState.Instance?.GetTradingPostView();
        if (view != null)
            TradingPostPanel.Render(view);
    }

    protected void RefreshCraftingPanel()
    {
        if (CraftingPanel == null || !CraftingPanel.Visible)
            return;
        var view = GameState.Instance?.GetCraftingView();
        if (view != null)
            CraftingPanel.Render(view);
    }

    protected void RefreshFriendshipPanel()
    {
        if (FriendshipPanel == null || !FriendshipPanel.Visible)
            return;
        var view = GameState.Instance?.GetFriendshipView();
        if (view != null)
            FriendshipPanel.Render(view, GetNearbyVillagerId());
    }

    protected void RefreshQuestPanel()
    {
        if (QuestPanel == null || !QuestPanel.Visible)
            return;
        var view = GameState.Instance?.GetQuestView();
        if (view != null)
            QuestPanel.Render(view);
    }

    protected void RefreshCalendarPanel()
    {
        if (CalendarPanel == null || !CalendarPanel.Visible)
            return;
        var view = GameState.Instance?.GetCalendarView();
        if (view != null)
            CalendarPanel.Render(view);
    }

    /// <summary>The villager NPC the player is standing beside, for the gift flow (scene knowledge —
    /// only the outpost hosts villager NPCs). Default: none.</summary>
    protected virtual string? GetNearbyVillagerId() => null;

    private void OnTreatWoundsRequested(string healerId, string targetId, int dc)
        => GameState.Instance?.TreatWounds(healerId, targetId, dc);

    private void OnTreatWoundsResolved(TreatWoundsResultView view)
        => SquadPanel?.ShowResult(view);

    /// <summary>Squad status lines (midnight exhaustion, the 30:00 dawn rollover) — shown wherever
    /// the day catches the player, same passive toast seam as the harvest/travel notices.</summary>
    private void OnSquadStatusNotice(string text) => Hud?.ShowToast(text, 3f);

    // ------------------------------------------------------------------ Day summary (passive push)

    /// <summary>
    /// Consume the one-shot staged day summary (if any) and show the modal — called on DayStarted
    /// (sleep and the 30:00 rollover end the day while a world scene is live) and once deferred
    /// from <see cref="SpawnDaySummaryPanel"/> (post-scene-swap arrivals, e.g. the defeat wake at
    /// the outpost). During a hand-off nothing is consumed: the staged summary survives the swap
    /// and the NEXT scene's _Ready consume shows it. Freezes the player and the day clock exactly
    /// like the squad-panel toggle; an open squad panel is closed first so the modals never fight.
    /// </summary>
    private void TryShowDaySummary()
    {
        if (DaySummaryPanel == null || DaySummaryPanel.Visible || IsTransitioning)
            return;

        var gs = GameState.Instance;
        var summary = gs?.ConsumeDaySummary();
        if (summary == null)
            return;

        // The squad panel yields the screen. Its Toggled(false) unfreezes the world; the summary
        // re-freezes right below, so the net state is "frozen for the summary".
        SquadPanel?.Close();

        if (Player != null)
            Player.ProcessMode = ProcessModeEnum.Disabled;
        var clock = gs!.Clock;
        if (clock != null)
            clock.IsPaused = true;

        DaySummaryPanel.Open(summary);
    }

    private void OnDaySummaryClosed()
    {
        // Mirror OnSquadPanelToggled(false): never unfreeze a deliberately frozen hand-off.
        if (Player != null && !IsTransitioning)
            Player.ProcessMode = ProcessModeEnum.Inherit;

        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = false;
    }

    protected void RefreshSquadPanel()
    {
        if (SquadPanel == null || !SquadPanel.Visible)
            return;

        var view = GameState.Instance?.GetSquadPanelView();
        if (view != null)
            SquadPanel.Render(view);
    }

    /// <summary>Stardew-subtle rejection feedback ("Can't till here"): short toast, rate-limited
    /// so a mashed or held interact shows it once per attempt-burst, never per frame.</summary>
    protected void ShowRejectionToast(string text)
    {
        ulong now = Time.GetTicksMsec();
        if (now - _lastRejectionToastMs < RejectionToastCooldownMs)
            return;
        _lastRejectionToastMs = now;
        Hud?.ShowToast(text, 1.2f);
    }

    // ------------------------------------------------------------------ Scene hand-off

    /// <summary>Freeze the avatar, flash the departure/encounter toast, then run
    /// <paramref name="route"/> after <see cref="HandOffDelaySeconds"/> — the shared pacing that
    /// keeps the toast readable across the scene swap.</summary>
    protected void BeginHandOff(string toast, Action route)
    {
        IsTransitioning = true;
        if (Player != null)
            Player.ProcessMode = ProcessModeEnum.Disabled;
        Hud?.ShowToast(toast, HandOffToastSeconds);
        GetTree().CreateTimer(HandOffDelaySeconds).Timeout += () => route();
    }
}
