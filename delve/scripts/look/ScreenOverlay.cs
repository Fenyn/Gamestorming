using Godot;

namespace Delve.Look;

/// <summary>
/// Full-screen rect for a post shader (grain, vignette). A Node2D rather than a Control, so it
/// never takes part in GUI picking and a hover check that asks "is the pointer over UI" still
/// sees the world under it.
/// </summary>
public partial class ScreenOverlay : Node2D
{
    public override void _EnterTree() => GetViewport().SizeChanged += QueueRedraw;

    public override void _ExitTree() => GetViewport().SizeChanged -= QueueRedraw;

    public override void _Draw() => DrawRect(GetViewportRect(), Colors.White);
}
