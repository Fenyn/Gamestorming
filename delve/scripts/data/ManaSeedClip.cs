using System.Collections.Generic;

namespace Delve.Data;

/// <summary>
/// One non-looping animation on a Mana Seed sheet: a rectangle of cells (a quadrant of a page),
/// its per-frame durations, and the frame on which the action's EFFECT should land.
///
/// A clip names a whole quadrant rather than a row because every Mana Seed animation is drawn in
/// all four facings at the same columns — the facing chooses the row, the clip chooses the
/// columns. <see cref="SheetFrame"/> is the only place that arithmetic lives.
///
/// <see cref="ImpactFrame"/> is what separates a swing that reads as deliberate from one that
/// reads as a teleporting result: the tilled soil, the poured water and the freed crop all appear
/// on the frame the art draws them, not on the button press. See <see cref="SpriteActionPlayer"/>.
/// </summary>
public sealed record ManaSeedClip
{
    /// <summary>Page file stem the clip's cells live on (e.g. <see cref="ManaSeedSheet.ToolPage"/>).</summary>
    public required string Page { get; init; }

    /// <summary>Row of the clip's SOUTH-facing strip; the facing row (0-3) is added to it.</summary>
    public required int RowOffset { get; init; }

    /// <summary>Leftmost column of the clip within its row.</summary>
    public required int StartColumn { get; init; }

    /// <summary>Seconds to hold each frame, in order. Its length is the frame count.</summary>
    public required IReadOnlyList<float> FrameTimes { get; init; }

    /// <summary>Index of the frame whose arrival applies the action's effect.</summary>
    public required int ImpactFrame { get; init; }

    public int FrameCount => FrameTimes.Count;

    /// <summary>Total run time in seconds.</summary>
    public float Duration
    {
        get
        {
            float total = 0f;
            for (int i = 0; i < FrameTimes.Count; i++)
                total += FrameTimes[i];
            return total;
        }
    }

    /// <summary>
    /// Seconds from <see cref="SpriteActionPlayer.Play"/> until <see cref="ImpactFrame"/> is on screen
    /// — the wait a caller that has to PACE something against the swing (rather than react to
    /// <see cref="SpriteActionPlayer.Tick"/>'s impact edge) needs: the combat presenter holds its
    /// event gate this long so the damage number lands on the strike frame, and the rendered shot
    /// spikes time their captures off it.
    /// </summary>
    public float TimeToImpact
    {
        get
        {
            float total = 0f;
            for (int i = 0; i < ImpactFrame && i < FrameTimes.Count; i++)
                total += FrameTimes[i];
            return total;
        }
    }

    /// <summary>Sheet cell index for a frame of this clip in a given facing row (0=S, 1=N, 2=E, 3=W).</summary>
    public int SheetFrame(int facingRow, int frame) =>
        (RowOffset + facingRow) * ManaSeedSheet.Columns + StartColumn + frame;
}
