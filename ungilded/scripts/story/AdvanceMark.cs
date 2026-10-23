using Godot;

namespace Ungilded.Story;

/// <summary>
/// The caret that shows a story screen waits for a click, Enter or Space. While visible it bobs
/// down and back in whole art pixels. Each time it appears the bob restarts from the top.
/// Its size is the texture at <see cref="PixelScale"/>; parents place it with anchors and grow direction.
/// </summary>
public partial class AdvanceMark : TextureRect
{
    /// <summary>Screen pixels per art pixel. The bob moves in steps of this size.</summary>
    [Export] public int PixelScale { get; set; } = 3;

    /// <summary>Lowest point of the bob, in art pixels.</summary>
    [Export] public int BobArtPixels { get; set; } = 2;

    [Export] public float BobSeconds { get; set; } = 0.9f;

    private float _top;
    private float _bottom;
    private double _time;

    public override void _Ready()
    {
        if (Texture != null) CustomMinimumSize = Texture.GetSize() * PixelScale;
        _top = OffsetTop;
        _bottom = OffsetBottom;
        VisibilityChanged += OnVisibilityChanged;
        OnVisibilityChanged();
    }

    public override void _Process(double delta)
    {
        _time = (_time + delta) % BobSeconds;
        float wave = 0.5f - 0.5f * Mathf.Cos(Mathf.Tau * (float)(_time / BobSeconds));
        SetBob(Mathf.Round(wave * BobArtPixels) * PixelScale);
    }

    private void OnVisibilityChanged()
    {
        _time = 0;
        SetBob(0);
        SetProcess(IsVisibleInTree());
    }

    private void SetBob(float pixels)
    {
        OffsetTop = _top + pixels;
        OffsetBottom = _bottom + pixels;
    }
}
