using Godot;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Delve.UI;

/// <summary>
/// Shows each resolved d20 without rolling gameplay dice. A full beat plays the hero roll (centre
/// stage while the defence is unknown, the degree track once it is known) and shrinks it into the
/// row; a short beat fills the row directly; with the dice reveal off only the settled row shows.
/// Rolls queue, and the combat presenter awaits each outcome instead of estimating its duration.
/// A click, Enter or Esc skips a beat to the settled row. The tumble uses its own display-only
/// random source, so it can never touch combat RNG.
/// </summary>
public partial class DiceRollPanel : PanelContainer
{
    private enum Phase { Idle, Beat, Settled }

    private sealed class Pending
    {
        public required CombatRoll Roll;
        public required string Context;
        public required TaskCompletionSource Result;
        public bool Reaction;
    }

    [Export] public DiceHeroView? Hero { get; set; }
    /// <summary>Space between the hero and the top of the roll row.</summary>
    [Export] public float HeroGap { get; set; } = 16;

    private Label _die = null!;
    private Control _face = null!;
    private TextureRect _outline = null!;
    private RichTextLabel _math = null!;
    private RichTextLabel _detail = null!;
    private RichTextLabel _applied = null!;
    private Label _outcome = null!;
    private Control _row = null!;
    private DegreeTrack _rowTrack = null!;
    private Pending? _current;
    private Phase _phase;
    private Tween? _tween;
    private readonly System.Random _tumble = new();
    private int _lastFace;
    private readonly Queue<Pending> _pending = new();
    private Task _latestResult = Task.CompletedTask;
    private bool _animationsEnabled = true;

    [Export] public bool AnimationsEnabled
    {
        get => _animationsEnabled;
        set { _animationsEnabled = value; if (!value) ClearRoll(); }
    }

    /// <summary>True from the outcome's arrival until the row fades.</summary>
    public bool ResultShowing { get; private set; }

    /// <summary>True while the row shows the finished roll.</summary>
    public bool Settled => _phase == Phase.Settled;

    /// <summary>How the showing roll is staged, or null with no roll.</summary>
    public RollBeat? Beat { get; private set; }

    /// <summary>The action the showing roll belongs to, as the log titled it.</summary>
    public string Context { get; private set; } = "";

    /// <summary>True while the face is still tumbling (before it lands on the rolled value).</summary>
    public bool Tumbling { get; private set; }

    public DegreeTrack RowTrack => _rowTrack;

    /// <summary>The roll on show, or null.</summary>
    public CombatRoll? Showing => _current?.Roll;

    /// <summary>Wait until every roll announced so far has shown its final outcome.</summary>
    public async Task WaitForResultsAsync(CancellationToken token = default)
    {
        token.ThrowIfCancellationRequested();
        while (true)
        {
            var pending = _latestResult;
            await pending.WaitAsync(token);
            token.ThrowIfCancellationRequested();
            if (pending == _latestResult) return;
        }
    }

    public override void _Ready()
    {
        _die = GetNode<Label>("%DieValue");
        _face = _die.GetParent<Control>();
        _outline = GetNode<TextureRect>("%Outline");
        _math = GetNode<RichTextLabel>("%RollMath");
        _detail = GetNode<RichTextLabel>("%RollDetail");
        _applied = GetNode<RichTextLabel>("%RollApplied");
        _outcome = GetNode<Label>("%RollOutcome");
        _row = GetNode<Control>("%Row");
        _rowTrack = GetNode<DegreeTrack>("%RowTrack");
        ClearRoll();
    }

    public void ClearRoll()
    {
        _tween?.Kill();
        _tween = null;
        Hero?.Clear();
        _current?.Result.TrySetResult();
        _current = null;
        _phase = Phase.Idle;
        Beat = null;
        Tumbling = false;
        ResultShowing = false;
        while (_pending.TryDequeue(out var pending)) pending.Result.TrySetResult();
        _latestResult = Task.CompletedTask;
        Visible = false;
    }

    public override void _ExitTree() => ClearRoll();

    public void ShowRoll(CombatRoll roll, string context)
    {
        var result = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var next = new Pending { Roll = roll, Context = context, Result = result };
        if (!AnimationsEnabled)
        {
            // The settled row replaces whatever shows; combat never waits for it.
            _tween?.Kill();
            _current?.Result.TrySetResult();
            result.TrySetResult();
            Start(next);
            return;
        }
        _latestResult = result.Task;
        _pending.Enqueue(next);
        if (_current == null) StartNextRoll();
    }

    /// <summary>The roll that raised a reaction prompt plays the full beat. A queued roll is marked;
    /// a showing short beat that has not reached its outcome restarts as a full one.</summary>
    public void PromoteLatest()
    {
        if (_pending.Count > 0)
        {
            _pending.ToArray()[^1].Reaction = true;
            return;
        }
        if (_current == null || _phase != Phase.Beat || Beat?.Pace != RollPace.Short) return;
        _current.Reaction = true;
        _tween?.Kill();
        Start(_current);
    }

    private void StartNextRoll()
    {
        if (_pending.TryDequeue(out var next)) Start(next);
    }

    private void Start(Pending next)
    {
        _current = next;
        Context = next.Context;
        Beat = RollBeat.For(next.Roll, AnimationsEnabled, next.Reaction);
        ResultShowing = false;
        Tumbling = false;
        Hero?.Clear();
        FillRow(next.Roll);
        Modulate = Modulate with { A = 1 };
        Visible = true;
        _phase = Phase.Beat;
        _tween = CreateTween();
        switch (Beat.Pace)
        {
            case RollPace.Full when Hero != null: BuildFull(next.Roll, Beat); break;
            case RollPace.Settled: ShowSettledRow(); Arrive(); break;
            default: BuildShort(); break;
        }
        AppendHoldAndFade();
    }

    /// <summary>The outcome has arrived: release the presenter.</summary>
    private void Arrive()
    {
        _phase = Phase.Settled;
        ResultShowing = true;
        _current?.Result.TrySetResult();
    }

    public override void _Process(double delta)
    {
        if (_phase == Phase.Beat && Hero is { Visible: true } hero) hero.Place(GetGlobalRect(), HeroGap);
    }

    public override void _Input(InputEvent input)
    {
        if (_phase != Phase.Beat) return;
        bool skip = input is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left or MouseButton.Right }
            || input.IsActionPressed(InputNames.Confirm) || input.IsActionPressed(InputNames.Decline);
        if (!skip) return;
        Skip();
        GetViewport()?.SetInputAsHandled();
    }

    /// <summary>Jump the showing beat to the settled row and release the presenter.</summary>
    public void Skip()
    {
        if (_phase != Phase.Beat || _current == null) return;
        _tween?.Kill();
        Hero?.Clear();
        Tumbling = false;
        ShowSettledRow();
        Modulate = Modulate with { A = 1 };
        Arrive();
        _tween = CreateTween();
        AppendHoldAndFade();
    }

    private void TumbleFace(System.Action<int> show)
    {
        int face;
        do face = _tumble.Next(1, 21); while (face == _lastFace);
        _lastFace = face;
        show(face);
    }
}
