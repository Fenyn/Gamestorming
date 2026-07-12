using Godot;

namespace Bulwark.Props;

/// <summary>
/// Interactable Winlu chest: 4-frame lid animation, solid while placed. World scenes route the
/// player's interact press here (mirror the territory InteractRequested pattern): check
/// <see cref="PlayerInRange"/>, then call <see cref="Open"/>. What opening yields is game-system
/// logic — subscribe to <see cref="Opened"/> and grant loot / open storage UI there. Standalone-safe.
/// </summary>
public partial class Chest : Node2D
{
    [Signal] public delegate void OpenedEventHandler();
    [Signal] public delegate void ClosedEventHandler();

    /// <summary>Open automatically when a body walks into the interact zone (loot-on-touch).</summary>
    [Export] public bool OpenOnTouch { get; set; }

    public bool IsOpen { get; private set; }

    /// <summary>True while a CharacterBody2D overlaps the interact zone.</summary>
    public bool PlayerInRange => _bodiesInRange > 0;

    private AnimatedSprite2D _sprite = null!;
    private int _bodiesInRange;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("%Sprite");

        var zone = GetNode<Area2D>("%InteractZone");
        zone.BodyEntered += OnBodyEntered;
        zone.BodyExited += OnBodyExited;
    }

    public void Open()
    {
        if (IsOpen)
            return;
        IsOpen = true;
        _sprite.Play("open");
        EmitSignal(SignalName.Opened);
    }

    public void Close()
    {
        if (!IsOpen)
            return;
        IsOpen = false;
        _sprite.PlayBackwards("open");
        EmitSignal(SignalName.Closed);
    }

    private void OnBodyEntered(Node2D body)
    {
        if (body is not CharacterBody2D)
            return;
        _bodiesInRange++;
        if (OpenOnTouch)
            Open();
    }

    private void OnBodyExited(Node2D body)
    {
        if (body is not CharacterBody2D)
            return;
        _bodiesInRange = Mathf.Max(0, _bodiesInRange - 1);
    }
}
