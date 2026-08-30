namespace Delve.Data;

/// <summary>
/// Plays one <see cref="ManaSeedClip"/> to completion and reports the sheet frame to draw. Plain C#
/// with no engine types: the owning Node feeds it <c>delta</c> and reads back a sheet frame, which is
/// the whole of the "Nodes are thin adapters" contract for animation.
///
/// A clip, once started, outranks walk and stand until it finishes, so the owner's rule is simply: if
/// <see cref="IsPlaying"/>, the clip owns the sprite frame.
///
/// The clip does not signal its impact frame. A caller that must PACE something against the swing
/// waits <see cref="ManaSeedClip.TimeToImpact"/> instead.
/// </summary>
public sealed class SpriteActionPlayer
{
    private ManaSeedClip? _clip;
    private int _frame;
    private float _timer;

    /// <summary>True from <see cref="Play"/> until the last frame's time has elapsed.</summary>
    public bool IsPlaying => _clip != null;

    /// <summary>Start a clip from frame 0, discarding anything already running.</summary>
    public void Play(ManaSeedClip clip)
    {
        _clip = clip;
        _frame = 0;
        _timer = 0f;
    }

    /// <summary>Abandon the running clip.</summary>
    public void Stop()
    {
        _clip = null;
        _frame = 0;
        _timer = 0f;
    }

    /// <summary>
    /// Advance the clock. When the last frame expires the clip ends and <see cref="IsPlaying"/> goes
    /// false — the caller should hand the sprite back to walk/stand on that same tick rather than draw
    /// one frame of a finished clip.
    /// </summary>
    public void Tick(float delta)
    {
        if (_clip == null)
            return;

        _timer += delta;
        while (_clip != null && _timer >= _clip.FrameTimes[_frame])
        {
            _timer -= _clip.FrameTimes[_frame];
            _frame++;
            if (_frame >= _clip.FrameCount)
                Stop();
        }
    }

    /// <summary>Sheet cell for the current frame in a given facing row, or -1 when idle.</summary>
    public int SheetFrame(int facingRow) => _clip?.SheetFrame(facingRow, _frame) ?? -1;
}
