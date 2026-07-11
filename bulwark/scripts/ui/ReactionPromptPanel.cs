using System.Threading.Tasks;
using Bulwark.Combat;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Modal reaction prompt: "Use Shield Block? (absorb N damage)" with Use / Skip. Passive UI —
/// renders a <see cref="ReactionPromptView"/> and resolves the awaited choice; it holds no rules
/// and no engine types. While visible, the full-rect backdrop (MouseFilter.Stop) swallows mouse
/// events before they reach GridInput3D, and _UnhandledKeyInput consumes Enter/Y (Use) and
/// Esc/N (Skip), so grid input is blocked for the duration of the prompt.
/// </summary>
public partial class ReactionPromptPanel : Control
{
    private Label _titleLabel = null!;
    private Label _reactorLabel = null!;
    private Label _descriptionLabel = null!;
    private Button _useButton = null!;
    private Button _skipButton = null!;

    private TaskCompletionSource<bool>? _choiceTcs;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("%TitleLabel");
        _reactorLabel = GetNode<Label>("%ReactorLabel");
        _descriptionLabel = GetNode<Label>("%DescriptionLabel");
        _useButton = GetNode<Button>("%UseButton");
        _skipButton = GetNode<Button>("%SkipButton");

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
        _useButton.GrabFocus();
        return _choiceTcs.Task;
    }

    public override void _UnhandledKeyInput(InputEvent @event)
    {
        if (!Visible || @event is not InputEventKey key || !key.Pressed || key.Echo)
            return;

        switch (key.Keycode)
        {
            case Key.Enter:
            case Key.KpEnter:
            case Key.Y:
                Resolve(true);
                GetViewport().SetInputAsHandled();
                break;

            case Key.Escape:
            case Key.N:
                Resolve(false);
                GetViewport().SetInputAsHandled();
                break;
        }
    }

    private void Resolve(bool use)
    {
        if (_choiceTcs == null) return;

        Visible = false;
        var tcs = _choiceTcs;
        _choiceTcs = null;
        tcs.TrySetResult(use);
    }
}
