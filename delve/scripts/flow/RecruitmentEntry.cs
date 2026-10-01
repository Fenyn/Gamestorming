using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>One unlock-journal tile: the traveler's portrait and name. A traveler not met yet shows a
/// dark silhouette of the portrait; the name stays, as the journal design lists every traveler.</summary>
public partial class RecruitmentEntry : Button
{
    /// <summary>The tallest the portrait may draw inside the tile.</summary>
    [Export] public int PortraitHeight { get; set; } = 96;

    public string CharacterId { get; private set; } = "";
    public string Status { get; private set; } = "";
    private Color _tint;

    public override void _Ready() => _tint = GetNode<TextureRect>("%Portrait").SelfModulate;

    public void ShowProgress(RecruitmentArc arc, CampaignProgress campaign, bool met)
    {
        CharacterId = arc.CharacterId;
        Status = RecruitmentPanel.StatusFor(arc, campaign);
        var name = GetNode<Label>("%EntryName");
        name.Text = CharacterCatalog.Find(CharacterId)?.DisplayName ?? CharacterId;
        TooltipText = $"{Status}: {arc.Title}";
        var portrait = GetNode<TextureRect>("%Portrait");
        var texture = HeroPortraits.For(CharacterId);
        portrait.Texture = texture;
        portrait.CustomMinimumSize = texture == null ? Vector2.Zero : texture.GetSize() * BestiaryPanel.WholeScale(texture, PortraitHeight);
        portrait.SelfModulate = met ? _tint : UiColors.Ink;
        name.ThemeTypeVariation = met ? "" : ThemeNames.HintLabel;
    }
}
