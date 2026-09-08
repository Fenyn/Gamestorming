using System;
using Delve.Run;
using Godot;

namespace Delve.Flow;

/// <summary>Rest availability and its ward cost.</summary>
public partial class RunMapRecovery : VBoxContainer
{
    private Label _cost = null!;
    private Button _restButton = null!;

    public event Action? RestPressed;
    public event Action<bool>? RestPreviewChanged;
    private bool _hovered;

    public override void _Ready()
    {
        _cost = GetNode<Label>("%RestCost");
        _restButton = GetNode<Button>("%ShortRestButton");
        _restButton.Pressed += () => RestPressed?.Invoke();
        _restButton.MouseEntered += () => { _hovered = true; UpdatePreview(); };
        _restButton.MouseExited += () => { _hovered = false; UpdatePreview(); };
        VisibilityChanged += () => { if (!IsVisibleInTree()) _hovered = false; UpdatePreview(); };
    }

    public void Render(RunState state)
    {
        var ward = state.Wardstone;
        int taken = state.Clock.ShortRestsToday;
        string day = $"Day {state.Clock.Day} · {taken} rest{(taken == 1 ? "" : "s")} taken";
        _cost.Text = ward.IsSpent ? "The ward is out."
            : ward.ShortRestWouldSpend ? "Rest unavailable: too little ward."
            : ward.UpshiftAfterShortRest > ward.Upshift
                ? $"Rest raises encounter threat to +{ward.UpshiftAfterShortRest}." : "";
        _cost.Visible = _cost.Text.Length > 0;
        _cost.TooltipText = WardLines.RestPreview(ward);
        _restButton.Text = $"Short Rest · {ward.Rules.ShortRestBurn} ward";
        _restButton.Disabled = !ward.CanAffordShortRest;
        UpdatePreview();
        _restButton.TooltipText = day + "\n" + (ward.CanAffordShortRest
            ? "Choose Treat Wounds, Refocus, or Repair Shield. Opening this menu costs nothing."
            : WardLines.RestUnavailable(ward));
    }

    private void UpdatePreview() => RestPreviewChanged?.Invoke(
        _hovered && IsVisibleInTree() && !_restButton.Disabled);
}
