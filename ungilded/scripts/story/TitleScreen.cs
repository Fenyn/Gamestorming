using Godot;

namespace Ungilded.Story;

/// <summary>Title screen: the title art, Prologue and Quit.</summary>
public partial class TitleScreen : Control
{
    /// <summary>Scene the Prologue button loads.</summary>
    [Export(PropertyHint.File, "*.tscn")] public string PrologueScenePath { get; set; } = "";

    private Button _prologue = null!;

    public override void _Ready()
    {
        _prologue = GetNode<Button>("%Prologue");
        _prologue.Pressed += StartPrologue;
        GetNode<Button>("%Quit").Pressed += Quit;
        _prologue.GrabFocus();
    }

    public void StartPrologue()
    {
        if (PrologueScenePath.Length == 0)
        {
            GD.PushError("[Title] PrologueScenePath is not set.");
            return;
        }
        GetTree().ChangeSceneToFile(PrologueScenePath);
    }

    private void Quit() => GetTree().Quit();
}
