using System.Threading.Tasks;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Modal reaction prompt: "Use Shield Block? (absorb N damage)" with Use / Skip. Passive UI —
/// renders a <see cref="ReactionPromptView"/> and resolves the awaited choice; it holds no rules
/// and no engine types. While visible, the full-rect backdrop (MouseFilter.Stop) swallows mouse
/// events before they reach GridInput3D, the panel holds <see cref="HudRoot"/>'s modal state so
/// sibling hotkeys go inert, and _Input consumes combat_confirm (Use) and combat_decline (Skip) —
/// a phase ahead of GridInput3D's ui_cancel in _UnhandledInput, so Escape resolves the prompt
/// instead of cancelling targeting. Gated strictly on Visible so an idle prompt never eats input.
/// </summary>
public partial class ReactionPromptPanel : Control
{
    private Label _titleLabel = null!;
    private Label _reactorLabel = null!;
    private Label _descriptionLabel = null!;
    private Button _useButton = null!;
    private Button _skipButton = null!;

    private HudRoot? _hud;
    private bool _modalHeld;

    private TaskCompletionSource<bool>? _choiceTcs;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("%TitleLabel");
        _reactorLabel = GetNode<Label>("%ReactorLabel");
        _descriptionLabel = GetNode<Label>("%DescriptionLabel");
        _useButton = GetNode<Button>("%UseButton");
        _skipButton = GetNode<Button>("%SkipButton");

        _hud = GetParentOrNull<HudRoot>();

        _useButton.Pressed += () => Resolve(true);
        _skipButton.Pressed += () => Resolve(false);

        Visible = false;
    }

    /// <summary>
    /// Show the prompt and await the player's choice. True = Use, false = Skip.
    /// One prompt at a time by design (the engine serializes reaction decisions).
    /// </summary>
    public Task<bool> ShowAsync(ReactionPromptView view)
    {
        _titleLabel.Text = $"Use {view.ReactionName}?";
        _reactorLabel.Text = view.ReactorName;
        _descriptionLabel.Text = view.Description;

        // Async continuations so the combat pipeline resumes outside the button-press callstack.
        _choiceTcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        Visible = true;
        HoldModal();
        _useButton.GrabFocus();
        return _choiceTcs.Task;
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
