using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// An FFT-style unit card: the hovered or acting unit bottom left, or the attacker and target on
/// the enemy-turn band. A portrait tile framed in the team colour, the name with level and class,
/// the HP and AC lines over a wide HP bar, and active conditions. A card collapses toward its
/// anchored edge when its content changes. Renders from <see cref="UnitInspectView"/> only; the
/// AC/HP lines arrive already masked, and the HP bar always fills to the real ratio
/// (board-visible information).
/// </summary>
public partial class UnitInspectPanel : PanelContainer
{
    private PanelContainer _portraitFrame = null!;
    private TextureRect _portrait = null!;
    private Label _levelLabel = null!;
    private Label _classLabel = null!;
    private PipRow _actionPips = null!;
    private Control _reactionSlot = null!;
    private Panel _reaction = null!;
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
    [Export] public bool ShowConditions { get; set; } = true;

    public string NameText => _nameLabel.Text;
    public bool AcShown => _acLabel.Visible;
    public bool HpShown => _hpLabel.Visible;

    public override void _Ready()
    {
        _portraitFrame = GetNode<PanelContainer>("%PortraitFrame");
        _portrait = GetNode<TextureRect>("%Portrait");
        _levelLabel = GetNode<Label>("%LevelLabel");
        _classLabel = GetNode<Label>("%ClassLabel");
        _actionPips = GetNode<PipRow>("%ActionPips");
        _reactionSlot = GetNode<Control>("%ReactionSlot");
        _reaction = GetNode<Panel>("%Reaction");
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
        _portrait.Texture = UnitPortraits.For(view.HeroId, view.SpriteFolder);
        _portraitFrame.ThemeTypeVariation = view.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;
        _levelLabel.Text = view.Level > 0 ? $"Lv {view.Level}" : "";
        _classLabel.Text = view.ClassName;
        _actionPips.Visible = view.MaxActions > 0;
        if (view.MaxActions > 0) _actionPips.SetActionEconomy(view.ActionsRemaining, view.MaxActions);
        _reactionSlot.Visible = view.Reaction != ReactionMark.None;
        _reaction.ThemeTypeVariation = view.Reaction == ReactionMark.Ready ? ThemeNames.ReactionReady : ThemeNames.ReactionSpent;
        _reactionSlot.TooltipText = view.Reaction == ReactionMark.Ready ? "Reaction ready" : "Reaction spent";

        int maxHp = System.Math.Max(1, view.MaxHp);
        _hpBar.MaxValue = maxHp;
        _hpBar.Value = System.Math.Clamp(view.Hp, 0, maxHp);
        _hpBar.ThemeTypeVariation =
            ThemeNames.HpBarFor(view.MaxHp > 0 ? (float)view.Hp / view.MaxHp : 0f);
        _hpLabel.Text = view.HpText.Length > 0 ? $"HP {view.HpText}" : "";
        _hpLabel.Visible = view.HpText.Length > 0 && !Masked(view.HpText);

        _conditionsLabel.Visible = ShowConditions && view.Conditions.Count > 0;
        _conditionsLabel.Text = string.Join("   ", view.Conditions);
        if (GrowVertical == GrowDirection.Begin) OffsetTop = OffsetBottom;
        else OffsetBottom = OffsetTop;
    }

    /// <summary>An unrevealed stat prints nothing on a card: a bare "?" answers no question.</summary>
    private static bool Masked(string text) => text.Contains('?');
}
