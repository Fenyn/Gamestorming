namespace Delve.Run;

/// <summary>
/// Stable seed mixing for every deterministic roll in a run. FNV-1a over (tag, index, run seed):
/// string.GetHashCode is randomized per .NET process, so it can never anchor "same seed, same run".
///
/// One tag per subsystem ("map", "battle", "fight", "event", "shortrest") keeps the map generator's
/// stream from shifting when an encounter or an event rolls a die.
/// </summary>
public static class RunRng
{
    /// <summary>Non-negative seed derived from the run seed, a per-call index and a subsystem tag.</summary>
    public static int StableSeed(int runSeed, int index, string tag)
    {
        unchecked
        {
            uint h = 2166136261u;
            foreach (char c in tag)
            {
                h ^= c;
                h *= 16777619u;
            }
            h ^= (uint)index;
            h *= 16777619u;
            h ^= (uint)runSeed;
            h *= 16777619u;
            return (int)(h & 0x7FFFFFFF);
        }
    }
}
