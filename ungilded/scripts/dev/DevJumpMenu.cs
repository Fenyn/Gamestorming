using Godot;
using Ungilded.Story;
using Ungilded.UI;

namespace Ungilded.Dev;

/// <summary>
/// Debug builds only, autoloaded: <see cref="InputNames.DevJump"/> opens a list of the title and
/// every Prologue beat. A beat loads a fresh Prologue scene that starts at it (the director
/// fast-forwards the beats before it). The tree is paused while the list shows, and the list
/// swallows the input it does not use.
/// </summary>
public partial class DevJumpMenu : CanvasLayer
{
    [Export(PropertyHint.File, "*.tscn")] public string PrologueScenePath { get; set; } = "";
    [Export(PropertyHint.File, "*.tscn")] public string TitleScenePath { get; set; } = "";

    /// <summary>A hidden button each beat's entry is copied from.</summary>
    [Export] public Button? BeatTemplate { get; set; }

    public bool IsOpen => Visible;

    private Container _entries = null!;
    private Button _title = null!;
    private PackedScene? _prologue;
    private bool _pausedBefore;
    private Control? _focusBefore;

    public override void _Ready()
    {
        if (!OS.IsDebugBuild())
        {
            QueueFree();
            return;
        }
        _entries = GetNode<Container>("%Entries");
        _title = GetNode<Button>("%Title");
        _title.Pressed += () => Jump(null);
        Hide();
    }

    public override void _Input(InputEvent e)
    {
        if (e.IsActionPressed(InputNames.DevJump))
        {
            if (Visible) Close();
            else Open();
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && e.IsActionPressed(InputNames.UiCancel))
        {
            Close();
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _UnhandledInput(InputEvent e)
    {
        if (Visible) GetViewport().SetInputAsHandled();
    }

    public void Open()
    {
        if (Visible) return;
        if (_prologue == null && !LoadBeats()) return;
        _pausedBefore = GetTree().Paused;
        _focusBefore = GetViewport().GuiGetFocusOwner();
        GetTree().Paused = true;
        Show();
        UiFocus.Grab(_title);
    }

    public void Close()
    {
        if (!Visible) return;
        Hide();
        GetTree().Paused = _pausedBefore;
        if (_focusBefore != null && IsInstanceValid(_focusBefore) && _focusBefore.IsVisibleInTree()) _focusBefore.GrabFocus();
        _focusBefore = null;
    }

    /// <summary>Load the Prologue scene and add one button per beat. False when it does not load.</summary>
    private bool LoadBeats()
    {
        _prologue = ResourceLoader.Load<PackedScene>(PrologueScenePath);
        if (BeatTemplate == null || _prologue?.Instantiate() is not PrologueDirector director)
        {
            GD.PushError($"[DevJump] BeatTemplate is not set or {PrologueScenePath} has no PrologueDirector root.");
            _prologue = null;
            return false;
        }
        for (int i = 0; i < director.Beats.Count; i++)
        {
            int beat = i;
            var button = (Button)BeatTemplate.Duplicate();
            button.Text = $"{i}  {Label(director.Beats[i])}";
            button.Visible = true;
            button.Pressed += () => Jump(beat);
            _entries.AddChild(button);
        }
        director.Free();
        return true;
    }

    private static string Label(PrologueBeat beat) =>
        beat.Kind == BeatKind.Encounter ? $"Encounter {beat.Encounter}" : beat.Sequence?.Id ?? beat.Describe();

    /// <summary>Load the title (null) or a fresh Prologue that starts at <paramref name="beat"/>.</summary>
    private void Jump(int? beat)
    {
        _pausedBefore = false;
        _focusBefore = null;
        Close();
        PauseMenu.Instance?.Close();
        if (beat is not { } start)
        {
            GetTree().ChangeSceneToFile(TitleScenePath);
            return;
        }
        var director = _prologue!.Instantiate<PrologueDirector>();
        director.StartBeat = start;
        GetTree().ChangeSceneToNode(director);
    }
}
