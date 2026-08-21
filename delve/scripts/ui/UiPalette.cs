using Godot;

namespace Delve.UI;

/// <summary>
/// Garrison-fixture UI palette (weathered ashlar, strap iron, bronze fittings, oiled timber):
/// the single code-side home for the color literals that mirror <c>assets/ui/ui_theme.tres</c>
/// (the .tres owns the authored styleboxes; these are the values scripts tint dynamic elements
/// with — keep them visually in step with the theme).
///
/// Contrast rules (keep new colors honest, target WCAG >= 4.5:1 for body text):
///  - Every themed surface is DARK, so text is the bone ramp (Cream / Parchment) and every
///    accent color here is a LIGHT one. The stone field sits at 0.036 relative luminance and
///    the inner recess at 0.013, so a color needs L >= 0.23 to clear 4.5:1 on either.
///  - InkDark is the one dark text color left, and only for text on the bronze active chip
///    (7.7:1 there); it is unreadable on anything else in this theme.
///  - Text floating over the 3D scene uses the FloatingLabel/WoodLabel variations, which carry
///    a near-black outline — no bone color is safe over open ground without one.
///  - Never communicate "disabled" by dimming a container's Modulate; use the themed
///    disabled styles so text stays readable.
/// </summary>
public static class UiPalette
{
    /// <summary>Aged bronze: available action pips, the active turn-order chip.</summary>
    public static readonly Color Gold = new(0.871f, 0.722f, 0.376f);

    /// <summary>Dark iron: spent pips, inactive chip borders.</summary>
    public static readonly Color DarkWood = new(0.161f, 0.165f, 0.184f);

    /// <summary>Bone-bright: the active chip's border.</summary>
    public static readonly Color Parchment = new(0.918f, 0.898f, 0.827f);

    /// <summary>Aged bone text on iron-toned chips.</summary>
    public static readonly Color Cream = new(0.949f, 0.91f, 0.827f);

    /// <summary>Dark ink text on the bronze active chip (7.7:1 on bronze).</summary>
    public static readonly Color InkDark = new(0.231f, 0.141f, 0.086f);

    /// <summary>Ally (team 1) moss-green chip fill.</summary>
    public static readonly Color AllyGreen = new(0.376f, 0.427f, 0.259f);

    /// <summary>Enemy (team 2) rust chip fill.</summary>
    public static readonly Color EnemyRed = new(0.482f, 0.263f, 0.196f);

    // HP bar fill tint by remaining-HP ratio. These triple as TEXT colors (encumbrance
    // warnings, crafting shortfalls), so all three are the light ends of their hues: the
    // former mid-tones cleared 4.5:1 on vellum and fell to 2.7:1 on stone.
    public static readonly Color HpGreen = new(0.451f, 0.71f, 0.365f);
    public static readonly Color HpAmber = new(0.851f, 0.663f, 0.298f);
    public static readonly Color HpRed = new(0.851f, 0.396f, 0.333f);

    // Victory banner results (outlined, floating over the scene).
    public static readonly Color VictoryGold = new(0.933f, 0.816f, 0.396f);
    public static readonly Color DefeatRed = new(0.878f, 0.443f, 0.412f);

    /// <summary>
    /// Combat-log entry colors indexed by PF2e.Core.CombatLogSeverity ordinal (kept as ints so the
    /// log Control stays engine-free). The log rides the InnerPanel recess (relative luminance
    /// 0.013), so every entry is the LIGHT end of its hue and clears 4.5:1 there — verify before
    /// changing. Hue still does the sorting; value only keeps them all readable.
    /// </summary>
    public static readonly Color[] LogSeverity =
    {
        new(0.80f, 0.78f, 0.72f),  // Info — bone grey (11.9:1)
        new(0.545f, 0.804f, 0.475f), // Hit — light green (8.9:1)
        new(0.902f, 0.769f, 0.373f), // CriticalHit — bright bronze (9.4:1)
        new(0.647f, 0.635f, 0.549f), // Miss — muted khaki (7.3:1)
        new(0.902f, 0.463f, 0.404f), // CriticalMiss — light rust (5.7:1)
        new(0.435f, 0.816f, 0.706f), // Healing — light teal (9.4:1)
        new(0.769f, 0.588f, 0.882f), // ConditionApplied — light plum (7.0:1)
        new(0.643f, 0.635f, 0.612f), // ConditionRemoved — grey (7.3:1)
        new(0.898f, 0.729f, 0.494f), // ActionHeader — amber (9.0:1)
        new(0.949f, 0.635f, 0.376f), // Reaction — burnt orange (7.6:1)
    };

    /// <summary>Green→amber→red HP fill/text tint by remaining-HP ratio (0..1). Shared by every
    /// spot that colors a value by HP fraction (squad panel, action bar vitals, unit inspect).</summary>
    public static Color HpFillColor(float ratio)
        => ratio > 0.5f ? HpGreen : ratio > 0.25f ? HpAmber : HpRed;
}
