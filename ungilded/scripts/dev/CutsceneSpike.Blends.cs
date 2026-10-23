using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Story;
using Ungilded.Story.Cutscene;

namespace Ungilded.Dev;

/// <summary>Checks that the wall cut holds still while the set camera blends. Rendered, with
/// UNGILDED_CUTSCENE_BLEND (a comma list of scene names: s1, s3a, s4 ...), it also saves frames
/// through the longest blend of each named scene.</summary>
public partial class CutsceneSpike
{
    /// <summary>Seconds between the frames saved through a blend, rendered.</summary>
    [Export] public float BlendFrameSeconds { get; set; } = 0.25f;

    private (string Shot, DialogueSequence Sequence)[] _scenes = System.Array.Empty<(string, DialogueSequence)>();
    private int _blends, _blendChanges, _blendQuadrant = -1;

    private void ResetBlends((string Shot, DialogueSequence Sequence)[] scenes)
    {
        _scenes = scenes;
        _blends = _blendChanges = 0;
        _blendQuadrant = -1;
    }

    private void WatchBlends(CutsceneSet set)
    {
        set.Camera.ShotStarted += _ => _blendQuadrant = -1;
        var wanted = OS.GetEnvironment("UNGILDED_CUTSCENE_BLEND").Split(',', System.StringSplitOptions.RemoveEmptyEntries);
        if (Headless || wanted.Length == 0) return;
        set.CueStarted += cue =>
        {
            if (cue is not ShotCue shot) return;
            foreach (var (name, sequence) in _scenes.Where(s => wanted.Contains(s.Shot)))
                if (LongestBlend(sequence) == shot) Hold(CaptureBlend(set, name, shot.Delay));
        };
    }

    /// <summary>Per frame while a blend runs: the camera quadrant the cut is drawn for.</summary>
    private void PollBlend(CutsceneSet? set)
    {
        if (set == null || !set.Camera.IsBlending || set.Stage.Cutaway is not { } cutaway) return;
        int quadrant = cutaway.CameraQuadrant;
        if (_blendQuadrant < 0)
        {
            _blends++;
            _blendQuadrant = quadrant;
            return;
        }
        if (quadrant == _blendQuadrant) return;
        _blendChanges++;
        GD.Print($"  {_case}: the cut changed mid-blend, quadrant {_blendQuadrant} to {quadrant}");
        _blendQuadrant = quadrant;
    }

    private void CheckBlendsAfter() =>
        Check($"{_case}: no wall changes state during a camera blend ({_blends} blends, {_blendChanges} changes)",
            _blendChanges == 0);

    private static ShotCue? LongestBlend(DialogueSequence sequence) =>
        sequence.Lines.SelectMany(l => l.StageCues.OfType<ShotCue>()).Skip(1)
            .OrderByDescending(s => s.Seconds).FirstOrDefault();

    /// <summary>Frames <see cref="BlendFrameSeconds"/> apart from the blend's start to its end.</summary>
    private async Task CaptureBlend(CutsceneSet set, string shot, float delay)
    {
        if (delay > 0f) await WaitSeconds(delay);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        int frame = 0;
        float next = 0f;
        for (float t = 0f; set.Camera.IsBlending; t += (float)GetProcessDeltaTime())
        {
            if (t >= next)
            {
                SaveViewportCapture(ShotDirectory.PathJoin($"cutscene_{shot}_blend_{frame++:00}.png"));
                next += BlendFrameSeconds;
            }
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        SaveViewportCapture(ShotDirectory.PathJoin($"cutscene_{shot}_blend_{frame:00}.png"));
    }
}
