using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public partial class UnitVisual : Node2D
{
    private const int TileSize = GridVisual.TileSize;

    private ColorRect _body;
    private ColorRect _outline;
    private Label _nameLabel;
    private Label _levelLabel;
    private ProgressBar _healthBar;
    private Label _hpText;
    private HBoxContainer _conditionRow;
    private AnimationPlayer _animPlayer;

    private ICharacter _character;
    private EnemyDefinition _definition;
    private int _teamId;
    private Color _bodyColor;
    private Color _outlineColor;

    public ICharacter Character => _character;
    public int TeamId => _teamId;

    public static UnitVisual Create(ICharacter character, EnemyDefinition definition, int teamId)
    {
        var unit = new UnitVisual();
        unit._character = character;
        unit._definition = definition;
        unit._teamId = teamId;
        unit._bodyColor = CreatureColors.GetCreatureColor(definition);
        unit._outlineColor = teamId == 1 ? CreatureColors.PlayerOutline : CreatureColors.EnemyOutline;
        return unit;
    }

    public override void _Ready()
    {
        int tileWidth = _character?.TileWidth ?? 1;
        int pixelSize = tileWidth * TileSize;

        _outline = new ColorRect();
        _outline.Size = new Vector2(pixelSize, pixelSize);
        _outline.Color = _outlineColor;
        AddChild(_outline);

        _body = new ColorRect();
        _body.Size = new Vector2(pixelSize - 4, pixelSize - 4);
        _body.Position = new Vector2(2, 2);
        _body.Color = _bodyColor;
        AddChild(_body);

        _nameLabel = new Label();
        _nameLabel.Text = _character?.Name ?? "???";
        _nameLabel.Position = new Vector2(2, -18);
        _nameLabel.AddThemeFontSizeOverride("font_size", 11);
        _nameLabel.AddThemeColorOverride("font_color", Colors.White);
        _nameLabel.AddThemeColorOverride("font_shadow_color", Colors.Black);
        _nameLabel.AddThemeConstantOverride("shadow_offset_x", 1);
        _nameLabel.AddThemeConstantOverride("shadow_offset_y", 1);
        AddChild(_nameLabel);

        int level = _definition?.StatBlock.CreatureLevel ?? 0;
        _levelLabel = new Label();
        _levelLabel.Text = $"Lv{level}";
        _levelLabel.Position = new Vector2(pixelSize - 28, 2);
        _levelLabel.AddThemeFontSizeOverride("font_size", 10);
        _levelLabel.AddThemeColorOverride("font_color", new Color(1, 0.85f, 0.3f));
        AddChild(_levelLabel);

        int maxHp = _character?.Health?.MaxHP ?? 1;
        int curHp = _character?.Health?.CurrentHP ?? maxHp;

        _healthBar = new ProgressBar();
        _healthBar.MinValue = 0;
        _healthBar.MaxValue = maxHp;
        _healthBar.Value = curHp;
        _healthBar.ShowPercentage = false;
        _healthBar.Position = new Vector2(0, pixelSize + 2);
        _healthBar.Size = new Vector2(pixelSize, 8);
        _healthBar.AddThemeStyleboxOverride("fill", CreateHealthFillStyle(1.0f));
        _healthBar.AddThemeStyleboxOverride("background", CreateHealthBgStyle());
        AddChild(_healthBar);

        _hpText = new Label();
        _hpText.Text = $"{curHp}/{maxHp}";
        _hpText.Position = new Vector2(2, pixelSize + 1);
        _hpText.AddThemeFontSizeOverride("font_size", 8);
        _hpText.AddThemeColorOverride("font_color", Colors.White);
        AddChild(_hpText);

        _conditionRow = new HBoxContainer();
        _conditionRow.Position = new Vector2(0, pixelSize + 12);
        _conditionRow.AddThemeConstantOverride("separation", 2);
        AddChild(_conditionRow);

        _animPlayer = new AnimationPlayer();
        AddChild(_animPlayer);
    }

    public void UpdateHealthBar()
    {
        if (_character?.Health == null) return;

        int cur = _character.Health.CurrentHP;
        int max = _character.Health.MaxHP;
        float ratio = max > 0 ? (float)cur / max : 0;

        _healthBar.Value = cur;
        _hpText.Text = $"{cur}/{max}";

        _healthBar.AddThemeStyleboxOverride("fill", CreateHealthFillStyle(ratio));
    }

    public void UpdateHealthBar(int currentHp, int maxHp)
    {
        float ratio = maxHp > 0 ? (float)currentHp / maxHp : 0;
        _healthBar.Value = currentHp;
        _hpText.Text = $"{currentHp}/{maxHp}";
        _healthBar.AddThemeStyleboxOverride("fill", CreateHealthFillStyle(ratio));
    }

    public void AddConditionDot(string conditionName, Color color)
    {
        var dot = new ColorRect();
        dot.Size = new Vector2(8, 8);
        dot.Color = color;
        dot.TooltipText = conditionName;
        _conditionRow.AddChild(dot);
    }

    public void ClearConditionDots()
    {
        foreach (var child in _conditionRow.GetChildren())
            child.QueueFree();
    }

    public void FlashHit()
    {
        var tween = CreateTween();
        _body.Color = Colors.White;
        tween.TweenProperty(_body, "color", _bodyColor, 0.2f);
    }

    public void FlashAttack()
    {
        var tween = CreateTween();
        var orig = Position;
        tween.TweenProperty(this, "position", orig + new Vector2(4, 0), 0.05f);
        tween.TweenProperty(this, "position", orig - new Vector2(4, 0), 0.05f);
        tween.TweenProperty(this, "position", orig, 0.05f);
    }

    public void SetHighlighted(bool highlighted)
    {
        if (highlighted)
        {
            var tween = CreateTween().SetLoops();
            tween.TweenProperty(_outline, "color", _outlineColor * 1.5f, 0.4f);
            tween.TweenProperty(_outline, "color", _outlineColor, 0.4f);
        }
        else
        {
            _outline.Color = _outlineColor;
        }
    }

    public void PlayDeath()
    {
        var tween = CreateTween();
        tween.TweenProperty(this, "modulate:a", 0.0f, 0.5f);
    }

    public void GrayOut()
    {
        Modulate = new Color(0.4f, 0.4f, 0.4f, 0.6f);
    }

    private static StyleBoxFlat CreateHealthFillStyle(float ratio)
    {
        Color fillColor;
        if (ratio > 0.6f)
            fillColor = new Color(0.2f, 0.8f, 0.2f);
        else if (ratio > 0.3f)
            fillColor = new Color(0.9f, 0.8f, 0.1f);
        else
            fillColor = new Color(0.9f, 0.2f, 0.2f);

        var style = new StyleBoxFlat();
        style.BgColor = fillColor;
        return style;
    }

    private static StyleBoxFlat CreateHealthBgStyle()
    {
        var style = new StyleBoxFlat();
        style.BgColor = new Color(0.15f, 0.15f, 0.15f);
        return style;
    }
}
