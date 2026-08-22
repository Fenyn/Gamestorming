namespace Delve.UI;

/// <summary>
/// String consts for every theme type variation that scripts assign at runtime. Typos in
/// variation names fail silently to the base style, so no literal variation strings in scripts —
/// always reference through this class.
/// </summary>
public static class ThemeNames
{
    public const string HudPanel = "HudPanel";
    public const string HudInset = "HudInset";
    public const string Keycap = "Keycap";
    public const string ModalPanel = "ModalPanel";
    public const string ModalDim = "ModalDim";
    public const string AccentStrip = "AccentStrip";
    public const string AccentButton = "AccentButton";
    public const string ActionChip = "ActionChip";
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
    public const string HintLabel = "HintLabel";
    public const string HeadingLabel = "HeadingLabel";
    public const string TitleLabel = "TitleLabel";
    public const string BannerLabel = "BannerLabel";
    public const string FloatingLabel = "FloatingLabel";

    /// <summary>HP-bar variation for a remaining-HP ratio — same 0.5 / 0.25 thresholds as
    /// <see cref="UiColors.HpFillColor"/>.</summary>
    public static string HpBarFor(float ratio)
        => ratio > 0.5f ? HpBarHigh : ratio > 0.25f ? HpBarMid : HpBarLow;
}
