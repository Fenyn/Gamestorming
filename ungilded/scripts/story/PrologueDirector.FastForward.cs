namespace Ungilded.Story;

/// <summary>A start past beat 0: the state the skipped beats would have left.</summary>
public partial class PrologueDirector
{
    /// <summary>Reset the run, then apply what beats 0 to <paramref name="startBeat"/> - 1 leave when
    /// played: every accessory cue of their lines in the <see cref="Wardrobe"/>, and each won
    /// encounter through <see cref="IEncounterRunner.Skip"/>.</summary>
    private void FastForward(int startBeat)
    {
        Wardrobe.Clear();
        for (int i = 0; i < startBeat; i++)
        {
            var beat = Beats[i];
            if (beat.Kind == BeatKind.Encounter) Runner.Skip(beat.Encounter);
            else if (beat.Sequence != null)
                foreach (var line in beat.Sequence.Lines)
                foreach (var cue in line.AccessoryCues)
                    Wardrobe.Apply(cue);
        }
    }
}
