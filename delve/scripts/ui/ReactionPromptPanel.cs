using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Compact modal reaction prompt docked at the bottom centre: "Shield Block?" with the accept and
/// Skip keycap buttons on one row, then at most two compact figures. Renders a
/// <see cref="ReactionPromptView"/> and resolves the awaited choice; it holds no rules. While
/// visible, the transparent full-rect backdrop swallows board clicks, the panel holds
/// <see cref="HudRoot"/>'s modal state, and _Input takes combat_confirm and combat_decline a phase
/// ahead of GridInput3D, so Escape resolves the prompt instead of cancelling targeting.
/// </summary>
public partial class ReactionPromptPanel : Control
{
    [Export] public PackedScene? FigureScene { get; set; }

    private Label _titleLabel = null!;
    private Label _descriptionLabel = null!;
    private HBoxContainer _figures = null!;
    private CaptionButton _useButton = null!;
    private CaptionButton _skipButton = null!;
    private Control _panel = null!;

    private HudRoot? _hud;
    private bool _modalHeld;

    private TaskCompletionSource<bool>? _choiceTcs;

    public Control Dock => _panel;
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
        _figures = GetNode<HBoxContainer>("%Figures");
        _useButton = GetNode<CaptionButton>("%UseButton");
        _skipButton = GetNode<CaptionButton>("%SkipButton");
        _panel = GetNode<Control>("%Panel");

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
        _descriptionLabel.Visible = !_figures.Visible;
        _descriptionLabel.Text = view.Description;
        // Collapse to the anchor so the grow directions re-fit the dock to this prompt's content.
        _panel.OffsetLeft = 0;
        _panel.OffsetRight = 0;
        _panel.OffsetTop = _panel.OffsetBottom;
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
