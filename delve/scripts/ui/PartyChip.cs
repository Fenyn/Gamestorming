using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>One party member card: portrait, name, condition icons and reaction
/// diamond on the top row, the HP bar with current/max under it. Used by the exploration party
/// cards (party_card.tscn).</summary>
public partial class PartyChip : Button
{
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int ConditionIconSize { get; set; } = 22;

    /// <summary>Icons before "+N". Matches the initiative row's count.</summary>
    [Export] public int MaxMarks { get; set; } = 2;

    /// <summary>Show the head-and-shoulders face crop instead of the full-body portrait.</summary>
    [Export] public bool UseFace { get; set; }

    private const string OpenSheetHint = "\nClick to open the character sheet.";

    private TextureRect _portrait = null!;
    private Label _name = null!;
    private Control _reactionSlot = null!;
    private Panel _reaction = null!;
    private ProgressBar _hpBar = null!;
    private Label _health = null!;
    private HBoxContainer _conditions = null!;
    private string _conditionSignature = "";
    private Label _promotion = null!;

    public int MemberId { get; private set; }
    public string HealthText => _health.Text;
    public bool Framed => ThemeTypeVariation == ThemeNames.PartyChipActive;
    public ReactionMark Reaction { get; private set; }
    public bool PromotionBadge => _promotion.Visible;

    /// <summary>The "+N" the chip prints, or "".</summary>
    public string OverflowText { get; private set; } = "";

    /// <summary>The icon key of the first mark, or "".</summary>
    public string FirstMark { get; private set; } = "";

    public override void _Ready()
    {
        _portrait = GetNode<TextureRect>("%Portrait");
        _name = GetNode<Label>("%Name");
        _reactionSlot = GetNode<Control>("%ReactionSlot");
        _reaction = GetNode<Panel>("%Reaction");
        _hpBar = GetNode<ProgressBar>("%HpBar");
        _health = GetNode<Label>("%Health");
        _conditions = GetNode<HBoxContainer>("%Conditions");
        _promotion = GetNode<Label>("%Promotion");
    }

    public void Setup(SquadMemberView member)
    {
        MemberId = member.Id;
        _portrait.Texture = UseFace ? HeroPortraits.Face(member.HeroId) : HeroPortraits.For(member.HeroId);
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
        int dying = member.Conditions.FirstOrDefault(c => c.IconKey == nameof(PF2e.Conditions.Condition.Dying))?.Value ?? 0;
        _health.Text = member.Down && dying > 0 ? $"Dying {dying}" : $"{member.Hp}/{member.MaxHp}";

        _promotion.Visible = member.PromotionPending;
        Reaction = member.Reaction;
        _reactionSlot.Visible = member.Reaction != ReactionMark.None;
        _reaction.ThemeTypeVariation = member.Reaction == ReactionMark.Ready ? ThemeNames.ReactionReady : ThemeNames.ReactionSpent;

        TooltipText = member.Tooltip + string.Concat(member.Conditions.Select(c => $"\n{c.Label}: {c.Description}"))
            + OpenSheetHint;
        RenderConditions(member);
    }

    /// <summary>The first <see cref="MaxMarks"/> conditions, most urgent first, then "+N". The name clips
    /// to make room, and the chip's hover lists every condition.</summary>
    private void RenderConditions(SquadMemberView member)
    {
        string signature = string.Join("|", member.Conditions.Select(c => $"{c.IconKey}:{c.Value}"));
        OverflowText = ConditionMarkRow.Overflow(member.Conditions.Count, MaxMarks);
        FirstMark = member.Conditions.Count > 0 ? member.Conditions[0].IconKey : "";
        if (signature == _conditionSignature) return;
        _conditionSignature = signature;
        ConditionMarkRow.Fill(_conditions, member.Conditions, Icons, MaxMarks, ConditionIconSize);
    }
}
