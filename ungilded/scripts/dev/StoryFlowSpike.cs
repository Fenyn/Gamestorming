using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;
using Ungilded.Autoload;
using Ungilded.Story;

namespace Ungilded.Dev;

/// <summary>
/// Story layer check. Headless it loads every dialogue sequence and checks line counts against the
/// spec, empty text, speaker names and narration flags; checks both portrait sets; runs the
/// Prologue director through every beat with <see cref="StubEncounterRunner"/> and checks the beat
/// order, the runner calls and the backdrop behind each line; checks who carries or wears the
/// spectacles on each line; prepares Encounter 2 with the real runner and checks the glow on the
/// hero tokens through Scene 3b; and checks the tutorial popup queue.
/// Rendered, it also saves the title, narration, dialogue, token glow and popup captures.
/// </summary>
public partial class StoryFlowSpike : SpikeBase
{
    [Export] public Array<DialogueSequence> Sequences { get; set; } = new();
    [Export] public Array<SpeakerPortraits> Portraits { get; set; } = new();
    [Export] public PackedScene? PrologueScene { get; set; }
    [Export] public PackedScene? TitleScene { get; set; }

    /// <summary>The combat harness, shown behind the board captures.</summary>
    [Export] public PackedScene? BoardScene { get; set; }

    [Export(PropertyHint.Dir)] public string ShotDirectory { get; set; } = "";
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);

    /// <summary>Fade length used for the director run, so the spike stays quick.</summary>
    [Export] public float QuickFadeSeconds { get; set; } = 0.05f;

    [Export] public float RunTimeoutSeconds { get; set; } = 60f;

    /// <summary>Seconds the combat harness gets to build and frame its board before a capture.</summary>
    [Export] public float BoardSettleSeconds { get; set; } = 6f;

    /// <summary>Line counts per sequence id, from designs/ungilded_opening.md sections 2 and 8.</summary>
    private static readonly System.Collections.Generic.Dictionary<string, int> ExpectedLines = new()
    {
        ["tutorial_narrative_intro"] = 6,
        ["tutorial_scene1_sewer_banter"] = 15,
        ["tutorial_scene2_rat_encounter"] = 4,
        ["tutorial_scene3_post_enc1"] = 11,
        ["tutorial_scene3_rats_appear"] = 9,
        ["tutorial_scene4_dead_truthseeker"] = 20,
        ["tutorial_scene5_flanking"] = 9,
        ["tutorial_scene6_post_enc3"] = 16,
        ["tutorial_scene7_boss_chamber"] = 4,
        ["encounter1_friend_strike"] = 1,
        ["encounter4_half_hp"] = 1,
        ["encounter4_quarter_hp"] = 2,
        ["encounter4_victory"] = 2,
        ["encounter4_closing"] = 1,
    };

    private static readonly string[] Speakers = { "The Player", "The Friend" };

    /// <summary>Beat starts and runner calls in the order spec section 1 plays them.</summary>
    private static readonly string[] ExpectedTrace =
    {
        "narration:tutorial_narrative_intro",
        "dialogue:tutorial_scene1_sewer_banter:set",
        "dialogue:tutorial_scene2_rat_encounter:board", "prepare 1",
        "encounter:1", "run 1", "release 1",
        "dialogue:tutorial_scene3_post_enc1:set",
        "dialogue:tutorial_scene3_rats_appear:board", "prepare 2",
        "encounter:2", "run 2", "release 2",
        "dialogue:tutorial_scene4_dead_truthseeker:set",
        "dialogue:tutorial_scene5_flanking:set",
        "encounter:3", "prepare 3", "run 3", "release 3",
        "dialogue:tutorial_scene6_post_enc3:set",
        "dialogue:tutorial_scene7_boss_chamber:set",
        "encounter:4", "prepare 4", "run 4", "release 4",
    };

    protected override string Banner => "==================== STORY FLOW SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (PrologueScene == null || TitleScene == null || BoardScene == null)
        {
            AbortFail("[StoryFlow] a scene export is not assigned.");
            return;
        }

        CheckSequences();
        CheckPortraits();
        CheckSceneLinks();
        await CheckDirectorRun();
        await CheckStartBeats();
        await CheckPagesFit();
        await CheckAccessoryFrames();
        await CheckTokenGlow();
        await CheckPopupQueue();
        if (!Headless) await SaveCaptures();
    }

    private void CheckSequences()
    {
        var seen = new HashSet<string>();
        foreach (var sequence in Sequences)
        {
            seen.Add(sequence.Id);
            bool known = ExpectedLines.TryGetValue(sequence.Id, out int expected);
            Check($"{sequence.Id}: {sequence.Lines.Count} lines (spec {(known ? expected : -1)})",
                known && sequence.Lines.Count == expected);
            var lines = sequence.Lines.ToList();
            Check($"{sequence.Id}: no line has empty text", lines.All(l => l.Text.Trim().Length > 0));
            Check($"{sequence.Id}: speakers are The Player, The Friend or empty",
                lines.All(l => l.Speaker.Length == 0 || Speakers.Contains(l.Speaker)));
            Check($"{sequence.Id}: narration lines and only those have no speaker",
                lines.All(l => l.IsNarration == (l.Speaker.Length == 0)));
            Check($"{sequence.Id}: no Unity italic tags", lines.All(l => !l.Text.Contains("<i>")));
        }
        Check("every spec sequence is loaded", ExpectedLines.Keys.All(seen.Contains));
    }

    private void CheckPortraits()
    {
        foreach (var name in Speakers)
        {
            var set = Portraits.FirstOrDefault(p => p.Speaker == name);
            Check($"{name} has a portrait set", set != null);
            if (set == null) continue;
            foreach (var emotion in System.Enum.GetValues<Emotion>())
            {
                var talk = set.TalkingFor(emotion);
                Check($"{name} {emotion}: rests on \"{set.For(emotion)}\", talks with \"{talk}\"",
                    set.Has(set.For(emotion)) && set.Has(talk) && talk != set.For(emotion)
                    && set.Frames!.GetFrameCount(talk) > 1 && set.Frames.GetAnimationLoop(talk));
            }
        }
    }

    /// <summary>The title opens the Prologue, the Prologue returns to the title, and the title is the main scene.</summary>
    private void CheckSceneLinks()
    {
        var title = TitleScene!.Instantiate<TitleScreen>();
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        Check($"the title's Prologue button loads {title.PrologueScenePath}",
            title.PrologueScenePath == PrologueScene.ResourcePath);
        Check($"the Prologue ends on {director.TitleScenePath}", director.TitleScenePath == TitleScene.ResourcePath);
        Check("the title is the main scene",
            ProjectSettings.GetSetting("application/run/main_scene").AsString() == TitleScene.ResourcePath);
        title.Free();
        director.Free();
    }

    private async Task CheckDirectorRun()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        director.TitleScenePath = "";
        director.BoardRevealSeconds = QuickFadeSeconds;
        director.BlackoutSeconds = QuickFadeSeconds;
        AddChild(director);
        director.Narration.FadeSeconds = QuickFadeSeconds;

        var stub = new StubEncounterRunner();
        director.Runner = stub;
        var trace = new List<string>();
        PrologueBeat? beat = null;
        var linesShown = new System.Collections.Generic.Dictionary<string, int>();
        bool backdropsRight = true;
        director.BeatStarted += (_, b) => { beat = b; trace.Add(b.Describe()); };
        stub.Called += trace.Add;
        director.Narration.PageStarted += _ => Count(linesShown, beat);
        director.Dialogue.LineStarted += _ =>
        {
            Count(linesShown, beat);
            bool board = beat?.Sequence?.Backdrop is DialogueBackdrop.Board or DialogueBackdrop.Set;
            if (board ? !director.Fade.IsClear : !director.Fade.IsOpaque)
            {
                backdropsRight = false;
                GD.Print($"  backdrop wrong for {beat?.Describe()}");
            }
        };
        RecordWardrobeAtBeats(director);
        var wornFaces = RecordWornFaces(director, () => beat);
        var carriers = RecordCarriers(director, () => beat);
        bool finished = false;
        director.Finished += () => finished = true;

        var run = director.RunAsync();
        for (float waited = 0; !run.IsCompleted && waited < RunTimeoutSeconds; waited += (float)GetProcessDeltaTime())
        {
            if (director.Dialogue.IsShowing) director.Dialogue.Advance();
            if (director.Narration.IsWaiting) director.Narration.Advance();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }

        Check("the director ran every beat", run.IsCompletedSuccessfully && finished);
        Check($"beat order and runner calls match the spec ({trace.Count} entries)", trace.SequenceEqual(ExpectedTrace));
        if (!trace.SequenceEqual(ExpectedTrace)) GD.Print("  trace: " + string.Join(" | ", trace));
        Check("each line showed over its backdrop (black or board)", backdropsRight);
        foreach (var b in director.Beats.Where(b => b.Sequence != null))
        {
            linesShown.TryGetValue(b.Sequence!.Id, out int shown);
            Check($"{b.Sequence.Id}: {shown} of {b.Sequence.Lines.Count} lines shown", shown == b.Sequence.Lines.Count);
        }
        CheckWornFaces(director, wornFaces);
        CheckCarriers(carriers);
        Check("the screen is black after the last encounter", director.Fade.IsOpaque);
        Check("no story modal is left open", ModalStack.Instance?.Count == 0);
        director.QueueFree();
    }

    /// <summary>Every page of every dialogue-box sequence fits the text area above the caret strip.</summary>
    private async Task CheckPagesFit()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        AddChild(director);
        var box = director.Dialogue;
        foreach (var sequence in Sequences.Where(s => !IsIntro(s)))
        {
            var clipped = new List<string>();
            int pages = 0, wrongFaces = 0;
            var play = box.Play(sequence);
            while (!play.IsCompleted)
            {
                await NextFrame();
                if (box.IsRevealing)
                {
                    if (!FaceMatches(box, talking: true)) wrongFaces++;
                    box.Advance();
                }
                await NextFrame();
                if (play.IsCompleted) break;
                pages++;
                if (!FaceMatches(box, talking: false)) wrongFaces++;
                if (!box.PageFits)
                    clipped.Add($"{box.PageText[..System.Math.Min(ClipQuoteLength, box.PageText.Length)]}... ({box.PageOverflow} px over)");
                box.Advance();
            }
            Check($"{sequence.Id}: all {pages} pages fit the box", clipped.Count == 0);
            Check($"{sequence.Id}: portraits talk while typing and rest after ({wrongFaces} wrong)", wrongFaces == 0);
            foreach (var page in clipped) GD.Print($"  clipped: {page}");
        }
        director.QueueFree();
        await NextFrame();
    }

    private const int ClipQuoteLength = 40;

    private bool FaceMatches(DialogueBox box, bool talking)
    {
        var line = box.CurrentLine;
        var set = line == null || line.IsNarration ? null : Portraits.FirstOrDefault(p => p.Speaker == line.Speaker);
        if (set == null) return box.PortraitAnimation == "";
        return box.PortraitAnimation == (talking ? set.TalkingFor(line!.Emotion) : set.For(line!.Emotion));
    }

    private static bool IsIntro(DialogueSequence sequence) =>
        sequence.Backdrop == DialogueBackdrop.Black && sequence.Lines.All(l => l.IsNarration) && sequence.Lines.Count > 1;

    private static void Count(System.Collections.Generic.Dictionary<string, int> counts, PrologueBeat? beat)
    {
        string id = beat?.Sequence?.Id ?? "";
        counts[id] = counts.GetValueOrDefault(id) + 1;
    }

    private async Task CheckPopupQueue()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        AddChild(director);
        var popup = director.Popup;
        string word = popup.Highlight("3 actions");
        Check($"the highlight uses the ember colour ({word})", word.Contains(popup.HighlightColor.ToHtml(false)));

        var first = popup.ShowMessage($"Each turn you have {word}.");
        var second = popup.ShowMessage("Second message.");
        await NextFrame();
        Check("the popup opens and holds a modal", popup.IsShowing && ModalStack.Instance?.Holds(popup) == true);
        popup.Dismiss();
        await NextFrame();
        Check("dismiss completes the first message only", first.IsCompleted && !second.IsCompleted && popup.IsShowing);
        popup.Dismiss();
        await NextFrame();
        Check("the second dismiss closes the popup", second.IsCompleted && !popup.IsShowing);

        var step = popup.OpenStep(new TipRequest("step", "Step tip."));
        await NextFrame();
        Check("a step tip shows without a modal",
            popup.StepShowing && !popup.IsShowing && ModalStack.Instance?.Holds(popup) != true);
        var rule = popup.ShowMessage("Rule over a step.");
        await NextFrame();
        Check("a rule tip covers the step tip and holds a modal", popup.IsShowing && !popup.StepShowing);
        popup.Dismiss();
        await NextFrame();
        Check("the step tip returns after the rule tip", rule.IsCompleted && popup.StepShowing);
        popup.Dismiss();
        await NextFrame();
        Check("dismiss leaves a step tip open", popup.StepShowing);
        step.Dispose();
        await NextFrame();
        Check("disposing the handle closes the step tip",
            !popup.StepShowing && popup.Current == null && popup.Records[^2].Closed);
        director.QueueFree();
        await NextFrame();
    }

    private async Task NextFrame()
    {
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
