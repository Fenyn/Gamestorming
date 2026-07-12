using Godot;

namespace Bulwark.Props;

/// <summary>
/// Animated Winlu door or gate. Plays the RPG-Maker-style "open" animation forward to open and
/// backward to close, and disables its doorway blocker while open. With <see cref="AutoOpen"/>
/// (the default) it opens when any CharacterBody2D enters the trigger area and closes when the
/// last one leaves — no input plumbing needed. Set it false for gameplay-gated doors/gates and
/// drive them via <see cref="Open"/>/<see cref="Close"/> instead. Standalone-safe: no scene or
/// autoload dependencies. Swap door styles by assigning a different SpriteFrames from
/// assets/props/ on the %Sprite node.
/// </summary>
public partial class Door : Node2D
{
    [Signal] public delegate void OpenedEventHandler();
    [Signal] public delegate void ClosedEventHandler();

    /// <summary>Locked doors ignore the trigger and <see cref="Open"/> calls until unlocked.</summary>
    [Export] public bool Locked { get; set; }

    /// <summary>Open/close automatically as bodies enter/leave the trigger area.</summary>
    [Export] public bool AutoOpen { get; set; } = true;

    public bool IsOpen { get; private set; }

    private AnimatedSprite2D _sprite = null!;
    private CollisionShape2D _blocker = null!;
    private int _bodiesInside;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("%Sprite");
        _blocker = GetNode<CollisionShape2D>("%BlockerShape");

        var trigger = GetNode<Area2D>("%Trigger");
        trigger.BodyEntered += OnBodyEntered;
        trigger.BodyExited += OnBodyExited;
    }

    public void Open()
    {
        if (IsOpen || Locked)
            return;
        IsOpen = true;
        _sprite.Play("open");
        _blocker.SetDeferred(CollisionShape2D.PropertyName.Disabled, true);
        EmitSignal(SignalName.Opened);
    }

    public void Close()
    {
        if (!IsOpen)
            return;
        IsOpen = false;
        _sprite.PlayBackwards("open");
        _blocker.SetDeferred(CollisionShape2D.PropertyName.Disabled, false);
        EmitSignal(SignalName.Closed);
    }

    private void OnBodyEntered(Node2D body)
    {
        if (body is not CharacterBody2D)
            return;
        _bodiesInside++;
        if (AutoOpen)
            Open();
    }

    private void OnBodyExited(Node2D body)
    {
        if (body is not CharacterBody2D)
            return;
        _bodiesInside = Mathf.Max(0, _bodiesInside - 1);
        if (AutoOpen && _bodiesInside == 0)
            Close();
    }
}
