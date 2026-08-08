using Godot;

namespace Bulwark.Fx;

/// <summary>
/// The Stardew-style day/night colour gradient: a pure piecewise-linear ramp from minute-of-day to a
/// light Color. The day runs 360 → 1800 (6:00 → 30:00, i.e. 6 AM the next morning), matching
/// <see cref="Bulwark.Cozy.DayClock"/>.
///
/// Salvaged intact from the deleted 2D HD-2D canvas stack, where it drove a CanvasModulate tint.
/// NOTE: it currently has NO consumer — the 3D world scenes light themselves with fixed rigs. Wiring
/// it up means feeding <see cref="EvaluateTint"/> from GameState's MinuteChanged into a world scene's
/// DirectionalLight3D colour (and/or the WorldEnvironment ambient light colour); the numbers below are
/// tuned as a multiplicative tint, so a light energy curve belongs alongside them, not inside them.
/// </summary>
public static class DayNightGradient
{
    private static readonly Color Dawn = new(0.985f, 0.835f, 0.74f);      // 6:00 — warm pink-orange
    private static readonly Color DayColor = new(0.99f, 0.99f, 0.98f);    // 8:00–17:00
    private static readonly Color DuskColor = new(0.98f, 0.68f, 0.50f);   // 19:00 — golden hour
    private static readonly Color NightColor = new(0.42f, 0.52f, 0.68f);  // 21:30 — moonlit blue
    private static readonly Color DeepNight = new(0.30f, 0.38f, 0.55f);   // 24:00–28:30 — deepest blue

    private static readonly (int Minute, Color Color)[] Keyframes =
    {
        (360, Dawn),        //  6:00 warm dawn
        (480, DayColor),    //  8:00 full day…
        (1020, DayColor),   // 17:00 …holds
        (1140, DuskColor),  // 19:00 golden dusk
        (1290, NightColor), // 21:30 night
        (1440, DeepNight),  // 24:00 deep night…
        (1710, DeepNight),  // 28:30 (4:30 AM) …holds
        (1800, Dawn),       // 30:00 (6:00 AM) back to dawn
    };

    /// <summary>
    /// The light tint for a minute-of-day, piecewise-lerped between the keyframes above.
    /// Out-of-range input clamps to the nearest end of the 360–1800 day span.
    /// </summary>
    public static Color EvaluateTint(int minuteOfDay)
    {
        int m = Mathf.Clamp(minuteOfDay, Keyframes[0].Minute, Keyframes[^1].Minute);

        for (int i = 1; i < Keyframes.Length; i++)
        {
            if (m > Keyframes[i].Minute)
                continue;

            var (fromMinute, fromColor) = Keyframes[i - 1];
            var (toMinute, toColor) = Keyframes[i];
            float t = (m - fromMinute) / (float)(toMinute - fromMinute);
            return fromColor.Lerp(toColor, t);
        }

        return Keyframes[^1].Color; // unreachable after the clamp; keeps the compiler satisfied
    }
}
