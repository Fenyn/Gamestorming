using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.Data;
using Ungilded.Content;
using Ungilded.Story;
using Ungilded.Tutorial.Encounters;

namespace Ungilded.Dev;

/// <summary>
/// Start-beat check: the director started at each of <see cref="JumpBeats"/> skips the earlier
/// encounters in order and starts on that beat with the spectacles where the full director run had
/// them. With the real runner the start beat's encounter prepares, the hero tokens glow from that
/// wardrobe, and the journal and the Player's HP match what the skipped encounters leave.
/// </summary>
public partial class StoryFlowSpike
{
    /// <summary>Beats the check starts the director at: Encounter 1 and Encounter 4.</summary>
    [Export] public int[] JumpBeats { get; set; } = { 3, 12 };

    /// <summary>Who has the spectacles as each beat starts in the full director run.</summary>
    private readonly Dictionary<int, (AccessoryState Friend, AccessoryState Player)> _wardrobeAtBeat = new();

    private void RecordWardrobeAtBeats(PrologueDirector director) =>
        director.BeatStarted += (index, _) => _wardrobeAtBeat[index] = SpectaclesOf(director.Wardrobe);

    private static (AccessoryState Friend, AccessoryState Player) SpectaclesOf(Wardrobe wardrobe) =>
        (wardrobe.StateOf(Friend, Spectacles), wardrobe.StateOf(Player, Spectacles));

    private async Task CheckStartBeats()
    {
        foreach (int beat in JumpBeats)
        {
            await CheckStubStart(beat);
            await CheckRunnerStart(beat);
        }
    }

    private PrologueDirector QuickDirector()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        director.TitleScenePath = "";
        director.BoardRevealSeconds = QuickFadeSeconds;
        director.BlackoutSeconds = QuickFadeSeconds;
        AddChild(director);
        director.Narration.FadeSeconds = QuickFadeSeconds;
        return director;
    }

    /// <summary>The runner calls before beat <paramref name="beat"/>'s own: one skip per earlier encounter.</summary>
    private static IEnumerable<string> SkipsBefore(PrologueDirector director, int beat) =>
        director.Beats.Take(beat).Where(b => b.Kind == BeatKind.Encounter).Select(b => $"skip {b.Encounter}");

    private async Task CheckStubStart(int beat)
    {
        var director = QuickDirector();
        var stub = new StubEncounterRunner();
        director.Runner = stub;
        var started = new List<int>();
        (AccessoryState, AccessoryState)? atStart = null;
        director.BeatStarted += (index, _) =>
        {
            started.Add(index);
            atStart ??= SpectaclesOf(director.Wardrobe);
        };
        var run = director.RunAsync(beat);
        for (float waited = 0; !run.IsCompleted && waited < RunTimeoutSeconds; waited += (float)GetProcessDeltaTime())
        {
            if (director.Dialogue.IsShowing) director.Dialogue.Advance();
            if (director.Narration.IsWaiting) director.Narration.Advance();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        var skips = SkipsBefore(director, beat).ToList();
        int encounter = director.Beats[beat].Encounter;
        Check($"start at beat {beat}: plays beats {beat} to {director.Beats.Count - 1} only",
            run.IsCompletedSuccessfully && started.SequenceEqual(Enumerable.Range(beat, director.Beats.Count - beat)));
        Check($"start at beat {beat}: skips {skips.Count} encounters, then prepares Encounter {encounter}",
            stub.Calls.Take(skips.Count + 1).SequenceEqual(skips.Append($"prepare {encounter}")));
        bool known = _wardrobeAtBeat.TryGetValue(beat, out var full);
        Check($"start at beat {beat}: spectacles {atStart} as in the full run ({(known ? full.ToString() : "not recorded")})",
            known && atStart.Equals(full));
        director.QueueFree();
        await NextFrame();
    }

    private async Task CheckRunnerStart(int beat)
    {
        var director = QuickDirector();
        if (director.Runner is not PrologueEncounterRunner runner)
        {
            Check("the Prologue uses the real encounter runner", false);
            director.QueueFree();
            return;
        }
        int encounter = director.Beats[beat].Encounter;
        bool prepared = false;
        runner.Prepared += index => prepared |= index == encounter;
        _ = director.RunAsync(beat);
        for (float waited = 0; !prepared && waited < RunTimeoutSeconds; waited += (float)GetProcessDeltaTime())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        Check($"start at beat {beat}: Encounter {encounter} prepares with the real runner",
            prepared && runner.CurrentEncounter == encounter);
        var player = runner.TokenOf(Player);
        var friend = runner.TokenOf(Friend);
        _wardrobeAtBeat.TryGetValue(beat, out var full);
        if (player != null && friend != null)
            Check($"start at beat {beat}: token glow follows the wardrobe (Friend {friend.GlowLit}, Player {player.GlowLit})",
                friend.GlowLit == (full.Friend != AccessoryState.Hidden)
                && player.GlowLit == (full.Player != AccessoryState.Hidden)
                && (full.Player != AccessoryState.Worn || IsWorn(player)));
        else Check($"start at beat {beat}: both hero tokens exist", false);

        bool afterE2 = encounter > 2;
        var journal = runner.Journal;
        string rat = PrologueBestiary.SewerRatId;
        Check($"start at beat {beat}: Sewer Rat {(afterE2 ? "Strikes and AC known" : "nothing known")}",
            journal.IsFieldRevealed(rat, CreatureKnowledgeField.Strikes) == afterE2
            && journal.IsFieldRevealed(rat, CreatureKnowledgeField.AC) == afterE2);
        Check($"start at beat {beat}: the species of earlier encounters are listed in the journal",
            encounter == 1 || journal.IsEncountered(rat) && journal.IsEncountered(PrologueBestiary.ViciousSewerRatId) == encounter > 3);
        var hp = runner.Player!.Health;
        Check($"start at beat {beat}: the Player has {hp.CurrentHP}/{hp.MaxHP} HP (full)", hp.CurrentHP == hp.MaxHP);

        director.QueueFree();
        await NextFrame();
    }
}
