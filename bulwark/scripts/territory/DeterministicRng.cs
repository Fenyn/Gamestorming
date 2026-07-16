namespace Bulwark.Territory;

/// <summary>
/// Stable seed mixing for the save's deterministic RNG seam (forage daily passes, respawn-window
/// rolls). FNV-1a over (tag, day, world seed) — string.GetHashCode is randomized per .NET process,
/// so it can never anchor save determinism.
/// </summary>
public static class DeterministicRng
{
    public static int StableSeed(int worldSeed, int day, string tag)
    {
        unchecked
        {
            uint h = 2166136261u;
            foreach (char c in tag)
            {
                h ^= c;
                h *= 16777619u;
            }
            h ^= (uint)day;
            h *= 16777619u;
            h ^= (uint)worldSeed;
            h *= 16777619u;
            return (int)(h & 0x7FFFFFFF);
        }
    }
}
