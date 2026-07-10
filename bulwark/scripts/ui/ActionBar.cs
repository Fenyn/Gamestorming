using System;
using System.Collections.Generic;
using Bulwark.Combat;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive action bar for the active ally: 3 action pips, the Move/Step/Strike/Raise-Shield/End-Turn
/// buttons, an AI toggle, and an attack-preview readout. Renders from <see cref="ActionBarState"/>
/// and raises intent events only — it holds no rules and no engine types.
/// </summary>
public partial class ActionBar : Control
{
    public event Action? MovePressed;
    public event Action? StepPressed;
    public event Action? StrikePressed;
    public event Action? RaiseShieldPressed;
    public event Action? EndTurnPressed;
    public event Action<bool>? AiToggled;
    /// <summary>Raised with (spellId, variantIndex) when a spell chip is pressed.</summary>
    public event Action<string, int>? SpellChipPressed;
    /// <summary>Raised with the skill action id when a skill chip is pressed.</summary>
    public event Action<string>? SkillChipPressed;

    private static readonly PackedScene ChipScene =
        GD.Load<PackedScene>("res://scenes/ui/action_chip.tscn");

    private Label _actorLabel = null!;
    private readonly ColorRect[] _pips = new ColorRect[3];
    private Button _moveBtn = null!;
    private Button _stepBtn = null!;
    private Button _strikeBtn = null!;
    private Button _shieldBtn = null!;
    private Button _endBtn = null!;
    private CheckButton _aiToggle = null!;
    private Label _previewLabel = null!;
    private HFlowContainer _chipRow = null!;

    private bool _suppressToggle;
    private bool _interactable = true;

    public override void _Ready()
    {
        _actorLabel = GetNode<Label>("%ActorLabel");
        _pips[0] = GetNode<ColorRect>("%Pip0");
        _pips[1] = GetNode<ColorRect>("%Pip1");
        _pips[2] = GetNode<ColorRect>("%Pip2");
        _moveBtn = GetNode<Button>("%MoveButton");
        _stepBtn = GetNode<Button>("%StepButton");
        _strikeBtn = GetNode<Button>("%StrikeButton");
        _shieldBtn = GetNode<Button>("%ShieldButton");
        _endBtn = GetNode<Button>("%EndButton");
        _aiToggle = GetNode<CheckButton>("%AiToggle");
        _previewLabel = GetNode<Label>("%PreviewLabel");
        _chipRow = GetNode<HFlowContainer>("%ChipRow");

        _moveBtn.Pressed += () => MovePressed?.Invoke();
        _stepBtn.Pressed += () => StepPressed?.Invoke();
        _strikeBtn.Pressed += () => StrikePressed?.Invoke();
        _shieldBtn.Pressed += () => RaiseShieldPressed?.Invoke();
        _endBtn.Pressed += () => EndTurnPressed?.Invoke();
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
    }

    /// <summary>Enable/disable the whole bar (disabled while an AI or enemy turn is running).</summary>
    public void SetInteractable(bool interactable)
    {
        _interactable = interactable;
        Modulate = interactable ? Colors.White : new Color(1, 1, 1, 0.45f);
    }

    public void SetAiToggle(bool on)
    {
        _suppressToggle = true;
        _aiToggle.ButtonPressed = on;
        _suppressToggle = false;
    }

    public void Render(ActionBarState state)
    {
        _actorLabel.Text = state.ActorName;

        for (int i = 0; i < _pips.Length; i++)
        {
            bool filled = i < state.ActionsRemaining && i < state.MaxActions;
            _pips[i].Color = filled ? new Color(1f, 0.85f, 0.3f) : new Color(0.25f, 0.25f, 0.28f);
            _pips[i].Visible = i < state.MaxActions;
        }

        _strikeBtn.Text = state.Map < 0 ? $"Strike ({state.Map})" : "Strike";

        _moveBtn.Disabled = !_interactable || !state.CanMove;
        _stepBtn.Disabled = !_interactable || !state.CanStep;
        _strikeBtn.Disabled = !_interactable || !state.CanStrike;
        _shieldBtn.Disabled = !_interactable || !state.CanRaiseShield;
        _endBtn.Disabled = !_interactable;

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
                () => SpellChipPressed?.Invoke(sid, vi));
        }

        foreach (var skill in skills)
        {
            string aid = skill.ActionId;
            AddChip($"{skill.Name}  {skill.CostText}",
                enabled: _interactable && skill.Castable,
                () => SkillChipPressed?.Invoke(aid));
        }
    }

    private void AddChip(string text, bool enabled, Action onPressed)
    {
        var chip = ChipScene.Instantiate<Button>();
        chip.Text = text;
        chip.Disabled = !enabled;
        chip.Pressed += onPressed;
        _chipRow.AddChild(chip);
    }

    public void ShowAttackPreview(AttackPreviewView? preview)
    {
        if (preview == null)
        {
            _previewLabel.Text = "";
            return;
        }

        string flank = preview.TargetOffGuard ? " [off-guard]" : "";
        _previewLabel.Text =
            $"{preview.WeaponName} +{preview.TotalAttackBonus} vs AC {preview.TargetAc}  " +
            $"{preview.HitChancePercent}% hit / {preview.CritChancePercent}% crit  " +
            $"dmg {preview.DamageFormula}{flank}";
    }
}
