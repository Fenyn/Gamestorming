namespace Delve.UI;

/// <summary>
/// String consts for the theme type variations that scripts assign at runtime. Typos in variation
/// names fail silently to the base style, so no literal variation strings in scripts — always
/// reference through this class. Variations only ever set in .tscn files are not listed here; the
/// scene is their single reference.
/// </summary>
public static class ThemeNames
{
    public const string AccentButton = "AccentButton";
    public const string MapNode = "MapNode";
    public const string Keycap = "Keycap";
    public const string ChipLabel = "ChipLabel";
    public const string HintLabel = "HintLabel";
    public const string PipFilled = "PipFilled";
    public const string PipSpent = "PipSpent";
    public const string PipDisabled = "PipDisabled";
    public const string TurnChipAlly = "TurnChipAlly";
    public const string TurnChipEnemy = "TurnChipEnemy";
    public const string TurnChipActive = "TurnChipActive";
    public const string HpBarAlly = "HpBarAlly";
    public const string HpBarEnemy = "HpBarEnemy";
    public const string HpBarHigh = "HpBarHigh";
    public const string HpBarMid = "HpBarMid";
    public const string HpBarLow = "HpBarLow";
    public const string RosterCard = "RosterCard";
    public const string RosterCardSelected = "RosterCardSelected";
    public const string RosterCardLocked = "RosterCardLocked";
    public const string CardRoleLabel = "CardRoleLabel";
    public const string HudInset = "HudInset";
    public const string SheetBoxKey = "SheetBoxKey";
    public const string SheetKeyValue = "SheetKeyValue";
    public const string SheetValue = "SheetValue";
    public const string StatChip = "StatChip";
    public const string TipTag = "TipTag";
    public const string TipMetaLabel = "TipMetaLabel";
    public const string TipBody = "TipBody";
    public const string SheetBoxHeadline = "SheetBoxHeadline";
    public const string RuleAccent = "RuleAccent";
    public const string RuleLine = "RuleLine";
    public const string RowLabel = "RowLabel";
    public const string SheetCaption = "SheetCaption";
    public const string SheetCaptionSmall = "SheetCaptionSmall";
    public const string TraitChip = "TraitChip";
    public const string TipFooter = "TipFooter";

    /// <summary>HP-bar variation for a remaining-HP ratio — same 0.5 / 0.25 thresholds as
    /// <see cref="UiColors.HpFillColor"/>.</summary>
    public static string HpBarFor(float ratio)
        => ratio > 0.5f ? HpBarHigh : ratio > 0.25f ? HpBarMid : HpBarLow;
}
