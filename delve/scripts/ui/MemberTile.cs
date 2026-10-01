using Godot;

namespace Delve.UI;

/// <summary>One party member in a screen header: face, name and one status line ("HP 26/26",
/// "Wounded 1", "Fighter · front line"). The status line turns to the warning style when it
/// reports something the player should act on.</summary>
public partial class MemberTile : Button
{
    public string MemberId { get; private set; } = "";

    public void Show(string id, string name, string line, bool alert)
    {
        MemberId = id;
        GetNode<TextureRect>("%Face").Texture = id.Length > 0 ? HeroPortraits.Face(id) : null;
        GetNode<Label>("%MemberName").Text = name;
        var status = GetNode<Label>("%MemberLine");
        status.Text = line;
        status.ThemeTypeVariation = alert ? ThemeNames.MemberAlert : ThemeNames.HintLabel;
        TooltipText = $"{name}  {line}";
    }
}
