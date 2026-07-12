using Godot;

namespace Bulwark.Props;

/// <summary>
/// Two-state Winlu lever (3-frame throw animation: off → upright → on). World scenes route the
/// player's interact press here: check <see cref="PlayerInRange"/>, call <see cref="Toggle"/>,
/// and react to <see cref="Toggled"/> (open a gate, power a mechanism). Standalone-safe.
/// </summary>
public partial class Lever : Node2D
{
    [Signal] public delegate void ToggledEventHandler(bool isOn);

    /// <summary>Starting state; the sprite snaps to it on ready without animating.</summary>
    [Export] public bool IsOn { get; set; }

    /// <summary>True while a CharacterBody2D overlaps the interact zone.</summary>
    public bool PlayerInRange => _bodiesInRange > 0;

    private AnimatedSprite2D _sprite = null!;
    private int _bodiesInRange;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("%Sprite");
        _sprite.Animation = "open";
        _sprite.Frame = IsOn ? _sprite.SpriteFrames.GetFrameCount("open") - 1 : 0;

        var zone = GetNode<Area2D>("%InteractZone");
        zone.BodyEntered += OnBodyEntered;
        zone.BodyExited += OnBodyExited;
    }

    public void Toggle() => SetState(!IsOn);

    public void SetState(bool on)
    {
        if (IsOn == on)
            return;
        IsOn = on;
        if (on)
            _sprite.Play("open");
        else
            _sprite.PlayBackwards("open");
        EmitSignal(SignalName.Toggled, on);
    }

    private void OnBodyEntered(Node2D body)
    {
        if (body is CharacterBody2D)
            _bodiesInRange++;
    }

    private void OnBodyExited(Node2D body)
    {
        if (body is CharacterBody2D)
            _bodiesInRange = Mathf.Max(0, _bodiesInRange - 1);
    }
}
