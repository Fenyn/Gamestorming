using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Passive action bar for the active ally: identity + vitals readout, 3 action pips, the
/// Move/Step/Strike/Raise-Shield/End-Turn buttons (combat_action_1..4 / combat_end_turn hotkeys),
/// the Spells/Skills flyout toggles (combat_spells / combat_skills), the AI and auto-react
/// toggles, and a structured attack-preview card. Spell and skill chips live in a categorized
/// flyout panel above the bar — opened per category, never all at once. Renders from
/// <see cref="ActionBarState"/> and raises intent events only — it holds no rules and no engine
/// types. Hotkeys gate on <see cref="HudRoot.ModalActive"/> so a modal (the reaction prompt)
/// blocks them; the modal's backdrop already swallows the mouse.
/// </summary>
public partial class ActionBar : Control
{
    public event Action? MovePressed;
    public event Action? StepPressed;
    public event Action? StrikePressed;
    public event Action? RaiseShieldPressed;
    public event Action? EndTurnPressed;
    public event Action<bool>? AiToggled;
    /// <summary>Raised when the per-ally auto-reactions toggle changes (true = auto-use, no prompt).</summary>
    public event Action<bool>? AutoReactToggled;
    /// <summary>Raised with (spellId, variantIndex) when a spell chip is pressed.</summary>
    public event Action<string, int>? SpellChipPressed;
    /// <summary>Raised with the skill action id when a skill chip is pressed.</summary>
    public event Action<string>? SkillChipPressed;

    private static readonly PackedScene ChipScene =
        GD.Load<PackedScene>("res://scenes/ui/action_chip.tscn");

    private Label _actorLabel = null!;
    private Label _vitalsLabel = null!;
    private PipRow _actionPips = null!;
    private Button _moveBtn = null!;
    private Button _stepBtn = null!;
    private Button _strikeBtn = null!;
    private Button _shieldBtn = null!;
    private Button _endBtn = null!;
    private CheckButton _aiToggle = null!;
    private CheckButton _autoReactToggle = null!;
    private Label _targetingHintLabel = null!;
    private Label _strikeActionLabel = null!;

    /// <summary>One action button's caption parts: the action Label and the keycap key Label.
    /// The labels are plain children (mouse_filter Ignore) so they don't track the button's
    /// font color states on their own — <see cref="RefreshCaptionColors"/> re-applies colors
    /// whenever Disabled is toggled. Accent marks the End Turn button (dark-on-gold text).</summary>
    private readonly record struct Caption(Button Btn, Label Action, Label Key, bool Accent);

    private Caption[] _captions = System.Array.Empty<Caption>();
    private Button _spellsBtn = null!;
    private Button _skillsBtn = null!;
    private PanelContainer _flyout = null!;
    private VBoxContainer _flyoutCol = null!;
    private PanelContainer _previewCard = null!;
    private Label _previewHeaderLabel = null!;
    private Label _previewStatsLabel = null!;
    private Label _offGuardTag = null!;

    private HudRoot? _hud;

    private bool _suppressToggle;
    private bool _interactable = true;
    private bool _targeting;

    /// <summary>Which chip category the flyout currently shows (None = closed).</summary>
    private enum FlyoutCategory { None, Spells, Skills }

    private FlyoutCategory _openCategory = FlyoutCategory.None;
    private string _lastActorName = "";
    private IReadOnlyList<SpellEntryView> _spells = System.Array.Empty<SpellEntryView>();
    private IReadOnlyList<SkillEntryView> _skills = System.Array.Empty<SkillEntryView>();

    private const string TargetingHint = "LMB  confirm · Esc  cancel";

    public override void _Ready()
    {
        _actorLabel = GetNode<Label>("%ActorLabel");
        _vitalsLabel = GetNode<Label>("%VitalsLabel");
        _actionPips = GetNode<PipRow>("%ActionPips");
        _moveBtn = GetNode<Button>("%MoveButton");
        _stepBtn = GetNode<Button>("%StepButton");
        _strikeBtn = GetNode<Button>("%StrikeButton");
        _shieldBtn = GetNode<Button>("%ShieldButton");
        _spellsBtn = GetNode<Button>("%SpellsButton");
        _skillsBtn = GetNode<Button>("%SkillsButton");
        _endBtn = GetNode<Button>("%EndButton");
        _aiToggle = GetNode<CheckButton>("%AiToggle");
        _autoReactToggle = GetNode<CheckButton>("%AutoReactToggle");
        _targetingHintLabel = GetNode<Label>("%TargetingHint");
        _flyout = GetNode<PanelContainer>("%Flyout");
        _flyoutCol = GetNode<VBoxContainer>("%FlyoutCol");
        _previewCard = GetNode<PanelContainer>("%PreviewCard");
        _previewHeaderLabel = GetNode<Label>("%PreviewHeaderLabel");
        _previewStatsLabel = GetNode<Label>("%PreviewStatsLabel");
        _offGuardTag = GetNode<Label>("%OffGuardTag");

        _hud = GetParentOrNull<HudRoot>();
        _offGuardTag.AddThemeColorOverride("font_color", UiColors.Accent);

        _captions = new[]
        {
            MakeCaption(_moveBtn), MakeCaption(_stepBtn), MakeCaption(_strikeBtn),
            MakeCaption(_shieldBtn), MakeCaption(_spellsBtn), MakeCaption(_skillsBtn),
            MakeCaption(_endBtn, accent: true),
        };
        _strikeActionLabel = _strikeBtn.GetNode<Label>("Content/ActionLabel");
        RefreshCaptionColors();
        foreach (var caption in _captions)
            FitCaption(caption.Btn);

        _moveBtn.Pressed += () => MovePressed?.Invoke();
        _stepBtn.Pressed += () => StepPressed?.Invoke();
        _strikeBtn.Pressed += () => StrikePressed?.Invoke();
        _shieldBtn.Pressed += () => RaiseShieldPressed?.Invoke();
        _endBtn.Pressed += () => EndTurnPressed?.Invoke();
        _spellsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Spells : FlyoutCategory.None);
        _skillsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Skills : FlyoutCategory.None);
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
        _autoReactToggle.Toggled += on => { if (!_suppressToggle) AutoReactToggled?.Invoke(on); };

        // A modal opening (reaction prompt) closes the flyout — the modal owns the screen.
        if (_hud != null)
            _hud.ModalChanged += modal => { if (modal) CloseFlyout(); };
    }

    /// <summary>
    /// Enable/disable the whole bar (disabled while an AI or enemy turn is running). The state is
    /// carried by the buttons' disabled styles — never by dimming the bar's Modulate, which made
    /// every label unreadable. Buttons disable immediately; re-enabling per-action state waits for
    /// the next <see cref="Render"/> (the turn-start state push), except End Turn which only
    /// depends on interactability.
    /// </summary>
    public void SetInteractable(bool interactable)
    {
        _interactable = interactable;
        if (!interactable)
        {
            _moveBtn.Disabled = true;
            _stepBtn.Disabled = true;
            _strikeBtn.Disabled = true;
            _shieldBtn.Disabled = true;
            CloseFlyout();
            // Whole-bar disable (another combatant is acting): every button explains itself the
            // same way. The per-action reasons stamped by Render would be stale here; the next
            // Render (this ally's turn-start state push) restores them.
            string waiting = UnavailableTooltip("Waiting for this ally's turn");
            foreach (var caption in _captions)
                caption.Btn.TooltipText = waiting;
        }
        _spellsBtn.Disabled = !interactable;
        _skillsBtn.Disabled = !interactable;
        _endBtn.Disabled = !interactable;
        RefreshCaptionColors();
    }

    /// <summary>"Unavailable: reason" tooltip for a disabled control; empty (no tooltip) for null —
    /// the shared format every disabled control uses to explain itself on hover.</summary>
    private static string UnavailableTooltip(string? reason)
        => string.IsNullOrEmpty(reason) ? "" : $"Unavailable: {reason}";

    private static Caption MakeCaption(Button btn, bool accent = false)
        => new(btn, btn.GetNode<Label>("Content/ActionLabel"),
            btn.GetNode<Label>("Content/Keycap/KeyLabel"), accent);

    /// <summary>Size a button (caption button or action chip) to its Content row plus its normal
    /// stylebox margins — the internal nodes are non-container children, so the button can't
    /// derive this itself. <paramref name="minHeight"/> keeps chips at their authored height.</summary>
    private static void FitCaption(Button btn, float minHeight = 0f)
    {
        Vector2 size = btn.GetNode<Control>("Content").GetCombinedMinimumSize()
            + btn.GetThemeStylebox("normal").GetMinimumSize();
        btn.CustomMinimumSize = new Vector2(size.X, Mathf.Max(size.Y, minHeight));
    }

    /// <summary>Re-apply caption label colors from each button's Disabled state so a disabled
    /// button visibly dims both the action label and its keycap. Enabled: action text (inverse
    /// on the accent End Turn), keycap text_dim. Disabled: both text_disabled.</summary>
    private void RefreshCaptionColors()
    {
        foreach (var (btn, action, key, accent) in _captions)
        {
            action.AddThemeColorOverride("font_color", btn.Disabled
                ? UiColors.TextDisabled
                : accent ? UiColors.TextInverse : UiColors.Text);
            key.AddThemeColorOverride("font_color",
                btn.Disabled ? UiColors.TextDisabled : UiColors.TextDim);
        }
    }

    public void SetAiToggle(bool on)
    {
        _suppressToggle = true;
        _aiToggle.ButtonPressed = on;
        _suppressToggle = false;
    }

    public void SetAutoReactToggle(bool on)
    {
        _suppressToggle = true;
        _autoReactToggle.ButtonPressed = on;
        _suppressToggle = false;
    }

    public void Render(ActionBarState state)
    {
        _actorLabel.Text = state.ActorName;

        _vitalsLabel.Visible = state.MaxHp > 0;
        if (state.MaxHp > 0)
        {
            _vitalsLabel.Text = $"HP {state.Hp}/{state.MaxHp}  AC {state.Ac}";
            _vitalsLabel.AddThemeColorOverride("font_color",
                UiColors.HpFillColor((float)state.Hp / state.MaxHp));
        }

        _actionPips.SetActionEconomy(state.ActionsRemaining, state.MaxActions);

        // MAP suffix goes on the action label only — the keycap always reads just "3".
        _strikeActionLabel.Text = state.Map < 0 ? $"Strike ({state.Map})" : "Strike";
        FitCaption(_strikeBtn);

        _moveBtn.Disabled = !_interactable || !state.CanMove;
        _stepBtn.Disabled = !_interactable || !state.CanStep;
        _strikeBtn.Disabled = !_interactable || !state.CanStrike;
        _shieldBtn.Disabled = !_interactable || !state.CanRaiseShield;
        _spellsBtn.Disabled = !_interactable;
        _skillsBtn.Disabled = !_interactable;
        _endBtn.Disabled = !_interactable;
        RefreshCaptionColors();

        // Disabled-reason tooltips: empty (no tooltip) when the button is enabled. Godot shows
        // tooltips on disabled buttons (Disabled only blocks presses; the internal Content nodes
        // are mouse_filter Ignore, so the button itself still owns the hover).
        _moveBtn.TooltipText = UnavailableTooltip(state.MoveDisabledReason);
        _stepBtn.TooltipText = UnavailableTooltip(state.StepDisabledReason);
        _strikeBtn.TooltipText = UnavailableTooltip(state.StrikeDisabledReason);
        _shieldBtn.TooltipText = UnavailableTooltip(state.ShieldDisabledReason);
        _spellsBtn.TooltipText = "";
        _skillsBtn.TooltipText = "";
        _endBtn.TooltipText = "";

        bool actorChanged = state.ActorName != _lastActorName;
        _lastActorName = state.ActorName;
        _spells = state.SpellEntries;
        _skills = state.SkillEntries;

        // Martials get no Spells button at all — an always-disabled category fails kitchen-sink.
        _spellsBtn.Visible = _spells.Count > 0;
        _skillsBtn.Visible = _skills.Count > 0;

        // Keep an open flyout fresh; close it when the actor changed or its category emptied.
        if (_openCategory != FlyoutCategory.None)
        {
            bool empty = _openCategory == FlyoutCategory.Spells ? _spells.Count == 0 : _skills.Count == 0;
            if (actorChanged || empty) CloseFlyout();
            else RebuildFlyout();
        }
    }

    /// <summary>Open the flyout on one category (None = close). Opening a category closes the
    /// other; the toggle buttons' pressed states mirror it without re-firing Toggled.</summary>
    private void SetFlyout(FlyoutCategory category)
    {
        _openCategory = category;
        _spellsBtn.SetPressedNoSignal(category == FlyoutCategory.Spells);
        _skillsBtn.SetPressedNoSignal(category == FlyoutCategory.Skills);
        if (category == FlyoutCategory.None)
        {
            _flyout.Visible = false;
            foreach (var child in _flyoutCol.GetChildren())
                child.QueueFree();
            return;
        }
        RebuildFlyout();
        _flyout.Visible = true;
    }

    private void CloseFlyout() => SetFlyout(FlyoutCategory.None);

    /// <summary>Rebuild the open category's flyout contents from the last rendered state
    /// (QueueFree-and-rebuild, chips via PackedScene.Instantiate). Spells split into a Cantrips
    /// section (at-will, SlotsText "cantrip") and a slotted Spells section; skills are one flow —
    /// the Skills button already names the category.</summary>
    private void RebuildFlyout()
    {
        foreach (var child in _flyoutCol.GetChildren())
            child.QueueFree();

        if (_openCategory == FlyoutCategory.Spells)
        {
            var cantrips = new List<SpellEntryView>();
            var slotted = new List<SpellEntryView>();
            foreach (var spell in _spells)
                (spell.SlotsText == "cantrip" ? cantrips : slotted).Add(spell);

            AddSpellSection("Cantrips", cantrips);
            AddSpellSection("Spells", slotted);
        }
        else if (_openCategory == FlyoutCategory.Skills)
        {
            var flow = AddChipFlow();
            foreach (var skill in _skills)
            {
                string aid = skill.ActionId;
                AddChip(flow, skill.Name, skill.CostText, slotText: null,
                    enabled: _interactable && skill.Castable,
                    tooltip: BuildChipTooltip(skill.Name, skill.CostText, null, skill.Description,
                        skill.UnavailableReason),
                    () => SkillChipPressed?.Invoke(aid));
            }
        }
    }

    /// <summary>One flyout section: a HintLabel header over a centered chip flow. Omitted
    /// entirely when the section has no spells.</summary>
    private void AddSpellSection(string header, List<SpellEntryView> spells)
    {
        if (spells.Count == 0) return;

        var label = new Label
        {
            Text = header,
            ThemeTypeVariation = ThemeNames.HintLabel,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _flyoutCol.AddChild(label);

        var flow = AddChipFlow();
        foreach (var spell in spells)
        {
            string sid = spell.SpellId;
            int vi = spell.VariantIndex;
            // No "[cantrip]" tag — the Cantrips section header already says it (kitchen-sink).
            AddChip(flow, spell.Name, spell.CostText,
                slotText: spell.SlotsText == "cantrip" ? null : $"[{spell.SlotsText}]",
                enabled: _interactable && spell.Castable,
                tooltip: BuildChipTooltip(spell.Name, spell.CostText, spell.SlotsText,
                    spell.Description, spell.UnavailableReason),
                () => SpellChipPressed?.Invoke(sid, vi));
        }
    }

    private HFlowContainer AddChipFlow()
    {
        var flow = new HFlowContainer { Alignment = FlowContainer.AlignmentMode.Center };
        flow.AddThemeConstantOverride("h_separation", 5);
        flow.AddThemeConstantOverride("v_separation", 5);
        _flyoutCol.AddChild(flow);
        return flow;
    }

    private void AddChip(Container parent, string name, string costText, string? slotText,
        bool enabled, string tooltip, Action onPressed)
    {
        var chip = ChipScene.Instantiate<Button>();
        chip.Disabled = !enabled;
        chip.TooltipText = tooltip;

        // Internal labels don't track the button's disabled font color (same as the bar captions)
        // — chips are rebuilt on every state change, so a one-shot override at build time is enough.
        var nameLabel = chip.GetNode<Label>("%NameLabel");
        nameLabel.Text = name;
        nameLabel.AddThemeColorOverride("font_color", enabled ? UiColors.Text : UiColors.TextDisabled);

        // Cost pips: one square per action. An unparseable cost falls back to the raw text, dim.
        var pipRow = chip.GetNode<PipRow>("%PipRow");
        if (TryParseActionCost(costText, out int pipCount))
        {
            pipRow.SetCost(pipCount, enabled);
        }
        else if (!string.IsNullOrEmpty(costText))
        {
            var costLabel = new Label
            {
                Text = costText,
                ThemeTypeVariation = ThemeNames.HintLabel,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            if (!enabled)
                costLabel.AddThemeColorOverride("font_color", UiColors.TextDisabled);
            pipRow.AddChild(costLabel);
        }

        var slotLabel = chip.GetNode<Label>("%SlotLabel");
        slotLabel.Visible = !string.IsNullOrEmpty(slotText);
        slotLabel.Text = slotText ?? "";
        if (!enabled)
            slotLabel.AddThemeColorOverride("font_color", UiColors.TextDisabled);

        // Picking a chip both fires the intent and folds the flyout away — targeting starts next.
        chip.Pressed += () => { onPressed(); CloseFlyout(); };
        parent.AddChild(chip);
        FitCaption(chip, minHeight: 30f);
    }

    /// <summary>"2a" -> 2. False for anything that isn't digits followed by 'a' — the chip then
    /// shows the raw cost text instead of pips (never crash on odd cost strings).</summary>
    private static bool TryParseActionCost(string costText, out int actions)
    {
        actions = 0;
        return costText.Length >= 2 && costText[^1] == 'a'
            && int.TryParse(costText[..^1], out actions) && actions > 0;
    }

    /// <summary>Full name, spelled-out action cost, remaining spell slots (if any), and a
    /// one-line description when the underlying spell/action data carries one. A disabled chip's
    /// <paramref name="unavailableReason"/> (empty otherwise) appends as a final
    /// "Unavailable: reason" line so the grey-out always explains itself.</summary>
    private static string BuildChipTooltip(string name, string costText, string? slotsText,
        string description, string unavailableReason)
    {
        var parts = new List<string> { name, SpellOutCost(costText) };
        if (!string.IsNullOrEmpty(slotsText))
            parts.Add(slotsText == "cantrip" ? "cantrip" : $"{slotsText.TrimStart('x')} remaining");

        string tooltip = string.Join(" · ", parts);
        if (!string.IsNullOrEmpty(description))
            tooltip += $"\n{description}";
        if (!string.IsNullOrEmpty(unavailableReason))
            tooltip += $"\nUnavailable: {unavailableReason}";
        return tooltip;
    }

    /// <summary>"2a" -> "2 actions" (CostText is always digits followed by 'a').</summary>
    private static string SpellOutCost(string costText)
    {
        if (costText.EndsWith("a") && int.TryParse(costText[..^1], out int n))
            return n == 1 ? "1 action" : $"{n} actions";
        return costText;
    }

    public void ShowAttackPreview(AttackPreviewView? preview)
    {
        _previewCard.Visible = preview != null;
        if (preview == null) return;

        // The AC / hit / crit strings arrive already masked for bestiary knowledge — this Control
        // never decides what the player may see.
        _previewHeaderLabel.Text =
            $"{preview.WeaponName} vs {preview.TargetName} — +{preview.TotalAttackBonus} vs AC {preview.TargetAcText}";
        _previewStatsLabel.Text =
            $"{preview.HitChanceText} hit · {preview.CritChanceText} crit · {preview.DamageFormula}";
        _offGuardTag.Visible = preview.TargetOffGuard;
    }

    /// <summary>
    /// While a targeting mode is active (the host feeds the controller's ModeChanged), the hint
    /// label shows "LMB confirm · Esc cancel" — independent of the attack-preview card, which has
    /// its own slot above the bar.
    /// </summary>
    public void SetTargetingHint(bool targeting)
    {
        _targeting = targeting;
        RefreshTargetingHint();
    }

    private void RefreshTargetingHint() => _targetingHintLabel.Text = _targeting ? TargetingHint : "";

    /// <summary>combat_action_1..4 = Move/Step/Strike/Raise Shield, combat_spells / combat_skills
    /// = Q/E flyout toggles, combat_end_turn = End Turn. Respects Disabled (a button already
    /// reflects CanX + interactable via Render/SetInteractable) and is fully gated off while a
    /// modal is up (the reaction prompt takes its keys in _Input, a phase ahead of this). Esc
    /// closes an open flyout and is consumed here — the HUD CanvasLayer handles input before
    /// GridInput3D, so targeting-cancel still gets Esc whenever no flyout is open. WASD/wheel/MMB
    /// are camera input and never reach here.</summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (!_interactable || _hud?.ModalActive == true)
            return;

        if (_openCategory != FlyoutCategory.None && @event.IsActionPressed("ui_cancel"))
        {
            CloseFlyout();
            GetViewport().SetInputAsHandled();
            return;
        }

        if (@event.IsActionPressed("combat_action_1"))
            Activate(_moveBtn, () => MovePressed?.Invoke());
        else if (@event.IsActionPressed("combat_action_2"))
            Activate(_stepBtn, () => StepPressed?.Invoke());
        else if (@event.IsActionPressed("combat_action_3"))
            Activate(_strikeBtn, () => StrikePressed?.Invoke());
        else if (@event.IsActionPressed("combat_action_4"))
            Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
        else if (@event.IsActionPressed("combat_spells"))
            Activate(_spellsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Spells ? FlyoutCategory.None : FlyoutCategory.Spells));
        else if (@event.IsActionPressed("combat_skills"))
            Activate(_skillsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Skills ? FlyoutCategory.None : FlyoutCategory.Skills));
        else if (@event.IsActionPressed("combat_end_turn"))
            Activate(_endBtn, () => EndTurnPressed?.Invoke());
    }

    private void Activate(Button button, Action fire)
    {
        if (button.Disabled || !button.Visible) return;
        fire();
        GetViewport().SetInputAsHandled();
    }
}
