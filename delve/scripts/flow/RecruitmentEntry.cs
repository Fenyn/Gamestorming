using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

public partial class RecruitmentEntry : Button
{
    public string CharacterId { get; private set; } = "";
    public void ShowProgress(RecruitmentArc arc, CampaignProgress campaign)
    {
        CharacterId = arc.CharacterId;
        Text = $"{CharacterCatalog.Find(CharacterId)?.DisplayName}\n{RecruitmentPanel.StatusFor(arc, campaign)}";
        TooltipText = arc.Title;
        foreach (string state in new[] { "font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color" })
            AddThemeColorOverride(state, UiColors.CharacterAccent(CharacterId));
    }
}
