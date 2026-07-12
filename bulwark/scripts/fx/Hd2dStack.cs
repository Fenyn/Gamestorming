using Bulwark.Autoload;
using Godot;

namespace Bulwark.Fx;

/// <summary>
/// One-node HD-2D ambiance stack: instance into any world scene. Carries the WorldEnvironment
/// (canvas HDR glow — lamps/fire bloom), a CanvasModulate for time-of-day tinting, and the
/// full-screen tilt-shift/vignette/grade post pass (assets/shaders/hd2d_post.gdshader — tune the
/// uniforms on the %Post material per scene).
///
/// Two tint modes:
/// - <see cref="FollowClock"/> (default, exterior scenes): the tint tracks GameState's day clock
///   continuously via <see cref="EvaluateTint"/> — Stardew-style dawn→day→dusk→night gradient,
///   one Color assign per in-game minute.
/// - Discrete presets (interiors / standalone F6 with no GameState): set FollowClock false (or run
///   without the autoload) and the node falls back to <see cref="Apply"/> with <see cref="Preset"/>.
/// PointLight2D props punch through the night tint either way.
/// </summary>
public partial class Hd2dStack : Node2D
{
    public enum TimeOfDay { Day, Dusk, Night, Interior }

    /// <summary>Starting tint preset, applied on ready when not following the clock.</summary>
    [Export] public TimeOfDay Preset { get; set; } = TimeOfDay.Day;

    /// <summary>
    /// When true and the GameState autoload exists, the tint continuously follows the day clock.
    /// Set false for interiors (then drive the tint via <see cref="Apply"/>).
    /// </summary>
    [Export] public bool FollowClock { get; set; } = true;

    // ---- Time-of-day gradient (minutes since midnight; the day runs 360 → 1800 = 6:00 → 30:00) ----

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
    /// Pure gradient: the CanvasModulate tint for a minute-of-day, piecewise-lerped between the
    /// keyframes above. Out-of-range input clamps to the nearest end of the 360–1800 day span.
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

    private CanvasModulate _tint = null!;
    private GameState? _followed;

    public override void _Ready()
    {
        _tint = GetNode<CanvasModulate>("%Tint");

        if (FollowClock && GameState.Instance != null)
        {
            _followed = GameState.Instance;
            _followed.MinuteChanged += OnMinuteChanged;
            _tint.Color = EvaluateTint(_followed.Clock.MinuteOfDay);
        }
        else
        {
            Apply(Preset); // interiors / standalone F6 fallback
        }
    }

    public override void _ExitTree()
    {
        // Mandatory: the autoload outlives world scenes — a dangling handler would leak this node.
        if (_followed != null)
        {
            _followed.MinuteChanged -= OnMinuteChanged;
            _followed = null;
        }
    }

    /// <summary>Discrete preset tint (interiors, scenes not following the clock).</summary>
    public void Apply(TimeOfDay preset)
    {
        Preset = preset;
        _tint.Color = preset switch
        {
            TimeOfDay.Dusk => DuskColor,
            TimeOfDay.Night => NightColor,
            TimeOfDay.Interior => new Color(0.94f, 0.88f, 0.80f),
            _ => DayColor,
        };
    }

    private void OnMinuteChanged()
    {
        _tint.Color = EvaluateTint(_followed!.Clock.MinuteOfDay);
    }
}
