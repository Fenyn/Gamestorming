using System;
using System.Collections.Generic;
using Godot;

namespace Ungilded.Story;

/// <summary>
/// One tutorial tip for <see cref="TutorialPopup"/>. <see cref="Resolve"/> fills the focus quads in
/// canvas pixels each frame, and the <see cref="TipClearance"/>: the rects the box must keep clear
/// of (the panel a focused part sits in, a named unit) and the points over the units the tip names.
/// Null shows the tip centred with no dim. A focus with no quads is the units themselves: the box
/// sits beside them with no dim. <see cref="Shown"/> and <see cref="Hidden"/> run as the tip comes
/// on and leaves the screen (a queued or covered tip is off screen).
/// </summary>
public sealed record TipRequest(string Id, string Bbcode)
{
    public Action<List<Vector2[]>, TipClearance>? Resolve { get; init; }

    /// <summary>Fills the HUD panels the box should stay off, each frame. Null places the box with
    /// no regard to the HUD (a centred tip then keeps the scene's own place).</summary>
    public Action<List<Rect2>>? Panels { get; init; }
    public Action? Shown { get; init; }
    public Action? Hidden { get; init; }

    /// <summary>False outlines the focus with no dim, and a step tip then lets every click through.</summary>
    public bool Dimmed { get; init; } = true;
}

/// <summary>What a focused tip's box keeps clear of this frame, in canvas pixels, and the points the
/// popup draws an arrow down at: one over each unit the tip names.</summary>
public sealed class TipClearance : List<Rect2>
{
    public List<Vector2> Marks { get; } = new();

    /// <summary>Empty the rects and the marks.</summary>
    public void Reset()
    {
        Clear();
        Marks.Clear();
    }
}

/// <summary>What one tip did on screen, frame by frame, for the spikes.</summary>
public sealed class TipRecord
{
    public required string Id { get; init; }
    public required bool Step { get; init; }
    public required bool Focused { get; init; }
    public bool Dimmed { get; init; } = true;
    public int FramesShown { get; internal set; }

    /// <summary>Frames whose focus (the cutout, or the marked units when there is no cutout) was
    /// non-empty and inside the viewport.</summary>
    public int FramesResolved { get; internal set; }

    /// <summary>Frames past the settle frames with an empty focus or one outside the viewport.</summary>
    public int FramesUnresolved { get; internal set; }

    /// <summary>Frames past the settle frames with the box partly off screen.</summary>
    public int FramesOffScreen { get; internal set; }

    /// <summary>Frames past the settle frames with the box over the cutout or a rect it keeps clear of.</summary>
    public int FramesOverlap { get; internal set; }

    /// <summary>Frames past the settle frames with the box over a HUD panel, and the most square
    /// pixels it covered in one frame.</summary>
    public int FramesPanelOverlap { get; internal set; }
    public float MostPanelOverlap { get; internal set; }

    /// <summary>The most unit arrows the tip drew in one frame.</summary>
    public int MostArrows { get; internal set; }

    public bool Closed { get; internal set; }

    /// <summary>The latest frame's focus bounds (cutout or marked units) and box, for a failure report.</summary>
    public Rect2 LastCutout { get; internal set; }
    public Rect2 LastBox { get; internal set; }
}

/// <summary>An open step tip. Disposing it closes the tip.</summary>
public sealed class TipHandle : IDisposable
{
    private Action? _close;

    internal TipHandle(Action close) => _close = close;

    public void Dispose()
    {
        _close?.Invoke();
        _close = null;
    }
}
