using System;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;

namespace Ungilded.Story;

/// <summary>
/// Runs the Prologue's <see cref="Beats"/> in order. Narration and black-backdrop dialogue play with
/// the black overlay up. A board-backdrop dialogue prepares the next encounter first and fades the
/// black out over <see cref="BoardRevealSeconds"/>. An Encounter beat runs through the
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

    public bool IsRunning { get; private set; }

    private int _prepared;

    public override void _Ready()
    {
        Fade = GetNode<FadeOverlay>("%Fade");
        Narration = GetNode<NarrationScreen>("%Narration");
        Dialogue = GetNode<DialogueBox>("%Dialogue");
        Popup = GetNode<TutorialPopup>("%Popup");

        if (EncounterRunnerNode is IEncounterRunner runner) Runner = runner;
        else
        {
            if (EncounterRunnerNode != null)
                GD.PushError($"[Prologue] {EncounterRunnerNode.Name} does not implement IEncounterRunner.");
            Runner = new StubEncounterRunner();
        }

        if (AutoStart) _ = RunLogged();
    }

    /// <summary>Play every beat, then load the title scene when one is set.</summary>
    public async Task RunAsync()
    {
        if (IsRunning) return;
        IsRunning = true;
        Fade.SetOpaque(true);
        _prepared = 0;
        try
        {
            for (int i = 0; i < Beats.Count; i++)
            {
                var beat = Beats[i];
                BeatStarted?.Invoke(i, beat);
                await PlayBeat(i, beat);
            }
        }
        finally
        {
            IsRunning = false;
        }
        Finished?.Invoke();
        if (TitleScenePath.Length > 0) GetTree().ChangeSceneToFile(TitleScenePath);
    }

    private async Task RunLogged()
    {
        try { await RunAsync(); }
        catch (Exception e) { GD.PushError($"[Prologue] {e}"); }
    }

    private async Task PlayBeat(int index, PrologueBeat beat)
    {
        switch (beat.Kind)
        {
            case BeatKind.Narration when beat.Sequence != null:
                await Fade.FadeIn(BlackoutSeconds);
                await Narration.Play(beat.Sequence);
                break;
            case BeatKind.Dialogue when beat.Sequence != null:
                if (beat.Sequence.Backdrop == DialogueBackdrop.Board)
                {
                    int next = NextEncounter(index);
                    if (next > 0) await PrepareEncounter(next);
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
