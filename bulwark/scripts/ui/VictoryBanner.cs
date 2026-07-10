using Godot;

namespace Bulwark.UI;

/// <summary>
/// End-of-encounter overlay: a dimmed full-screen banner with a result headline and a Restart
/// button that reloads the current scene. Passive — <c>CombatScene</c> calls <see cref="ShowResult"/>
/// with a pre-formatted string + color; this holds no game rules and no engine types.
/// </summary>
public partial class VictoryBanner : Control
{
    private Label _label = null!;

    public override void _Ready()
    {
        _label = GetNode<Label>("%VictoryLabel");
        GetNode<Button>("%RestartButton").Pressed += () => GetTree().ReloadCurrentScene();
        Visible = false;
    }

    /// <summary>Display the banner with the given headline and headline color.</summary>
    public void ShowResult(string text, Color color)
    {
        _label.Text = text;
        _label.AddThemeColorOverride("font_color", color);
        Visible = true;
    }
}
