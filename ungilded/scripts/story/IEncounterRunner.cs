using System.Threading.Tasks;

namespace Ungilded.Story;

/// <summary>How an encounter ended.</summary>
public enum EncounterOutcome
{
    Victory,
    /// <summary>The party fell. The director prepares and runs the same encounter again.</summary>
    Defeat,
}

/// <summary>
/// The combat side of the Prologue. <see cref="PrologueDirector"/> calls it in this order for each
/// encounter: <see cref="Prepare"/> while the screen is black (or before a lead-in over the board),
/// then <see cref="Run"/> once the board shows, then <see cref="Release"/> after the screen is black
/// again. The director knows nothing else about combat.
/// </summary>
public interface IEncounterRunner
{
    /// <summary>Build the board for encounter <paramref name="index"/> (1 to 4) and stop before the
    /// first turn. The screen is black while this runs.</summary>
    Task Prepare(int index);

    /// <summary>Play encounter <paramref name="index"/> on the prepared board until it ends. Mid-fight
    /// lines, tutorial popups and the Encounter 4 victory and closing lines belong here.</summary>
    Task<EncounterOutcome> Run(int index);

    /// <summary>Free everything <see cref="Prepare"/> and <see cref="Run"/> made. The screen is black.</summary>
    void Release(int index);
}
