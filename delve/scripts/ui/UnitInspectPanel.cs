using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// A unit card: the hovered unit under the party column, or the attacker and target beside the
/// enemy-turn band. Letter badge, name and AC behind a team-coloured strip, HP bar with masked HP,
/// and active conditions. A card collapses toward its anchored edge when its content changes. Renders from <see cref="UnitInspectView"/> only; the AC/HP lines arrive
/// already masked, and the HP bar always fills to the real ratio (board-visible information).
/// </summary>
public partial class UnitInspectPanel : PanelContainer
{
    private ColorRect _accent = null!;
    private Control _badge = null!;
    private Label _badgeLabel = null!;
    private Label _nameLabel = null!;
    private Label _acLabel = null!;
    private ProgressBar _hpBar = null!;
    private Label _hpLabel = null!;
    private Label _conditionsLabel = null!;

    /// <summary>Off on combat cards: the initiative rows carry conditions, and a conditions line
    /// gave cards on one band different heights.</summary>
    [Export] public bool ShowConditions { get; set; }

    public string NameText => _nameLabel.Text;
    public bool AcShown => _acLabel.Visible;
    public bool HpShown => _hpLabel.Visible;

    public override void _Ready()
    {
        _accent = GetNode<ColorRect>("%Accent");
        _badge = GetNode<Control>("%Badge");
        _badgeLabel = GetNode<Label>("%BadgeLabel");
        _nameLabel = GetNode<Label>("%NameLabel");
        _acLabel = GetNode<Label>("%AcLabel");
        _hpBar = GetNode<ProgressBar>("%HpBar");
        _hpLabel = GetNode<Label>("%HpLabel");
        _conditionsLabel = GetNode<Label>("%ConditionsLabel");
        Visible = false;
    }

    /// <summary>Render the unit, or hide when null.</summary>
    public void Render(UnitInspectView? view)
    {
        Visible = view != null;
        if (view == null) return;

        _accent.Color = view.IsAlly ? UiColors.Ally : UiColors.Enemy;
        _badge.Visible = view.Letter.Length > 0;
        _badgeLabel.Text = view.Letter;
        _nameLabel.Text = view.Letter.Length > 0 && view.BaseName.Length > 0 ? view.BaseName : view.Name;
        _acLabel.Text = view.AcText;
        _acLabel.Visible = !Masked(view.AcText);

        int maxHp = System.Math.Max(1, view.MaxHp);
        _hpBar.MaxValue = maxHp;
        _hpBar.Value = System.Math.Clamp(view.Hp, 0, maxHp);
        _hpBar.ThemeTypeVariation =
            ThemeNames.HpBarFor(view.MaxHp > 0 ? (float)view.Hp / view.MaxHp : 0f);
        _hpLabel.Text = view.HpText;
        _hpLabel.Visible = view.HpText.Length > 0 && !Masked(view.HpText);

        _conditionsLabel.Visible = ShowConditions && view.Conditions.Count > 0;
        _conditionsLabel.Text = string.Join("   ", view.Conditions);
        if (GrowVertical == GrowDirection.Begin) OffsetTop = OffsetBottom;
        else OffsetBottom = OffsetTop;
    }

    /// <summary>An unrevealed stat prints nothing on a card: a bare "?" answers no question.</summary>
    private static bool Masked(string text) => text.Contains('?');
}
