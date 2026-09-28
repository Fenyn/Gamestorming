using Godot;
using System.Linq;
using System.Text.RegularExpressions;

namespace Delve.UI;

/// <summary>The settled row: die, total vs target, outcome, then the die and its modifiers, and a thin
/// copy of the degree track once the defence is known.</summary>
public partial class DiceRollPanel
{
    /// <summary>Font size of the two numbers that decide the roll: the total and the target it meets.</summary>
    [Export] public int SumFontSize { get; set; } = 36;
    /// <summary>Font size of the arithmetic around them ("19 +10", "vs").</summary>
    [Export] public int SumDetailFontSize { get; set; } = 18;
    [Export] public ConditionIconSet? Icons { get; set; }
    /// <summary>The condition icon beside a named modifier: the pack's 22 px art at 1x.</summary>
    [Export] public int AppliedIconSize { get; set; } = 22;

    /// <summary>The detail arithmetic as drawn, named modifiers included.</summary>
    public string DetailText => Plain(_detail.GetParsedText() + (_applied.Visible ? "\n" + _applied.GetParsedText() : ""));

    /// <summary>Every row text is in place from the start of a beat; the beat only reveals it.</summary>
    private void FillRow(CombatRoll roll)
    {
        _die.Text = roll.Die.ToString();
        RollTone.PaintFace(_die, roll.Die);
        _outline.Rotation = 0;
        string dim = UiColors.TextDim.ToHtml();
        string Detail(string text) => $"[font_size={SumDetailFontSize}][color=#{dim}]{text}[/color][/font_size]";
        string Big(string number, Color colour) =>
            $"[font_size={SumFontSize}][b][color=#{colour.ToHtml()}]{number}[/color][/b][/font_size]";
        _math.Text = $"{Big(roll.Total.ToString(), RollTone.For(roll))} {Detail("vs")} {Big(roll.DcText, UiColors.Text)}";
        _detail.Text = $"[font_size={SumDetailFontSize}]{Detail(roll.Die.ToString())} {FormatAdjustments(roll)}[/font_size]";
        _outcome.Text = roll.Outcome;
        _applied.Text = $"[font_size={SumDetailFontSize}]{FormatApplied(roll, Icons, AppliedIconSize)}[/font_size]";
        if (_applied.GetContentWidth() > AppliedRoom())
            _applied.Text = $"[font_size={SumDetailFontSize}]{FormatApplied(roll, Icons, AppliedIconSize, compact: true)}[/font_size]";
        _applied.Visible = !roll.Breakdown.IsEmpty;
        RollTone.Paint(_outcome, RollTone.For(roll));
        _rowTrack.Visible = !roll.DcMasked;
        _rowTrack.Configure(roll.DC, roll.IsAttack, roll.EnemyRoll);
        _rowTrack.MarkerValue = roll.Total;
        _rowTrack.LitZone = roll.DegreeIndex;
        ShowSettledRow();
    }

    /// <summary>Width the named line may take before the row passes its minimum width.</summary>
    private float AppliedRoom()
    {
        int gap = _row.GetThemeConstant("separation");
        return CustomMinimumSize.X - GetThemeStylebox("panel").GetMinimumSize().X - 3 * gap
            - _face.GetCombinedMinimumSize().X - _math.GetContentWidth() - _outcome.GetMinimumSize().X;
    }

    private void ShowSettledRow()
    {
        foreach (var node in new CanvasItem[] { _math, _detail, _applied, _outcome, _rowTrack })
            node.Modulate = node.Modulate with { A = 1 };
        foreach (var node in new Control[] { _face, _outcome })
            node.Scale = Vector2.One;
        SetRowAlpha(1, 1);
    }

    private void HideRow() => SetRowAlpha(0, 0);

    /// <summary>The panel chrome and the row content fade separately from the whole node, whose alpha
    /// belongs to the final fade.</summary>
    private void SetRowAlpha(float panel, float content)
    {
        SelfModulate = SelfModulate with { A = panel };
        _row.Modulate = _row.Modulate with { A = content };
        _rowTrack.SelfModulate = _rowTrack.SelfModulate with { A = content };
    }

    /// <summary>Color signed adjustments supplied by the roll feed. Preserve their names and signs;
    /// never infer a named condition from an unexplained difference in the final total.</summary>
    internal static string FormatAdjustments(CombatRoll roll)
    {
        int reported = roll.Breakdown.Roll.Sum(m => m.Value);
        string text = Regex.Replace(CombatLogFormat.Escape(roll.Modifiers), @"[+-]\d+", match =>
        {
            if (!int.TryParse(match.Value, out int value)) return match.Value;
            reported += value;
            var color = value < 0 ? UiColors.HpLow : UiColors.HpHigh;
            return $"[color=#{color.ToHtml()}]{match.Value}[/color]";
        });
        int remaining = roll.Total - roll.Die - reported;
        if (remaining != 0)
        {
            var color = remaining < 0 ? UiColors.HpLow : UiColors.HpHigh;
            text += $" · Other [color=#{color.ToHtml()}]{remaining:+0;-0;0}[/color]";
        }
        return $"[color=#{UiColors.TextDim.ToHtml()}]{text}[/color]";
    }

    /// <summary>The named modifiers in the forecast's order: the roller's ("Prone -2"), then the
    /// defence's ("AC -1"). A condition's icon names a defence entry; any other source keeps its label.
    /// The compact form, for a row with no room, lets the icon name the roller's entries too.</summary>
    internal static string FormatApplied(CombatRoll roll, ConditionIconSet? icons, int iconSize, bool compact = false)
    {
        string defense = roll.IsAttack ? "AC" : "DC";
        var parts = roll.Breakdown.Roll.Select(m => Entry(m, compact && m.IconKey.Length > 0 ? "" : m.Label, icons, iconSize))
            .Concat(roll.Breakdown.Defense.Select(m => Entry(m, m.IconKey.Length > 0 ? defense : $"{m.Label} {defense}", icons, iconSize)));
        return string.Join("  ", parts);
    }

    private static string Entry(Delve.Combat.ModifierChip modifier, string label, ConditionIconSet? icons, int iconSize)
    {
        string icon = modifier.IconKey.Length > 0 && icons?.Tile(modifier.IconKey) is { ResourcePath.Length: > 0 } texture
            ? $"[img={iconSize}x{iconSize}]{texture.ResourcePath}[/img]" : "";
        var color = modifier.Value < 0 ? UiColors.HpLow : UiColors.HpHigh;
        string name = label.Length == 0 ? ""
            : $"[color=#{UiColors.TextDim.ToHtml()}]{CombatLogFormat.Escape(label).Replace(' ', NoBreak)}[/color]{NoBreak}";
        return $"{icon}{name}[color=#{color.ToHtml()}]{modifier.Value:+0;-0}[/color]";
    }

    /// <summary>Keeps one named modifier on one line when the detail wraps.</summary>
    private const char NoBreak = ' ';

    internal static string Plain(string parsed) => parsed.Replace(NoBreak, ' ');
}
