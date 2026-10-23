using System.Collections.Generic;
using System.Linq;
using Ungilded.Combat;
using Godot;

namespace Ungilded.UI;

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
    private JournalFactsGrid _knowledge = null!;
    private Label _callout = null!;

    /// <summary>Off on combat cards: the initiative rows carry conditions, and a conditions line
    /// gave cards on one band different heights.</summary>
    [Export] public bool ShowConditions { get; set; } = true;

    public string NameText => _nameLabel.Text;
    public bool AcShown => _acLabel.Visible;
    public bool HpShown => _hpLabel.Visible;

    /// <summary>The knowledge rows as drawn ("AC ???", "Fort +7"). Dev spikes read them.</summary>
    public IReadOnlyList<string> KnowledgeTexts { get; private set; } = System.Array.Empty<string>();

    public bool CalloutShown => _callout.Visible;
    public string CalloutText => _callout.Text;

    /// <summary>The action squares, or null while the card does not draw them.</summary>
    public Control? ActionPipsPart => Drawn(_actionPips);

    /// <summary>The reaction diamond, or null while the card does not draw it.</summary>
    public Control? ReactionPart => Drawn(_reactionSlot);

    /// <summary>The reaction diamond's hover. The diamond's colour shows whether it is spent.</summary>
    public const string ReactionTooltip = "1 reaction per round. It comes back at the start of your turn.";

    /// <summary>The reaction diamond's hover text as set, for the spikes.</summary>
    public string ReactionHover => _reactionSlot.TooltipText;

    /// <summary>The name row (letter badge and name), or null while the card is hidden.</summary>
    public Control? NamePart => Drawn(_nameLabel.GetParent<Control>());

    /// <summary>The HP bar and, when it shows, the HP line above it.</summary>
    public IEnumerable<Control> HpParts()
    {
        if (Drawn(_hpLabel) is { } label) yield return label;
        if (Drawn(_hpBar) is { } bar) yield return bar;
    }

    /// <summary>The knowledge row whose label is <paramref name="label"/> ("AC", "Weakness"), or null.</summary>
    public Control? KnowledgePart(string label)
        => FindRow(label) is { } row && row.Index < row.Grid.GetChildCount()
            ? Drawn(row.Grid.GetChild<Control>(row.Index)) : null;

    private static Control? Drawn(Control control) => control.IsVisibleInTree() ? control : null;

    /// <summary>Pulse the knowledge row whose label is <paramref name="field"/> ("Abilities"), with
    /// no change to its text. False when the card shows no such row.</summary>
    public bool PulseKnowledgeRow(string field)
        => Visible && FindRow(field) is { } row && row.Grid.Pulse(row.Index);

    /// <summary>The grid that draws the row labelled <paramref name="label"/>, and its index there.</summary>
    private (JournalFactsGrid Grid, int Index)? FindRow(string label)
    {
        foreach (var (grid, texts) in new[] { (_knowledge, _shortTexts), (_knowledgeWide, _wideTexts) })
            for (int i = 0; i < texts.Length; i++)
                if (texts[i].StartsWith(label + " ", System.StringComparison.Ordinal)) return (grid, i);
        return null;
    }

    private string[] _shortTexts = System.Array.Empty<string>();
    private string[] _wideTexts = System.Array.Empty<string>();
    private JournalFactsGrid _knowledgeWide = null!;

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
        _knowledge = GetNode<JournalFactsGrid>("%KnowledgeGrid");
        _knowledgeWide = GetNode<JournalFactsGrid>("%KnowledgeWide");
        _callout = GetNode<Label>("%HiddenCallout");
        Visible = false;
    }

    private int _remaining, _max, _previewSpend;

    /// <summary>Hollow out the actions a hovered move or action would spend (0 clears). It holds
    /// across re-renders until the hover changes, since a hover also refreshes the card.</summary>
    public void PreviewSpend(int actions)
    {
        _previewSpend = actions;
        RenderPips();
    }

    public int PreviewedSpend => _max > 0 ? System.Math.Min(_previewSpend, _remaining) : 0;

    private void RenderPips()
    {
        if (_max > 0) _actionPips.SetActionEconomy(_remaining, _max, System.Math.Min(_previewSpend, _remaining));
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
        // The knowledge rows carry AC themselves, "???" included.
        _acLabel.Visible = !Masked(view.AcText) && view.KnowledgeRows.Count == 0;
        // Short values share a grid; a long one (a weakness list, the strikes) gets its own line,
        // so a revealed value never runs into the next column.
        var shortRows = view.KnowledgeRows.Where(r => !r.Wide).ToArray();
        var wideRows = view.KnowledgeRows.Where(r => r.Wide).ToArray();
        _knowledge.Visible = shortRows.Length > 0;
        _knowledge.Render(shortRows);
        _knowledgeWide.Visible = wideRows.Length > 0;
        _knowledgeWide.Render(wideRows);
        _shortTexts = shortRows.Select(r => r.Text).ToArray();
        _wideTexts = wideRows.Select(r => r.Text).ToArray();
        KnowledgeTexts = _shortTexts.Concat(_wideTexts).ToArray();
        _callout.Text = view.HiddenCallout;
        _callout.Visible = view.HiddenCallout.Length > 0 && view.KnowledgeRows.Any(r => !r.Known);
        _portrait.Texture = UnitPortraits.For(view.HeroId, view.SpriteFolder);
        _portraitFrame.ThemeTypeVariation = view.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;
        _levelLabel.Text = view.Level > 0 ? $"Lv {view.Level}" : "";
        _classLabel.Text = view.ClassName;
        _actionPips.Visible = view.MaxActions > 0;
        _remaining = view.ActionsRemaining;
        _max = view.MaxActions;
        RenderPips();
        _reactionSlot.Visible = view.Reaction != ReactionMark.None;
        _reaction.ThemeTypeVariation = view.Reaction == ReactionMark.Ready ? ThemeNames.ReactionReady : ThemeNames.ReactionSpent;
        _reactionSlot.TooltipText = ReactionTooltip;

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
