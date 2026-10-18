using Delve.UI;
using Godot;

namespace Delve.Dungeon;

/// <summary>
/// A doorway's floating sign: the floor plan's icon for the room beyond (a "?" until it is seen or
/// scouted) on an ink plate, bobbing gently over the threshold. A cleared room's sign fades, and the
/// focused doorway's sign grows. It always draws over the scenery, so a tree never hides a way out.
/// </summary>
public partial class DoorSign : Node3D
{
    [Export] public RoomIconSet Icons { get; set; } = null!;

    /// <summary>How far the sign rises and falls, and how long one rise takes.</summary>
    [Export] public float BobHeight { get; set; } = 0.08f;

    [Export] public double BobSeconds { get; set; } = 1.4;

    [Export(PropertyHint.Range, "0,1,0.05")] public float ClearedAlpha { get; set; } = 0.45f;

    /// <summary>Scale of the sign over the focused doorway.</summary>
    [Export] public float FocusScale { get; set; } = 1.3f;

    private Node3D _float = null!;
    private Sprite3D _plate = null!, _glyph = null!;
    private Tween? _bob;

    /// <summary>The icon key shown, for spikes.</summary>
    public string IconKey { get; private set; } = "";

    public bool Faded { get; private set; }

    public override void _Ready()
    {
        _float = GetNode<Node3D>("%Float");
        _plate = GetNode<Sprite3D>("%Plate");
        _glyph = GetNode<Sprite3D>("%Glyph");
        _bob = CreateTween().SetLoops();
        _bob.TweenProperty(_float, "position:y", BobHeight, BobSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _bob.TweenProperty(_float, "position:y", 0f, BobSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>Show the icon for <paramref name="key"/>, faded when the room beyond is cleared.</summary>
    public void Show(string key, bool cleared)
    {
        IconKey = key;
        Faded = cleared;
        float alpha = cleared ? ClearedAlpha : 1f;
        _glyph.Texture = Icons.For(key);
        _glyph.Modulate = UiColors.Text with { A = alpha };
        _plate.Modulate = UiColors.Ink with { A = alpha };
    }

    public void SetFocused(bool focused) => Scale = Vector3.One * (focused ? FocusScale : 1f);
}
