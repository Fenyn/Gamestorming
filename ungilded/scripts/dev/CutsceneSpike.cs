using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;
using Ungilded.Autoload;
using Ungilded.Story;
using Ungilded.Story.Cutscene;
using Ungilded.Tutorial.Encounters;

namespace Ungilded.Dev;

/// <summary>
/// Plays every set-backdrop scene through the Prologue director with the real encounter runner, one
/// case per run of set beats: the last intro pages and Scene 1, Scene 3a, Scenes 4 and 5 (one set),
/// Scenes 6 and 7 (two sets). Checks that each set builds with no combat scene, fires every stage cue
/// with its line, keeps the actors on floor tiles, keeps each speaker in frame above the dialogue box
/// and clear of walls, and frees itself; then that the next encounter still prepares on the combat
/// board. Rendered, it saves the revealing page, every line that changes the shot and the board
/// after each case. UNGILDED_CUTSCENE (comma list of case names: s1, s3a, s4, s6) runs only those.
/// </summary>
public partial class CutsceneSpike : SpikeBase
{
    [Export] public PackedScene? PrologueScene { get; set; }
    [Export] public DialogueSequence? Intro { get; set; }
    [Export] public DialogueSequence? Scene1 { get; set; }
    [Export] public DialogueSequence? Scene3a { get; set; }
    [Export] public DialogueSequence? Scene4 { get; set; }
    [Export] public DialogueSequence? Scene5 { get; set; }
    [Export] public DialogueSequence? Scene6 { get; set; }
    [Export] public DialogueSequence? Scene7 { get; set; }

    /// <summary>The intro pages played, counted from its end.</summary>
    [Export] public int IntroPages { get; set; } = 2;

    [Export] public string ShotDirectory { get; set; } = "res://dev_shots";

    /// <summary>Seconds the revealing page shows before its capture, rendered.</summary>
    [Export] public float RevealHoldSeconds { get; set; } = 8f;

    /// <summary>Seconds into the revealing page of the crossfade capture, rendered.</summary>
    [Export] public float CrossfadeCaptureSeconds { get; set; } = 0.6f;

    /// <summary>Longest wait for a camera blend before a line is checked.</summary>
    [Export] public float BlendWaitSeconds { get; set; } = 8f;

    /// <summary>Longest run of one case.</summary>
    [Export] public float RunTimeoutSeconds { get; set; } = 240f;

    /// <summary>Height above a tile the sight and frame checks aim at, metres: an actor's chest.</summary>
    [Export] public float SightHeight { get; set; } = 0.8f;

    /// <summary>Sewer wall rise in corner units, as the sight check expects.</summary>
    [Export] public int WallHeightUnits { get; set; } = 16;

    /// <summary>Top of the dialogue box as a fraction of the viewport height. A speaker's chest
    /// must show above it.</summary>
    [Export] public float DialogueBoxTop { get; set; } = 0.69f;

    protected override string Banner => "==================== CUTSCENE SPIKE ====================";

    /// <summary>One run of set beats and the encounter that follows them. Each scene names its
    /// captures.</summary>
    private sealed record Case(string Name, int Encounter, int Sets, bool WithIntro, (string Shot, DialogueSequence Sequence)[] Scenes);

    private DialogueLine? _page;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (PrologueScene == null || Intro == null || Scene1 == null || Scene3a == null || Scene4 == null
            || Scene5 == null || Scene6 == null || Scene7 == null)
        {
            AbortFail("[Cutscene] a scene or sequence export is not assigned.");
            return;
        }

        var director = PrologueScene.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        director.TitleScenePath = "";
        AddChild(director);
        var runner = director.Runner as PrologueEncounterRunner;
        Check("the Prologue uses the real encounter runner", runner != null);
        director.Narration.PageStarted += line =>
        {
            _page = line;
            if (line.RevealsSet && !Headless) _ = CaptureAfter(CrossfadeCaptureSeconds, "cutscene_page6_crossfade.png");
        };

        var only = OS.GetEnvironment("UNGILDED_CUTSCENE").Split(',', System.StringSplitOptions.RemoveEmptyEntries);
        foreach (var run in Cases())
        {
            if (only.Length > 0 && !only.Contains(run.Name)) continue;
            GD.Print($"  --- case {run.Name}");
            await RunCase(director, runner, run);
        }
        director.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private Case[] Cases() => new[]
    {
        new Case("s1", 1, 1, true, new[] { ("s1", Scene1!) }),
        new Case("s3a", 2, 1, false, new[] { ("s3a", Scene3a!) }),
        new Case("s4", 3, 1, false, new[] { ("s4", Scene4!), ("s5", Scene5!) }),
        new Case("s6", 4, 2, false, new[] { ("s6", Scene6!), ("s7", Scene7!) }),
    };

    private async Task RunCase(PrologueDirector director, PrologueEncounterRunner? runner, Case run)
    {
        var beats = new Array<PrologueBeat>();
        var pages = new DialogueSequence();
        if (run.WithIntro)
        {
            pages = new DialogueSequence { Id = Intro!.Id, Lines = new Array<DialogueLine>(Intro.Lines.TakeLast(IntroPages)) };
            beats.Add(new PrologueBeat { Kind = BeatKind.Narration, Sequence = pages });
            Check("an intro page reveals the set", pages.Lines.Any(l => l.RevealsSet));
        }
        foreach (var (_, sequence) in run.Scenes)
        {
            Check($"{sequence.Id} plays on a cutscene set", sequence.Backdrop == DialogueBackdrop.Set && sequence.CutsceneSet != null);
            CheckCameraGrammar(sequence.Id, sequence);
            beats.Add(new PrologueBeat { Kind = BeatKind.Dialogue, Sequence = sequence });
        }
        director.Beats = beats;
        ResetFlavor(run.Name);
        ResetBlends(run.Scenes);

        var fired = new List<StageCue>();
        var sets = new List<CutsceneSet>();
        void OnSet(CutsceneSet? built)
        {
            if (built == null) return;
            sets.Add(built);
            // The runner keeps its combat scene between fights, released and disabled.
            Check($"{run.Name}: the set builds with no live combat board", runner is { CurrentEncounter: 0 }
                && (runner.Scene == null || runner.Scene.ProcessMode == ProcessModeEnum.Disabled));
            built.CueStarted += fired.Add;
            WatchFlavor(built);
            WatchBlends(built);
        }
        director.SetChanged += OnSet;
        void Poll()
        {
            PollFlavor(director.LiveSet);
            PollBlend(director.LiveSet);
        }
        GetTree().ProcessFrame += Poll;

        var task = director.RunAsync();
        DialogueLine? handled = null;
        bool revealChecked = false, cuesInStep = true;
        int seen = 0;
        var shown = run.Scenes.ToDictionary(s => s.Sequence, _ => 0);
        var framed = new HashSet<CutsceneSet>();
        void CheckCues(DialogueLine line)
        {
            var since = fired.Skip(seen).ToList();
            seen = fired.Count;
            if (since.SequenceEqual(line.StageCues)) return;
            cuesInStep = false;
            GD.Print($"  cues out of step at \"{Quote(line)}\": {since.Count} fired, {line.StageCues.Count} authored");
        }
        for (float waited = 0; !task.IsCompleted && waited < RunTimeoutSeconds; waited += (float)GetProcessDeltaTime())
        {
            var set = director.LiveSet;
            bool setShows = !director.Fade.IsOpaque && !(director.Narration.IsShowing && !director.Narration.ShowsSet);
            if (set != null && setShows && framed.Add(set))
                Check($"{run.Name}: the set has a camera shot on the first frame it shows", set.Camera.Shot.Distance > 0f);
            if (director.Narration.IsWaiting && _page != handled && _page != null)
            {
                handled = _page;
                CheckCues(_page);
                if (_page.RevealsSet && set != null)
                {
                    await CheckReveal(director, set);
                    revealChecked = true;
                }
                director.Narration.Advance();
            }
            else if (director.Dialogue.CurrentLine is { } line && line != handled && set != null)
            {
                handled = line;
                CheckCues(line);
                var (shot, sequence) = run.Scenes.First(s => s.Sequence.Lines.Contains(line));
                shown[sequence]++;
                int number = sequence.Lines.IndexOf(line) + 1;
                await CheckLine(director, set, line, $"{shot} line {number}", $"cutscene_{shot}_{number:00}.png", number == 1);
                await CheckFlavor(director, set, line, $"{shot} line {number}");
                director.Dialogue.Advance();
            }
            else if (director.Dialogue.IsShowing && director.Dialogue.CurrentLine == handled)
                director.Dialogue.Advance();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        director.SetChanged -= OnSet;
        GetTree().ProcessFrame -= Poll;

        string names = string.Join(" and ", run.Scenes.Select(s => s.Shot));
        Check($"{run.Name}: the director played {names}", task.IsCompletedSuccessfully);
        if (task.IsFaulted) GD.PushError($"[Cutscene] director run failed: {task.Exception}");
        Check($"{run.Name}: {sets.Count} set(s) built (expected {run.Sets})", sets.Count == run.Sets);
        if (run.WithIntro) Check("the revealing page was checked", revealChecked);
        foreach (var (shot, sequence) in run.Scenes)
            Check($"{shot}: every line showed ({shown[sequence]} of {sequence.Lines.Count})", shown[sequence] == sequence.Lines.Count);
        int authored = pages.Lines.Concat(run.Scenes.SelectMany(s => s.Sequence.Lines)).Sum(l => l.StageCues.Count);
        Check($"{run.Name}: every stage cue fired once with its line ({fired.Count} of {authored})", fired.Count == authored && cuesInStep);

        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check($"{run.Name}: the set is freed after {run.Scenes[^1].Shot}",
            director.LiveSet == null && sets.All(s => !IsInstanceValid(s)));
        Check($"{run.Name}: the screen is black after {run.Scenes[^1].Shot}", director.Fade.IsOpaque);
        CheckFlavorAfter(director);
        CheckBlendsAfter();

        if (runner != null) await CheckEncounterAfter(director, runner, run.Encounter);
    }

    private const int QuoteLength = 32;

    private static string Quote(DialogueLine line) =>
        line.Text.Length <= QuoteLength ? line.Text : line.Text[..QuoteLength] + "...";
}
