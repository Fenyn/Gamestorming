using System.Collections.Generic;
using System.Linq;
using Godot;
using Ungilded.Content;
using Ungilded.Fx;

namespace Ungilded.Dev;

/// <summary>
/// The acid flask's impact effect, recorded through the effect watch (PrologueRunSpike.FxWatch.cs):
/// which creature each <see cref="AcidSplash"/> stood on, whether it was full or minor, its layers and
/// its body scale. Rendered, Encounter 3's flask hit number <see cref="AcidShotHit"/> is saved at
/// <see cref="AcidShotSeconds"/> and <see cref="AcidLateShotSeconds"/>, at full viewport size.
/// </summary>
public partial class PrologueRunSpike
{
    [Export] public float AcidShotSeconds { get; set; } = 0.15f;
    [Export] public float AcidLateShotSeconds { get; set; } = 0.5f;

    /// <summary>Which Encounter 3 flask hit the captures follow, counted from 1.</summary>
    [Export] public int AcidShotHit { get; set; } = 1;

    private static readonly string[] AcidDirectLayers = { "%Flash", "%Glass", "%Ring", "%Puddles", "%Light" };

    private sealed class SplashRecord : FxRecord
    {
        public SplashRecord(AcidSplash node, int encounter) : base(node, encounter)
        {
            Minor = node.Minor;
            ImpactHeight = node.ImpactHeight;
            FxScale = node.FxScale;
        }

        public bool Minor { get; }
        public float ImpactHeight { get; }
        public float FxScale { get; }
        public bool LayersMatch { get; set; }
        public float BodyScale { get; set; }
    }

    private readonly System.Collections.Generic.List<SplashRecord> _splashes = new();
    private int _acidHitsSeen;

    /// <summary>Persistent acid ticks per creature. Each tick is acid damage and plays a minor splash.</summary>
    private readonly System.Collections.Generic.Dictionary<PF2e.Core.ICharacter, int> _acidTicks = new();

    private void WatchAcidTicks()
    {
        foreach (var creature in _runner.Scene!.Session!.Team2)
            creature.Health.OnDamageTaken += e =>
            {
                if (e.Result.Cause == PF2e.Data.DamageCause.Persistent && e.Result.DamageType == PF2e.Data.DamageType.Acid)
                    _acidTicks[creature] = _acidTicks.GetValueOrDefault(creature) + 1;
            };
    }

    private void NoteAcidSplash(AcidSplash splash)
    {
        var record = Track(new SplashRecord(splash, _runner.CurrentEncounter)
        {
            BodyScale = splash.GetNode<Node3D>("%Body").Scale.X,
        });
        _splashes.Add(record);

        bool shown = AcidDirectLayers.All(n => splash.GetNode<Node3D>(n).Visible);
        bool hidden = AcidDirectLayers.All(n => !splash.GetNode<Node3D>(n).Visible);
        bool bodyPlays = splash.GetNode<GpuParticles3D>("%Splat").Emitting;
        bool lightPlays = splash.GetNode<AnimationPlayer>("%Anim").IsPlaying();
        record.LayersMatch = bodyPlays && (splash.Minor ? hidden && !lightPlays : shown && lightPlays);

        if (record.Encounter == 3 && !splash.Minor && ++_acidHitsSeen == AcidShotHit && !Headless)
            _ = CaptureAfterSpawn(record, $"flask hit {AcidShotHit}",
                ("acid_splash.png", AcidShotSeconds), ("acid_splash_late.png", AcidLateShotSeconds));
    }

    private void CheckAcidSplashes()
    {
        foreach (var s in _splashes)
            GD.Print($"[PrologueRun] acid splash E{s.Encounter} on {s.Unit?.Name ?? "?"} minor {s.Minor} "
                + $"fx group {s.InFxGroup} feet gap {s.FeetGap:0.000} impact {s.ImpactHeight:0.00} of bar {s.BarHeight:0.00} "
                + $"FxScale {s.FxScale:0.00} body scale {s.BodyScale:0.000} layers {s.LayersMatch} {s.Timing}");

        var e3 = _splashes.Where(s => s.Encounter == 3).ToArray();
        var full = e3.Where(s => !s.Minor).ToArray();
        var minor = e3.Where(s => s.Minor).ToArray();
        var target = full.Select(s => s.Unit).Distinct().ToArray();
        var onTarget = target.Length == 1 ? minor.Count(s => s.Unit == target[0]) : -1;
        int targetTicks = target.Length == 1 && target[0] != null ? _acidTicks.GetValueOrDefault(target[0]!) : 0;
        Check($"E3: each flask hit on the target spawned a full acid splash ({full.Length})", full.Length >= 2);
        Check($"E3: each rat the splash alone reached got a minor one ({minor.Length - onTarget} on other rats)",
            minor.Length - onTarget >= 2);
        Check($"E3: the full splashes stood on the flask's target, a minor one on it only for each persistent acid tick ({onTarget} for {targetTicks} ticks)",
            target.Length == 1 && target[0] != null && onTarget == targetTicks && minor.All(s => s.Unit != null));
        Check("E4: the flask on the Sewer Tyrant spawned a full acid splash", _splashes.Any(s => s.Encounter == 4
            && !s.Minor && s.Unit?.CreatureStats?.CreatureId == PrologueBestiary.SewerTyrantId));

        CheckWith("every acid splash joined the Fx group", _splashes.All(s => s.InFxGroup), Units(_splashes.Where(s => !s.InFxGroup)));
        CheckWith("every acid splash stood at its token's feet with its body under the HP bar",
            _splashes.All(OnToken), Units(_splashes.Where(s => !OnToken(s))));
        CheckWith("every full splash played all its layers and the light, every minor one only the body",
            _splashes.All(s => s.LayersMatch), Units(_splashes.Where(s => !s.LayersMatch)));
        CheckWith("every acid splash freed itself", _splashes.All(s => s.Freed), Units(_splashes.Where(s => !s.Freed)));
        CheckWith($"every Encounter 3 splash lived its Lifetime of game time, within {FxLifetimeSlack:0.0} s",
            e3.All(s => s.LivedItsLifetime(FxLifetimeSlack)), Units(e3.Where(s => !s.LivedItsLifetime(FxLifetimeSlack))));
    }

    private bool OnToken(SplashRecord s)
        => s.FeetGap <= FxFeetTolerance && s.ImpactHeight > 0f && s.ImpactHeight < s.BarHeight;
}
