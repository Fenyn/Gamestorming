using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Blockout-grade transition marker (scenes/territory/transition_sign.tscn): a placeholder signpost
/// placed at a travel trigger so the player can find it, plus a proximity seam — when the bound
/// player comes within <see cref="HintRadius"/> it raises <see cref="PlayerApproached"/> once per
/// approach (hysteresis: it re-arms only after they walk back out past the margin, so the HUD hint
/// never spams). Render/intent only per CLAUDE.md: the host scene turns the event into a toast and
/// owns the actual travel. The user replaces the visuals later; the marker position contract stays.
/// </summary>
public partial class TransitionSign : Node2D
{
    /// <summary>Distance (px) at which <see cref="PlayerApproached"/> fires.</summary>
    [Export] public float HintRadius { get; set; } = 96f;

    /// <summary>Extra distance past the radius before the hint re-arms (edge-jitter guard).</summary>
    [Export] public float RearmMargin { get; set; } = 32f;

    /// <summary>Raised once each time the tracked player comes into hint range.</summary>
    public event Action? PlayerApproached;

    /// <summary>True while the tracked player is inside the hint radius.</summary>
    public bool PlayerInRange { get; private set; }

    private Node2D? _player;
    private Label _label = null!;

    public override void _Ready()
    {
        _label = GetNode<Label>("%Label");
    }

    /// <summary>Injected by the host scene after instancing: sign text + the player to track
    /// (null player = purely visual marker, no proximity events).</summary>
    public void Bind(string text, Node2D? player)
    {
        _label.Text = text;
        _player = player;
    }

    public override void _Process(double delta)
    {
        if (_player == null || !IsInstanceValid(_player))
            return;

        float distance = GlobalPosition.DistanceTo(_player.GlobalPosition);
        if (!PlayerInRange && distance <= HintRadius)
        {
            PlayerInRange = true;
            PlayerApproached?.Invoke();
        }
        else if (PlayerInRange && distance > HintRadius + RearmMargin)
        {
            PlayerInRange = false;
        }
    }
}
