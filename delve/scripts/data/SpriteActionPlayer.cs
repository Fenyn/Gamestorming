namespace Delve.Data;

/// <summary>
/// Plays one <see cref="ManaSeedClip"/> to completion and reports the tick its impact frame lands.
/// Plain C# with no engine types: the owning Node feeds it <c>delta</c> and reads back a sheet
/// frame, which is the whole of the "Nodes are thin adapters" contract for animation.
///
/// A clip, once started, outranks walk and stand until it finishes, so
/// the owner's rule is simply: if <see cref="IsPlaying"/>, the clip owns the sprite frame.
///
/// The impact edge fires exactly once per <see cref="Play"/>, on the first tick at or past
/// <see cref="ManaSeedClip.ImpactFrame"/> — so a clip whose impact is frame 0, or one advanced by a
/// delta large enough to skip frames, still lands its effect exactly once and never zero times.
/// </summary>
public sealed class SpriteActionPlayer
{
    private ManaSeedClip? _clip;
    private int _frame;
    private float _timer;
    private bool _impactFired;

    /// <summary>True from <see cref="Play"/> until the last frame's time has elapsed.</summary>
    public bool IsPlaying => _clip != null;

    /// <summary>The running clip, or null when idle.</summary>
    public ManaSeedClip? Clip => _clip;

    /// <summary>Index of the current frame WITHIN the clip (not a sheet cell).</summary>
    public int Frame => _frame;

    /// <summary>Start a clip from frame 0, discarding anything already running.</summary>
    public void Play(ManaSeedClip clip)
    {
        _clip = clip;
        _frame = 0;
        _timer = 0f;
        _impactFired = false;
    }

    /// <summary>Abandon the running clip without firing a pending impact.</summary>
    public void Stop()
    {
        _clip = null;
        _frame = 0;
        _timer = 0f;
        _impactFired = false;
    }

    /// <summary>
    /// Advance the clock. Returns true on the single tick the impact frame is reached, which is the
    /// caller's cue to apply the action's effect. When the last frame expires the clip ends and
    /// <see cref="IsPlaying"/> goes false — the caller should hand the sprite back to walk/stand on
    /// that same tick rather than draw one frame of a finished clip.
    /// </summary>
    public bool Tick(float delta)
    {
        if (_clip == null)
            return false;

        _timer += delta;
        while (_clip != null && _timer >= _clip.FrameTimes[_frame])
        {
            _timer -= _clip.FrameTimes[_frame];
            _frame++;
            if (_frame >= _clip.FrameCount)
            {
                // Ran off the end: fire a not-yet-fired impact rather than swallow it, so an effect
                // can never be lost to a long frame.
                bool lateImpact = !_impactFired;
                _impactFired = true;
                Stop();
                return lateImpact;
            }
        }

        if (!_impactFired && _clip != null && _frame >= _clip.ImpactFrame)
        {
            _impactFired = true;
            return true;
        }
        return false;
    }

    /// <summary>Sheet cell for the current frame in a given facing row, or -1 when idle.</summary>
    public int SheetFrame(int facingRow) => _clip?.SheetFrame(facingRow, _frame) ?? -1;
}
