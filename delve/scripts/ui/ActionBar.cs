using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Bottom action bar for the active ally: portrait, action pips, resource pips and the Strike,
/// Shield, Spells, Abilities, Delay, End Turn and Control buttons, with the signature row and the
/// <see cref="DecisionSlot"/> stacked above it. No name, HP or AC: the party column owns those.
/// Renders from <see cref="ActionBarState"/> and raises intent events only. Hotkeys gate on
/// <see cref="HudRoot.ModalActive"/> so the reaction prompt blocks them.
/// </summary>
public partial class ActionBar : Control
{
    [Export] public SpellIconCatalog? SpellIcons { get; set; }
    [Export] public PackedScene? ResourcePipScene { get; set; }

    public event Action? ConfirmTargetsPressed;
    public event Action? ConfirmOrderPressed;
    public event Action? StrikePressed;
    public event Action? RaiseShieldPressed;
    public event Action? DelayPressed;
    public event Action? EndTurnPressed;
    public event Action? OverviewPressed;
    public event Action? StagingChanged;
    public event Action<bool>? AiToggled;
    /// <summary>Raised when the per-ally auto-reactions toggle changes (true = auto-use, no prompt).</summary>
    public event Action<bool>? AutoReactToggled;
    /// <summary>Raised with (spellId, variantIndex) when a spell chip is pressed.</summary>
    public event Action<string, int>? SpellChipPressed;
    /// <summary>Raised with the skill action id when a skill chip is pressed.</summary>
    public event Action<string>? SkillChipPressed;

    private TextureRect _portrait = null!;
    private PipRow _actionPips = null!;
    private VBoxContainer _resources = null!;
    private CaptionButton _strikeBtn = null!;
    private CaptionButton _shieldBtn = null!;
    private CaptionButton _delayBtn = null!;
    private CaptionButton _endBtn = null!;
    private CaptionButton _spellsBtn = null!;
    private CaptionButton _skillsBtn = null!;
    private CheckBox _aiToggle = null!;
    private CheckBox _autoReactToggle = null!;
    private CheckBox _stageOrders = null!;
    private Button _controlButton = null!;
    private Control _controlOptions = null!;
    private Control _bar = null!;
    private ChipFlyout _flyout = null!;

    /// <summary>Every caption button on the bar. Their labels are plain children, so
    /// <see cref="RefreshCaptionColors"/> re-applies colours whenever Disabled changes.</summary>
    private CaptionButton[] _captions = Array.Empty<CaptionButton>();

    private HudRoot? _hud;
    private bool _suppressToggle;
    private bool _interactable = true;
    private string _lastActorName = "";
    private IReadOnlyList<SpellEntryView> _spells = Array.Empty<SpellEntryView>();
    private IReadOnlyList<SkillEntryView> _skills = Array.Empty<SkillEntryView>();

    private const string DelayTooltip = "Wait and act later this round. Pick whom to act after; the choice is final.";

    public DecisionSlot Decision { get; private set; } = null!;
    public Control BarPanel => _bar;
    public string ActorName => _lastActorName;
    public bool StageOrders => _stageOrders.ButtonPressed;

    public override void _Ready()
    {
        _portrait = GetNode<TextureRect>("%Portrait");
        _actionPips = GetNode<PipRow>("%ActionPips");
        _resources = GetNode<VBoxContainer>("%Resources");
        _strikeBtn = GetNode<CaptionButton>("%StrikeButton");
        _shieldBtn = GetNode<CaptionButton>("%ShieldButton");
        _spellsBtn = GetNode<CaptionButton>("%SpellsButton");
        _skillsBtn = GetNode<CaptionButton>("%SkillsButton");
        _delayBtn = GetNode<CaptionButton>("%DelayButton");
        _endBtn = GetNode<CaptionButton>("%EndButton");
        _aiToggle = GetNode<CheckBox>("%AiToggle");
        _autoReactToggle = GetNode<CheckBox>("%AutoReactToggle");
        _stageOrders = GetNode<CheckBox>("%StageOrders");
        _controlButton = GetNode<Button>("%ControlButton");
        _controlOptions = GetNode<Control>("%ControlOptions");
        _bar = GetNode<Control>("%Bar");
        _flyout = GetNode<ChipFlyout>("%Flyout");
        _signatures = GetNode<ChipFlyout>("%SignatureActions");
        Decision = GetNode<DecisionSlot>("%DecisionSlot");
        _hud = HudRoot.Find(this);

        _captions = new[] { _strikeBtn, _shieldBtn, _spellsBtn, _skillsBtn, _delayBtn, _endBtn };
        RefreshCaptionColors();

        _controlButton.Toggled += on => SetFlyout(on ? FlyoutCategory.Control : FlyoutCategory.None);
        _signatures.ChipPressed += OnSignaturePressed;
        _flyout.ChipPressed += OnChipPressed;
        Decision.ConfirmTargetsPressed += () => ConfirmTargetsPressed?.Invoke();
        Decision.ConfirmOrderPressed += () => ConfirmOrderPressed?.Invoke();
        GetNode<Button>("%Overview").Pressed += () => OverviewPressed?.Invoke();
        _stageOrders.Toggled += _ => StagingChanged?.Invoke();

        _strikeBtn.Pressed += () => StrikePressed?.Invoke();
        _shieldBtn.Pressed += () => RaiseShieldPressed?.Invoke();
        _delayBtn.Pressed += () => DelayPressed?.Invoke();
        _endBtn.Pressed += () => EndTurnPressed?.Invoke();
        _spellsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Spells : FlyoutCategory.None);
        _skillsBtn.Toggled += on => SetFlyout(on ? FlyoutCategory.Skills : FlyoutCategory.None);
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
        _autoReactToggle.Toggled += on => { if (!_suppressToggle) AutoReactToggled?.Invoke(on); };

        if (_hud != null)
            _hud.ModalChanged += modal => { if (modal) CloseFlyout(); };
    }

    /// <summary>
    /// Enable or disable the whole bar (disabled while another combatant acts). The state lives in
    /// the buttons' disabled styles, never in the bar's Modulate. Per-action state returns with the
    /// next <see cref="Render"/>.
    /// </summary>
    public void SetInteractable(bool interactable)
    {
        _interactable = interactable;
        if (!interactable)
        {
            _strikeBtn.Disabled = true;
            _shieldBtn.Disabled = true;
            _delayBtn.Disabled = true;
            CloseFlyout();
            string waiting = UnavailableTooltip("Waiting for this ally's turn");
            foreach (var btn in _captions)
                btn.TooltipText = waiting;
        }
        _spellsBtn.Disabled = !interactable;
        _skillsBtn.Disabled = !interactable;
        _endBtn.Disabled = !interactable;
        RefreshCaptionColors();
        Decision.SetInteractable(interactable);
        RebuildSignatures();
    }

    private static string UnavailableTooltip(string? reason)
        => string.IsNullOrEmpty(reason) ? "" : $"Unavailable: {reason}";

    private void RefreshCaptionColors()
    {
        foreach (var btn in _captions)
        {
            btn.ActionLabel?.AddThemeColorOverride("font_color", btn.Disabled ? UiColors.TextDisabled : UiColors.Text);
            btn.KeyLabel?.AddThemeColorOverride("font_color", btn.Disabled ? UiColors.TextDisabled : UiColors.TextDim);
        }
    }

    public void SetAiToggle(bool on)
    {
        _suppressToggle = true;
        _aiToggle.ButtonPressed = on;
        _suppressToggle = false;
    }

    /// <summary>The AI and reaction preferences apply only to a combatant the player may command.
    /// Plan orders and Overview stay available.</summary>
    public void SetControlOptionsEnabled(bool enabled)
    {
        _aiToggle.Disabled = !enabled;
        _autoReactToggle.Disabled = !enabled;
        _aiToggle.TooltipText = enabled ? "Let the AI choose this ally's actions." : UnavailableTooltip("This combatant is AI controlled");
        _autoReactToggle.TooltipText = enabled ? "Use available reactions automatically. Uncheck to decide each reaction." : UnavailableTooltip("This combatant is AI controlled");
    }

    public void SetAutoReactToggle(bool on)
    {
        _suppressToggle = true;
        _autoReactToggle.ButtonPressed = on;
        _suppressToggle = false;
    }

    public void SetStaged(bool staged) => Decision.SetStaged(staged);

    public void Render(ActionBarState state)
    {
        _portrait.Texture = state.ActorId.Length > 0 ? HeroPortraits.For(state.ActorId) : null;
        _portrait.TooltipText = state.ActorName;
        _actionPips.SetActionEconomy(state.ActionsRemaining, state.MaxActions);
        _actionPips.TooltipText = $"{state.ActionsRemaining} of {state.MaxActions} actions remaining";
        RenderResources(state);

        _strikeBtn.SetActionText(state.Map < 0 ? $"Strike {state.Map}" : "Strike");
        _strikeBtn.Disabled = !_interactable || !state.CanStrike;
        _shieldBtn.Disabled = !_interactable || !state.CanRaiseShield;
        _shieldBtn.Visible = state.HasShield;
        _delayBtn.Disabled = !_interactable || !state.CanDelay;
        _spellsBtn.Disabled = !_interactable;
        _skillsBtn.Disabled = !_interactable;
        _endBtn.Disabled = !_interactable;
        RefreshCaptionColors();

        _strikeBtn.TooltipText = UnavailableTooltip(state.StrikeDisabledReason);
        _shieldBtn.TooltipText = UnavailableTooltip(state.ShieldDisabledReason);
        _delayBtn.TooltipText = state.CanDelay ? DelayTooltip : UnavailableTooltip(state.DelayDisabledReason);
        _spellsBtn.TooltipText = "";
        _skillsBtn.TooltipText = "";
        _endBtn.TooltipText = state.ActionsRemaining > 0
            ? $"End this turn with {state.ActionsRemaining} unused actions." : "End this turn.";

        bool actorChanged = state.ActorName != _lastActorName;
        _lastActorName = state.ActorName;
        _spells = state.SpellEntries;
        _skills = state.SkillEntries;
        RebuildSignatures();

        // Martials get no Spells button at all: an always-disabled category fails kitchen-sink.
        _spellsBtn.Visible = _spells.Count > 0;
        _skillsBtn.Visible = _skills.Count > 0;

        if (_openCategory != FlyoutCategory.None)
        {
            bool empty = _openCategory == FlyoutCategory.Spells ? _spells.Count == 0
                : _openCategory == FlyoutCategory.Skills && _skills.Count == 0;
            if (actorChanged || empty) CloseFlyout();
            else if (_openCategory != FlyoutCategory.Control) RebuildFlyout();
        }
    }

    private void RenderResources(ActionBarState state)
    {
        while (_resources.GetChildCount() > state.ResourcePips.Count)
        {
            var extra = _resources.GetChild(_resources.GetChildCount() - 1);
            _resources.RemoveChild(extra);
            extra.QueueFree();
        }
        while (_resources.GetChildCount() < state.ResourcePips.Count && ResourcePipScene != null)
        {
            var row = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
            row.AddChild(new Label { ThemeTypeVariation = ThemeNames.HintLabel, MouseFilter = MouseFilterEnum.Ignore });
            row.AddChild(ResourcePipScene.Instantiate<PipRow>());
            _resources.AddChild(row);
        }
        for (int i = 0; i < _resources.GetChildCount(); i++)
        {
            var resource = state.ResourcePips[i];
            var row = _resources.GetChild(i);
            row.GetChild<Label>(0).Text = resource.Name;
            var pips = row.GetChild<PipRow>(1);
            pips.SizeFlagsVertical = SizeFlags.ShrinkCenter;
            pips.SetActionEconomy(resource.Current, resource.Max);
        }
        _resources.Visible = state.ResourcePips.Count > 0;
        _resources.TooltipText = state.Resources;
    }

    public void ShowAttackPreview(AttackPreviewView? preview) => Decision.ShowPreview(preview);

    public void SetTargetingHint(bool targeting, bool pickingDelaySlot = false)
        => Decision.SetTargeting(targeting, pickingDelaySlot);

    public void SetMoveHint(MoveHoverView? hover) => Decision.SetMoveHover(hover);

    public void SetSpellTargetSelection(int count, int limit) => Decision.SetSpellTargetSelection(count, limit);

    /// <summary>combat_action_1..2, combat_spells / combat_skills, combat_delay and
    /// combat_end_turn, gated off while a modal is up. Esc closes an open flyout and is consumed
    /// here; otherwise it reaches GridInput3D's targeting cancel.</summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (_hud?.ModalActive == true || !IsVisibleInTree())
            return;

        if (_openCategory != FlyoutCategory.None && @event.IsActionPressed(InputNames.UiCancel))
        {
            CloseFlyout();
            GetViewport().SetInputAsHandled();
            return;
        }

        if (!_interactable) return;

        if (@event.IsActionPressed(InputNames.Confirm) && Decision.CanConfirmTargets)
            Activate(Decision.ConfirmTargetsButton, () => ConfirmTargetsPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action1))
            Activate(_strikeBtn, () => StrikePressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action2))
            Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Spells))
            Activate(_spellsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Spells ? FlyoutCategory.None : FlyoutCategory.Spells));
        else if (@event.IsActionPressed(InputNames.Skills))
            Activate(_skillsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Skills ? FlyoutCategory.None : FlyoutCategory.Skills));
        else if (@event.IsActionPressed(InputNames.Delay))
            Activate(_delayBtn, () => DelayPressed?.Invoke());
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
