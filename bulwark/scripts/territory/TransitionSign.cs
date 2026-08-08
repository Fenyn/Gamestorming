using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Greybox transition marker (scenes/territory/transition_sign.tscn): a placeholder signpost — a
/// post box plus a billboarded <see cref="Label3D"/> — placed at a travel trigger so the player can
/// find it, plus a proximity seam: when the bound player comes within <see cref="HintRadius"/>
/// METRES it raises <see cref="PlayerApproached"/> once per approach (hysteresis: it re-arms only
/// after they walk back out past the margin, so the HUD hint never spams). Render/intent only per
/// CLAUDE.md: the host scene turns the event into a toast and owns the actual travel. The user
/// replaces the visuals later (swap the whole scene); the marker position contract stays.
/// </summary>
public partial class TransitionSign : Node3D
{
    /// <summary>Distance (m) at which <see cref="PlayerApproached"/> fires (~2 cells).</summary>
    [Export] public float HintRadius { get; set; } = 2f;

    /// <summary>Extra distance past the radius before the hint re-arms (edge-jitter guard).</summary>
    [Export] public float RearmMargin { get; set; } = 0.7f;

    /// <summary>Raised once each time the tracked player comes into hint range.</summary>
    public event Action? PlayerApproached;

    /// <summary>True while the tracked player is inside the hint radius.</summary>
    public bool PlayerInRange { get; private set; }

    private Node3D? _player;
    private Label3D? _label;

    public override void _Ready()
    {
        _label = GetNodeOrNull<Label3D>("%Label");
    }

    /// <summary>Injected by the host scene after instancing: sign text + the player to track
    /// (null player = purely visual marker, no proximity events).</summary>
    public void Bind(string text, Node3D? player)
    {
        _label ??= GetNodeOrNull<Label3D>("%Label");
        if (_label != null)
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
