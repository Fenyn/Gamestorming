using Godot;

namespace Delve.UI;

/// <summary>A short visual reveal of the latest resolved d20; never rolls gameplay dice.</summary>
public partial class DiceRollPanel : PanelContainer
{
    [Export] public float RevealSeconds { get; set; } = 0.25f;
    [Export] public float HoldSeconds { get; set; } = 1.1f;
    [Export] public float FadeSeconds { get; set; } = 0.2f;
    private Label _die = null!;
    private Label _context = null!;
    private Label _math = null!;
    private Label _outcome = null!;
    private CombatRoll? _roll;
    private float _elapsed;
    private bool _enabled;

    public override void _Ready()
    {
        _die = GetNode<Label>("%DieValue");
        _context = GetNode<Label>("%RollContext");
        _math = GetNode<Label>("%RollMath");
        _outcome = GetNode<Label>("%RollOutcome");
        SetEnabled(Delve.Settings.ViewPreferences.ShowDiceRolls);
        ClearRoll();
    }

    public void SetEnabled(bool enabled)
    {
        _enabled = enabled;
        if (!enabled) ClearRoll();
    }

    public void ClearRoll() { _roll = null; Visible = false; }

    public void ShowRoll(CombatRoll roll, string context)
    {
        if (!_enabled) return;
        _roll = roll;
        _elapsed = 0;
        _context.Text = context;
        _math.Text = "d20";
        _outcome.Text = "";
        _die.Text = "…";
        Modulate = Colors.White;
        Visible = true;
    }

    public override void _Process(double delta)
    {
        if (_roll == null) return;
        _elapsed += (float)delta;
        if (_elapsed < RevealSeconds)
        {
            _die.Text = (1 + ((int)(_elapsed * 70) % 20)).ToString();
            return;
        }
        _die.Text = _roll.Die.ToString();
        _math.Text = $"{_roll.Die}{_roll.Modifiers} = {_roll.Total} vs {_roll.Defense} {_roll.DC}";
        _outcome.Text = _roll.Outcome;
        int severity = _roll.Degree switch { "CriticalSuccess" => 2, "Success" => 1, "Failure" => 3, _ => 4 };
        _outcome.AddThemeColorOverride("font_color", UiColors.LogSeverity[severity]);
        float fade = _elapsed - RevealSeconds - HoldSeconds;
        if (fade > 0) Modulate = Colors.White with { A = Mathf.Clamp(1 - fade / Mathf.Max(0.01f, FadeSeconds), 0, 1) };
        if (fade >= FadeSeconds) ClearRoll();
    }
}
