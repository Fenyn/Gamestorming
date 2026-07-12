using Bulwark.Autoload;
using Bulwark.Fx;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the day/night lighting cycle: the pure
/// <see cref="Hd2dStack.EvaluateTint"/> gradient (anchor colors, warmth/coolness at key hours,
/// monotonic darkening into midnight, full-range sanity, out-of-range clamping) plus the live
/// hd2d_stack scene in both tint modes — preset fallback and clock-following. Prints
/// [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class LightingSpike : SpikeBase
{
    public override void _Ready()
    {
        GD.Print("==================== LIGHTING SPIKE ====================");

        TestAnchors();
        TestMonotonicDarkening();
        TestFullRangeSanity();
        TestOutOfRangeClamps();
        TestStackScene();

        FinishAndQuit("LightingSpike");
    }

    // ---- Pure gradient ----

    private void TestAnchors()
    {
        GD.Print("-- gradient anchors --");

        var noon = Hd2dStack.EvaluateTint(720);
        Check($"noon is the Day color ({noon})",
            noon.IsEqualApprox(new Color(0.99f, 0.99f, 0.98f)));

        var dusk = Hd2dStack.EvaluateTint(1140);
        Check($"19:00 is duskish, R > B ({dusk})", dusk.R > dusk.B);

        var midnight = Hd2dStack.EvaluateTint(1440);
        Check($"24:00 is night-ish, B > R ({midnight})", midnight.B > midnight.R);

        var dawnStart = Hd2dStack.EvaluateTint(360);
        var dawnEnd = Hd2dStack.EvaluateTint(1800);
        Check($"6:00 is dawn-warm, R > B ({dawnStart})", dawnStart.R > dawnStart.B);
        Check($"30:00 is dawn-warm, R > B ({dawnEnd})", dawnEnd.R > dawnEnd.B);
        Check("all-nighter dawn matches morning dawn", dawnStart.IsEqualApprox(dawnEnd));
    }

    private void TestMonotonicDarkening()
    {
        GD.Print("-- 21:00 → 24:00 darkening --");

        bool monotonic = true;
        float prev = Luminance(Hd2dStack.EvaluateTint(1260));
        for (int m = 1261; m <= 1440; m++)
        {
            float lum = Luminance(Hd2dStack.EvaluateTint(m));
            if (lum >= prev)
            {
                monotonic = false;
                break;
            }
            prev = lum;
        }
        Check("luminance strictly decreases every minute 21:00 → 24:00", monotonic);
    }

    private void TestFullRangeSanity()
    {
        GD.Print("-- full-range sanity --");

        bool allValid = true;
        for (int m = 360; m <= 1800; m++)
        {
            var c = Hd2dStack.EvaluateTint(m);
            if (!ComponentValid(c.R) || !ComponentValid(c.G) || !ComponentValid(c.B))
            {
                GD.Print($"  invalid tint at minute {m}: {c}");
                allValid = false;
                break;
            }
        }
        Check("every minute in [360, 1800] yields finite components in [0, 1]", allValid);
    }

    private void TestOutOfRangeClamps()
    {
        GD.Print("-- out-of-range clamping --");

        var below = Hd2dStack.EvaluateTint(0);
        Check($"minute 0 clamps to the 6:00 dawn ({below})",
            below.IsEqualApprox(Hd2dStack.EvaluateTint(360)));

        var above = Hd2dStack.EvaluateTint(5000);
        Check($"minute 5000 clamps to the 30:00 dawn ({above})",
            above.IsEqualApprox(Hd2dStack.EvaluateTint(1800)));
    }

    // ---- Live scene ----

    private void TestStackScene()
    {
        GD.Print("-- hd2d_stack scene --");

        var packed = GD.Load<PackedScene>("res://scenes/fx/hd2d_stack.tscn");
        if (packed == null)
        {
            AbortFail("scenes/fx/hd2d_stack.tscn failed to load");
            return;
        }

        // Preset fallback branch (FollowClock=false — same branch a scene with no GameState hits).
        var presetStack = packed.Instantiate<Hd2dStack>();
        presetStack.FollowClock = false;
        presetStack.Preset = Hd2dStack.TimeOfDay.Night;
        AddChild(presetStack);
        var presetTint = presetStack.GetNode<CanvasModulate>("%Tint");
        Check($"FollowClock=false survives _Ready and applies the Night preset ({presetTint.Color})",
            presetTint.Color.IsEqualApprox(new Color(0.42f, 0.52f, 0.68f)));

        presetStack.Apply(Hd2dStack.TimeOfDay.Interior);
        Check($"Apply(Interior) still works ({presetTint.Color})",
            presetTint.Color.IsEqualApprox(new Color(0.94f, 0.88f, 0.80f)));
        presetStack.Free();

        // Clock-following branch (the autoload is live in a --path run).
        if (GameState.Instance != null)
        {
            var followStack = packed.Instantiate<Hd2dStack>();
            AddChild(followStack); // FollowClock defaults to true
            var followTint = followStack.GetNode<CanvasModulate>("%Tint");
            var expected = Hd2dStack.EvaluateTint(GameState.Instance.Clock.MinuteOfDay);
            Check($"FollowClock=true applies EvaluateTint(clock) on ready ({followTint.Color})",
                followTint.Color.IsEqualApprox(expected));
            followStack.Free(); // exercises the _ExitTree unsubscribe
        }
        else
        {
            GD.Print("  (GameState autoload absent — follow-clock branch not exercisable this run)");
        }
    }

    // ---- Helpers ----

    private static float Luminance(Color c) => 0.299f * c.R + 0.587f * c.G + 0.114f * c.B;

    private static bool ComponentValid(float v) => float.IsFinite(v) && v is >= 0f and <= 1f;
}
