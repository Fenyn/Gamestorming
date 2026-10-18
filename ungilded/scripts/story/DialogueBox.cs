using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;
using Ungilded.Autoload;

namespace Ungilded.Story;

/// <summary>
/// FFT-style dialogue box along the bottom of the screen. Each line shows the speaker's portrait
/// for its <see cref="Emotion"/> on the speaker's side, a name plate and a typewriter reveal.
/// Narration lines show no portrait or name and render in italics. A click, Enter or Space first
/// completes the reveal, then advances. Calls made while a sequence plays queue behind it.
/// While open it holds a <see cref="ModalStack"/> entry and swallows clicks to the board.
/// </summary>
public partial class DialogueBox : CanvasLayer
{
    /// <summary>One entry per speaker. A speaker with no entry shows no portrait.</summary>
    [Export] public Array<SpeakerPortraits> Portraits { get; set; } = new();

    [Export] public float CharactersPerSecond { get; set; } = 40f;

    /// <summary>True when the box opens, false when the last queued line closes it.</summary>
    public event Action<bool>? ShowingChanged;

    /// <summary>Fires as each line starts, after its text and portrait are set.</summary>
    public event Action<DialogueLine>? LineStarted;

    public bool IsShowing { get; private set; }

    /// <summary>True while the current line is still typing out.</summary>
    public bool IsRevealing => IsShowing && _revealed < _length;

    public DialogueLine? CurrentLine { get; private set; }

    private Control _root = null!;
    private Control _leftFrame = null!;
    private Control _rightFrame = null!;
    private TextureRect _leftPortrait = null!;
    private TextureRect _rightPortrait = null!;
    private Label _name = null!;
    private RichTextLabel _text = null!;

    private Task _tail = Task.CompletedTask;
    private int _queued;
    private TaskCompletionSource? _lineDone;
    private float _revealed;
    private int _length;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _leftFrame = GetNode<Control>("%LeftFrame");
        _rightFrame = GetNode<Control>("%RightFrame");
        _leftPortrait = GetNode<TextureRect>("%LeftPortrait");
        _rightPortrait = GetNode<TextureRect>("%RightPortrait");
        _name = GetNode<Label>("%Name");
        _text = GetNode<RichTextLabel>("%Text");
        _root.Visible = false;
        _root.GuiInput += OnRootInput;
        SetProcess(false);
    }

    /// <summary>Play every line of <paramref name="sequence"/>. Completes after the last line is advanced.</summary>
    public Task Play(DialogueSequence sequence) => Play(sequence.Lines);

    /// <summary>Play <paramref name="lines"/> in order, after anything already queued.</summary>
    public Task Play(IReadOnlyList<DialogueLine> lines)
    {
        _queued++;
        var run = PlayAfter(_tail, lines);
        _tail = run;
        return run;
    }

    /// <summary>Play one line, after anything already queued.</summary>
    public Task Say(DialogueLine line) => Play(new[] { line });

    /// <summary>Complete the reveal of the current line, or advance past it when it is fully shown.</summary>
    public void Advance()
    {
        if (!IsShowing || _lineDone == null) return;
        if (IsRevealing)
        {
            SetRevealed(_length);
            return;
        }
        var done = _lineDone;
        _lineDone = null;
        done.TrySetResult();
    }

    public override void _Process(double delta)
    {
        if (!IsRevealing) return;
        SetRevealed(_revealed + (float)delta * CharactersPerSecond);
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsShowing || !StoryInput.IsAdvanceKey(@event)) return;
        Advance();
        GetViewport().SetInputAsHandled();
    }

    private void OnRootInput(InputEvent @event)
    {
        if (!StoryInput.IsAdvanceClick(@event)) return;
        Advance();
        _root.AcceptEvent();
    }

    private async Task PlayAfter(Task previous, IReadOnlyList<DialogueLine> lines)
    {
        await previous;
        try
        {
            if (lines.Count > 0) Open();
            foreach (var line in lines) await ShowLine(line);
        }
        finally
        {
            _queued--;
            if (_queued == 0) Close();
        }
    }

    private Task ShowLine(DialogueLine line)
    {
        CurrentLine = line;
        var speaker = line.IsNarration ? null : FindPortraits(line.Speaker);
        var texture = speaker?.For(line.Emotion);
        bool left = speaker?.Side != PortraitSide.Right;

        _leftFrame.Visible = texture != null && left;
        _rightFrame.Visible = texture != null && !left;
        var portrait = left ? _leftPortrait : _rightPortrait;
        portrait.Texture = texture;
        portrait.FlipH = speaker?.FlipH ?? false;

        _name.Visible = !line.IsNarration && line.Speaker.Length > 0;
        _name.Text = line.Speaker;
        _name.HorizontalAlignment = left ? HorizontalAlignment.Left : HorizontalAlignment.Right;

        _text.Text = line.IsNarration ? $"[i]{line.Text}[/i]" : line.Text;
        _length = _text.GetParsedText().Length;
        SetRevealed(0);

        var done = new TaskCompletionSource();
        _lineDone = done;
        LineStarted?.Invoke(line);
        return done.Task;
    }

    private SpeakerPortraits? FindPortraits(string speaker)
    {
        foreach (var entry in Portraits)
            if (entry.Speaker == speaker) return entry;
        return null;
    }

    private void SetRevealed(float count)
    {
        _revealed = Mathf.Min(count, _length);
        _text.VisibleCharacters = _revealed >= _length ? -1 : (int)_revealed;
    }

    private void Open()
    {
        if (IsShowing) return;
        IsShowing = true;
        _root.Visible = true;
        SetProcess(true);
        ModalStack.Instance?.Push(this);
        ShowingChanged?.Invoke(true);
    }

    private void Close()
    {
        CurrentLine = null;
        _lineDone = null;
        _length = 0;
        _revealed = 0;
        if (!IsShowing) return;
        IsShowing = false;
        _root.Visible = false;
        SetProcess(false);
        ModalStack.Instance?.Pop(this);
        ShowingChanged?.Invoke(false);
    }
}
