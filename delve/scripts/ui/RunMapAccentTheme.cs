using Godot;

namespace Delve.UI;

/// <summary>Builds a map-local theme without changing the shared UI theme or semantic colors.</summary>
public partial class RunMapAccentTheme : Resource
{
    [Export] public Texture2D PanelTexture { get; set; } = null!;
    [Export] public float PanelNeutralMix { get; set; } = 0.45f;
    [Export] public float ButtonFillStrength { get; set; } = 0.28f;
    [Export] public float ButtonHoverStrength { get; set; } = 0.38f;
    [Export] public float ButtonPressedStrength { get; set; } = 0.20f;
    [Export] public float RestPreviewStrength { get; set; } = 0.35f;

    public Theme Build(Theme source, Color accent)
    {
        var theme = (Theme)source.Duplicate();
        foreach (string type in new[] { "MapFrame", "MapSidebarPanel", "MapRecoveryPanel", "MapWardPanel" })
        {
            var panel = (StyleBoxTexture)source.GetStylebox("panel", type).Duplicate();
            panel.Texture = PanelTexture;
            panel.ModulateColor = type == "MapWardPanel" ? accent : accent.Lerp(Colors.White, PanelNeutralMix);
            theme.SetStylebox("panel", type, panel);
        }

        var ground = ((StyleBoxFlat)source.GetStylebox("panel", "MapGround")).BgColor;
        foreach (var (state, strength) in new[] {
            ("normal", ButtonFillStrength), ("hover", ButtonHoverStrength),
            ("pressed", ButtonPressedStrength), ("focus", ButtonFillStrength) })
        {
            var button = (StyleBoxFlat)source.GetStylebox(state, "MapRestButton").Duplicate();
            button.BgColor = ground.Lerp(accent, strength);
            button.BorderColor = accent;
            theme.SetStylebox(state, "MapRestButton", button);
        }
        foreach (var (state, color) in new[] { ("fill", accent), ("background", ground) })
        {
            var bar = (StyleBoxFlat)source.GetStylebox(state, "MapWardBar").Duplicate();
            bar.BgColor = color;
            theme.SetStylebox(state, "MapWardBar", bar);
        }
        var spent = (StyleBoxFlat)source.GetStylebox("fill", "MapWardBar").Duplicate();
        spent.BgColor = ground.Lerp(accent, RestPreviewStrength);
        theme.SetStylebox("panel", "MapWardRestSegment", spent);
        theme.SetColor("font_color", "MapWardPreviewValue", accent.Lerp(Colors.White, PanelNeutralMix));
        return theme;
    }
}
