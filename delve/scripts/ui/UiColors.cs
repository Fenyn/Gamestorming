using Delve.Run;
using Godot;

namespace Delve.UI;

/// <summary>
/// Code-side access to the palette authored in <c>assets/ui/ui_theme.tres</c> (synthetic theme
/// type "Palette"). The .tres is the single source of color truth; scripts tint dynamic elements
/// through this class and never carry color literals. Lazy-loaded — call only from _Ready/render
/// paths, never a static initializer (the theme resource may not be importable yet during
/// engine-side static setup).
/// </summary>
public static class UiColors
{
    private const string ThemePath = "res://assets/ui/ui_theme.tres";
    private const string PaletteType = "Palette";

    private static Theme? _theme;

    private static Theme PaletteTheme => _theme ??= GD.Load<Theme>(ThemePath);

    private static Color Get(string name) => PaletteTheme.GetColor(name, PaletteType);

    /// <summary>Gold: active states, accent strips, default buttons, available pips.</summary>
    public static Color Accent => Get("accent");

    /// <summary>
    /// One character's personal accent, keyed by catalog id, for the identity touches the
    /// hero-select surfaces carry (portrait strip, name rule, roster strip). Unknown ids take
    /// the base accent, so a new character is never colourless.
    /// </summary>
    public static Color CharacterAccent(string id) => id switch
    {
        "player" => Get("char_player"),
        "elara" => Get("char_elara"),
        "tharr" => Get("char_tharr"),
        "fenwick" => Get("char_fenwick"),
        _ => Accent,
    };

    /// <summary>Identity color of a run-map node kind: the icon tint on the map and the legend.</summary>
    public static Color NodeKindColor(NodeKind kind) => kind switch
    {
        NodeKind.Combat => Get("node_combat"),
        NodeKind.Elite => Get("node_elite"),
        NodeKind.Event => Get("node_event"),
        NodeKind.Rest => Get("node_rest"),
        NodeKind.Boss => Get("node_boss"),
        NodeKind.Shop => Get("node_shop"),
        NodeKind.Treasure => Get("node_treasure"),
        _ => Get("text"),
    };

    /// <summary>Ground tone of a floor's map backdrop, keyed by <c>FloorTheme.Id</c>. Unknown ids
    /// take the first floor's tones, so a new stratum is never colourless.</summary>
    public static Color MapBase(string themeId) => themeId switch
    {
        "deepforest" => Get("map_base_deepforest"),
        "swamp" => Get("map_base_swamp"),
        _ => Get("map_base_grassland"),
    };

    /// <summary>Fog tint of a floor's map backdrop, keyed by <c>FloorTheme.Id</c>.</summary>
    public static Color MapFog(string themeId) => themeId switch
    {
        "deepforest" => Get("map_fog_deepforest"),
        "swamp" => Get("map_fog_swamp"),
        _ => Get("map_fog_grassland"),
    };

    /// <summary>Fill of a run-map medallion.</summary>
    public static Color NodeFace => Get("node_face");

    /// <summary>Fill of a hovered run-map medallion.</summary>
    public static Color NodeFaceHover => Get("node_face_hover");

    /// <summary>Ally (team 1) identity color.</summary>
    public static Color Ally => Get("ally");

    /// <summary>Enemy (team 2) identity color.</summary>
    public static Color Enemy => Get("enemy");

    /// <summary>Near-black: text outlines over open ground, deepest fills.</summary>
    public static Color Ink => Get("ink");

    /// <summary>Standard translucent panel field.</summary>
    public static Color Surface => Get("surface");

    /// <summary>Recessed sub-panel field (ticker, preview card, tooltips).</summary>
    public static Color Inset => Get("inset");

    /// <summary>1 px borders and separators.</summary>
    public static Color Line => Get("line");

    /// <summary>Body text.</summary>
    public static Color Text => Get("text");

    /// <summary>Secondary text, detail log entries.</summary>
    public static Color TextDim => Get("text_dim");

    /// <summary>Disabled control text.</summary>
    public static Color TextDisabled => Get("text_disabled");

    /// <summary>Dark text on accent fills (active turn chip, accent buttons).</summary>
    public static Color TextInverse => Get("text_inverse");

    /// <summary>HP fill/text at ratio &gt; 0.5.</summary>
    public static Color HpHigh => Get("hp_high");

    /// <summary>HP fill/text at ratio &gt; 0.25.</summary>
    public static Color HpMid => Get("hp_mid");

    /// <summary>HP fill/text at ratio &lt;= 0.25.</summary>
    public static Color HpLow => Get("hp_low");

    /// <summary>Victory banner headline.</summary>
    public static Color Victory => Get("victory");

    /// <summary>Defeat banner headline.</summary>
    public static Color Defeat => Get("defeat");

    /// <summary>Full-screen backdrop behind modals.</summary>
    public static Color ModalDim => Get("modal_dim");

    private static Color[]? _logSeverity;

    /// <summary>
    /// Combat-log entry colors indexed by PF2e.Core.CombatLogSeverity ordinal (kept as ints so the
    /// log Control stays engine-free). Order must match the engine enum: Info, Hit, CriticalHit,
    /// Miss, CriticalMiss, Healing, ConditionApplied, ConditionRemoved, ActionHeader, Reaction.
    /// </summary>
    public static Color[] LogSeverity => _logSeverity ??= new[]
    {
        Get("log_info"),
        Get("log_hit"),
        Get("log_crit_hit"),
        Get("log_miss"),
        Get("log_crit_miss"),
        Get("log_healing"),
        Get("log_condition_applied"),
        Get("log_condition_removed"),
        Get("log_action_header"),
        Get("log_reaction"),
    };

    /// <summary>Green→amber→red HP fill/text tint by remaining-HP ratio (0..1). Shared by every
    /// spot that colors a value by HP fraction (action bar vitals, unit inspect).</summary>
    public static Color HpFillColor(float ratio)
        => ratio > 0.5f ? HpHigh : ratio > 0.25f ? HpMid : HpLow;
}
