using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Props;
using Ungilded.Story;
using Ungilded.Story.Cutscene;

namespace Ungilded.Dev;

/// <summary>Checks for the cutscene flavour: speaker hops, emotes, the carried glow, floor props, the
/// sigil, the camera shake, splashes, the letterbox and creature shading. Rendered, it also saves a
/// still or a pair of frames of each effect as it happens.</summary>
public partial class CutsceneSpike
{
    private readonly List<CutsceneActor> _hops = new();
    private readonly Dictionary<CutsceneActor, int> _emotesSeen = new();
    private readonly Dictionary<StringName, bool> _propsExpected = new();
    private readonly HashSet<string> _fxSaved = new();
    private int _splashes, _drySplashes, _shakesExpected;
    private float _darkest = 1f;
    private bool _darkExpected;
    private ulong _shotFrame;
    private string _case = "";

    /// <summary>A creature drawn below this shade reads as standing in the dark.</summary>
    private const float DarkShade = 0.95f;

    private void ResetFlavor(string caseName)
    {
        _case = caseName;
        _hops.Clear();
        _emotesSeen.Clear();
        _propsExpected.Clear();
        _splashes = _drySplashes = _shakesExpected = 0;
        _darkest = 1f;
        _darkExpected = false;
    }

    private void WatchFlavor(CutsceneSet set)
    {
        if ((set.Stage.Look?.Dressing as SewerDressing)?.TorchesEnabled == true)
            Check($"{_case}: the set's torches carry motes ({set.MoteTorches})", set.MoteTorches > 0);
        else GD.Print($"[{_case}] torches off, no mote check");
        set.SpeakerHopped += actor =>
        {
            _hops.Add(actor);
            Hold(MeasureHop(actor));
            // The pair is taken on a line that keeps the shot, so only the hop moves between frames.
            bool shotMoves = set.Camera.IsBlending || _shotFrame == Engine.GetProcessFrames();
            if (!Headless && !shotMoves) Hold(CapturePair("hop", 0f, actor.HopPixels * actor.HopStepSeconds + actor.HopTopSeconds * 0.5f));
        };
        set.Splashed += tile =>
        {
            _splashes++;
            if (!set.WetTiles.Contains(tile)) _drySplashes++;
            if (!Headless) Hold(CaptureOnce("splash", 0.1f));
        };
        set.Camera.Shaken += () =>
        {
            if (!Headless) Hold(CapturePair("quake", 0.05f, 0.15f, 0.9f));
        };
        set.CueStarted += cue =>
        {
            if (cue is QuakeCue) _shakesExpected++;
            if (cue is ShotCue) _shotFrame = Engine.GetProcessFrames();
            if (cue is PlaceCue place && set.Creatures.ContainsKey(place.Actor)
                && set.ShadeAt(set.TileToWorld(place.Tile)) < DarkShade)
                _darkExpected = true;
            if (Headless) return;
            switch (cue)
            {
                case EmoteCue emote: Hold(CaptureOnce($"emote_{emote.Emote.ToString().ToLowerInvariant()}", emote.Delay + 0.5f)); break;
                case GlowCue { On: true } glow: Hold(CaptureOnce("glow", glow.Delay + 1.0f)); break;
                case SigilCue sigil: Hold(CaptureOnce("sigil", sigil.Delay + sigil.Seconds)); break;
                case PropCue { Show: true } prop: Hold(CaptureOnce("props", prop.Delay + 0.4f)); break;
                case GradeCue grade: Hold(CaptureOnce("grade", grade.Delay + grade.Seconds)); break;
            }
        };
    }

    /// <summary>Per frame: the darkest a creature has been drawn.</summary>
    private void PollFlavor(CutsceneSet? set)
    {
        if (set == null) return;
        foreach (var actor in set.Actors.Where(a => a.Visible && a.ShadeInDark))
            _darkest = Mathf.Min(_darkest, actor.Shade);
    }

    /// <summary>After a line's own checks: its speaker hopped once and nobody else did, every flavour
    /// cue left its mark, the bars are up and clear of the dialogue box, and creatures are shaded by
    /// the terrain under them.</summary>
    private async Task CheckFlavor(PrologueDirector director, CutsceneSet set, DialogueLine line, string tag)
    {
        float delay = line.StageCues.Select(c => c.Delay).DefaultIfEmpty(0f).Max();
        if (delay > 0f) await WaitSeconds(delay + 0.1f);
        await Task.WhenAll(_pendingCaptures);
        _pendingCaptures.Clear();

        string? speaker = !line.IsNarration && SpeakerActors.TryGetValue(line.Speaker, out var id) ? id : null;
        var hoppers = string.Join(", ", _hops.Select(a => a.Name.ToString()));
        if (speaker == null)
            Check($"{tag}: nobody hops on a narration line ({hoppers})", _hops.Count == 0);
        else
            Check($"{tag}: {speaker} hops once for the line, {_hopPixels:0.#} sprite pixels high ({hoppers})",
                _hops.Count == 1 && _hops[0].Name.ToString() == speaker
                && Mathf.IsEqualApprox(_hopPixels, _hops[0].HopPixels));
        _hops.Clear();
        _hopPixels = 0f;

        foreach (var cue in line.StageCues)
            CheckCueMark(set, cue, tag);
        foreach (var actor in set.Actors)
            _emotesSeen[actor] = actor.Emotes.Count;
        foreach (var (prop, shown) in _propsExpected)
            Check($"{tag}: prop {prop} is {(shown ? "on the floor" : "gone")}", set.HasProp(prop) == shown);

        var bar = director.Letterbox.BottomRect;
        var box = director.Dialogue.BoxRect;
        Check($"{tag}: the letterbox is up and its bottom bar ({bar.Position.Y:0} to {bar.End.Y:0}) is under the dialogue box (ends {box.End.Y:0})",
            director.Letterbox.IsShown && bar.Position.Y >= box.End.Y);
        Check($"{tag}: the top bar ends above the dialogue box", director.Letterbox.TopRect.End.Y <= box.Position.Y);

        foreach (var actor in set.Actors.Where(a => a.Visible && a.ShadeInDark && !a.IsWalking))
            Check($"{tag}: {actor.Name} is shaded as the floor under it ({actor.Shade:0.00})",
                Mathf.Abs(actor.Shade - set.ShadeAt(actor.Position)) < 0.01f);
    }

    private void CheckCueMark(CutsceneSet set, StageCue cue, string tag)
    {
        switch (cue)
        {
            case EmoteCue emote:
            {
                var actor = set.Actor(emote.Actor);
                int before = _emotesSeen.GetValueOrDefault(actor);
                var shown = actor.Emotes.Skip(before).ToList();
                Check($"{tag}: {emote.Emote} pops above {emote.Actor}",
                    shown.Any(r => r.Emote == emote.Emote && r.Height >= actor.Sprite.BodyHeight));
                break;
            }
            case GlowCue glow:
                Check($"{tag}: {glow.Actor}'s glow is {(glow.On ? "on" : "off")}", set.Actor(glow.Actor).GlowOn == glow.On);
                break;
            case PropCue prop:
                _propsExpected[prop.Id] = prop.Show;
                break;
            case SigilCue sigil:
                Check($"{tag}: the sigil wakes to {sigil.Strength:0.0}",
                    set.Sigil != null && Mathf.IsEqualApprox(set.Sigil.Awakening, sigil.Strength));
                break;
            case QuakeCue:
                Check($"{tag}: the camera shook ({set.Camera.Shakes} of {_shakesExpected})", set.Camera.Shakes == _shakesExpected);
                break;
            case GradeCue grade:
                Check($"{tag}: the grade blends to #{grade.Tint.ToHtml(false)}", set.GradeTint == grade.Tint);
                break;
        }
    }

    /// <summary>After a case: the bars are down, every splash was on a wet tile, and the darkest a
    /// creature was drawn.</summary>
    private void CheckFlavorAfter(PrologueDirector director)
    {
        Check($"{_case}: the letterbox is down after the set", !director.Letterbox.IsShown);
        Check($"{_case}: every splash was on a wet tile ({_splashes} splashes)", _drySplashes == 0);
        if (_darkExpected)
            Check($"{_case}: a creature placed past the lit area was drawn darker ({_darkest:0.00})", _darkest < DarkShade);
        else GD.Print($"  {_case}: darkest creature shade {_darkest:0.00}");
    }

    /// <summary>Effect captures still to save. A line waits for them, so each still shows its line.</summary>
    private readonly List<Task> _pendingCaptures = new();

    private void Hold(Task capture) => _pendingCaptures.Add(capture);

    /// <summary>Sprite pixels the last hop reached at its top.</summary>
    private float _hopPixels;

    /// <summary>The highest the hop lifts the sprite, sampled every frame while it runs.</summary>
    private async Task MeasureHop(CutsceneActor actor)
    {
        float seconds = 2 * actor.HopPixels * actor.HopStepSeconds + actor.HopTopSeconds + 0.1f;
        _hopPixels = 0f;
        for (float waited = 0f; waited < seconds; waited += (float)GetProcessDeltaTime())
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            _hopPixels = Mathf.Max(_hopPixels, actor.Lift / actor.SpritePixel);
        }
    }

    private async Task CaptureOnce(string kind, float seconds)
    {
        string name = $"cutscene_fx_{_case}_{kind}.png";
        if (!_fxSaved.Add(name)) return;
        await WaitSeconds(seconds);
        SaveViewportCapture(ShotDirectory.PathJoin(name));
    }

    /// <summary>Frames of one effect at each of <paramref name="times"/>, seconds after it starts.</summary>
    private async Task CapturePair(string kind, params float[] times)
    {
        string first = $"cutscene_fx_{_case}_{kind}_a.png";
        if (!_fxSaved.Add(first)) return;
        float at = 0f;
        for (int i = 0; i < times.Length; i++)
        {
            if (times[i] > at)
            {
                var timer = GetTree().CreateTimer(times[i] - at);
                await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
                at = times[i];
            }
            SaveViewportCapture(ShotDirectory.PathJoin($"cutscene_fx_{_case}_{kind}_{(char)('a' + i)}.png"));
        }
    }
}
