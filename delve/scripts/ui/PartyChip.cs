using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>One party member in the combat party column: portrait, name, HP bar with current/max,
/// reaction diamond and condition icons. The only HUD surface that prints hero HP.</summary>
public partial class PartyChip : Button
{
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int ConditionIconSize { get; set; } = 24;

    private TextureRect _portrait = null!;
    private Label _name = null!;
    private Control _reactionSlot = null!;
    private Panel _reaction = null!;
    private ProgressBar _hpBar = null!;
    private Label _health = null!;
    private HBoxContainer _conditions = null!;
    private string _conditionSignature = "";

    public int MemberId { get; private set; }
    public string HealthText => _health.Text;
    public bool Framed => ThemeTypeVariation == ThemeNames.PartyChipActive;
    public ReactionMark Reaction { get; private set; }

    public override void _Ready()
    {
        _portrait = GetNode<TextureRect>("%Portrait");
        _name = GetNode<Label>("%Name");
        _reactionSlot = GetNode<Control>("%ReactionSlot");
        _reaction = GetNode<Panel>("%Reaction");
        _hpBar = GetNode<ProgressBar>("%HpBar");
        _health = GetNode<Label>("%Health");
        _conditions = GetNode<HBoxContainer>("%Conditions");
    }

    public void Setup(SquadMemberView member)
    {
        MemberId = member.Id;
        _portrait.Texture = HeroPortraits.For(member.HeroId);
        _name.Text = member.Name;
    }

    public void Render(SquadMemberView member)
    {
        SetPressedNoSignal(member.Focused);
        ThemeTypeVariation = member.Framed ? ThemeNames.PartyChipActive : ThemeNames.PartyChip;
        int max = System.Math.Max(1, member.MaxHp);
        _hpBar.MaxValue = max;
        _hpBar.Value = System.Math.Clamp(member.Hp, 0, max);
        _hpBar.ThemeTypeVariation = ThemeNames.HpBarFor(member.MaxHp > 0 ? (float)member.Hp / member.MaxHp : 0f);
        _health.Text = member.Down ? $"Down  {member.Hp}/{member.MaxHp}" : $"{member.Hp}/{member.MaxHp}";

        Reaction = member.Reaction;
        _reactionSlot.Visible = member.Reaction != ReactionMark.None;
        _reaction.ThemeTypeVariation = member.Reaction == ReactionMark.Ready ? ThemeNames.ReactionReady : ThemeNames.ReactionSpent;

        TooltipText = member.Tooltip + string.Concat(member.Conditions.Select(c => $"\n{c.Label}: {c.Description}"));
        RenderConditions(member);
    }

    private void RenderConditions(SquadMemberView member)
    {
        string signature = string.Join("|", member.Conditions.Select(c => $"{c.IconKey}:{c.Value}"));
        if (signature == _conditionSignature) return;
        _conditionSignature = signature;
        foreach (var child in _conditions.GetChildren())
        {
            _conditions.RemoveChild(child);
            child.QueueFree();
        }
        foreach (var condition in member.Conditions)
        {
            _conditions.AddChild(new TextureRect
            {
                Texture = Icons?.Find(condition.IconKey),
                CustomMinimumSize = new Vector2(ConditionIconSize, ConditionIconSize),
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                TextureFilter = TextureFilterEnum.Nearest,
                SizeFlagsVertical = SizeFlags.ShrinkCenter,
                MouseFilter = MouseFilterEnum.Ignore,
            });
            if (condition.Value > 0)
                _conditions.AddChild(new Label { Text = condition.Value.ToString(), MouseFilter = MouseFilterEnum.Ignore });
        }
    }
}
