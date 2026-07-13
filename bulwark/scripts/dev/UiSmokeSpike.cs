using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Territory;
using Bulwark.UI;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless instantiation smoke for every scenes/ui/*.tscn after the cozy UI-theme pass. For each
/// UI scene it instantiates the PackedScene, adds it to the tree, waits for layout, asserts the
/// %UniqueName nodes its script contract depends on resolve, spot-checks that key panels laid out
/// with a non-zero size, and exercises the passive render entry points (Render/SetX/ShowX) with
/// tiny view-models. Prints PASS/FAIL per check; the final SPIKE RESULT line gates the exit code.
/// </summary>
public partial class UiSmokeSpike : SpikeBase
{
    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== UI SMOKE SPIKE ====================");

        var theme = GD.Load<Theme>("res://assets/ui/ui_theme.tres");
        Check("ui_theme.tres loads as a Theme resource", theme != null);

        CheckToolBelt();
        CheckInputMapActions();
        await CheckCozyHud();
        await CheckInputLegendScene();
        await CheckCombatHudLegend();
        await CheckActionBar();
        await CheckActionChip();
        await CheckTurnOrderBar();
        await CheckTurnOrderChip();
        await CheckCombatLog();
        await CheckVictoryBanner();
        await CheckReactionPrompt();
        await CheckSquadPanel();
        await CheckDaySummaryPanel();
        await CheckPartySelect();
        await CheckInventoryPanel();
        await CheckSmithyPanel();
        await CheckCraftingPanel();
        await CheckTradingPostPanel();

        FinishAndQuit("UiSmoke");
    }

    // ------------------------------------------------------------------ plain-C# checks

    /// <summary>Unit-style checks for the ToolBelt selection API (pure C#, no scene needed).</summary>
    private void CheckToolBelt()
    {
        GD.Print("-------------------- tool_belt --------------------");
        var belt = new ToolBelt();
        Check("tool_belt starts on Hoe (slot 0)", belt.Current == ToolKind.Hoe && belt.CurrentIndex == 0);

        belt.SelectTool(4);
        Check("SelectTool(4) selects Pick", belt.Current == ToolKind.Pick);

        belt.SelectTool(6);
        belt.SelectTool(-1);
        Check("out-of-range SelectTool is ignored", belt.Current == ToolKind.Pick);

        belt.CycleTool();
        Check("Tab cycles forward from the direct selection", belt.Current == ToolKind.Hand);
        belt.CycleTool();
        Check("Tab wraps past the last slot", belt.Current == ToolKind.Hoe);
        belt.CycleToolBack();
        Check("wheel-up cycles backward with wrap", belt.Current == ToolKind.Hand);

        int changed = 0;
        belt.Changed += () => changed++;
        belt.SelectTool(5);
        Check("re-selecting the active non-seed slot is a no-op", belt.Current == ToolKind.Hand && changed == 0);

        var seedA = new ItemDefinition { Id = "smoke_a", DisplayName = "Smoke A", Category = ItemCategory.Seed, CropId = "a" };
        var seedB = new ItemDefinition { Id = "smoke_b", DisplayName = "Smoke B", Category = ItemCategory.Seed, CropId = "b" };
        belt.RefreshSeeds(new List<ItemDefinition> { seedA, seedB });
        belt.SelectTool(2);
        Check("SelectTool(2) selects Seeds with first seed", belt.Current == ToolKind.Seeds && belt.SelectedSeed == seedA);
        belt.SelectTool(2);
        Check("re-selecting the Seeds slot cycles the held seed", belt.SelectedSeed == seedB);
        belt.CycleSeed();
        Check("Q still cycles seeds after direct selection", belt.SelectedSeed == seedA);
    }

    /// <summary>The select_tool actions exist and carry both main-row and keypad digit bindings.</summary>
    private void CheckInputMapActions()
    {
        GD.Print("-------------------- input_map --------------------");
        for (int i = 1; i <= 6; i++)
            Check($"input map defines select_tool_{i}", InputMap.HasAction($"select_tool_{i}"));
        Check("existing cycle_tool / cycle_seed / interact actions untouched", InputMap.HasAction("cycle_tool") && InputMap.HasAction("cycle_seed") && InputMap.HasAction("interact"));

        bool hasMainRow = false, hasKeypad = false;
        foreach (InputEvent ev in InputMap.ActionGetEvents("select_tool_1"))
        {
            if (ev is not InputEventKey key) continue;
            if (key.Keycode == Key.Key1) hasMainRow = true;
            if (key.Keycode == Key.Kp1) hasKeypad = true;
        }
        Check("select_tool_1 bound to main-row 1", hasMainRow);
        Check("select_tool_1 bound to keypad 1", hasKeypad);
    }

    // ------------------------------------------------------------------ per-scene checks

    private async Task CheckCozyHud()
    {
        GD.Print("-------------------- cozy_hud --------------------");
        var hud = await Spawn<CozyHud>("res://scenes/ui/cozy_hud.tscn");
        if (hud == null) return;

        foreach (string n in new[]
                 {
                     "%TimeLabel", "%DateLabel", "%ToolLabel", "%SeedLabel", "%InventoryLabel",
                     "%InventoryPanel", "%FadeRect", "%ToastLabel", "%ToastPanel",
                     "%Slot0", "%Slot1", "%Slot2", "%Slot3", "%Slot4", "%Slot5",
                     "%SlotBadge0", "%SlotBadge1", "%SlotBadge2", "%SlotBadge3", "%SlotBadge4", "%SlotBadge5",
                     "%ControlsLegend", "%ZoomInButton", "%ZoomOutButton",
                 })
            CheckNode(hud, n);

        hud.SetTimeDate("6:00 AM", "Spring 1, Year 1");
        hud.SetTool(2, "Seeds", "Parsnip", 5);
        hud.SetInventory(new List<(string, int)> { ("Parsnip", 3), ("Log", 12) });
        hud.ShowToast("Smoke toast", 0.1f);
        await Frames(2);

        Check("cozy_hud hotbar slot has non-zero size", NonZeroSize(hud.GetNodeOrNull<Control>("%Slot0")));
        Check("cozy_hud Seeds slot highlighted when Seeds tool active", hud.GetNodeOrNull<Control>("%Slot2")?.ThemeTypeVariation == "HotbarSlotSelected");
        Check("cozy_hud inventory panel visible with items", hud.GetNodeOrNull<Control>("%InventoryPanel")?.Visible == true);

        Check("cozy_hud slot number badges read 1..6", hud.GetNodeOrNull<Label>("%SlotBadge0")?.Text == "1"
              && hud.GetNodeOrNull<Label>("%SlotBadge5")?.Text == "6");

        var legend = hud.GetNodeOrNull<Control>("%ControlsLegend");
        Check("cozy_hud controls legend has non-zero size", NonZeroSize(legend));
        Check("cozy_hud legend first row lists WASD", legend?.GetNodeOrNull<Label>("%Key0")?.Text == "WASD");
        Check("cozy_hud legend uses all five rows", legend?.GetNodeOrNull<Label>("%Key4")?.Visible == true);
        hud.SetLegendVisible(false);
        Check("SetLegendVisible(false) hides the legend", legend?.Visible == false);
        hud.SetLegendVisible(true);
        Check("SetLegendVisible(true) shows it again", legend?.Visible == true);

        int zoomIn = 0, zoomOut = 0;
        hud.ZoomInRequested += () => zoomIn++;
        hud.ZoomOutRequested += () => zoomOut++;
        hud.GetNode<Button>("%ZoomInButton").EmitSignal(BaseButton.SignalName.Pressed);
        hud.GetNode<Button>("%ZoomOutButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("zoom buttons raise ZoomInRequested/ZoomOutRequested", zoomIn == 1 && zoomOut == 1);

        hud.QueueFree();
        await Frames(1);
    }

    private async Task CheckInputLegendScene()
    {
        GD.Print("-------------------- input_legend --------------------");
        var legend = await Spawn<InputLegend>("res://scenes/ui/input_legend.tscn");
        if (legend == null) return;

        for (int i = 0; i < InputLegend.MaxRows; i++)
        {
            CheckNode(legend, $"%Key{i}");
            CheckNode(legend, $"%Action{i}");
        }

        legend.SetRows(new List<(string, string)> { ("X", "Test"), ("Y", "Other") });
        await Frames(1);
        Check("input_legend renders fed rows", legend.GetNodeOrNull<Label>("%Key1")?.Text == "Y"
              && legend.GetNodeOrNull<Label>("%Action1")?.Text == "Other");
        Check("input_legend hides unused rows", legend.GetNodeOrNull<Label>("%Key2")?.Visible == false);
        Check("input_legend carries the shared theme", legend.Theme != null);

        legend.QueueFree();
        await Frames(1);
    }

    /// <summary>The combat scene's HUD carries the upper-left legend, fed by CombatScene._Ready.</summary>
    private async Task CheckCombatHudLegend()
    {
        GD.Print("-------------------- combat hud legend --------------------");
        var combat = await Spawn<CombatScene>("res://scenes/combat/combat.tscn");
        if (combat == null) return;

        var legend = combat.GetNodeOrNull<Control>("%ControlsLegend");
        Check("combat: %ControlsLegend resolves", legend != null);
        await Frames(1);
        Check("combat controls legend has non-zero size", NonZeroSize(legend));
        Check("combat legend first row lists LMB", legend?.GetNodeOrNull<Label>("%Key0")?.Text == "LMB");
        Check("combat legend uses all five rows", legend?.GetNodeOrNull<Label>("%Key4")?.Visible == true);

        combat.QueueFree();
        await Frames(1);
    }

    private async Task CheckActionBar()
    {
        GD.Print("-------------------- action_bar --------------------");
        var bar = await Spawn<ActionBar>("res://scenes/ui/action_bar.tscn");
        if (bar == null) return;

        foreach (string n in new[]
                 {
                     "%ActorLabel", "%Pip0", "%Pip1", "%Pip2", "%MoveButton", "%StepButton",
                     "%StrikeButton", "%ShieldButton", "%EndButton", "%AiToggle",
                     "%AutoReactToggle", "%PreviewLabel", "%ChipRow",
                 })
            CheckNode(bar, n);

        bar.SetInteractable(true);
        bar.Render(new ActionBarState
        {
            ActorName = "Veteran", ActionsRemaining = 2, Map = -5,
            CanMove = true, CanStep = true, CanStrike = true, CanRaiseShield = false,
        });
        bar.ShowAttackPreview(null);
        await Frames(2);

        Check("action_bar panel has non-zero size", NonZeroSize(bar.GetNodeOrNull<Control>("Panel")));
        Check("action_bar Strike button shows MAP", bar.GetNodeOrNull<Button>("%StrikeButton")?.Text == "Strike (-5)");
        Check("action_bar root carries the shared theme", bar.Theme != null);

        var previewLabel = bar.GetNodeOrNull<Label>("%PreviewLabel");
        bar.SetTargetingHint(true);
        Check("action_bar shows LMB/Esc hint while targeting with no preview", previewLabel?.Text.Contains("LMB") == true && previewLabel.Text.Contains("Esc"));
        bar.ShowAttackPreview(new AttackPreviewView
        {
            AttackerName = "Veteran", TargetName = "Goblin",
            WeaponName = "Sword", TotalAttackBonus = 7, TargetAc = 15,
            HitChancePercent = 60, CritChancePercent = 5, DamageFormula = "1d8+4",
        });
        Check("attack preview overrides the targeting hint", previewLabel?.Text.Contains("Sword") == true);
        bar.ShowAttackPreview(null);
        Check("hint returns when the preview clears mid-targeting", previewLabel?.Text.Contains("LMB") == true);
        bar.SetTargetingHint(false);
        Check("hint clears when targeting ends", previewLabel?.Text == "");

        bar.QueueFree();
        await Frames(1);
    }

    private async Task CheckActionChip()
    {
        GD.Print("-------------------- action_chip --------------------");
        var chip = await Spawn<Button>("res://scenes/ui/action_chip.tscn");
        if (chip == null) return;

        chip.Text = "Smoke chip";
        await Frames(1);
        Check("action_chip uses the ActionChip variation", chip.ThemeTypeVariation == "ActionChip");

        chip.QueueFree();
        await Frames(1);
    }

    private async Task CheckTurnOrderBar()
    {
        GD.Print("-------------------- turn_order_bar --------------------");
        var bar = await Spawn<TurnOrderBar>("res://scenes/ui/turn_order_bar.tscn");
        if (bar == null) return;

        CheckNode(bar, "%Row");
        bar.Render(new List<UnitView>
        {
            new() { Name = "Veteran", TeamId = 1, IsCurrent = true },
            new() { Name = "Goblin", TeamId = 2 },
            new() { Name = "Scout", TeamId = 1, IsDead = true },
        });
        await Frames(2);

        Check("turn_order_bar renders one chip per combatant", bar.GetNodeOrNull<Control>("%Row")?.GetChildCount() == 3);
        Check("turn_order_bar panel has non-zero size", NonZeroSize(bar.GetNodeOrNull<Control>("Panel")));

        bar.QueueFree();
        await Frames(1);
    }

    private async Task CheckTurnOrderChip()
    {
        GD.Print("-------------------- turn_order_chip --------------------");
        var chip = await Spawn<PanelContainer>("res://scenes/ui/turn_order_chip.tscn");
        if (chip == null) return;

        CheckNode(chip, "%Label");
        chip.QueueFree();
        await Frames(1);
    }

    private async Task CheckCombatLog()
    {
        GD.Print("-------------------- combat_log_panel --------------------");
        var log = await Spawn<CombatLogPanel>("res://scenes/ui/combat_log_panel.tscn");
        if (log == null) return;

        CheckNode(log, "%Log");
        for (int sev = 0; sev < 10; sev++)
            log.AppendEntry($"severity {sev} line", sev, isDetail: sev % 2 == 1);
        log.AppendEntry("bbcode [escape] check", 0, false);
        await Frames(2);

        Check("combat_log escapes bbcode and renders entries", log.GetNodeOrNull<RichTextLabel>("%Log")?.GetParsedText().Contains("bbcode [escape] check") == true);
        log.ClearLog();

        log.QueueFree();
        await Frames(1);
    }

    private async Task CheckVictoryBanner()
    {
        GD.Print("-------------------- victory_banner --------------------");
        var banner = await Spawn<VictoryBanner>("res://scenes/ui/victory_banner.tscn");
        if (banner == null) return;

        CheckNode(banner, "%VictoryLabel");
        CheckNode(banner, "%RestartButton");
        banner.ShowResult("Victory!", new Color(1f, 0.9f, 0.4f));
        await Frames(1);
        Check("victory_banner becomes visible on ShowResult", banner.Visible);

        banner.QueueFree();
        await Frames(1);
    }

    private async Task CheckReactionPrompt()
    {
        GD.Print("-------------------- reaction_prompt_panel --------------------");
        var prompt = await Spawn<ReactionPromptPanel>("res://scenes/ui/reaction_prompt_panel.tscn");
        if (prompt == null) return;

        foreach (string n in new[]
                 { "%TitleLabel", "%ReactorLabel", "%DescriptionLabel", "%UseButton", "%SkipButton" })
            CheckNode(prompt, n);

        Task<bool> choice = prompt.ShowAsync(new ReactionPromptView
        {
            ReactionName = "Shield Block", ReactorName = "Veteran", Description = "Absorb 5 damage.",
        });
        await Frames(1);
        Check("reaction_prompt visible while awaiting choice", prompt.Visible);
        prompt.GetNode<Button>("%UseButton").EmitSignal(BaseButton.SignalName.Pressed);
        bool used = await choice;
        Check("reaction_prompt Use button resolves the awaited choice as true", used);
        Check("reaction_prompt hides after resolving", !prompt.Visible);

        prompt.QueueFree();
        await Frames(1);
    }

    private async Task CheckSquadPanel()
    {
        GD.Print("-------------------- squad_panel --------------------");
        var panel = await Spawn<SquadPanel>("res://scenes/ui/squad_panel.tscn");
        if (panel == null) return;

        for (int i = 0; i < 4; i++)
            foreach (string n in new[] { $"%Name{i}", $"%HpBar{i}", $"%Hp{i}", $"%Cond{i}", $"%Immune{i}", $"%Treat{i}", $"%Healer{i}", $"%Dc{i}" })
                CheckNode(panel, n);
        foreach (string n in new[] { "%FlowSection", "%FlowLabel", "%ConfirmButton", "%CancelButton", "%ResultLabel" })
            CheckNode(panel, n);

        panel.Render(new SquadPanelView
        {
            Members = new List<SquadMemberView>
            {
                new() { Id = "vet", Name = "Veteran", CurrentHp = 10, MaxHp = 40 },
                new() { Id = "scout", Name = "Scout", CurrentHp = 30, MaxHp = 30 },
            },
        });
        await Frames(2);

        var bar0 = panel.GetNodeOrNull<ProgressBar>("%HpBar0");
        Check("squad_panel HP bar reflects the rendered view", bar0 != null && bar0.MaxValue == 40 && (int)bar0.Value == 10);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckDaySummaryPanel()
    {
        GD.Print("-------------------- day_summary_panel --------------------");
        var panel = await Spawn<DaySummaryPanel>("res://scenes/ui/day_summary_panel.tscn");
        if (panel == null) return;

        foreach (string n in new[]
                 {
                     "%TitleLabel", "%FatigueLabel", "%HarvestSection", "%HarvestLabel",
                     "%BattlesSection", "%BattlesLabel", "%XpSection", "%XpLabel",
                     "%LevelUpsSection", "%LevelUpsLabel", "%OnwardButton",
                 })
            CheckNode(panel, n);

        Check("day_summary starts hidden", !panel.Visible);

        // Populated view: every section visible with the expected lines.
        panel.Open(new DaySummaryView
        {
            Date = "Spring 3, Year 1",
            ItemsGained = new Dictionary<string, int> { ["wood"] = 5, ["turnip"] = 2 },
            CropsHarvested = 2,
            XpAwarded = 80,
            EncountersWon = 1,
            EncountersLost = 0,
            TreatWoundsUses = 1,
            AllNighter = false,
            FatigueNotice = null,
            LevelUps = new List<SquadLevelUpView> { new("vet", "Maren", 2, 3) },
        });
        await Frames(2);

        Check("day_summary visible after Open", panel.Visible);
        Check("day_summary title carries the ended day's date",
            panel.GetNodeOrNull<Label>("%TitleLabel")?.Text == "Day complete — Spring 3, Year 1");
        var harvestLabel = panel.GetNodeOrNull<Label>("%HarvestLabel");
        Check("day_summary harvest section visible with resolved item names",
            panel.GetNodeOrNull<Control>("%HarvestSection")?.Visible == true
            && harvestLabel?.Text.Contains("Wood × 5") == true
            && harvestLabel.Text.Contains("Turnip × 2")
            && harvestLabel.Text.Contains("Crops harvested: 2"));
        Check("day_summary battles section shows won/lost + treatments",
            panel.GetNodeOrNull<Control>("%BattlesSection")?.Visible == true
            && panel.GetNodeOrNull<Label>("%BattlesLabel")?.Text.Contains("Won 1 — Lost 0") == true);
        Check("day_summary XP section shows the award",
            panel.GetNodeOrNull<Control>("%XpSection")?.Visible == true
            && panel.GetNodeOrNull<Label>("%XpLabel")?.Text.Contains("+80 XP") == true);
        Check("day_summary level-up line reads \"Maren — Level 3!\"",
            panel.GetNodeOrNull<Control>("%LevelUpsSection")?.Visible == true
            && panel.GetNodeOrNull<Label>("%LevelUpsLabel")?.Text == "Maren — Level 3!");
        Check("day_summary fatigue line hidden after a real rest",
            panel.GetNodeOrNull<Label>("%FatigueLabel")?.Visible == false);
        Check("day_summary panel has non-zero size",
            NonZeroSize(panel.GetNodeOrNull<Control>("Root/Center/Panel")));

        int closed = 0;
        panel.Closed += () => closed++;
        panel.GetNode<Button>("%OnwardButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("day_summary Onward raises Closed once and hides", closed == 1 && !panel.Visible);

        // Empty all-nighter view: zero-content sections hidden, fatigue line shown.
        panel.Open(new DaySummaryView
        {
            Date = "Spring 4, Year 1",
            ItemsGained = new Dictionary<string, int>(),
            CropsHarvested = 0,
            XpAwarded = 0,
            EncountersWon = 0,
            EncountersLost = 0,
            TreatWoundsUses = 0,
            AllNighter = true,
            FatigueNotice = "The squad pushed through the night — Fatigued",
            LevelUps = new List<SquadLevelUpView>(),
        });
        await Frames(1);

        Check("day_summary zero-content sections hidden",
            panel.GetNodeOrNull<Control>("%HarvestSection")?.Visible == false
            && panel.GetNodeOrNull<Control>("%BattlesSection")?.Visible == false
            && panel.GetNodeOrNull<Control>("%XpSection")?.Visible == false
            && panel.GetNodeOrNull<Control>("%LevelUpsSection")?.Visible == false);
        Check("day_summary all-nighter fatigue line shown",
            panel.GetNodeOrNull<Label>("%FatigueLabel")?.Visible == true
            && panel.GetNodeOrNull<Label>("%FatigueLabel")?.Text.Contains("Fatigued") == true);

        panel.Close();
        Check("day_summary Close raises Closed again", closed == 2);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckPartySelect()
    {
        GD.Print("-------------------- party_select_panel --------------------");
        var panel = await Spawn<PartySelectPanel>("res://scenes/ui/party_select_panel.tscn");
        if (panel == null) return;

        foreach (string n in new[]
                 { "%TitleLabel", "%LeaderLabel", "%Companion0", "%Companion1", "%Companion2", "%ConfirmButton", "%CancelButton" })
            CheckNode(panel, n);

        var view = new PartySelectView { DestinationName = "the Fringe", LeaderName = "Veteran", TravelMinutes = 30 };
        view.Companions.Add(new CompanionOptionView { Id = "scout", Name = "Scout", HpText = "30/30", CanJoin = true });
        panel.Open(view);
        await Frames(1);
        Check("party_select opens with a view", panel.Visible);
        Check("party_select title shows the destination", panel.GetNodeOrNull<Label>("%TitleLabel")?.Text.Contains("the Fringe") == true);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckInventoryPanel()
    {
        GD.Print("-------------------- inventory_panel --------------------");
        var panel = await Spawn<InventoryPanel>("res://scenes/ui/inventory_panel.tscn");
        if (panel == null) return;

        foreach (string n in new[] { "%Body", "%GoldLabel" })
            CheckNode(panel, n);

        var view = new InventoryView
        {
            Gold = 125,
            Members = new List<MemberInventoryView>
            {
                new()
                {
                    MemberId = "vet", Name = "Veteran",
                    Stacks = new Dictionary<string, int> { ["wood"] = 6 },
                    CarriedBulk = 9.5, EncumberedThreshold = 7, MaxBulk = 12, Encumbered = true,
                },
            },
            Warehouse = new Dictionary<string, int> { ["stone"] = 4 },
        };

        // At the outpost: warehouse stacks + take affordance render.
        panel.Render(view, warehouseAccessible: true);
        await Frames(2);
        Check("inventory_panel gold counter renders", panel.GetNodeOrNull<Label>("%GoldLabel")?.Text.Contains("125") == true);
        Check("inventory_panel shows the member Bulk load line", HasLabelContaining(panel, "Bulk 9.5"));
        Check("inventory_panel flags the encumbered member", HasLabelContaining(panel, "ENCUMBERED"));
        Check("inventory_panel renders the warehouse take affordance when accessible", FindButton(panel, "◂ Take") != null);

        int deposits = 0; string? depItem = null;
        panel.DepositRequested += (mid, iid, qty) => { deposits++; depItem = iid; };
        FindButton(panel, "Store ▸")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("inventory_panel Store raises DepositRequested with the stack", deposits == 1 && depItem == "wood");

        int withdraws = 0;
        panel.WithdrawRequested += (mid, iid, qty) => withdraws++;
        FindButton(panel, "◂ Take")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("inventory_panel Take raises WithdrawRequested", withdraws == 1);

        // In the field: warehouse withheld with a note, no take affordance, deposit disabled.
        panel.Render(view, warehouseAccessible: false);
        await Frames(1);
        Check("inventory_panel hides warehouse stacks when not accessible", FindButton(panel, "◂ Take") == null);
        Check("inventory_panel disables Store when the warehouse is unreachable", FindButton(panel, "Store ▸")?.Disabled == true);
        Check("inventory_panel explains the warehouse is outpost-only in the field", HasLabelContaining(panel, "only reachable back at the outpost"));

        bool lastOpen = true;
        panel.Toggled += open => lastOpen = open;
        panel.Visible = true;
        panel.Close();
        Check("inventory_panel Close hides and raises Toggled(false)", !panel.Visible && lastOpen == false);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckSmithyPanel()
    {
        GD.Print("-------------------- smithy_panel --------------------");
        var panel = await Spawn<SmithyPanel>("res://scenes/ui/smithy_panel.tscn");
        if (panel == null) return;

        foreach (string n in new[] { "%Body", "%GoldLabel" })
            CheckNode(panel, n);

        var view = new SmithyView
        {
            Gold = 500,
            Members = new List<SmithyMemberView>
            {
                new()
                {
                    MemberId = "vet", Name = "Veteran", WeaponName = "Longsword",
                    PotencyBonus = 0, HasStriking = false,
                    RuneUpgrades = new List<SmithyRuneOption>
                    {
                        new() { Kind = RuneKind.Potency, Label = "Potency +1", Cost = 100, ReagentCost = 1, Available = true, CanAfford = true },
                    },
                },
            },
            Weapons = new List<SmithyWeaponOption>
            {
                new() { WeaponSlug = "greatsword", DisplayName = "Greatsword", Price = 200, MetalCost = 2, CanAfford = true },
            },
        };
        panel.Render(view);
        await Frames(2);
        Check("smithy_panel gold counter renders", panel.GetNodeOrNull<Label>("%GoldLabel")?.Text.Contains("500") == true);
        Check("smithy_panel shows a rune upgrade row", HasLabelContaining(panel, "Potency +1"));
        Check("smithy_panel shows the weapon metal-material cost (physical model)", HasLabelContaining(panel, "200g + 2"));
        Check("smithy_panel shows the rune reagent cost", HasLabelContaining(panel, "100g + 1"));
        // Reframe: the smithy is a forge/rune bench — selling moved to the Trading Post.
        Check("smithy_panel presents a Forge shelf (not a store)", HasLabelContaining(panel, "Forge Weapons"));
        Check("smithy_panel no longer shows a Sell Surplus shelf", !HasLabelContaining(panel, "Sell Surplus"));
        Check("smithy_panel no longer shows a sell button", FindButton(panel, "Sell 1") == null);

        int runes = 0; RuneKind runeKind = default;
        panel.ApplyRuneRequested += (mid, k) => { runes++; runeKind = k; };
        FindButton(panel, "Apply")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("smithy_panel Apply raises ApplyRuneRequested(Potency)", runes == 1 && runeKind == RuneKind.Potency);

        int buys = 0; string? boughtSlug = null;
        panel.BuyWeaponRequested += (mid, slug) => { buys++; boughtSlug = slug; };
        FindButton(panel, "Forge")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("smithy_panel Forge raises BuyWeaponRequested with the slug", buys == 1 && boughtSlug == "greatsword");

        bool lastOpen = true;
        panel.Toggled += open => lastOpen = open;
        panel.Visible = true;
        panel.Close();
        Check("smithy_panel Close hides and raises Toggled(false)", !panel.Visible && lastOpen == false);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckCraftingPanel()
    {
        GD.Print("-------------------- crafting_panel --------------------");
        var panel = await Spawn<CraftingPanel>("res://scenes/ui/crafting_panel.tscn");
        if (panel == null) return;

        CheckNode(panel, "%Body");

        var view = new CraftingView
        {
            Recipes = new List<CraftableRecipeView>
            {
                new()
                {
                    RecipeId = "plank", DisplayName = "Plank", OutputItemId = "plank",
                    OutputDisplayName = "Plank", OutputQuantity = 1, CraftMinutes = 10,
                    Inputs = new List<RecipeInputView>
                    {
                        new() { ItemId = "wood", DisplayName = "Wood", Need = 2, Have = 6 },
                    },
                    Unlocked = true, HasInputs = true, Fits = true,
                },
                new()
                {
                    RecipeId = "cloth", DisplayName = "Cloth", OutputItemId = "cloth",
                    OutputDisplayName = "Cloth", OutputQuantity = 1, CraftMinutes = 15,
                    Inputs = new List<RecipeInputView>
                    {
                        new() { ItemId = "fiber", DisplayName = "Fiber", Need = 3, Have = 0 },
                    },
                    RequiredCategory = "loom", Unlocked = false, HasInputs = false, Fits = true,
                },
            },
        };

        panel.Render(view);
        await Frames(2);
        Check("crafting_panel shows a recipe input have/need line", HasLabelContaining(panel, "Wood   6/2"));
        Check("crafting_panel shows the locked recipe's requirement", HasLabelContaining(panel, "requires loom"));

        var craftButtons = new List<Button>();
        CollectButtons(panel, "Craft", craftButtons);
        Check("crafting_panel renders a Craft button per recipe", craftButtons.Count == 2);
        Check("crafting_panel disables Craft for the uncraftable recipe",
            craftButtons.Exists(b => !b.Disabled) && craftButtons.Exists(b => b.Disabled));

        int crafts = 0; string? craftedId = null;
        panel.CraftRequested += (rid, count) => { crafts++; craftedId = rid; };
        craftButtons.Find(b => !b.Disabled)?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("crafting_panel Craft raises CraftRequested for the ready recipe", crafts == 1 && craftedId == "plank");

        bool lastOpen = true;
        panel.Toggled += open => lastOpen = open;
        panel.Visible = true;
        panel.Close();
        Check("crafting_panel Close hides and raises Toggled(false)", !panel.Visible && lastOpen == false);

        panel.QueueFree();
        await Frames(1);
    }

    private async Task CheckTradingPostPanel()
    {
        GD.Print("-------------------- trading_post_panel --------------------");
        var panel = await Spawn<TradingPostPanel>("res://scenes/ui/trading_post_panel.tscn");
        if (panel == null) return;

        foreach (string n in new[] { "%Body", "%GoldLabel" })
            CheckNode(panel, n);

        var view = new TradingPostView
        {
            Gold = 250,
            Offers = new List<TradingPostOffer>
            {
                new() { ItemId = "turnip_seed", DisplayName = "Turnip Seeds", Price = 6, Unlocked = true, CanAfford = true, Fits = true },
                new() { ItemId = "copper_ingot", DisplayName = "Copper Ingot", Price = 45, Unlocked = false, CanAfford = false, Fits = true },
            },
            SellShelf = new List<TradingPostSellStack>
            {
                new() { ItemId = "goblin_fang", DisplayName = "Goblin Fang", Quantity = 3, UnitValue = 5 },
            },
        };

        panel.Render(view);
        await Frames(2);
        Check("trading_post_panel gold counter renders", panel.GetNodeOrNull<Label>("%GoldLabel")?.Text.Contains("250") == true);
        Check("trading_post_panel shows a buy offer with price", HasLabelContaining(panel, "Turnip Seeds"));
        Check("trading_post_panel shows the locked-offer smithy hint", HasLabelContaining(panel, "locked (upgrade the smithy)"));
        Check("trading_post_panel shows a sellable surplus row", HasLabelContaining(panel, "Goblin Fang"));

        int buys = 0; string? boughtId = null; int boughtCount = 0;
        panel.BuyRequested += (iid, count) => { buys++; boughtId = iid; boughtCount = count; };
        FindButton(panel, "Buy")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("trading_post_panel Buy raises BuyRequested(turnip_seed, 1)", buys == 1 && boughtId == "turnip_seed" && boughtCount == 1);

        int sells = 0; int sellQty = 0;
        panel.SellRequested += (iid, qty) => { sells++; sellQty = qty; };
        FindButton(panel, "Sell 1")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("trading_post_panel Sell raises SellRequested", sells == 1 && sellQty == 1);

        bool lastOpen = true;
        panel.Toggled += open => lastOpen = open;
        panel.Visible = true;
        panel.Close();
        Check("trading_post_panel Close hides and raises Toggled(false)", !panel.Visible && lastOpen == false);

        panel.QueueFree();
        await Frames(1);
    }

    // ------------------------------------------------------------------ helpers

    /// <summary>Depth-first search for the first Button whose text equals <paramref name="text"/>.</summary>
    private static Button? FindButton(Node root, string text)
    {
        if (root is Button b && b.Text == text)
            return b;
        foreach (Node c in root.GetChildren())
            if (FindButton(c, text) is { } found)
                return found;
        return null;
    }

    /// <summary>Collect every Button whose text equals <paramref name="text"/> (row-per-recipe checks).</summary>
    private static void CollectButtons(Node root, string text, List<Button> into)
    {
        if (root is Button b && b.Text == text)
            into.Add(b);
        foreach (Node c in root.GetChildren())
            CollectButtons(c, text, into);
    }

    /// <summary>True when any Label under <paramref name="root"/> contains <paramref name="substr"/>.</summary>
    private static bool HasLabelContaining(Node root, string substr)
    {
        if (root is Label l && l.Text.Contains(substr))
            return true;
        foreach (Node c in root.GetChildren())
            if (HasLabelContaining(c, substr))
                return true;
        return false;
    }

    private async Task<T?> Spawn<T>(string path) where T : Node
    {
        var packed = GD.Load<PackedScene>(path);
        if (packed == null)
        {
            Check($"{path} loads", false);
            return null;
        }

        var node = packed.Instantiate<T>();
        AddChild(node);
        await Frames(2);
        Check($"{path} instantiates and enters the tree", true);
        return node;
    }

    private void CheckNode(Node root, string uniquePath)
        => Check($"{root.Name}: {uniquePath} resolves", root.GetNodeOrNull(uniquePath) != null);

    private static bool NonZeroSize(Control? c) => c != null && c.Size.X > 0f && c.Size.Y > 0f;

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
