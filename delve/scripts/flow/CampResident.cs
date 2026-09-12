using System;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>A selectable resident anchored in the camp. Animation reverses from its current pose.</summary>
public partial class CampResident : Button
{
    [Export] public float PoseSeconds { get; set; } = 0.16f;
    [Export] public float IdlePeriod { get; set; } = 3.8f;
    [Export] public float IdleBobPixels { get; set; } = 1;
    private Sprite2D _sprite = null!;
    private Label _name = null!;
    private Label _caption = null!;
    private ShaderMaterial _material = null!;
    private Texture2D[] _poses = Array.Empty<Texture2D>();
    private Image[] _hitImages = Array.Empty<Image>();
    private bool _selected;
    private int _pose;
    private float _clock;
    private float _time;
    private Vector2 _restPosition;
    public string Id { get; private set; } = "";
    public bool Selected => _selected;
    public bool Resting => !_selected && _pose == 0;
    public bool IsReady => _selected && _pose == _poses.Length - 1;
    public event Action<string>? Clicked;
    public event Action<string?>? Hovered;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("%Sprite");
        _name = GetNode<Label>("%NameLabel");
        _caption = GetNode<Label>("%CaptionLabel");
        _material = (ShaderMaterial)_sprite.Material.Duplicate();
        _sprite.Material = _material;
        _restPosition = _sprite.Position;
        Pressed += () => Clicked?.Invoke(Id);
        MouseEntered += () => Hovered?.Invoke(Id);
        FocusEntered += () => Hovered?.Invoke(Id);
    }

    public void Setup(CharacterDef def, CampAppearance appearance, int seat)
    {
        Id = def.Id;
        _name.Text = def.DisplayName;
        _poses = appearance.Poses();
        _hitImages = Array.ConvertAll(_poses, texture => texture.GetImage());
        _sprite.Texture = _poses[0];
        _sprite.FlipH = seat % 2 == 0;
        _pose = 0;
        _time = seat * 0.83f;
        var accent = UiColors.CharacterAccent(Id);
        _material.SetShaderParameter("outline_color", accent);
        _caption.AddThemeColorOverride("font_color", accent);
    }

    public void SetState(bool selected, string? reason)
    {
        _selected = selected;
        Disabled = reason != null;
        TooltipText = reason == null ? (selected ? "Click to remove from the party" : "Click to join the party") : $"Unavailable: {reason}";
        _caption.Text = selected ? "IN PARTY" : "";
        _material.SetShaderParameter("selected", selected);
        _name.Modulate = Disabled ? UiColors.TextDim : Colors.White;
    }

    public override bool _HasPoint(Vector2 point)
    {
        if (_hitImages.Length == 0) return false;
        if (_name.GetRect().HasPoint(point) || (_selected && _caption.GetRect().HasPoint(point))) return true;
        Vector2 source = (point - _sprite.Position) / _sprite.Scale + new Vector2(32, 32);
        int x = Mathf.FloorToInt(source.X), y = Mathf.FloorToInt(source.Y);
        if (_sprite.FlipH) x = 63 - x;
        // Ignore the large transparent sprite-cell corners so nearby residents remain clickable.
        return x is >= 0 and < 64 && y is >= 0 and < 64 && _hitImages[_pose].GetPixel(x, y).A > 0.1f;
    }

    public override void _Process(double delta)
    {
        if (_poses.Length == 0 || !IsVisibleInTree()) return;
        _clock += (float)delta;
        _time += (float)delta;
        if (_clock >= PoseSeconds)
        {
            _clock = 0;
            _pose = Math.Clamp(_pose + (_selected ? 1 : -1), 0, _poses.Length - 1);
            _sprite.Texture = _poses[_pose];
        }
        // Pixel-stepped breathing has a different phase at each seat, without distorting the art.
        float bob = Mathf.Sin(_time * Mathf.Tau / IdlePeriod) > 0.7f ? IdleBobPixels : 0;
        _sprite.Position = _restPosition + new Vector2(0, -bob);
    }
}
