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
/// Both portrait slots always keep their space, so the text column never moves; the unused one is
/// transparent. Narration lines show no portrait or name and use <see cref="NarrationVariation"/>.
/// A line with blank-line paragraph breaks shows one paragraph per page. A click, Enter or Space
/// first completes the reveal, then advances. Calls made while a sequence plays queue behind it.
/// While open it holds a <see cref="ModalStack"/> entry and swallows clicks to the board.
/// </summary>
public partial class DialogueBox : CanvasLayer
{
    /// <summary>One entry per speaker. A speaker with no entry shows no portrait.</summary>
    [Export] public Array<SpeakerPortraits> Portraits { get; set; } = new();

    [Export] public float CharactersPerSecond { get; set; } = 40f;

    [Export] public StringName SpeechVariation { get; set; } = "";

    [Export] public StringName NarrationVariation { get; set; } = "";

    /// <summary>Where narration sits in the text area. Speech always starts at the top, under the name.</summary>
    [Export] public VerticalAlignment NarrationAlignment { get; set; } = VerticalAlignment.Top;

    /// <summary>Who wears what. A line's <see cref="DialogueLine.AccessoryCues"/> change it as the line
    /// starts, and the speaker's portrait shows the first worn accessory it has frames for. An owner
    /// that outlives the box, such as <see cref="PrologueDirector"/>, may replace it.</summary>
    public Wardrobe Wardrobe { get; set; } = new();

    /// <summary>Fires as a line with accessory cues starts, after they change <see cref="Wardrobe"/>
    /// and before its staging.</summary>
    public event Action? WardrobeChanged;

    /// <summary>Runs as each line starts, before its text shows. While the returned task runs the box
    /// stays closed, so staging can play out first.</summary>
    public Func<DialogueLine, Task>? BeforeLine { get; set; }

    /// <summary>The paragraph break that splits a line into pages.</summary>
    private const string PageBreak = "\n\n";

    /// <summary>True when the box opens, false when the last queued line closes it.</summary>
    public event Action<bool>? ShowingChanged;

    /// <summary>Fires as each line starts, after its text and portrait are set.</summary>
    public event Action<DialogueLine>? LineStarted;

    public bool IsShowing { get; private set; }

    /// <summary>True while the current line is still typing out.</summary>
    public bool IsRevealing => IsShowing && _revealed < _length;

    public DialogueLine? CurrentLine { get; private set; }

    /// <summary>True while the caret that asks for a click shows.</summary>
    public bool ShowsAdvanceMark => _advanceMark.Visible;

    /// <summary>True when the current page's text fits the text area without clipping.</summary>
    public bool PageFits => PageOverflow <= 0f;

    /// <summary>Pixels of the current page's text below the text area. Zero or less when it fits.</summary>
    public float PageOverflow => _text.GetContentHeight() - _text.Size.Y;

    /// <summary>The animation the speaker's portrait plays, or empty when the line shows no portrait.</summary>
    public StringName PortraitAnimation => _speaker == null ? "" : _portrait.CurrentAnimation;

    /// <summary>The portrait that shows the current speaker, or null when the line shows none.</summary>
    public PortraitView? SpeakerPortrait => _speaker == null ? null : _portrait;

    /// <summary>The text of the page on screen, as shown (no markup).</summary>
    public string PageText => _text.GetParsedText();

    /// <summary>The box panel's rectangle on screen.</summary>
    public Rect2 BoxRect => _box.GetGlobalRect();

    private Control _root = null!;
    private Control _box = null!;
    private Control _leftFrame = null!;
    private Control _rightFrame = null!;
    private PortraitView _leftPortrait = null!;
    private PortraitView _rightPortrait = null!;
    private PortraitView _portrait = null!;
    private SpeakerPortraits? _speaker;
    private bool? _talking;
    private Label _name = null!;
    private RichTextLabel _text = null!;
    private Control _advanceMark = null!;

    private Task _tail = Task.CompletedTask;
    private int _queued;
    private TaskCompletionSource? _lineDone;
    private float _revealed;
    private int _length;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _box = GetNode<Control>("%Box");
        _leftFrame = GetNode<Control>("%LeftFrame");
        _rightFrame = GetNode<Control>("%RightFrame");
        _leftPortrait = GetNode<PortraitView>("%LeftPortrait");
        _rightPortrait = GetNode<PortraitView>("%RightPortrait");
        _portrait = _leftPortrait;
        _name = GetNode<Label>("%Name");
        _text = GetNode<RichTextLabel>("%Text");
        _advanceMark = GetNode<Control>("%AdvanceMark");
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
        _advanceMark.Visible = false;
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

    private async Task ShowLine(DialogueLine line)
    {
        foreach (var cue in line.AccessoryCues) Wardrobe.Apply(cue);
        if (line.AccessoryCues.Count > 0) WardrobeChanged?.Invoke();
        if (BeforeLine?.Invoke(line) is { IsCompleted: false } staging)
        {
            _root.Visible = false;
            await staging;
        }
        _root.Visible = true;
        CurrentLine = line;
        var speaker = line.IsNarration ? null : FindPortraits(line.Speaker);
        bool hasFace = speaker != null && speaker.Has(speaker.For(line.Emotion));
        bool left = speaker?.Side != PortraitSide.Right;

        SetSlotShown(_leftFrame, hasFace && left);
        SetSlotShown(_rightFrame, hasFace && !left);
        _speaker = hasFace ? speaker : null;
        _portrait = left ? _leftPortrait : _rightPortrait;
        _portrait.FlipH = speaker?.FlipH ?? false;
        _portrait.SetAccessory(hasFace ? WornFrames(speaker!) : null);
        var other = left ? _rightPortrait : _leftPortrait;
        other.SetAccessory(null);
        other.Play(null, "");
        _talking = null;

        _name.Visible = !line.IsNarration && line.Speaker.Length > 0;
        _name.Text = line.Speaker;
        _text.ThemeTypeVariation = line.IsNarration ? NarrationVariation : SpeechVariation;
        _text.VerticalAlignment = line.IsNarration ? NarrationAlignment : VerticalAlignment.Top;

        var pages = line.Text.Split(PageBreak, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        for (int i = 0; i < pages.Length; i++)
        {
            var shown = ShowPage(pages[i]);
            if (i == 0) LineStarted?.Invoke(line);
            await shown;
        }
    }

    private Task ShowPage(string text)
    {
        _text.Text = text;
        _length = _text.GetParsedText().Length;
        var done = new TaskCompletionSource();
        _lineDone = done;
        SetRevealed(0);
        return done.Task;
    }

    private static void SetSlotShown(Control slot, bool shown) =>
        slot.Modulate = slot.Modulate with { A = shown ? 1f : 0f };

    private SpeakerPortraits? FindPortraits(string speaker)
    {
        foreach (var entry in Portraits)
            if (entry.Speaker == speaker) return entry;
        return null;
    }

    private SpriteFrames? WornFrames(SpeakerPortraits speaker)
    {
        foreach (var (accessory, frames) in speaker.Accessories)
            if (Wardrobe.IsWearing(speaker.Speaker, accessory)) return frames;
        return null;
    }

    private void SetRevealed(float count)
    {
        _revealed = Mathf.Min(count, _length);
        bool full = _revealed >= _length;
        _text.VisibleCharacters = full ? -1 : (int)_revealed;
        _advanceMark.Visible = full && _lineDone != null;
        SetTalking(!full);
    }

    /// <summary>Play the speaker's talking animation while text types out, and its resting one after.</summary>
    private void SetTalking(bool talking)
    {
        if (_talking == talking || CurrentLine == null) return;
        _talking = talking;
        if (_speaker == null)
        {
            _portrait.Play(null, "");
            return;
        }
        var emotion = CurrentLine.Emotion;
        _portrait.Play(_speaker.Frames, talking ? _speaker.TalkingFor(emotion) : _speaker.For(emotion));
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
        _advanceMark.Visible = false;
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
