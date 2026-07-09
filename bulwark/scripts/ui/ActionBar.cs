using System;
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

    private Label _actorLabel = null!;
    private readonly ColorRect[] _pips = new ColorRect[3];
    private Button _moveBtn = null!;
    private Button _stepBtn = null!;
    private Button _strikeBtn = null!;
    private Button _shieldBtn = null!;
    private Button _endBtn = null!;
    private CheckButton _aiToggle = null!;
    private Label _previewLabel = null!;

    private bool _suppressToggle;
    private bool _interactable = true;

    public override void _Ready()
    {
        var panel = new PanelContainer();
        panel.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(panel);

        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        panel.AddChild(row);

        _actorLabel = new Label { Text = "—", CustomMinimumSize = new Vector2(120, 0) };
        _actorLabel.VerticalAlignment = VerticalAlignment.Center;
        row.AddChild(_actorLabel);

        var pipRow = new HBoxContainer();
        pipRow.AddThemeConstantOverride("separation", 4);
        for (int i = 0; i < _pips.Length; i++)
        {
            _pips[i] = new ColorRect { CustomMinimumSize = new Vector2(16, 16) };
            pipRow.AddChild(_pips[i]);
        }
        row.AddChild(pipRow);

        _moveBtn = MakeButton(row, "Move", () => MovePressed?.Invoke());
        _stepBtn = MakeButton(row, "Step", () => StepPressed?.Invoke());
        _strikeBtn = MakeButton(row, "Strike", () => StrikePressed?.Invoke());
        _shieldBtn = MakeButton(row, "Raise Shield", () => RaiseShieldPressed?.Invoke());
        _endBtn = MakeButton(row, "End Turn", () => EndTurnPressed?.Invoke());

        _aiToggle = new CheckButton { Text = "AI" };
        _aiToggle.Toggled += on => { if (!_suppressToggle) AiToggled?.Invoke(on); };
        row.AddChild(_aiToggle);

        _previewLabel = new Label { Text = "", CustomMinimumSize = new Vector2(220, 0) };
        _previewLabel.VerticalAlignment = VerticalAlignment.Center;
        _previewLabel.AddThemeColorOverride("font_color", new Color(0.85f, 0.85f, 0.7f));
        row.AddChild(_previewLabel);
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

    private static Button MakeButton(Node parent, string text, Action onPressed)
    {
        var btn = new Button { Text = text };
        btn.Pressed += onPressed;
        parent.AddChild(btn);
        return btn;
    }
}
