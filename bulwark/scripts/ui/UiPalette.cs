using Godot;

namespace Bulwark.UI;

/// <summary>
/// Weathered combat-UI palette (rugged fantasy outpost: aged vellum, dark timber, oxblood accent,
/// brass highlights): the single code-side home for the color literals that mirror
/// <c>assets/ui/ui_theme.tres</c> (the .tres owns the authored styleboxes; these are the values
/// scripts tint dynamic elements with — keep them visually in step with the theme).
///
/// Contrast rules (keep new colors honest, target WCAG >= 4.5:1 for body text):
///  - Text on parchment surfaces uses the dark ink ramp (InkDark / LogSeverity).
///  - Text on wood panels or floating over the 3D scene uses Cream WITH a dark outline
///    (theme variations WoodLabel / FloatingLabel) — plain cream-on-wood is under 4.5:1
///    and is not enough on its own.
///  - Never communicate "disabled" by dimming a container's Modulate; use the themed
///    disabled styles so text stays readable.
/// </summary>
public static class UiPalette
{
    /// <summary>Aged brass: available action pips, the active turn-order chip.</summary>
    public static readonly Color Gold = new(0.871f, 0.722f, 0.376f);

    /// <summary>Dark iron-timber: spent pips, inactive chip borders.</summary>
    public static readonly Color DarkWood = new(0.251f, 0.18f, 0.125f);

    /// <summary>Vellum-bright: the active chip's border.</summary>
    public static readonly Color Parchment = new(0.914f, 0.847f, 0.718f);

    /// <summary>Aged bone text on wood-toned chips.</summary>
    public static readonly Color Cream = new(0.949f, 0.91f, 0.827f);

    /// <summary>Dark ink text on the brass active chip (7.7:1 on brass).</summary>
    public static readonly Color InkDark = new(0.231f, 0.141f, 0.086f);

    /// <summary>Ally (team 1) moss-green chip fill.</summary>
    public static readonly Color AllyGreen = new(0.376f, 0.427f, 0.259f);

    /// <summary>Enemy (team 2) rust chip fill.</summary>
    public static readonly Color EnemyRed = new(0.482f, 0.263f, 0.196f);

    // HP bar fill tint by remaining-HP ratio.
    public static readonly Color HpGreen = new(0.357f, 0.545f, 0.267f);
    public static readonly Color HpAmber = new(0.78f, 0.58f, 0.22f);
    public static readonly Color HpRed = new(0.647f, 0.247f, 0.176f);

    // Victory banner results (outlined, floating over the scene).
    public static readonly Color VictoryGold = new(0.933f, 0.816f, 0.396f);
    public static readonly Color DefeatRed = new(0.878f, 0.443f, 0.412f);

    /// <summary>
    /// Combat-log entry colors indexed by PF2e.Core.CombatLogSeverity ordinal (kept as ints so the
    /// log Control stays engine-free). Every entry is tuned to >= 4.5:1 contrast on the
    /// weathered-vellum log panel (bg 0.867/0.800/0.659) — verify before changing.
    /// </summary>
    public static readonly Color[] LogSeverity =
    {
        new(0.29f, 0.22f, 0.15f),  // Info — dark brown (7.0:1)
        new(0.16f, 0.36f, 0.11f),  // Hit — green (5.0:1)
        new(0.45f, 0.30f, 0.02f),  // CriticalHit — deep gold (4.8:1)
        new(0.36f, 0.30f, 0.20f),  // Miss — muted khaki (5.2:1)
        new(0.54f, 0.19f, 0.14f),  // CriticalMiss — red-brown (5.2:1)
        new(0.11f, 0.35f, 0.25f),  // Healing — teal-green (5.2:1)
        new(0.40f, 0.23f, 0.52f),  // ConditionApplied — plum (5.2:1)
        new(0.37f, 0.32f, 0.25f),  // ConditionRemoved — gray-brown (4.8:1)
        new(0.46f, 0.29f, 0.08f),  // ActionHeader — amber-brown (4.8:1)
        new(0.52f, 0.25f, 0.06f),  // Reaction — burnt orange (4.9:1)
    };
}
