using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Passive action bar for the active ally: vitals readout, 3 action pips, the
/// Move/Step/Strike/Raise-Shield/End-Turn buttons (with number/space hotkeys), an AI toggle, and
/// a structured attack-preview card. Renders from <see cref="ActionBarState"/> and raises intent
/// events only — it holds no rules and no engine types.
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
    private readonly ColorRect[] _pips = new ColorRect[3];
    private Button _moveBtn = null!;
    private Button _stepBtn = null!;
    private Button _strikeBtn = null!;
    private Button _shieldBtn = null!;
    private Button _endBtn = null!;
    private CheckButton _aiToggle = null!;
    private CheckButton _autoReactToggle = null!;
    private Label _previewLabel = null!;
    private HFlowContainer _chipRow = null!;
    private PanelContainer _previewCard = null!;
    private Label _previewHeaderLabel = null!;
    private Label _previewStatsLabel = null!;
    private Label _offGuardTag = null!;

    private bool _suppressToggle;
    private bool _interactable = true;
    private bool _modalBlocking;
    private bool _targeting;

    private const string TargetingHint = "LMB  confirm · Esc  cancel";

    public override void _Ready()
    {
        _actorLabel = GetNode<Label>("%ActorLabel");
        _vitalsLabel = GetNode<Label>("%VitalsLabel");
        _pips[0] = GetNode<ColorRect>("%Pip0");
        _pips[1] = GetNode<ColorRect>("%Pip1");
        _pips[2] = GetNode<ColorRect>("%Pip2");
        _moveBtn = GetNode<Button>("%MoveButton");
        _stepBtn = GetNode<Button>("%StepButton");
        _strikeBtn = GetNode<Button>("%StrikeButton");
        _shieldBtn = GetNode<Button>("%ShieldButton");
        _endBtn = GetNode<Button>("%EndButton");
        _aiToggle = GetNode<CheckButton>("%AiToggle");
        _autoReactToggle = GetNode<CheckButton>("%AutoReactToggle");
        _previewLabel = GetNode<Label>("%PreviewLabel");
        _chipRow = GetNode<HFlowContainer>("%ChipRow");
        _previewCard = GetNode<PanelContainer>("%PreviewCard");
        _previewHeaderLabel = GetNode<Label>("%PreviewHeaderLabel");
        _previewStatsLabel = GetNode<Label>("%PreviewStatsLabel");
        _offGuardTag = GetNode<Label>("%OffGuardTag");

        _moveBtn.Pressed += () => MovePressed?.Invoke();
        _stepBtn.Pressed += () => StepPressed?.Invoke();
        _strikeBtn.Pressed += () => StrikePressed?.Invoke();
        _shieldBtn.Pressed += () => RaiseShieldPressed?.Invoke();
        _endBtn.Pressed += () => EndTurnPressed?.Invoke();
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
        _autoReactToggle.Toggled += on => { if (!_suppressToggle) AutoReactToggled?.Invoke(on); };
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
        }
        _endBtn.Disabled = !interactable;
    }

    /// <summary>Blocks the 1/2/3/4/Space hotkeys while a modal (the reaction prompt) is up. Its
    /// full-rect backdrop already swallows mouse clicks, but _UnhandledKeyInput fires regardless
    /// of mouse filters, so hotkeys need this explicit gate. Wired by CombatScene from
    /// ReactionPromptPanel.VisibilityChanged.</summary>
    public void SetModalBlocking(bool blocking) => _modalBlocking = blocking;

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
                UiPalette.HpFillColor((float)state.Hp / state.MaxHp));
        }

        for (int i = 0; i < _pips.Length; i++)
        {
            bool filled = i < state.ActionsRemaining && i < state.MaxActions;
            // Warm theme colors: gold = available action, dark wood = spent.
            _pips[i].Color = filled ? UiPalette.Gold : UiPalette.DarkWood;
            _pips[i].Visible = i < state.MaxActions;
        }

        _strikeBtn.Text = state.Map < 0 ? $"Strike [3] ({state.Map})" : "Strike [3]";

        _moveBtn.Disabled = !_interactable || !state.CanMove;
        _stepBtn.Disabled = !_interactable || !state.CanStep;
        _strikeBtn.Disabled = !_interactable || !state.CanStrike;
        _shieldBtn.Disabled = !_interactable || !state.CanRaiseShield;
        _endBtn.Disabled = !_interactable;

        // Disabled-reason tooltips: empty (no tooltip) when the button is enabled.
        _moveBtn.TooltipText = state.MoveDisabledReason ?? "";
        _stepBtn.TooltipText = state.StepDisabledReason ?? "";
        _strikeBtn.TooltipText = state.StrikeDisabledReason ?? "";
        _shieldBtn.TooltipText = state.ShieldDisabledReason ?? "";

        RebuildChips(state.SpellEntries, state.SkillEntries);
    }

    /// <summary>Rebuild the dynamic spell/skill chip row from state (children via PackedScene.Instantiate).</summary>
    private void RebuildChips(IReadOnlyList<SpellEntryView> spells, IReadOnlyList<SkillEntryView> skills)
    {
        foreach (var child in _chipRow.GetChildren())
            child.QueueFree();

        foreach (var spell in spells)
        {
            string sid = spell.SpellId;
            int vi = spell.VariantIndex;
            AddChip($"{spell.Name}  {spell.CostText} [{spell.SlotsText}]",
                enabled: _interactable && spell.Castable,
                tooltip: BuildChipTooltip(spell.Name, spell.CostText, spell.SlotsText, spell.Description),
                () => SpellChipPressed?.Invoke(sid, vi));
        }

        foreach (var skill in skills)
        {
            string aid = skill.ActionId;
            AddChip($"{skill.Name}  {skill.CostText}",
                enabled: _interactable && skill.Castable,
                tooltip: BuildChipTooltip(skill.Name, skill.CostText, null, skill.Description),
                () => SkillChipPressed?.Invoke(aid));
        }
    }

    private void AddChip(string text, bool enabled, string tooltip, Action onPressed)
    {
        var chip = ChipScene.Instantiate<Button>();
        chip.Text = text;
        chip.Disabled = !enabled;
        chip.TooltipText = tooltip;
        chip.Pressed += onPressed;
        _chipRow.AddChild(chip);
    }

    /// <summary>Full name, spelled-out action cost, remaining spell slots (if any), and a
    /// one-line description when the underlying spell/action data carries one.</summary>
    private static string BuildChipTooltip(string name, string costText, string? slotsText, string description)
    {
        var parts = new List<string> { name, SpellOutCost(costText) };
        if (!string.IsNullOrEmpty(slotsText))
            parts.Add(slotsText == "cantrip" ? "cantrip" : $"{slotsText.TrimStart('x')} remaining");

        string header = string.Join(" · ", parts);
        return string.IsNullOrEmpty(description) ? header : $"{header}\n{description}";
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
        RefreshPreviewLabel();
    }

    private void RefreshPreviewLabel() => _previewLabel.Text = _targeting ? TargetingHint : "";

    /// <summary>1/2/3/4 = Move/Step/Strike/Raise Shield, Space = End Turn. Respects Disabled (a
    /// button already reflects CanX + interactable via Render/SetInteractable) and is fully gated
    /// off while a modal is up. WASD/wheel/MMB are camera input and never reach here.</summary>
    public override void _UnhandledKeyInput(InputEvent @event)
    {
        if (!_interactable || _modalBlocking || @event is not InputEventKey key || !key.Pressed || key.Echo)
            return;

        switch (key.Keycode)
        {
            case Key.Key1:
            case Key.Kp1:
                Activate(_moveBtn, () => MovePressed?.Invoke());
                break;
            case Key.Key2:
            case Key.Kp2:
                Activate(_stepBtn, () => StepPressed?.Invoke());
                break;
            case Key.Key3:
            case Key.Kp3:
                Activate(_strikeBtn, () => StrikePressed?.Invoke());
                break;
            case Key.Key4:
            case Key.Kp4:
                Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
                break;
            case Key.Space:
                Activate(_endBtn, () => EndTurnPressed?.Invoke());
                break;
        }
    }

    private void Activate(Button button, Action fire)
    {
        if (button.Disabled) return;
        fire();
        GetViewport().SetInputAsHandled();
    }
}
