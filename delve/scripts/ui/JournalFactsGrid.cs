using System.Collections.Generic;
using Delve.Run;
using Godot;

namespace Delve.UI;

/// <summary>A species' journal fields as labelled values in columns. Known values read in body ink,
/// unknown ones ("AC ?") dim. Shared by the combat journal and the outpost bestiary.</summary>
public partial class JournalFactsGrid : GridContainer
{
    public void Render(IReadOnlyList<JournalFact> facts)
    {
        foreach (var child in GetChildren())
        {
            RemoveChild(child);
            child.QueueFree();
        }
        foreach (var fact in facts)
        {
            AddChild(new Label
            {
                Text = fact.Text,
                ThemeTypeVariation = fact.Known ? "" : ThemeNames.HintLabel,
                AutowrapMode = TextServer.AutowrapMode.WordSmart,
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
                MouseFilter = MouseFilterEnum.Ignore,
            });
        }
    }
}
