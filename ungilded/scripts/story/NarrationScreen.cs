using System;
using System.Threading.Tasks;
using Godot;
using Ungilded.Autoload;

namespace Ungilded.Story;

/// <summary>
/// Full-screen narration over black: one line of a sequence per page, centred. Each page fades in,
/// waits for a click, Enter or Space, and fades out. Advancing during the fade-in shows the page at
/// once. The task from <see cref="Play"/> completes after the last page fades out.
/// </summary>
public partial class NarrationScreen : CanvasLayer
{
    [Export] public float FadeSeconds { get; set; } = 0.6f;

    /// <summary>Fires as each page starts to fade in.</summary>
    public event Action<DialogueLine>? PageStarted;

    public bool IsShowing { get; private set; }

    /// <summary>True once the current page has fully faded in and waits for input.</summary>
    public bool IsWaiting => _pageDone != null && _fade == null;

    private Control _root = null!;
    private Label _page = null!;
    private Tween? _fade;
    private TaskCompletionSource? _fadeDone;
    private float _fadeTarget;
    private TaskCompletionSource? _pageDone;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _page = GetNode<Label>("%Page");
        _root.Visible = false;
        _root.GuiInput += OnRootInput;
    }

    /// <summary>Show every line of <paramref name="sequence"/> as its own page.</summary>
    public async Task Play(DialogueSequence sequence)
    {
        IsShowing = true;
        _root.Visible = true;
        ModalStack.Instance?.Push(this);
        try
        {
            foreach (var line in sequence.Lines)
            {
                _page.Text = line.Text;
                _page.Modulate = _page.Modulate with { A = 0f };
                var waiting = new TaskCompletionSource();
                _pageDone = waiting;
                PageStarted?.Invoke(line);
                await FadePage(1f);
                await waiting.Task;
                await FadePage(0f);
            }
        }
        finally
        {
            _pageDone = null;
            IsShowing = false;
            _root.Visible = false;
            ModalStack.Instance?.Pop(this);
        }
    }

    /// <summary>Finish the fade-in of the current page, or move on once it is fully shown.</summary>
    public void Advance()
    {
        if (!IsShowing || _pageDone == null) return;
        if (_fade != null)
        {
            if (_pageDone.Task.IsCompleted) return;
            EndFade();
            return;
        }
        _pageDone.TrySetResult();
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

    private Task FadePage(float alpha)
    {
        if (FadeSeconds <= 0f)
        {
            _page.Modulate = _page.Modulate with { A = alpha };
            return Task.CompletedTask;
        }
        var done = new TaskCompletionSource();
        var tween = CreateTween().SetIgnoreTimeScale();
        _fade = tween;
        _fadeDone = done;
        _fadeTarget = alpha;
        tween.TweenProperty(_page, "modulate:a", alpha, FadeSeconds);
        tween.Finished += () => { if (_fade == tween) EndFade(); };
        return done.Task;
    }

    /// <summary>Snap the running fade to its end value and release its waiter.</summary>
    private void EndFade()
    {
        if (_fade == null) return;
        _fade.Kill();
        _fade = null;
        var done = _fadeDone;
        _fadeDone = null;
        _page.Modulate = _page.Modulate with { A = _fadeTarget };
        done?.TrySetResult();
    }
}
