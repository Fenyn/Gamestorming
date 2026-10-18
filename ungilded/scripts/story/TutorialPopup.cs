using System;
using System.Threading.Tasks;
using Godot;
using Ungilded.Autoload;

namespace Ungilded.Story;

/// <summary>
/// Modal tutorial panel: BBCode text and one Continue button. <see cref="ShowMessage"/> returns a
/// task that completes when the player dismisses that message. Messages sent while one shows queue
/// behind it. While open it holds a <see cref="ModalStack"/> entry and swallows clicks to the board.
/// </summary>
public partial class TutorialPopup : CanvasLayer
{
    /// <summary>True when the first message opens the panel, false when the last one closes it.</summary>
    public event Action<bool>? ShowingChanged;

    public bool IsShowing { get; private set; }

    /// <summary>The ember accent from the story theme, for highlighted words.</summary>
    public Color HighlightColor => _root.GetThemeColor(EmberColor, StoryPaletteType);

    private const string StoryPaletteType = "StoryPalette";
    private const string EmberColor = "ember";

    private Control _root = null!;
    private RichTextLabel _text = null!;
    private Button _continue = null!;
    private Task _tail = Task.CompletedTask;
    private TaskCompletionSource? _dismissed;
    private int _queued;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _text = GetNode<RichTextLabel>("%Text");
        _continue = GetNode<Button>("%Continue");
        _root.Visible = false;
        _continue.Pressed += Dismiss;
    }

    /// <summary>Show <paramref name="bbcode"/> after any queued message. Completes on dismiss.</summary>
    public Task ShowMessage(string bbcode)
    {
        _queued++;
        var run = ShowAfter(_tail, bbcode);
        _tail = run;
        return run;
    }

    /// <summary>Wrap <paramref name="text"/> in a BBCode colour tag with <see cref="HighlightColor"/>.</summary>
    public string Highlight(string text) => $"[color=#{HighlightColor.ToHtml(false)}]{text}[/color]";

    /// <summary>Close the current message, as the Continue button does.</summary>
    public void Dismiss()
    {
        var done = _dismissed;
        _dismissed = null;
        done?.TrySetResult();
    }

    private async Task ShowAfter(Task previous, string bbcode)
    {
        await previous;
        var done = new TaskCompletionSource();
        _dismissed = done;
        _text.Text = bbcode;
        Open();
        _continue.GrabFocus();
        await done.Task;
        _queued--;
        if (_queued == 0) Close();
    }

    private void Open()
    {
        if (IsShowing) return;
        IsShowing = true;
        _root.Visible = true;
        ModalStack.Instance?.Push(this);
        ShowingChanged?.Invoke(true);
    }

    private void Close()
    {
        if (!IsShowing) return;
        IsShowing = false;
        _root.Visible = false;
        ModalStack.Instance?.Pop(this);
        ShowingChanged?.Invoke(false);
    }
}
