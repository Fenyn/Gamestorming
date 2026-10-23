using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;

namespace Ungilded.Story;

/// <summary>
/// Runs the Prologue's <see cref="Beats"/> in order. Narration and black-backdrop dialogue play with
/// the black overlay up. A board-backdrop dialogue prepares the next encounter first and fades the
/// black out over <see cref="BoardRevealSeconds"/>. A set-backdrop dialogue builds its cutscene set
/// behind the black the same way, plays each line's stage cues on it, and frees it after the beat
/// unless the next beat uses the same set. A narration beat with a page that reveals the set builds
/// the next beat's set first, so the page shows it behind the text. An Encounter beat runs through the
/// <see cref="IEncounterRunner"/>, then the black comes back over <see cref="BlackoutSeconds"/> and
/// the runner releases the board. A Defeat prepares and runs the same encounter again. After the
/// last beat the director loads <see cref="TitleScenePath"/>.
/// </summary>
public partial class PrologueDirector : Node
{
    [Export] public Array<PrologueBeat> Beats { get; set; } = new();

    /// <summary>A node that implements <see cref="IEncounterRunner"/>. Empty uses <see cref="StubEncounterRunner"/>.</summary>
    [Export] public Node? EncounterRunnerNode { get; set; }

    /// <summary>Scene loaded after the last beat. Empty stays in this scene.</summary>
    [Export(PropertyHint.File, "*.tscn")] public string TitleScenePath { get; set; } = "";

    /// <summary>Start <see cref="RunAsync"/> from _Ready.</summary>
    [Export] public bool AutoStart { get; set; } = true;

    /// <summary>The beat the auto start begins at. The beats before it are fast-forwarded, not played.</summary>
    [Export] public int StartBeat { get; set; }

    /// <summary>Black to board, before a board lead-in or a fight.</summary>
    [Export] public float BoardRevealSeconds { get; set; } = 1.5f;

    /// <summary>Board to black, after a fight or before a black-backdrop beat.</summary>
    [Export] public float BlackoutSeconds { get; set; } = 0.5f;

    /// <summary>Fires as beat <c>index</c> starts.</summary>
    public event Action<int, PrologueBeat>? BeatStarted;

    /// <summary>Fires after the last beat, before the title scene loads.</summary>
    public event Action? Finished;

    /// <summary>The encounter side. Set it before <see cref="RunAsync"/> to replace the export.</summary>
    public IEncounterRunner Runner { get; set; } = null!;

    public FadeOverlay Fade { get; private set; } = null!;
    public NarrationScreen Narration { get; private set; } = null!;
    public DialogueBox Dialogue { get; private set; } = null!;
    public TutorialPopup Popup { get; private set; } = null!;
    public Letterbox Letterbox { get; private set; } = null!;

    public bool IsRunning { get; private set; }

    /// <summary>Who carries or wears what for the whole run. The dialogue box reads and changes it; a
    /// live set shows it as the glow on each speaker's actor.</summary>
    public Wardrobe Wardrobe { get; } = new();

    private int _prepared;

    public override void _Ready()
    {
        Fade = GetNode<FadeOverlay>("%Fade");
        Narration = GetNode<NarrationScreen>("%Narration");
        Dialogue = GetNode<DialogueBox>("%Dialogue");
        Popup = GetNode<TutorialPopup>("%Popup");
        Letterbox = GetNode<Letterbox>("%Letterbox");
        Dialogue.Wardrobe = Wardrobe;
        Dialogue.WardrobeChanged += ShowWardrobe;
        Dialogue.BeforeLine = PlayCues;
        Narration.PageStarted += line => _ = PlayCues(line);

        if (EncounterRunnerNode is IEncounterRunner runner) Runner = runner;
        else
        {
            if (EncounterRunnerNode != null)
                GD.PushError($"[Prologue] {EncounterRunnerNode.Name} does not implement IEncounterRunner.");
            Runner = new StubEncounterRunner();
        }

        if (AutoStart) _ = RunLogged();
    }

    /// <summary>Play every beat from <paramref name="startBeat"/> on, then load the title scene when
    /// one is set. The beats before <paramref name="startBeat"/> are fast-forwarded first.</summary>
    public async Task RunAsync(int startBeat = 0)
    {
        if (IsRunning) return;
        IsRunning = true;
        Fade.SetOpaque(true);
        _prepared = 0;
        startBeat = Math.Clamp(startBeat, 0, Beats.Count);
        FastForward(startBeat);
        try
        {
            for (int i = startBeat; i < Beats.Count; i++)
            {
                var beat = Beats[i];
                BeatStarted?.Invoke(i, beat);
                await PlayBeat(i, beat);
            }
        }
        finally
        {
            FreeSet();
            IsRunning = false;
        }
        Finished?.Invoke();
        if (TitleScenePath.Length > 0) GetTree().ChangeSceneToFile(TitleScenePath);
    }

    private async Task RunLogged()
    {
        try { await RunAsync(StartBeat); }
        catch (Exception e)
        {
            // A scene change frees the director mid-beat; its abandoned awaits may throw on freed nodes.
            if (IsInstanceValid(this) && IsInsideTree()) GD.PushError($"[Prologue] {e}");
        }
    }

    private async Task PlayBeat(int index, PrologueBeat beat)
    {
        switch (beat.Kind)
        {
            case BeatKind.Narration when beat.Sequence != null:
                await Fade.FadeIn(BlackoutSeconds);
                var revealed = beat.Sequence.Lines.Any(l => l.RevealsSet) ? SetAt(index + 1) : null;
                if (revealed != null) await EnsureSet(revealed);
                var pages = Narration.Play(beat.Sequence);
                // The narration's own black covers the set until a page reveals it.
                if (revealed != null) Fade.SetOpaque(false);
                await pages;
                break;
            case BeatKind.Dialogue when beat.Sequence != null:
                if (beat.Sequence.Backdrop == DialogueBackdrop.Board)
                {
                    int next = NextEncounter(index);
                    if (next > 0) await PrepareEncounter(next);
                    await Fade.FadeOut(BoardRevealSeconds);
                }
                else if (beat.Sequence is { Backdrop: DialogueBackdrop.Set, CutsceneSet: { } set })
                {
                    await EnsureSet(set, beat.Sequence.Lines.FirstOrDefault());
                    await Fade.FadeOut(BoardRevealSeconds);
                }
                else await Fade.FadeIn(BlackoutSeconds);
                await Dialogue.Play(beat.Sequence);
                break;
            case BeatKind.Encounter:
                await PlayEncounter(beat.Encounter);
                break;
            default:
                GD.PushError($"[Prologue] beat {index} ({beat.Kind}) has no sequence.");
                break;
        }
        await LeaveSet(index);
    }

    private async Task PlayEncounter(int encounter)
    {
        while (true)
        {
            await PrepareEncounter(encounter);
            await Fade.FadeOut(BoardRevealSeconds);
            var outcome = await Runner.Run(encounter);
            await Fade.FadeIn(BlackoutSeconds);
            Runner.Release(encounter);
            _prepared = 0;
            if (outcome == EncounterOutcome.Victory) return;
        }
    }

    /// <summary>Prepare <paramref name="encounter"/> behind the black unless it is already prepared.</summary>
    private async Task PrepareEncounter(int encounter)
    {
        if (_prepared == encounter) return;
        await Fade.FadeIn(BlackoutSeconds);
        FreeSet();
        if (_prepared != 0) Runner.Release(_prepared);
        await Runner.Prepare(encounter);
        _prepared = encounter;
    }

    /// <summary>The encounter of the first Encounter beat after <paramref name="index"/>, or 0.</summary>
    private int NextEncounter(int index)
    {
        for (int i = index + 1; i < Beats.Count; i++)
            if (Beats[i].Kind == BeatKind.Encounter) return Beats[i].Encounter;
        return 0;
    }
}
