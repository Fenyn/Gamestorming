using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>Persistent identity card for the actor whose turn is resolving.</summary>
public partial class ActiveCharacterPanel : PanelContainer
{
    private TextureRect _portrait = null!;
    private Label _name = null!;
    private Label _hp = null!;
    private Label _gear = null!;
    private Label _bonuses = null!;
    private Label _fallback = null!;
    private Label _status = null!;
    private ProgressBar _health = null!;
    private ActiveCharacterView? _last;

    public override void _Ready()
    {
        _portrait = GetNode<TextureRect>("%Portrait");
        _name = GetNode<Label>("%ActorName");
        _hp = GetNode<Label>("%HealthText");
        _gear = GetNode<Label>("%Gear");
        _bonuses = GetNode<Label>("%Bonuses");
        _fallback = GetNode<Label>("%Fallback");
        _status = GetNode<Label>("%Status");
        _health = GetNode<ProgressBar>("%HealthBar");
        Visible = false;
    }

    public void Render(ActiveCharacterView? view)
    {
        if (_last == view) return;
        _last = view;
        Visible = view != null;
        if (view == null) return;
        _portrait.Texture = view.IsHero ? HeroPortraits.For(view.Id) : null;
        _fallback.Visible = _portrait.Texture == null;
        _fallback.Text = view.Name.Length > 0 ? view.Name[..1] : "?";
        _name.Text = view.Name;
        _name.AddThemeColorOverride("font_color", view.IsHero ? UiColors.CharacterAccent(view.Id) : UiColors.Enemy);
        _hp.Text = $"HP {view.HpText}";
        _health.MaxValue = System.Math.Max(1, view.MaxHp);
        _health.Value = view.Hp;
        _health.ThemeTypeVariation = ThemeNames.HpBarFor(view.MaxHp > 0 ? (float)view.Hp / view.MaxHp : 0);
        _gear.Text = view.Gear;
        _gear.Visible = view.Gear.Length > 0;
        _gear.TooltipText = view.Gear + "\nWeapon bonuses are before multiple-attack penalties and target adjustments.";
        _bonuses.Text = view.Bonuses;
        _status.Text = view.Status;
        _status.TooltipText = view.StatusTip;
        _status.Visible = view.Status.Length > 0;
        _status.AddThemeColorOverride("font_color", UiColors.Accent);
    }
}
