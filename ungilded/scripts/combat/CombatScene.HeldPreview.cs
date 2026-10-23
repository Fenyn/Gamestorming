using PF2e.Core;

namespace Ungilded.Combat;

/// <summary>The attack preview a tutorial tip holds. While Strike aims, the preview card shows the
/// forecast against the held target whenever the pointer is not on a target of its own, so a tip
/// that points at the card keeps it on screen.</summary>
public partial class CombatScene
{
    private ICharacter? _previewHeldOn;
    private bool _hoverPreviewShown;

    /// <summary>Subscribed after the view's own preview handler, so the held forecast replaces a cleared one.</summary>
    private void WireHeldPreview()
    {
        _controller.AttackPreviewChanged += preview =>
        {
            _hoverPreviewShown = preview != null;
            ShowHeldPreview();
        };
        _controller.ModeChanged += _ => ShowHeldPreview();
    }

    /// <summary>Hold the preview on <paramref name="target"/>, or let it go (null).</summary>
    private void HoldPreview(ICharacter? target)
    {
        _previewHeldOn = target;
        if (_controller == null || _hoverPreviewShown) return;
        _actionBar.ShowAttackPreview(target != null ? _controller.StrikePreview(target) : null);
    }

    private void ShowHeldPreview()
    {
        if (_previewHeldOn != null && !_hoverPreviewShown)
            _actionBar.ShowAttackPreview(_controller.StrikePreview(_previewHeldOn));
    }
}
