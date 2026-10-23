using System;
using System.Threading.Tasks;
using Godot;
using Ungilded.Autoload;

namespace Ungilded.Story;

/// <summary>
/// Full-screen narration: one line of a sequence per page, in centred lines of balanced width on a
/// centred on screen. Behind it is the line's <see cref="DialogueLine.Scenery"/>, or black, or the
/// cutscene set when the line has <see cref="DialogueLine.RevealsSet"/>.
/// Each page fades in, waits for a click, Enter or Space, and fades out. Advancing during the
/// fade-in shows the page at once. A new scenery crossfades over the old one. The task from
/// <see cref="Play"/> completes after the last page and its scenery fade out.
/// </summary>
public partial class NarrationScreen : CanvasLayer
{
    private static readonly StringName FontItem = "font";
    private static readonly StringName FontSizeItem = "font_size";

    [Export] public float FadeSeconds { get; set; } = 0.6f;

    [Export] public float SceneryFadeSeconds { get; set; } = 1.2f;

    /// <summary>Widest line of page text, in screen pixels.</summary>
    [Export] public float WrapWidth { get; set; } = 1200f;

    /// <summary>Fires as each page starts to fade in.</summary>
    public event Action<DialogueLine>? PageStarted;

    public bool IsShowing { get; private set; }

    /// <summary>True once the current page has fully faded in and waits for input.</summary>
    public bool IsWaiting => _pageDone != null && _fade == null;

    /// <summary>True while the caret that asks for a click shows.</summary>
    public bool ShowsAdvanceMark => _advanceMark.Visible;

    /// <summary>Pixels between the bottom of the current page's text and the caret. Negative when they overlap.</summary>
    public float GapAboveMark => _advanceMark.GlobalPosition.Y - (_page.GlobalPosition.Y + _page.GetMinimumSize().Y);

    /// <summary>The scenery scene behind the current page, or null over black.</summary>
    public PackedScene? CurrentScenery => _sceneryScene;

    /// <summary>True while the black behind the page is down and the cutscene set shows through.</summary>
    public bool ShowsSet => _background.Modulate.A < 1f;

    private Control _root = null!;
    private Control _background = null!;
    private Tween? _backgroundFade;
    private Control _sceneryHolder = null!;
    private Control _pad = null!;
    private Label _page = null!;
    private Control _advanceMark = null!;
    private Tween? _fade;
    private TaskCompletionSource? _fadeDone;
    private float _fadeTarget;
    private TaskCompletionSource? _pageDone;
    private PackedScene? _sceneryScene;
    private CrawlScenery? _scenery;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _background = GetNode<Control>("%Background");
        _sceneryHolder = GetNode<Control>("%Scenery");
        _pad = GetNode<Control>("%Pad");
        _page = GetNode<Label>("%Page");
        _advanceMark = GetNode<Control>("%AdvanceMark");
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
                _page.Text = BalancedWrap.Wrap(line.Text, _page.GetThemeFont(FontItem),
                    _page.GetThemeFontSize(FontSizeItem), WrapWidth);
                _pad.Modulate = _pad.Modulate with { A = 0f };
                var waiting = new TaskCompletionSource();
                _pageDone = waiting;
                ShowBackground(!line.RevealsSet);
                _ = ShowScenery(line.Scenery);
                PageStarted?.Invoke(line);
                await FadePage(1f);
                _advanceMark.Visible = true;
                await waiting.Task;
                _advanceMark.Visible = false;
                await FadePage(0f);
            }
            await ShowScenery(null);
        }
        finally
        {
            _pageDone = null;
            _advanceMark.Visible = false;
            IsShowing = false;
            _root.Visible = false;
            _backgroundFade?.Kill();
            _background.Modulate = _background.Modulate with { A = 1f };
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

    /// <summary>Bring the black behind the page up, or take it down to show the cutscene set. A
    /// scenery on screen covers the black, so it drops at once and the scenery's own fade-out
    /// crossfades into the set.</summary>
    private void ShowBackground(bool shown)
    {
        float alpha = shown ? 1f : 0f;
        _backgroundFade?.Kill();
        _backgroundFade = null;
        if (_scenery != null || SceneryFadeSeconds <= 0f)
        {
            _background.Modulate = _background.Modulate with { A = alpha };
            return;
        }
        _backgroundFade = CreateTween().SetIgnoreTimeScale();
        _backgroundFade.TweenProperty(_background, "modulate:a", alpha, SceneryFadeSeconds);
    }

    /// <summary>Crossfade to <paramref name="scene"/>, or to black when it is null. Completes when the fade ends.</summary>
    private Task ShowScenery(PackedScene? scene)
    {
        if (scene == _sceneryScene) return Task.CompletedTask;
        _sceneryScene = scene;
        var old = _scenery;
        _scenery = null;
        if (scene != null)
        {
            _scenery = scene.Instantiate<CrawlScenery>();
            _sceneryHolder.AddChild(_scenery);
            _scenery.Play();
        }
        if (SceneryFadeSeconds <= 0f || FadeSeconds <= 0f)
        {
            old?.QueueFree();
            return Task.CompletedTask;
        }
        var done = new TaskCompletionSource();
        var tween = CreateTween().SetParallel().SetIgnoreTimeScale();
        if (_scenery != null)
        {
            _scenery.Modulate = _scenery.Modulate with { A = 0f };
            tween.TweenProperty(_scenery, "modulate:a", 1f, SceneryFadeSeconds);
        }
        if (old != null) tween.TweenProperty(old, "modulate:a", 0f, SceneryFadeSeconds);
        else tween.TweenInterval(SceneryFadeSeconds);
        tween.Chain().TweenCallback(Callable.From(() =>
        {
            old?.QueueFree();
            done.TrySetResult();
        }));
        return done.Task;
    }

    private Task FadePage(float alpha)
    {
        if (FadeSeconds <= 0f)
        {
            _pad.Modulate = _pad.Modulate with { A = alpha };
            return Task.CompletedTask;
        }
        var done = new TaskCompletionSource();
        var tween = CreateTween().SetIgnoreTimeScale();
        _fade = tween;
        _fadeDone = done;
        _fadeTarget = alpha;
        tween.TweenProperty(_pad, "modulate:a", alpha, FadeSeconds);
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
        _pad.Modulate = _pad.Modulate with { A = _fadeTarget };
        done?.TrySetResult();
    }
}
