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

    private Label _actorLabel = null!;
    private Label _vitalsLabel = null!;
    private PipRow _actionPips = null!;
    private CaptionButton _moveBtn = null!;
    private CaptionButton _stepBtn = null!;
    private CaptionButton _strikeBtn = null!;
    private CaptionButton _shieldBtn = null!;
    private CaptionButton _endBtn = null!;
    private CheckButton _aiToggle = null!;
    private CheckButton _autoReactToggle = null!;
    private Label _targetingHintLabel = null!;

    /// <summary>Every caption button on the bar, in bar order. Their action and keycap labels are
    /// plain children (mouse_filter Ignore) so they do not track the button's font color states on
    /// their own — <see cref="RefreshCaptionColors"/> re-applies colors whenever Disabled changes.</summary>
    private CaptionButton[] _captions = System.Array.Empty<CaptionButton>();

    private CaptionButton _spellsBtn = null!;
    private CaptionButton _skillsBtn = null!;
    private ChipFlyout _flyout = null!;
    private PanelContainer _previewCard = null!;
    private Label _previewHeaderLabel = null!;
    private Label _previewStatsLabel = null!;
    private Label _offGuardTag = null!;

    private HudRoot? _hud;

    private bool _suppressToggle;
    private bool _interactable = true;

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
        _moveBtn = GetNode<CaptionButton>("%MoveButton");
        _stepBtn = GetNode<CaptionButton>("%StepButton");
        _strikeBtn = GetNode<CaptionButton>("%StrikeButton");
        _shieldBtn = GetNode<CaptionButton>("%ShieldButton");
        _spellsBtn = GetNode<CaptionButton>("%SpellsButton");
        _skillsBtn = GetNode<CaptionButton>("%SkillsButton");
        _endBtn = GetNode<CaptionButton>("%EndButton");
        _aiToggle = GetNode<CheckButton>("%AiToggle");
        _autoReactToggle = GetNode<CheckButton>("%AutoReactToggle");
        _targetingHintLabel = GetNode<Label>("%TargetingHint");
        _flyout = GetNode<ChipFlyout>("%Flyout");
        _previewCard = GetNode<PanelContainer>("%PreviewCard");
        _previewHeaderLabel = GetNode<Label>("%PreviewHeaderLabel");
        _previewStatsLabel = GetNode<Label>("%PreviewStatsLabel");
        _offGuardTag = GetNode<Label>("%OffGuardTag");

        _hud = HudRoot.Find(this);
        _offGuardTag.AddThemeColorOverride("font_color", UiColors.Accent);

        _captions = new[]
        {
            _moveBtn, _stepBtn, _strikeBtn, _shieldBtn, _spellsBtn, _skillsBtn, _endBtn,
        };
        RefreshCaptionColors();

        _moveBtn.Pressed += () => MovePressed?.Invoke();
        _stepBtn.Pressed += () => StepPressed?.Invoke();
        _strikeBtn.Pressed += () => StrikePressed?.Invoke();
        _shieldBtn.Pressed += () => RaiseShieldPressed?.Invoke();
        _endBtn.Pressed += () => EndTurnPressed?.Invoke();
        _spellsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Spells : FlyoutCategory.None);
        _skillsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Skills : FlyoutCategory.None);
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
        _autoReactToggle.Toggled += on => { if (!_suppressToggle) AutoReactToggled?.Invoke(on); };
        _flyout.ChipPressed += OnChipPressed;

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
            foreach (var btn in _captions)
                btn.TooltipText = waiting;
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

    /// <summary>Re-apply caption label colors from each button's Disabled state so a disabled
    /// button visibly dims both the action label and its keycap. Enabled: action text (inverse
    /// on the accent End Turn), keycap text_dim. Disabled: both text_disabled.</summary>
    private void RefreshCaptionColors()
    {
        foreach (var btn in _captions)
        {
            bool accent = btn == _endBtn;
            btn.ActionLabel?.AddThemeColorOverride("font_color", btn.Disabled
                ? UiColors.TextDisabled
                : accent ? UiColors.TextInverse : UiColors.Text);
            btn.KeyLabel?.AddThemeColorOverride("font_color",
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

        // MAP suffix goes on the action label only — the keycap always reads just "3". The button
        // re-fits itself when the label grows (see CaptionButton).
        if (_strikeBtn.ActionLabel != null)
            _strikeBtn.ActionLabel.Text = state.Map < 0 ? $"Strike ({state.Map})" : "Strike";

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
            _flyout.Clear();
            return;
        }
        RebuildFlyout();
        _flyout.Visible = true;
    }

    private void CloseFlyout() => SetFlyout(FlyoutCategory.None);

    /// <summary>Rebuild the open category's flyout contents from the last rendered state. Spells
    /// split into a Cantrips section (at-will) and a slotted Spells section; skills are one flow —
    /// the Skills button already names the category. This is the only place spell and skill views
    /// become chips; the flyout itself carries no combat vocabulary.</summary>
    private void RebuildFlyout()
    {
        _flyout.Clear();

        if (_openCategory == FlyoutCategory.Spells)
        {
            var cantrips = new List<SpellEntryView>();
            var slotted = new List<SpellEntryView>();
            foreach (var spell in _spells)
                (spell.IsCantrip ? cantrips : slotted).Add(spell);

            AddSpellSection("Cantrips", cantrips);
            AddSpellSection("Spells", slotted);
        }
        else if (_openCategory == FlyoutCategory.Skills)
        {
            var flow = _flyout.AddFlow();
            foreach (var skill in _skills)
                _flyout.AddChip(flow, new ChipSpec
                {
                    Id = skill.ActionId,
                    Name = skill.Name,
                    ActionCost = skill.ActionCost,
                    CostText = SpellOutCost(skill.ActionCost, skill.CostText),
                    Enabled = _interactable && skill.Castable,
                    Description = skill.Description,
                    UnavailableReason = skill.UnavailableReason,
                });
        }
    }

    /// <summary>One flyout section: a header over a chip flow of these spells. Omitted entirely
    /// when the section has no spells.</summary>
    private void AddSpellSection(string header, List<SpellEntryView> spells)
    {
        if (spells.Count == 0) return;

        _flyout.AddSection(header);
        var flow = _flyout.AddFlow();
        foreach (var spell in spells)
            _flyout.AddChip(flow, new ChipSpec
            {
                Id = spell.SpellId,
                Variant = spell.VariantIndex,
                Name = spell.Name,
                ActionCost = spell.ActionCost,
                CostText = SpellOutCost(spell.ActionCost, spell.CostText),
                // No "[cantrip]" badge — the Cantrips section header already says it (kitchen-sink).
                BadgeText = spell.IsCantrip ? null : $"[{spell.SlotsText}]",
                Enabled = _interactable && spell.Castable,
                Detail = spell.IsCantrip ? "cantrip"
                    : string.IsNullOrEmpty(spell.SlotsText) ? "" : $"{spell.SlotsText.TrimStart('x')} remaining",
                Description = spell.Description,
                UnavailableReason = spell.UnavailableReason,
            });
    }

    /// <summary>A pressed chip fires the category's intent and folds the flyout away — targeting
    /// starts next. The spec's payload is the spell or skill id the chip was built from.</summary>
    private void OnChipPressed(ChipSpec spec)
    {
        if (_openCategory == FlyoutCategory.Spells)
            SpellChipPressed?.Invoke(spec.Id, spec.Variant);
        else if (_openCategory == FlyoutCategory.Skills)
            SkillChipPressed?.Invoke(spec.Id);
        CloseFlyout();
    }

    /// <summary>1 -> "1 action", 2 -> "2 actions". Falls back to the raw cost text when the rules
    /// layer reported no action count (reactions, free actions).</summary>
    private static string SpellOutCost(int actionCost, string costText)
        => actionCost switch
        {
            1 => "1 action",
            > 1 => $"{actionCost} actions",
            _ => costText,
        };

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
        => _targetingHintLabel.Text = targeting ? TargetingHint : "";

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

        if (_openCategory != FlyoutCategory.None && @event.IsActionPressed(InputNames.UiCancel))
        {
            CloseFlyout();
            GetViewport().SetInputAsHandled();
            return;
        }

        if (@event.IsActionPressed(InputNames.Action1))
            Activate(_moveBtn, () => MovePressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action2))
            Activate(_stepBtn, () => StepPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action3))
            Activate(_strikeBtn, () => StrikePressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action4))
            Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Spells))
            Activate(_spellsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Spells ? FlyoutCategory.None : FlyoutCategory.Spells));
        else if (@event.IsActionPressed(InputNames.Skills))
            Activate(_skillsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Skills ? FlyoutCategory.None : FlyoutCategory.Skills));
        else if (@event.IsActionPressed(InputNames.EndTurn))
            Activate(_endBtn, () => EndTurnPressed?.Invoke());
    }

    private void Activate(Button button, Action fire)
    {
        if (button.Disabled || !button.Visible) return;
        fire();
        GetViewport().SetInputAsHandled();
    }
}
