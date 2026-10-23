using System.Collections.Generic;
using System.Threading.Tasks;
using Ungilded.Combat;
using Godot;

namespace Ungilded.UI;

/// <summary>
/// Compact modal reaction prompt: "Shield Block?" with the accept and Skip keycap buttons on one
/// row, then at most two compact figures. The scene places it beside the units that set it off
/// each frame (<see cref="Place"/>), with a pointer at the trigger, or docks it at the bottom
/// centre when they are off screen (<see cref="DockBottom"/>). Renders a
/// <see cref="ReactionPromptView"/> and resolves the awaited choice; it holds no rules. While
/// visible, the transparent full-rect backdrop swallows board clicks, the panel holds
/// <see cref="HudRoot"/>'s modal state, and _Input takes combat_confirm and combat_decline a phase
/// ahead of GridInput3D, so Escape resolves the prompt instead of cancelling targeting.
/// </summary>
public partial class ReactionPromptPanel : Control
{
    [Export] public PackedScene? FigureScene { get; set; }

    /// <summary>Pixels between the trigger and the box.</summary>
    [Export] public float Gap { get; set; } = 32f;

    /// <summary>Pixels the box keeps from the screen edges, and from the bottom when docked.</summary>
    [Export] public float ScreenMargin { get; set; } = 16f;

    /// <summary>Pixels between the box positions tried.</summary>
    [Export] public float PlacementStep { get; set; } = 16f;

    /// <summary>Steps past the gap the box may move away from the trigger to clear a HUD panel.</summary>
    [Export] public int PlacementMaxPush { get; set; } = 8;

    /// <summary>Cost of one square pixel of box over a HUD panel, against one pixel of distance.</summary>
    [Export] public float PanelOverlapWeight { get; set; } = 100f;

    [Export] public float PointerLength { get; set; } = 22f;

    /// <summary>Pixels the pointer keeps from the box corners.</summary>
    [Export] public float PointerInset { get; set; } = 28f;

    /// <summary>The farthest the box may sit from its trigger once placed beside it.</summary>
    public float MaxReach => Gap + PlacementMaxPush * PlacementStep;

    private Label _titleLabel = null!;
    private Label _descriptionLabel = null!;
    private Label _triggerLabel = null!;

    public string TriggerText => _triggerLabel.Text;
    private HBoxContainer _figures = null!;
    private CaptionButton _useButton = null!;
    private CaptionButton _skipButton = null!;
    private Control _panel = null!;
    private Ungilded.Story.TipPointer _pointer = null!;

    private HudRoot? _hud;
    private bool _modalHeld;

    private TaskCompletionSource<bool>? _choiceTcs;

    /// <summary>The prompt box, in HUD pixels.</summary>
    public Rect2 BoxRect => _panel.GetGlobalRect();

    /// <summary>True while the pointer aims at a trigger (the box sits beside it).</summary>
    public bool Pointing { get; private set; }
    public string TitleText => _titleLabel.Text;
    public string AcceptText => _useButton.ActionLabel?.Text ?? "";

    public IReadOnlyList<FigureLabel> FigureLabels
    {
        get
        {
            var labels = new List<FigureLabel>();
            foreach (var child in _figures.GetChildren())
                if (child is FigureLabel label) labels.Add(label);
            return labels;
        }
    }

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("%TitleLabel");
        _descriptionLabel = GetNode<Label>("%DescriptionLabel");
        _triggerLabel = GetNode<Label>("%TriggerLabel");
        _figures = GetNode<HBoxContainer>("%Figures");
        _useButton = GetNode<CaptionButton>("%UseButton");
        _skipButton = GetNode<CaptionButton>("%SkipButton");
        _panel = GetNode<Control>("%Panel");
        _pointer = GetNode<Ungilded.Story.TipPointer>("%Pointer");
        _pointer.Fill = UiColors.Accent;

        _hud = GetParentOrNull<HudRoot>();

        _useButton.Pressed += () => Resolve(true);
        _skipButton.Pressed += () => Resolve(false);

        Visible = false;
    }

    /// <summary>Show the prompt and await the player's choice. True = accept, false = Skip.</summary>
    public Task<bool> ShowAsync(ReactionPromptView view)
    {
        Render(view);
        _choiceTcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        Visible = true;
        HoldModal();
        return _choiceTcs.Task;
    }

    private void Render(ReactionPromptView view)
    {
        _titleLabel.Text = view.Title.Length > 0 ? view.Title : $"{view.ReactionName}?";
        _triggerLabel.Text = view.Trigger;
        _triggerLabel.Visible = view.Trigger.Length > 0;
        _useButton.SetActionText(view.AcceptLabel);
        _panel.TooltipText = view.Description;

        foreach (var child in _figures.GetChildren())
        {
            _figures.RemoveChild(child);
            child.QueueFree();
        }
        if (FigureScene != null)
            foreach (var figure in view.Figures)
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                _figures.AddChild(label);
                label.Render(figure);
            }
        _figures.Visible = _figures.GetChildCount() > 0;
        _descriptionLabel.Visible = !_figures.Visible && view.Description.Length > 0;
        _descriptionLabel.Text = view.Description;
        _panel.ResetSize();
    }

    /// <summary>Put the box beside <paramref name="trigger"/> (the unit that set the reaction off,
    /// with its plate), never over <paramref name="keepOff"/>, off <paramref name="panels"/> where
    /// it can be, with the pointer at <paramref name="aim"/>. All rects in HUD pixels.</summary>
    public void Place(Rect2 trigger, Vector2 aim, IReadOnlyList<Rect2> panels, IReadOnlyList<Rect2> keepOff)
    {
        _panel.ResetSize();
        var space = new Ungilded.Story.TipSpace(GetGlobalRect(), Gap, ScreenMargin, PlacementStep, PlacementMaxPush,
            PanelOverlapWeight, panels);
        var layout = Ungilded.Story.TipPlacement.Place(space, trigger, keepOff, aim, _panel.Size,
            PointerLength, PointerInset);
        _panel.GlobalPosition = layout.BoxPosition;
        _pointer.Point(layout.PointerBase, layout.PointerTip);
        Pointing = true;
    }

    /// <summary>The bottom-centre dock, with no pointer, for a trigger that is not on screen.</summary>
    public void DockBottom()
    {
        _panel.ResetSize();
        var screen = GetGlobalRect();
        _panel.GlobalPosition = new Vector2(screen.GetCenter().X - _panel.Size.X / 2,
            screen.End.Y - ScreenMargin - _panel.Size.Y).Round();
        _pointer.Clear();
        Pointing = false;
    }

    public override void _Input(InputEvent @event)
    {
        if (!Visible) return;

        if (@event.IsActionPressed(InputNames.Confirm))
        {
            Resolve(true);
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed(InputNames.Decline))
        {
            Resolve(false);
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _ExitTree() => ReleaseModal();

    /// <summary>Answer the open prompt as the accept or Skip button does.</summary>
    public void Choose(bool use) => Resolve(use);

    private void Resolve(bool use)
    {
        if (_choiceTcs == null) return;

        Visible = false;
        ReleaseModal();
        var tcs = _choiceTcs;
        _choiceTcs = null;
        tcs.TrySetResult(use);
    }

    private void HoldModal()
    {
        if (_modalHeld) return;
        _modalHeld = true;
        _hud?.PushModal();
    }

    private void ReleaseModal()
    {
        if (!_modalHeld) return;
        _modalHeld = false;
        _hud?.PopModal();
    }
}
